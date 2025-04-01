$folderPath = "c:\temp\NodeJSInstallation"
$logFile = "$folderPath\NodeJSInstaller.log"
$filex64 = "$folderPath\nodejs-x64.msi"
$filearm64 = "$folderPath\nodejs-arm64.msi"
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
    # Fetch the latest version from the Node.js distribution page
    $nodejsUrl = "https://nodejs.org/dist/"
    $response = Invoke-WebRequest -Uri $nodejsUrl -UseBasicParsing
    $latestVersion = ($response.Content -split "`n" | Select-String -Pattern 'v\d+\.\d+\.\d+/' | ForEach-Object { ($_ -match 'v\d+\.\d+\.\d+') | Out-Null; $matches[0] }) | Sort-Object -Descending | Select-Object -First 1

    if (-not $latestVersion) {
        throw "Unable to determine the latest Node.js version."
    }

    Invoke-LogMessage "Determined latest Node.js version: $latestVersion"

    # Construct the download URLs
    $baseUrl = "$nodejsUrl$latestVersion/"
    $urlx64 = "$baseUrl/node-$latestVersion-x64.msi"
    $urlarm64 = "$baseUrl/node-$latestVersion-arm64.msi"

    Invoke-LogMessage "Constructed x64 URL: $urlx64"
    Invoke-LogMessage "Constructed ARM64 URL: $urlarm64"

    # Download installers
    $arch = (Get-ComputerInfo).CSDescription
    if ($arch -like "*ARM*") {
        $Download.DownloadFile($urlarm64, $filearm64)
        Invoke-LogMessage "Downloaded ARM64 installer to $filearm64"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$filearm64`" /qn" -Wait -NoNewWindow
        Invoke-LogMessage "Successfully installed Node.js for ARM64."
    } else {
        $Download.DownloadFile($urlx64, $filex64)
        Invoke-LogMessage "Downloaded x64 installer to $filex64"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$filex64`" /qn" -Wait -NoNewWindow
        Invoke-LogMessage "Successfully installed Node.js for x64."
    }
} catch {
    Invoke-LogMessage "Error: $($_.Exception.Message)"
    Write-Host "An error occurred. Check the log file at $logFile for details."
}