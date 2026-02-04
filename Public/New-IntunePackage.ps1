function New-IntunePackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Id,  # e.g. "Dell.CommandUpdate"

        [string]$OutputFolder = "C:\IntunePackages"
    )

    # --- 1. SETUP ---
    $PackagerTemp = "$env:TEMP\IntunePackager_Working\$Id"
    $SourceDir = "$PackagerTemp\Source"
    $IntuneUtil = "$env:TEMP\IntuneWinAppUtil.exe"

    # Clean Workspace
    if (Test-Path $PackagerTemp) { Remove-Item $PackagerTemp -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -Path $SourceDir -ItemType Directory -Force | Out-Null
    
    # Ensure Output Dir
    if (-not (Test-Path $OutputFolder)) { New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null }

    # Ensure Intune Utility
    if (-not (Test-Path $IntuneUtil)) {
        Write-PackagerLog -Message "Downloading IntuneWinAppUtil.exe..."
        Invoke-WebRequest "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe" -OutFile $IntuneUtil
    }

    # --- 2. GENERATE INSTALL.PS1 (The One-Liner) ---
    $InstallScript = @"
# Install Trigger for $Id
`$ErrorActionPreference = 'Stop'

# Try to load the module if not already loaded (Assumes it is installed on the PC)
Import-Module TecharyGet -ErrorAction SilentlyContinue

Write-Host "Triggering Install for: $Id"
Install-SmartApp -Id "$Id"
"@
    Set-Content -Path "$SourceDir\Install.ps1" -Value $InstallScript

    # --- 3. GENERATE UNINSTALL.PS1 (The One-Liner) ---
    $UninstallScript = @"
# Uninstall Trigger for $Id
`$ErrorActionPreference = 'Stop'

Import-Module TecharyGet -ErrorAction SilentlyContinue

Write-Host "Triggering Uninstall for: $Id"
Uninstall-SmartApp -Name "$Id"
"@
    Set-Content -Path "$SourceDir\Uninstall.ps1" -Value $UninstallScript

    # --- 4. PACKAGE IT ---
    Write-PackagerLog -Message "Packaging scripts into .intunewin..."
    
    $Process = Start-Process -FilePath $IntuneUtil `
                             -ArgumentList "-c `"$SourceDir`"", "-s `"Install.ps1`"", "-o `"$OutputFolder`"", "-q" `
                             -PassThru -Wait -NoNewWindow
    
    if ($Process.ExitCode -eq 0) {
        $Original = Join-Path $OutputFolder "Install.intunewin"
        $Final = Join-Path $OutputFolder "$Id.intunewin"
        if (Test-Path $Original) { Move-Item $Original $Final -Force }
        
        Write-PackagerLog -Message "SUCCESS: Package created at $Final"
        Invoke-Item $OutputFolder
    } else {
        Write-PackagerLog -Message "Packaging Failed with Exit Code $($Process.ExitCode)" -Severity Error
    }
}