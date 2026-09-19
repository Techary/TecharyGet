<#
.SYNOPSIS
    Pre-resolves winget-pkgs manifests into a single JSON index.

.DESCRIPTION
    Runs in CI, not on endpoints. Resolving a package costs two
    api.github.com calls; doing it once here and publishing the result means
    endpoints read one file from raw.githubusercontent.com instead, which is
    CDN-backed and not subject to the API rate limit.

    A package that fails to resolve is reported and skipped. The build only
    fails if every package failed, so one delisted app cannot stop the
    nightly refresh.
#>
[CmdletBinding()]
param(
    [string]$CatalogPath = 'Index/Catalog.json',
    [string]$OutputPath = 'Index/Manifests.json',
    [string[]]$Architectures = @('x64', 'arm64'),
    [string]$GitHubToken = $env:GITHUB_TOKEN
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\Private\Resolve-GitHubManifest.ps1')

$Headers = @{ 'User-Agent' = 'TecharyGet-IndexBuilder' }
if ($GitHubToken) {
    $Headers['Authorization'] = "token $GitHubToken"
    Write-Host "Authenticated to the GitHub API (5000 requests/hour)."
} else {
    Write-Warning "No token supplied. Falling back to 60 requests/hour, which will not cover a full catalogue."
}

$Catalog = Get-Content -Path $CatalogPath -Raw | ConvertFrom-Json
$Ids = @($Catalog.Packages | Sort-Object)
Write-Host "Catalogue contains $($Ids.Count) package(s); resolving $($Architectures -join ', ')."

$Packages = [ordered]@{}
$Ok = 0
$Failed = New-Object System.Collections.Generic.List[string]

foreach ($Id in $Ids) {
    $PerArch = [ordered]@{}

    foreach ($Arch in $Architectures) {
        try {
            $Meta = Resolve-GitHubManifest -Id $Id -SysArch $Arch -Headers $Headers
            $PerArch[$Arch] = [ordered]@{
                Version       = $Meta.Version
                Url           = $Meta.Url
                SilentArgs    = $Meta.SilentArgs
                InstallerType = $Meta.InstallerType
                ProductCode   = $Meta.ProductCode
            }
            Write-Host ("  ok    {0,-34} {1,-6} v{2}" -f $Id, $Arch, $Meta.Version)
        }
        catch {
            # Most packages genuinely have no arm64 installer. Only an x64
            # failure is worth counting as a real failure.
            $Level = if ($Arch -eq 'x64') { 'warn ' } else { 'skip ' }
            Write-Host ("  {0} {1,-34} {2,-6} {3}" -f $Level, $Id, $Arch, $_.Exception.Message)
        }
    }

    if ($PerArch.Count -gt 0) {
        $Packages[$Id] = $PerArch
        $Ok++
    } else {
        $Failed.Add($Id)
    }
}

if ($Ok -eq 0) {
    throw "Every package in the catalogue failed to resolve. Refusing to publish an empty index."
}

$Index = [ordered]@{
    Generated    = (Get-Date).ToUniversalTime().ToString('o')
    Source       = 'microsoft/winget-pkgs'
    PackageCount = $Ok
    Packages     = $Packages
}

$Dir = Split-Path $OutputPath -Parent
if ($Dir -and -not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
$Index | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputPath -Encoding UTF8

Write-Host ""
Write-Host "Wrote $OutputPath with $Ok package(s)."
if ($Failed.Count -gt 0) { Write-Warning "Unresolved: $($Failed -join ', ')" }
