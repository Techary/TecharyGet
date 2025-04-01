$folderPath = "c:\temp\8x8workInstallation"
$logFile = "$folderPath\8x8work.log"
$filex64 = "$folderPath\8x8workx64.msi"
$filearm64 = "$folderPath\8x8workarm64.msi"
$arch = get-computerinfo

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

# 8x8 Work Installer Script with Dynamic Version from Winget GitHub
try {
    # Get latest version from GitHub API
    $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/8/8x8/Work"
    $headers = @{
        "User-Agent" = "PowerShell"
        "Accept" = "application/vnd.github.v3+json"
    }
    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers

    $versions = $response | Where-Object { $_.type -eq "dir" } | ForEach-Object {
        try { [version]$_.name } catch { $null }
    } | Where-Object { $_ -ne $null }

    $latestVersion = $versions | Sort-Object -Descending | Select-Object -First 1
    Invoke-LogMessage "Latest version found: $latestVersion"

    # Build YAML URL from Github to gather Installation URL
    $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/8/8x8/Work/$latestVersion/8x8.Work.installer.yaml"
    Invoke-LogMessage "Downloading YAML from: $yamlUrl"

    # Step 3: Download YAML content
    $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
    $yamlText = $yamlContent.Content

    # Find the first InstallerUrl
    $pattern = 'InstallerUrl:\s*(\S+)'
    if ($yamlText -match $pattern) {
        $installerUrl = $matches[1]
        Invoke-LogMessage "Installer URL: $installerUrl"
    } else {
        throw "Installer URL not found in YAML."
    }

    # Determine architecture and download path
    $filex64 = "${folderPath}\8x8Work_x64.msi"
    $filearm64 = "${folderPath}\8x8Work_arm64.msi"
    $Download = New-Object System.Net.WebClient
    $arch = (Get-ComputerInfo).CSDescription

    # Download the installer
    if ($arch.CSDescription -eq "ARM processor family") {
        $Download.DownloadFile($latestUrlARM64, $filearm64)
        Invoke-LogMessage "Downloaded ARM64 installer to $filearm64"
    } 
    else {
        $Download.DownloadFile($installerUrl, $filex64)
        Invoke-LogMessage "Downloaded x64 installer to $filex64"
    }

    # Start installation here
    if ($arch.CSDescription -eq "ARM processor family") {
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$filearm64`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
    } else {
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$filex64`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
    }
    Invoke-LogMessage "Successfully installed 8x8 Work."
} catch {
    Invoke-LogMessage "Error installing 8x8 Work: $($_.Exception.Message)"
}
