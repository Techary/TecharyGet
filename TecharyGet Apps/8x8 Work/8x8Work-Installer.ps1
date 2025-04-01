$folderPath = "c:\temp\8x8workInstallation"
$logFile = "$folderPath\8x8work.log"
$filex64 = "$folderPath\8x8workx64.msi"
$filearm64 = "$folderPath\8x8workarm64.msi"
$arch = get-computerinfo
$Download = New-Object net.webclient

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
    $baseUrl = "https://vod-updates.8x8.com/ga/"
    
    # Fetch the latest version dynamically (if the server provides a directory listing or metadata)
    $response = Invoke-WebRequest -Uri $baseUrl
    $latestFile = ($response.Links | Where-Object { $_.href -match "work-.*-msi.*\.msi" }).href

    if (-not $latestFile) {
        throw "Unable to determine the latest version of the installer."
    }

    $latestUrl = "$baseUrl$latestFile"
    Invoke-LogMessage "Determined latest installer URL: $latestUrl"

    # Download installers
    if ($arch.CSDescription -eq "ARM processor family") {
        $Download.DownloadFile($latestUrl, $filearm64)
        Invoke-LogMessage "Downloaded ARM64 installer to $filearm64"
    } else {
        $Download.DownloadFile($latestUrl, $filex64)
        Invoke-LogMessage "Downloaded x64 installer to $filex64"
    }

    # Install 8x8 Work based on architecture
    if ($arch.CSDescription -eq "ARM processor family") {
        Start-Process -FilePath $filearm64 -ArgumentList "/quiet /norestart" -Wait
        Invoke-LogMessage "Successfully installed 8x8 Work for ARM64."
    } else {
        Start-Process -FilePath $filex64 -ArgumentList "/quiet /norestart" -Wait
        Invoke-LogMessage "Successfully installed 8x8 Work for x64."
    }
} catch {
    Invoke-LogMessage "Error: $($_.Exception.Message)"
    Write-Host "An error occurred. Check the log file at $logFile for details."
}