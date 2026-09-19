function Get-GitHubInstaller {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Id,
        [string]$DownloadPath = "$env:TEMP\AppPackager",

        # A PAT lifts the GitHub API allowance from 60 to 5000 requests/hour.
        # Falls back to the environment so endpoints can be seeded centrally
        # without the token appearing in a command line or an RMM job log.
        [string]$GitHubToken = $env:TECHARYGET_GITHUB_TOKEN,

        # Resolved manifests are cached on disk, and the prebuilt index covers
        # the catalogue centrally. Repeat and retry installs of the same app
        # then cost no API calls at all.
        [int]$CacheHours = 24,
        [switch]$NoCache
    )

    Write-PackagerLog -Message "Querying GitHub Manifests for: $Id"

    # PS 5.1 on older builds still negotiates TLS 1.0 by default, which GitHub refuses.
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

    $CacheDir  = "$env:ProgramData\TecharyGet\ManifestCache"
    $CacheFile = Join-Path $CacheDir ("$Id.json" -replace '[\/:*?"<>|]', '_')

    $Headers = @{ 'User-Agent' = 'TecharyGet' }
    if ($GitHubToken) { $Headers['Authorization'] = "token $GitHubToken" }

    # 1. Detect Architecture
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { $SysArch = "arm64" }
    elseif ([Environment]::Is64BitOperatingSystem) { $SysArch = "x64" }
    else { $SysArch = "x86" }

    # --- RESOLVE MANIFEST METADATA -------------------------------------
    # Order: fresh cache -> live API -> stale cache. The stale fallback is
    # what keeps a rate-limited or offline site installing software.
    $Meta = $null

    if (-not $NoCache -and (Test-Path $CacheFile)) {
        $Age = (Get-Date) - (Get-Item $CacheFile).LastWriteTime
        if ($Age.TotalHours -lt $CacheHours) {
            try {
                $Cached = Get-Content $CacheFile -Raw | ConvertFrom-Json
                if ($Cached.Arch -eq $SysArch -and $Cached.Url) {
                    Write-PackagerLog -Message "Using cached manifest for $Id (v$($Cached.Version), $([int]$Age.TotalHours)h old). No API call needed."
                    $Meta = $Cached
                }
            }
            catch {
                Write-PackagerLog -Message "Manifest cache for $Id unreadable, re-resolving." -Severity Warning
            }
        }
    }

    # Prebuilt index: one CDN file covering the whole catalogue, refreshed
    # nightly in CI. Costs no api.github.com allowance at all.
    if (-not $Meta -and -not $NoCache) {
        $Indexed = Get-IndexedManifest -Id $Id -SysArch $SysArch
        if ($Indexed) {
            Write-PackagerLog -Message "Resolved $Id v$($Indexed.Version) from the prebuilt index. No API call needed."
            $Meta = $Indexed
        }
    }

    if (-not $Meta) {
        # winget's own latest_version for this package. Authoritative, and it
        # avoids re-deriving the version from a directory listing that also
        # contains architectures, channels and nested package namespaces.
        $KnownVersion = $null
        try {
            $Entry = Get-DetectionEntry -Id $Id
            if ($Entry -and $Entry.Version) {
                $KnownVersion = $Entry.Version
                Write-PackagerLog -Message "Index gives $Id latest version $KnownVersion; skipping version discovery."
            }
        } catch { }

        try {
            $Meta = Resolve-GitHubManifest -Id $Id -SysArch $SysArch -Headers $Headers -KnownVersion $KnownVersion

            try {
                if (-not (Test-Path $CacheDir)) { New-Item -ItemType Directory -Path $CacheDir -Force -ErrorAction Stop | Out-Null }
                $Meta | ConvertTo-Json -Depth 4 | Set-Content -Path $CacheFile -Encoding UTF8 -ErrorAction Stop
            }
            catch {
                Write-PackagerLog -Message "Could not cache manifest for ${Id}: $($_.Exception.Message)" -Severity Warning
            }
        }
        catch {
            $Reason = $_.Exception.Message
            $IsRateLimit = $Reason -match '\(403\)|rate limit'

            if ($IsRateLimit -and -not $GitHubToken) {
                Write-PackagerLog -Message "GitHub API rate limit hit (60/hour per public IP, unauthenticated). Supply -GitHubToken or set TECHARYGET_GITHUB_TOKEN to raise this to 5000/hour." -Severity Warning
            }

            if (-not $NoCache -and (Test-Path $CacheFile)) {
                try {
                    $Stale = Get-Content $CacheFile -Raw | ConvertFrom-Json
                    if ($Stale.Arch -eq $SysArch -and $Stale.Url) {
                        $StaleAge = [int]((Get-Date) - (Get-Item $CacheFile).LastWriteTime).TotalHours
                        Write-PackagerLog -Message "Live resolve failed ($Reason). Falling back to cached manifest for $Id, ${StaleAge}h old (v$($Stale.Version))." -Severity Warning
                        $Meta = $Stale
                    }
                }
                catch { }
            }

            if (-not $Meta) {
                Write-PackagerLog -Message "GitHub Scraping Failed: $Reason" -Severity Error
                throw $_
            }
        }
    }

    try {
        $SelectedUrl     = $Meta.Url
        $SelectedArgs    = $Meta.SilentArgs
        $SelectedType    = $Meta.InstallerType
        $SelectedCode    = $Meta.ProductCode
        $LatestVersion   = $Meta.Version

        # --- PER-PACKAGE OVERRIDES ---
        # Applied after the cache read so a correction here takes effect
        # immediately rather than waiting for the cache to expire.
        switch ($Id) {
            "Dell.CommandUpdate"        { $SelectedArgs = '/s /l="C:\Windows\Temp\DellCommand.log" /v"/qn"' }
            "8x8.Work"                  { $SelectedArgs = "/qn /norestart" }
            "SublimeHQ.SublimeText.4"   { $SelectedArgs = "/VERYSILENT /NORESTART" }
        }

        # --- DOWNLOAD ---
        $UriObj = [System.Uri]$SelectedUrl
        $RealExtension = [System.IO.Path]::GetExtension($UriObj.LocalPath).ToLower()
        if (-not $RealExtension) { $RealExtension = ".$SelectedType" }
        $FileName = "$Id-$LatestVersion-$SysArch$RealExtension"

        if (Test-Path $DownloadPath) { Remove-Item "$DownloadPath\*" -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
        $FullPath = Join-Path $DownloadPath $FileName

        # The installer itself comes from the vendor CDN, not the GitHub API,
        # so it is never rate limited.
        Write-PackagerLog -Message "Downloading to $FullPath..."
        Invoke-WebRequest -Uri $SelectedUrl -OutFile $FullPath -UseBasicParsing -UserAgent "Mozilla/5.0"

        return [PSCustomObject]@{
            Name          = $Id
            InstallerPath = $FullPath
            FileName      = $FileName
            SilentArgs    = $SelectedArgs
            InstallerType = $SelectedType
            ProductCode   = $SelectedCode
        }
    }
    catch {
        Write-PackagerLog -Message "Installer download failed: $_" -Severity Error
        throw $_
    }
}
