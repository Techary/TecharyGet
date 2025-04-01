param (
    [string]$VersionDate = "2025-03"  # Default value for the date parameter
)

$folderPath = "c:\temp\DisplayLinkInstallation"
$logFile = "$folderPath\displaylink.log"
$zipFile = "$folderPath\DisplayLinkInstaller.zip"
$extractedPath = "$folderPath"
$msiFile = "$extractedPath\PublicSoftware - Displaylink\DisplayLink_Win10RS.msi"
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
    # Construct the download URL dynamically using the parameter
    $baseUrl = "https://www.synaptics.com/sites/default/files/msi_files"
    $fileName = "DisplayLink%20USB%20Graphics%20Software%20for%20Windows11.6%20M1-MSI.zip"
    $downloadUrl = "$baseUrl/$VersionDate/$fileName"

    Invoke-LogMessage "Constructed download URL: $downloadUrl"

    # Download the ZIP file
    $Download.DownloadFile($downloadUrl, $zipFile)
    Invoke-LogMessage "Downloaded ZIP file to $zipFile"

    # Extract the ZIP file
    if (-not (Test-Path -Path $extractedPath)) {
        New-Item -ItemType Directory -Path $extractedPath -Force
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $extractedPath)
    Invoke-LogMessage "Extracted ZIP file to $extractedPath"

    # Verify the MSI file exists
    if (-not (Test-Path -Path $msiFile)) {
        throw "MSI file not found at $msiFile"
    }

    Invoke-LogMessage "Located MSI file: $msiFile"

    # Install the MSI file silently using msiexec
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiFile`" ALLUSERS=1 /quiet /norestart" -Wait -NoNewWindow
    Invoke-LogMessage "Successfully installed DisplayLink USB Graphics Software."
} catch {
    Invoke-LogMessage "Error: $($_.Exception.Message)"
    Write-Host "An error occurred. Check the log file at $logFile for details."
}