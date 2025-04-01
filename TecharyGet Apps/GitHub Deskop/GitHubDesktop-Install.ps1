$folderPath = "c:\temp\visualstudiocode"
$logFile = "$folderPath\GitHubDesktopInstaller.log"
$filex64 = "$folderPath\GitHubDesktopInstallerx64.msi"
$filearm64 = "$folderPath\GitHubDesktopInstallerarm64.msi"
$arch = get-computerinfo
$Download = New-Object net.webclient

# Function to log messages
function Invoke-LogMessage
 {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "[$timestamp] $Message"
}

# Check Folder exists
if (-not (Test-Path -Path $folderPath)) {
    New-Item -ItemType Directory -Path $folderPath -Force
    Invoke-LogMessage
     "Created folder: $folderPath"
}

try {
    # Download installers
    if ($arch -eq "ARM processor family") {
        $Download.DownloadFile("https://central.github.com/deployments/desktop/desktop/latest/win32?format=msi", "$filearm64")
        Invoke-LogMessage
         "Downloaded ARM64 installer to $filearm64"
    } else {
        $Download.DownloadFile("https://central.github.com/deployments/desktop/desktop/latest/win32?format=msi", "$filex64")
        Invoke-LogMessage
         "Downloaded x64 installer to $filex64"
    }
    # Install GitHub Desktop" based on architecture
    if ($arch.CSDescription -eq "ARM processor family") {
        Start-Process -FilePath $filearm64 -ArgumentList "/qn /norestart" -Wait
        Invoke-LogMessage "Successfully installed GitHub Desktop"
    } else {
        Start-Process -FilePath $filex64 -ArgumentList "/qn /norestart" -Wait
        Invoke-LogMessage "Successfully installed GitHub Desktop"
    }
} catch {
    Invoke-LogMessage
     "Error: $($_.Exception.Message)"
    Write-Host "An error occurred. Check the log file at $logFile for details."
}