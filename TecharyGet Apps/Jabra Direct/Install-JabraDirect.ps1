$folderPath = "c:\logs\TecharyGetLogs\Installs\JabraDirect"
$logFile = "$folderPath\Install-JabraDirect.log"
$filex64 = "$folderPath\JabraDirectx64.msi"
$filearm64 = "$folderPath\JabraDirectarm64.msi"
$arch = (Get-ComputerInfo).CSDescription
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

# Check folder exists
if (-not (Test-Path -Path $folderPath)) {
    New-Item -ItemType Directory -Path $folderPath -Force
    Invoke-LogMessage
     "Created folder: $folderPath"
}

try {
    # Download installers
    if ($arch -like "*ARM*") {
        $Download.DownloadFile("https://jabraxpressonlineprdstor.blob.core.windows.net/jdo/JabraDirectSetup.exe", "$filearm64")
        Invoke-LogMessage "Downloaded ARM64 installer to $filearm64"
    } else {
        $Download.DownloadFile("https://jabraxpressonlineprdstor.blob.core.windows.net/jdo/JabraDirectSetup.exe", "$filex64")
        Invoke-LogMessage "Downloaded x64 installer to $filex64"
    }
    # Install Chrome based on architecture
    if ($arch.CSDescription -eq "ARM processor family") {
        Start-Process -FilePath $filearm64 -ArgumentList "/install /quiet /norestart" -Wait
        Invoke-LogMessage "Successfully installed Jabra Direct"
    } else {
        Start-Process -FilePath $filex64 -ArgumentList "/install /quiet /norestart" -Wait
        Invoke-LogMessage "Successfully installed Jabra Direct"
    }
} catch {
    Invoke-LogMessage "Error: $($_.Exception.Message)"
    Write-Host "An error occurred. Check the log file at $logFile for details."
}
