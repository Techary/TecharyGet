function Get-ManifestIndexUrl {
    # Published by .github/workflows/build-manifest-index.yml to a dedicated
    # orphan branch, so a nightly refresh never touches code history.
    # raw.githubusercontent.com is CDN-backed and is NOT subject to the
    # api.github.com rate limit, which is the entire point of the index.
    return "https://raw.githubusercontent.com/Techary/TecharyGet/manifest-index/Manifests.json"
}

function Get-ManifestIndex {
    [CmdletBinding()]
    param(
        [int]$CacheHours = 12,
        [switch]$Force
    )

    $CacheDir  = "$env:ProgramData\TecharyGet"
    $CachePath = Join-Path $CacheDir 'ManifestIndex.json'

    try {
        if (-not (Test-Path $CacheDir)) { New-Item -ItemType Directory -Path $CacheDir -Force -ErrorAction Stop | Out-Null }

        $NeedUpdate = $true
        if (-not $Force -and (Test-Path $CachePath)) {
            $Age = (Get-Date) - (Get-Item $CachePath).LastWriteTime
            if ($Age.TotalHours -lt $CacheHours) { $NeedUpdate = $false }
        }

        if ($NeedUpdate) {
            try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

            # Stage and parse before promoting, so a captive portal or proxy
            # page returning HTTP 200 with HTML cannot poison the cache.
            $StagePath = "$CachePath.tmp"
            Invoke-WebRequest -Uri (Get-ManifestIndexUrl) -OutFile $StagePath -UseBasicParsing -ErrorAction Stop

            $Parsed = Get-Content -Path $StagePath -Raw | ConvertFrom-Json
            if (-not $Parsed.Packages) { throw "Index downloaded but contains no Packages block." }

            Move-Item -Path $StagePath -Destination $CachePath -Force -ErrorAction Stop
            Write-PackagerLog -Message "Manifest index refreshed ($($Parsed.PackageCount) packages, generated $($Parsed.Generated))."
        }
    }
    catch {
        # An index miss is not an error: the live API path still works.
        Write-PackagerLog -Message "Could not refresh manifest index ($($_.Exception.Message)). Using local copy if present." -Severity Warning
        Remove-Item "$CachePath.tmp" -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path $CachePath)) { return $null }

    try { return (Get-Content -Path $CachePath -Raw | ConvertFrom-Json) }
    catch {
        Write-PackagerLog -Message "Manifest index cache is unreadable: $($_.Exception.Message)" -Severity Warning
        return $null
    }
}

function Get-IndexedManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Id,
        [Parameter(Mandatory=$true)][string]$SysArch
    )

    $Index = Get-ManifestIndex
    if (-not $Index -or -not $Index.Packages) { return $null }

    $Entry = $Index.Packages.$Id
    if (-not $Entry) { return $null }

    $ForArch = $Entry.$SysArch
    if (-not $ForArch -or -not $ForArch.Url) { return $null }

    # Shaped identically to Resolve-GitHubManifest so callers can use either.
    return [PSCustomObject]@{
        Id            = $Id
        Version       = $ForArch.Version
        Arch          = $SysArch
        Url           = $ForArch.Url
        SilentArgs    = $ForArch.SilentArgs
        InstallerType = $ForArch.InstallerType
        ProductCode   = $ForArch.ProductCode
        ResolvedUtc   = $Index.Generated
        Source        = 'index'
    }
}
