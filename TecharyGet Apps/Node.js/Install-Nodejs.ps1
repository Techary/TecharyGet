$folderPath = "c:\logs\TecharyGetLogs\Installs\Nodejs"
$logFile = "$folderPath\Install-Nodejs.log"
$filex64 = "$folderPath\Nodejsx64.msi"
$filearm64 = "$folderPath\Nodejsarm64.msi"
$arch = (Get-ComputerInfo).CSDescription
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
    if ($arch -like "*ARM*") {
        $Download.DownloadFile($urlarm64, $filearm64)
        Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
        $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Nodejs_Installer_arm64.msi"
        Rename-Item -Path $local:filex64 -NewName $renamedFile
        Invoke-LogMessage "Renamed installer to: $renamedFile"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /qn" -Wait -NoNewWindow
        Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
        Invoke-LogMessage "Removed installer: $renamedFile"
    } else {
        $Download.DownloadFile($urlx64, $filex64)
        Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
        $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Nodejs_Installer_x64.msi"
        Rename-Item -Path $local:filex64 -NewName $renamedFile
        Invoke-LogMessage "Renamed installer to: $renamedFile"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /qn" -Wait -NoNewWindow
        Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
        Invoke-LogMessage "Removed installer: $renamedFile"
    }
    Invoke-LogMessage "Successfully installed Node.js."
} catch {
    Invoke-LogMessage "Error installing Node.js: $($_.Exception.Message)"
}
