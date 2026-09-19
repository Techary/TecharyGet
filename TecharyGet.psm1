$Root = $PSScriptRoot
if (-not $Root) { $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }

# Dot-source Private first: Public functions depend on those helpers.
# A failure here is fatal - a half-loaded module is worse than no module,
# because the caller gets "command not found" instead of the real reason.
foreach ($Scope in 'Private', 'Public') {
    $Dir = Join-Path $Root $Scope
    if (-not (Test-Path $Dir)) { continue }

    foreach ($File in (Get-ChildItem -Path $Dir -Filter '*.ps1' -File)) {
        try {
            . $File.FullName
        }
        catch {
            throw "TecharyGet: failed to load '$Scope\$($File.Name)': $($_.Exception.Message)"
        }
    }
}

$PublicDir = Join-Path $Root 'Public'
if (Test-Path $PublicDir) {
    $ToExport = @((Get-ChildItem -Path $PublicDir -Filter '*.ps1' -File).BaseName)
    if ($ToExport.Count -gt 0) { Export-ModuleMember -Function $ToExport }
}
