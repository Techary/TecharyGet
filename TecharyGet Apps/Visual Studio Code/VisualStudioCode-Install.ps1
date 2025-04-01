$folderPath = "c:\temp\visualstudiocodeinstallation"
$logFile = "$folderPath\visualstudiocode.log"
$filex64 = "$folderPath\visualstudiocodeinstallerx64.exe"
$filearm64 = "$folderPath\visualstudiocodeinstallerarm64.exe"
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
        $Download.DownloadFile("https://code.visualstudio.com/sha/download?build=stable&os=win32-arm64", "$filearm64")
        Invoke-LogMessage
         "Downloaded ARM64 installer to $filearm64"
    } else {
        $Download.DownloadFile("https://code.visualstudio.com/sha/download?build=stable&os=win32-x64", "$filex64")
        Invoke-LogMessage
         "Downloaded x64 installer to $filex64"
    }
    # Install Visual Studio Code based on architecture
    if ($arch.CSDescription -eq "ARM processor family") {
        Start-Process -FilePath $filearm64 -ArgumentList "/VERYSILENT /MERGETASKS=!runcode" -Wait
        Invoke-LogMessage "Successfully installed Visual Studio Code"
    } else {
        Start-Process -FilePath $filex64 -ArgumentList "/VERYSILENT /MERGETASKS=!runcode" -Wait
        Invoke-LogMessage "Successfully installed Visual Studio Code"
    }
} catch {
    Invoke-LogMessage
     "Error: $($_.Exception.Message)"
    Write-Host "An error occurred. Check the log file at $logFile for details."
}