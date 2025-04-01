$folderPath = "c:\temp\ChromeInstallation"
$logFile = "$folderPath\ChromeInstaller.log"
$filex64 = "$folderPath\googlechromestandaloneenterprise64.msi"
$filearm64 = "$folderPath\googlechromestandaloneenterprisearm64.msi"
$arch = get-computerinfo
$Download = New-Object net.webclient

# Function to log messages
function Invoke-LogMessage
 {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "[$timestamp] $Message"
}

# Ensure the folder exists
if (-not (Test-Path -Path $folderPath)) {
    New-Item -ItemType Directory -Path $folderPath -Force
    Invoke-LogMessage
     "Created folder: $folderPath"
}

try {
    # Download installers
    $Download.DownloadFile("https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi", "$filex64")
    Invoke-LogMessage
     "Downloaded x64 installer to $filex64"

    $Download.DownloadFile("https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprisearm64.msi", "$filearm64")
    Invoke-LogMessage
     "Downloaded ARM64 installer to $filearm64"

    # Install Chrome based on architecture
    if ($arch.CSDescription -eq "ARM processor family") {
        Start-Process -FilePath $filearm64 -ArgumentList "/quiet" -Wait
        Invoke-LogMessage
         "Successfully installed Chrome"
    } else {
        Start-Process -FilePath $filex64 -ArgumentList "/quiet" -Wait
        Invoke-LogMessage
         "Successfully installed Chrome"
    }
} catch {
    Invoke-LogMessage
     "Error: $($_.Exception.Message)"
    Write-Host "An error occurred. Check the log file at $logFile for details."
}