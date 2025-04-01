$folderPath = "c:\temp\SlackInstallation"
$logFile = "$folderPath\SlackInstaller.log"
$filex64 = "$folderPath\SlackSetup-x64.msi"
$filearm64 = "$folderPath\SlackSetup-arm64.msi"
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
        $Download.DownloadFile("https://slack.com/ssb/download-win64-msi", "$filearm64")
        Invoke-LogMessage
         "Downloaded ARM64 installer to $filearm64"
    } else {
        $Download.DownloadFile("https://slack.com/ssb/download-win64-msi", "$filex64")
        Invoke-LogMessage
         "Downloaded x64 installer to $filex64"
    }
    # Install Slack based on architecture
    if ($arch.CSDescription -eq "ARM processor family") {
        Start-Process -FilePath $filearm64 -ArgumentList "-s" -Wait
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$filearm64`" /qn /norestart" -Wait -NoNewWindow
        Invoke-LogMessage "Successfully installed Slack"
    } else {
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$filex64`" /qn /norestart" -Wait -NoNewWindow
        Invoke-LogMessage "Successfully installed Slack"
    }
} catch {
    Invoke-LogMessage
     "Error: $($_.Exception.Message)"
    Write-Host "An error occurred. Check the log file at $logFile for details."
}