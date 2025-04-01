$folderPath = "c:\temp\AdobeReaderInstallation"
$logFile = "$folderPath\AdobeReaderInstaller.log"
$filex64 = "$folderPath\AdobeReaderx64.exe"
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
    # Define the URL that redirects to the latest version
    $redirectUrl = "https://rdc.adobe.io/reader/downloadUrl?name=Reader%202025.001.20432%20English%20UK%20Windows(64Bit)&nativeOs=Windows%2010&os=Windows%2010&site=landing&lang=uk&declined=mss&mcvisId=59900072829567155813622154372917826538&country=GB&api_key=dc-get-adobereader-cdn"

    # Fetch the content of the redirection URL
    $response = Invoke-WebRequest -Uri $redirectUrl -UseBasicParsing
    $content = $response.Content

    # Extract the fallbackDownloadURL from the content
    $downloadUrl = ($content -split "`n" | Select-String -Pattern 'fallbackDownloadURL.*?https?://.*?\.exe' | ForEach-Object {
        ($_ -split 'fallbackDownloadURL":')[1] -replace '[",}]', ''
    }).Trim()

    if (-not $downloadUrl) {
        throw "Unable to determine the download URL from the content."
    }

    Invoke-LogMessage "Determined download URL: $downloadUrl"

    # Download the installer
    $Download.DownloadFile($downloadUrl, $filex64)
    Invoke-LogMessage "Downloaded installer to $filex64"

    # Install Adobe Acrobat Reader (hidden)
    Start-Process -FilePath $filex64 -ArgumentList "/sAll /rs /msi EULA_ACCEPT=YES" -WindowStyle Hidden -Wait
    Invoke-LogMessage "Successfully installed Adobe Acrobat Reader."
} catch {
    Invoke-LogMessage "Error: $($_.Exception.Message)"
    Write-Host "An error occurred. Check the log file at $logFile for details."
}