function Get-DetectionIndexUrl {
    # Built nightly from Microsoft's own published winget source index, so it
    # covers EVERY package in the winget repository rather than the curated
    # Index/Catalog.json. Served from raw.githubusercontent.com, which is
    # CDN-backed and carries no api.github.com rate limit.
    return "https://raw.githubusercontent.com/Techary/TecharyGet/manifest-index/Detection.json"
}

function Get-DetectionIndex {
    <#
    .SYNOPSIS
        The full package-to-ARP mapping used to identify installed software.
    #>
    [CmdletBinding()]
    param(
        [int]$CacheHours = 12,
        [switch]$NoRefresh,
        [switch]$Force
    )

    $CacheDir  = "$env:ProgramData\TecharyGet"
    $CachePath = Join-Path $CacheDir 'DetectionIndex.json'
    $HaveCache = Test-Path $CachePath

    try {
        if (-not (Test-Path $CacheDir)) { New-Item -ItemType Directory -Path $CacheDir -Force -ErrorAction Stop | Out-Null }

        # -NoRefresh means "do not re-download a copy we already have", NOT
        # "never download". An endpoint that only runs detection installs
        # nothing, so nothing else would ever fetch this for it.
        $NeedUpdate = $true
        if ($HaveCache -and -not $Force) {
            $Age = (Get-Date) - (Get-Item $CachePath).LastWriteTime
            if ($NoRefresh -or $Age.TotalHours -lt $CacheHours) { $NeedUpdate = $false }
        }

        if ($NeedUpdate) {
            try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

            # Stage and parse before promoting, so a captive portal or proxy
            # page returning HTTP 200 with HTML cannot poison the cache.
            $StagePath = "$CachePath.tmp"
            Invoke-WebRequest -Uri (Get-DetectionIndexUrl) -OutFile $StagePath -UseBasicParsing -ErrorAction Stop

            $Parsed = Get-Content -Path $StagePath -Raw | ConvertFrom-Json
            if (-not $Parsed.Packages) { throw "Detection index downloaded but contains no Packages block." }

            Move-Item -Path $StagePath -Destination $CachePath -Force -ErrorAction Stop
            Write-PackagerLog -Message "Detection index refreshed ($($Parsed.PackageCount) packages, generated $($Parsed.Generated))."
        }
    }
    catch {
        # A miss is not an error: detection falls back to name matching.
        Write-PackagerLog -Message "Could not refresh the detection index ($($_.Exception.Message)). Using local copy if present." -Severity Warning
        Remove-Item "$CachePath.tmp" -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path $CachePath)) { return $null }

    try { return (Get-Content -Path $CachePath -Raw | ConvertFrom-Json) }
    catch {
        Write-PackagerLog -Message "Detection index cache is unreadable: $($_.Exception.Message)" -Severity Warning
        return $null
    }
}

function Get-DetectionEntry {
    <#
    .SYNOPSIS
        ARP product codes and MSIX package family names for one package ID.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Id,
        [switch]$NoRefresh
    )

    $Index = Get-DetectionIndex -NoRefresh:$NoRefresh
    if (-not $Index -or -not $Index.Packages) { return $null }

    $Entry = $Index.Packages.$Id
    if (-not $Entry) { return $null }

    return [PSCustomObject]@{
        Id           = $Id
        Name         = $Entry.Name
        Version      = $Entry.Version
        ProductCodes = @($Entry.ProductCodes)
        Pfns         = @($Entry.Pfns)
    }
}
