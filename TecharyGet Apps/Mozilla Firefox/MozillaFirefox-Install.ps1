$folderPath = "c:\temp\mozillafirefoxinstallation"
$logFile = "$folderPath\mozillafirefox.log"
$filex64 = "$folderPath\mozillafirefoxinstallerx64.exe"
$filearm64 = "$folderPath\mozillafirefoxinstallerarm64.exe"
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
        $Download.DownloadFile("https://download.mozilla.org/?product=firefox-latest-ssl&os=win64-aarch64&lang=en-GB", "$filearm64")
        Invoke-LogMessage
         "Downloaded ARM64 installer to $filearm64"
    } else {
        $Download.DownloadFile("https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-GB", "$filex64")
        Invoke-LogMessage
         "Downloaded x64 installer to $filex64"
    }
    # Install Mozilla Firefox based on architecture
    if ($arch.CSDescription -eq "ARM processor family") {
        Start-Process -FilePath $filearm64 -ArgumentList "/S /PreventRebootRequired=true" -Wait
        Invoke-LogMessage "Successfully installed Mozilla Firefox"
    } else {
        Start-Process -FilePath $filex64 -ArgumentList "/S /PreventRebootRequired=true" -Wait
        Invoke-LogMessage "Successfully installed Mozilla Firefox"
    }
} catch {
    Invoke-LogMessage
     "Error: $($_.Exception.Message)"
    Write-Host "An error occurred. Check the log file at $logFile for details."
}