function Get-ManifestVersionKey {
    param([string]$Name)

    # winget version folders are not reliably [Version]-parseable: "1.2.3-beta",
    # "20240101", "2.0" and "1.2.3.4.5" all occur. Casting to [Version] and
    # discarding the failures silently dropped real releases, and threw outright
    # for packages where no folder happened to parse. Build a zero-padded key so
    # ordinary string sorting gives correct numeric ordering instead.
    # A winget version folder starts with a digit. Siblings like "x86",
    # "arm64", "Canary", "PTB" and "Development" are architectures or release
    # channels, not versions, and must not be ranked as such: "x86" yields 86,
    # which outranks the first component of 1.0.9258 and wins the sort. Discord
    # carries all five of those alongside 144 real versions.
    if ($Name -notmatch '^v?\d') { return $null }

    $Numbers = [regex]::Matches($Name, '\d+') | ForEach-Object { $_.Value }
    if (-not $Numbers) { return $null }

    # Always emit the same number of components. With variable-length keys
    # "1.2" sorted ABOVE "1.2.3", because the separator that terminated the
    # shorter key compared higher than the '.' in the longer one.
    $Parts = New-Object System.Collections.Generic.List[string]
    foreach ($N in ($Numbers | Select-Object -First 6)) {
        try { $Parts.Add('{0:D12}' -f [int64]$N) } catch { $Parts.Add('{0:D12}' -f 0) }
    }
    while ($Parts.Count -lt 6) { $Parts.Add('{0:D12}' -f 0) }

    # Tiebreak on equal numbers: prefer the stable release over a prerelease,
    # so "1.2.3" beats "1.2.3-beta" instead of the winner being arbitrary.
    $Rank = if ($Name -match '[A-Za-z]') { '0' } else { '9' }

    return (($Parts -join '.') + '|' + $Rank)
}

function Resolve-GitHubManifest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$Id,
        [Parameter(Mandatory=$true)][string]$SysArch,
        [Parameter(Mandatory=$true)][hashtable]$Headers
    )

    # 2. Construct API Path
    $IdPath = $Id.Replace(".", "/")
    $FirstChar = $Id.Substring(0,1).ToLower()
    $BaseApi = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$FirstChar/$IdPath"

    # 3. Get Version (Latest)  [API call 1 of 2]
    $VersionsResponse = Invoke-RestMethod -Uri $BaseApi -Method Get -Headers $Headers -ErrorAction Stop

    $LatestVersionObj = $VersionsResponse |
        Where-Object { $_.type -eq "dir" } |
        Select-Object *, @{N='SortKey'; E={ Get-ManifestVersionKey -Name $_.name }} |
        Where-Object { $null -ne $_.SortKey } |
        Sort-Object SortKey -Descending |
        Select-Object -First 1

    if (-not $LatestVersionObj) { throw "Could not determine a valid version folder for '$Id'." }
    $LatestVersion = $LatestVersionObj.Name

    # 4. Get Manifest  [API call 2 of 2]
    $VersionPath = "$BaseApi/$LatestVersion"
    $VersionFiles = Invoke-RestMethod -Uri $VersionPath -Method Get -Headers $Headers -ErrorAction Stop
    $InstallerFile = $VersionFiles | Where-Object { $_.name -like "*.installer.yaml" } | Select-Object -First 1
    if (-not $InstallerFile) { throw "No installer YAML found for '$Id' $LatestVersion." }

    # Served from raw.githubusercontent.com, which is CDN-backed and not
    # subject to the API rate limit, so no credentials are sent here.
    $YamlContent = Invoke-RestMethod -Uri $InstallerFile.download_url -Headers @{ 'User-Agent' = 'TecharyGet' } -ErrorAction Stop

    # --- PARSING LOGIC ---
    # We split by "- Architecture" to separate blocks, but keep the delimiter to help identification
    $Blocks = $YamlContent -split '(?=-\s*Architecture:)'

    $SelectedUrl = $null
    $SelectedArgs = $null
    $SelectedType = "exe"
    $SelectedCode = $null

    foreach ($Block in $Blocks) {
        if ([string]::IsNullOrWhiteSpace($Block)) { continue }

        if ($Block -match 'Architecture:\s*([a-zA-Z0-9]+)') {
            $BlockArch = $Matches[1].Trim()

            if ($BlockArch -eq $SysArch) {
                if ($Block -match 'InstallerUrl:\s*["'']?([^"''\r\n]+)["'']?') { $SelectedUrl = $Matches[1].Trim() }
                if ($Block -match 'InstallerType:\s*([a-zA-Z0-9]+)') { $SelectedType = $Matches[1].Trim() }

                if ($Block -match 'Silent:\s*(.+)') { $SelectedArgs = $Matches[1].Trim().Trim("'").Trim('"') }
                elseif ($Block -match 'SilentWithProgress:\s*(.+)') { $SelectedArgs = $Matches[1].Trim().Trim("'").Trim('"') }

                if ($Block -match 'ProductCode:\s*["'']?([^"''\r\n]+)["'']?') { $SelectedCode = $Matches[1].Trim() }

                if ($SelectedUrl) { break }
            }
        }
    }

    # Fallbacks (Global properties if not in block)
    if (-not $SelectedUrl) { if ($YamlContent -match 'InstallerUrl:\s*["'']?([^"''\r\n]+)["'']?') { $SelectedUrl = $Matches[1].Trim() } }
    if (-not $SelectedArgs) {
         if ($YamlContent -match 'Silent:\s*(.+)') { $SelectedArgs = $Matches[1].Trim().Trim("'").Trim('"') }
    }
    if (-not $SelectedCode) {
        if ($YamlContent -match 'ProductCode:\s*["'']?([^"''\r\n]+)["'']?') { $SelectedCode = $Matches[1].Trim() }
    }

    if (-not $SelectedUrl) { throw "No InstallerUrl found in the manifest for '$Id' $LatestVersion." }

    return [PSCustomObject]@{
        Id            = $Id
        Version       = $LatestVersion
        Arch          = $SysArch
        Url           = $SelectedUrl
        SilentArgs    = $SelectedArgs
        InstallerType = $SelectedType
        ProductCode   = $SelectedCode
        ResolvedUtc   = (Get-Date).ToUniversalTime().ToString('o')
    }
}
