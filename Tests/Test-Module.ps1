<#
.SYNOPSIS
    Structural checks that every change to this module must pass.

.DESCRIPTION
    Each of these corresponds to a defect that reached a production endpoint
    because nothing checked for it:

      parse        - a stray scope qualifier stopped the module loading
      manifest     - FunctionsToExport advertised a function with no file
      import       - a file that failed to dot-source took its functions
                     with it, surfacing later as "command not found"
      exports      - the manifest and the files on disk disagreed
      encoding     - a control character in a workflow file made it
                     unparseable, so the Action produced no jobs at all
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Fail = 0
function Assert-Ok { param([string]$Name, [bool]$Ok, [string]$Detail = '')
    if ($Ok) { Write-Host ("  pass  {0}" -f $Name) }
    else { $script:Fail++; Write-Host ("  FAIL  {0}  {1}" -f $Name, $Detail) }
}

Write-Host 'parse'
foreach ($f in (Get-ChildItem $Root -Recurse -Include *.ps1, *.psm1 -File)) {
    $errs = $null
    [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs) | Out-Null
    if ($errs) { Assert-Ok $f.Name $false ($errs[0].Message) }
}
if ($Fail -eq 0) { Write-Host '  pass  every .ps1 and .psm1 parses' }

Write-Host 'manifest and import'
$manifest = Join-Path $Root 'TecharyGet.psd1'
try { $m = Test-ModuleManifest $manifest -ErrorAction Stop; Assert-Ok 'Test-ModuleManifest' $true }
catch { Assert-Ok 'Test-ModuleManifest' $false $_.Exception.Message }
try { Import-Module $manifest -Force -ErrorAction Stop; Assert-Ok 'Import-Module' $true }
catch { Assert-Ok 'Import-Module' $false $_.Exception.Message }

Write-Host 'exports match the files on disk'
$declared = @((Import-PowerShellDataFile $manifest).FunctionsToExport)
$present   = @((Get-ChildItem (Join-Path $Root 'Public') -Filter *.ps1 -File).BaseName)
$phantom   = @($declared | Where-Object { $_ -notin $present })
$unexported= @($present  | Where-Object { $_ -notin $declared })
Assert-Ok 'no exported function without a file' ($phantom.Count -eq 0) ($phantom -join ', ')
if ($unexported.Count) { Write-Host ("  note  present but not exported: {0}" -f ($unexported -join ', ')) }

Write-Host 'file encoding'
foreach ($f in (Get-ChildItem (Join-Path $Root '.github') -Recurse -Include *.yml, *.yaml -File)) {
    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    $ctrl  = @($bytes | Where-Object { $_ -lt 9 -or ($_ -gt 13 -and $_ -lt 32) })
    $cr    = @($bytes | Where-Object { $_ -eq 13 })
    Assert-Ok ("{0}: no control characters" -f $f.Name) ($ctrl.Count -eq 0) ("found {0}" -f $ctrl.Count)
    Assert-Ok ("{0}: LF line endings" -f $f.Name) ($cr.Count -eq 0) ("found {0} CR" -f $cr.Count)
}

Write-Host ''
if ($Fail -gt 0) { Write-Host ("{0} check(s) failed" -f $Fail); exit 1 }
Write-Host 'all structural checks passed'
