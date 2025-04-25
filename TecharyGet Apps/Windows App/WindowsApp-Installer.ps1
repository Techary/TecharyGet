$folderPath = "c:\temp\WindowsAppInstallation"
$logFile = "$folderPath\WindowsApp-Install.log"
$filex64 = "$folderPath\WindowsApp_Installer_x64.msix"
$filearm64 = "$folderPath\WindowsApp_Installer-arm64.msix"
$arch = (Get-ComputerInfo).CSDescription

# Function to log messages
function Invoke-LogMessage {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "[$timestamp] $Message"
}

# Ensure the folder exists
if (-not (Test-Path -Path $folderPath)) {
    New-Item -ItemType Directory -Path $folderPath -Force
    Invoke-LogMessage "Created folder: $folderPath"
}

try {
# Define base URL for the installer
$baseUrl = "https://go.microsoft.com/fwlink/?linkid=2262633"

# Download installers
if ($arch -eq "ARM processor family") {
    Invoke-WebRequest -Uri $baseUrl -OutFile $filearm64
    Invoke-LogMessage "Downloaded ARM64 installer to $filearm64"
} else {
    Invoke-WebRequest -Uri $baseUrl -OutFile $filex64
    Invoke-LogMessage "Downloaded x64 installer to $filex64"
}

# Install 8x8 Work based on architecture
if ($arch -eq "ARM processor family") {
    Invoke-LogMessage "Downloaded arm64 installer to $local:filearm64"
    $renamedFile = Join-Path -Path $local:folderPath -ChildPath "WindowsApp_Installer_arm64.msix"
    Rename-Item -Path $local:filearm64 -NewName $renamedFile
    Invoke-LogMessage "Renamed installer to: $renamedFile"
    Add-AppxProvisionedPackage -Online -PackagePath "C:\temp\TecharyGetInstallationLogs\WindowsApp_Installer_arm64.msix" -SkipLicense
    Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
    Invoke-LogMessage "Removed installer: $renamedFile"
} else {
    Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
    $renamedFile = Join-Path -Path $local:folderPath -ChildPath "WindowsApp_Installer_x64.msix"
    Rename-Item -Path $local:filex64 -NewName $renamedFile
    Invoke-LogMessage "Renamed installer to: $renamedFile"
    Add-AppxProvisionedPackage -Online -PackagePath "C:\temp\TecharyGetInstallationLogs\WindowsApp_Installer_x64.msix" -SkipLicense
    Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
    Invoke-LogMessage "Removed installer: $renamedFile"
}
} catch {
    Invoke-LogMessage "Error installing MyDPD: $($_.Exception.Message)"
}