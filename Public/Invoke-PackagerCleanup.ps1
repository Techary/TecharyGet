function Invoke-PackagerCleanup {
    [CmdletBinding()]
    param ([string[]]$Paths = @("$env:TEMP\AppPackager"), [switch]$Force)
    process {
        foreach ($Path in $Paths) {
            if (Test-Path $Path) {
                Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
                Write-PackagerLog -Message "Cleaned: $Path"
            }
        }
    }
}
