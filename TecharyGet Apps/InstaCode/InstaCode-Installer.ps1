$folderPath = "c:\temp\InstaCodeInstallation"
$logFile = "$folderPath\InstaCode-Install.log"
$filex64 = "$folderPath\InstaCode_Installer_x64.msi"
$filearm64 = "$folderPath\InstaCode_Installer-arm64.msi"
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
    $baseUrl = "https://download.whsoftware.com/%%UpdateDownloadFolder%%/ICUpdate.exe"

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
        $renamedFile = Join-Path -Path $local:folderPath -ChildPath "InstaCode_Installer_arm64.exe"
        Rename-Item -Path $local:filearm64 -NewName $renamedFile
        Invoke-LogMessage "Renamed installer to: $renamedFile"
        Start-Process -FilePath $renamedFile -ArgumentList "--Silent" -Wait -ErrorAction Stop
        Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
        Invoke-LogMessage "Removed installer: $renamedFile"
    } else {
        Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
        $renamedFile = Join-Path -Path $local:folderPath -ChildPath "InstaCode_Installer_x64.exe"
        Rename-Item -Path $local:filex64 -NewName $renamedFile
        Invoke-LogMessage "Renamed installer to: $renamedFile"
        Start-Process -FilePath $renamedFile -ArgumentList "--Silent" -Wait -ErrorAction Stop
        Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
        Invoke-LogMessage "Removed installer: $renamedFile"
    }
} catch {
    Invoke-LogMessage "Error installing MyDPD: $($_.Exception.Message)"
}