<#
.SYNOPSIS
    Proves the name normaliser matches winget's, using winget's own vectors.

.DESCRIPTION
    Line N of InputNames.txt and InputPublishers.txt must normalise to line N
    of NormalizationInitialIds.txt, formatted "<publisher>.<name>"
    (NameNormalizationTests.cpp:93-95).

    The C++ test calls Normalize without FoldCase, so the expected values
    keep their original case. Our input is folded, so the comparison is
    case-insensitive.

    Exits non-zero on any mismatch, so CI fails on a drift.
#>
[CmdletBinding()]
param([int]$ShowFailures = 15)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

Import-Module (Join-Path $Root 'TecharyGet.psd1') -Force
$Module = Get-Module TecharyGet

$Corpus = Join-Path $Root 'Tests\corpus'
$Names  = Get-Content (Join-Path $Corpus 'InputNames.txt')
$Pubs   = Get-Content (Join-Path $Corpus 'InputPublishers.txt')
$Want   = Get-Content (Join-Path $Corpus 'NormalizationInitialIds.txt')

if ($Names.Count -ne $Want.Count -or $Pubs.Count -ne $Want.Count) {
    throw "Corpus files are not aligned: $($Names.Count) / $($Pubs.Count) / $($Want.Count)"
}

$Failures = [Collections.Generic.List[object]]::new()

for ($i = 0; $i -lt $Want.Count; $i++) {
    $n = & $Module { Get-WgNormalizedName -Name $args[0] } $Names[$i]
    $p = & $Module { Get-WgNormalizedPublisher -Publisher $args[0] } $Pubs[$i]
    $got = '{0}.{1}' -f $p, $n.Name

    if (-not [string]::Equals($got, $Want[$i].Trim(), [StringComparison]::OrdinalIgnoreCase)) {
        $Failures.Add([pscustomobject]@{
            Line = $i + 1; InName = $Names[$i]; InPublisher = $Pubs[$i]
            Expected = $Want[$i].Trim(); Actual = $got
        })
    }
}

$Pass = $Want.Count - $Failures.Count
Write-Host ("normaliser corpus: {0}/{1} pass" -f $Pass, $Want.Count)

if ($Failures.Count -gt 0) {
    Write-Host ""
    Write-Host ("first {0} failures:" -f [Math]::Min($ShowFailures, $Failures.Count))
    foreach ($f in ($Failures | Select-Object -First $ShowFailures)) {
        Write-Host ("  line {0}" -f $f.Line)
        Write-Host ("    name      : '{0}'" -f $f.InName)
        Write-Host ("    publisher : '{0}'" -f $f.InPublisher)
        Write-Host ("    expected  : {0}" -f $f.Expected)
        Write-Host ("    actual    : {0}" -f $f.Actual)
    }
    exit 1
}

# Anchors from NameNormalizationTests.cpp:110-155 that the corpus does not
# cover, because they assert the architecture field rather than the string.
$ArchCases = @(
    @{ In = 'Name';            Arch = 'Unknown' }
    @{ In = 'Name x86';        Arch = 'X86' }
    @{ In = 'Name x86_64';     Arch = 'X64' }
    @{ In = 'Name (64 bit)';   Arch = 'X64' }
    @{ In = 'Name 32/64 bit';  Arch = 'Unknown' }
    @{ In = 'Fox86';           Arch = 'Unknown' }
)
$ArchFail = 0
foreach ($c in $ArchCases) {
    $r = & $Module { Get-WgNormalizedName -Name $args[0] } $c.In
    if ($r.Architecture -ne $c.Arch) {
        $ArchFail++
        Write-Host ("architecture: '{0}' expected {1}, got {2}" -f $c.In, $c.Arch, $r.Architecture)
    }
}
Write-Host ("architecture anchors: {0}/{1} pass" -f ($ArchCases.Count - $ArchFail), $ArchCases.Count)
if ($ArchFail -gt 0) { exit 1 }

Write-Host "all normaliser checks passed"
