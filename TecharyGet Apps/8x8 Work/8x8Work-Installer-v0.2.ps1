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
    # Fetch the latest version from the Winget repository
    $wingetManifestUrl = "https://github.com/microsoft/winget-pkgs/tree/master/manifests/8/8x8/Work"
    $response = Invoke-WebRequest -Uri $wingetManifestUrl -UseBasicParsing
    $latestVersion = ($response.Content -split "`n" | Select-String -Pattern 'work-(\d+\.\d+\.\d+\.\d+)-msi' | ForEach-Object { ($_ -split 'work-')[1] -split '-msi' })[0]

    if (-not $latestVersion) {
        throw "Unable to determine the latest version from Winget repository."
    }

    Invoke-LogMessage "Determined latest version: $latestVersion"

    # Construct the download URL
    $baseUrl = "https://vod-updates.8x8.com/ga/"
    $latestUrlX64 = "$baseUrl/work-v$latestVersion-*-msi-x64.msi"
    $latestUrlARM64 = "$baseUrl/work-v$latestVersion-*-msi-arm64.msi"

    Invoke-LogMessage "Constructed x64 URL: $latestUrlX64"
    Invoke-LogMessage "Constructed ARM64 URL: $latestUrlARM64"

    # Download installers
    if ($arch.CSDescription -eq "ARM processor family") {
        $Download.DownloadFile($latestUrlARM64, $filearm64)
        Invoke-LogMessage "Downloaded ARM64 installer to $filearm64"
    } else {
        $Download.DownloadFile($latestUrlX64, $filex64)
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