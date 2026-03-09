$Root = Split-Path $MyInvocation.MyCommand.Path
Get-ChildItem -Path "$Root\Private\*.ps1" | ForEach-Object { . $_.FullName }
Get-ChildItem -Path "$Root\Public\*.ps1"  | ForEach-Object { . $_.FullName }
Export-ModuleMember -Function (Get-ChildItem -Path "$Root\Public\*.ps1").BaseName
