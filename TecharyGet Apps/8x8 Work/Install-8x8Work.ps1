$folderPath = "c:\logs\TecharyGetLogs\Installs\8x8work"
$logFile = "$folderPath\8x8work.log"
$filex64 = "$folderPath\8x8workx64.msi"
$filearm64 = "$folderPath\8x8workarm64.msi"
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

# 8x8 Work Installer Script with Dynamic Version from Winget GitHub
try {
    # Get latest version from GitHub API
    $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/8/8x8/Work"
    $headers = @{
        "User-Agent" = "PowerShell"
        "Accept" = "application/vnd.github.v3+json"}
    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers
    $versions = $response | Where-Object { $_.type -eq "dir" } | ForEach-Object {
        try { [version]$_.name } catch { $null }
    } | Where-Object { $_ -ne $null }
    $latestVersion = $versions | Sort-Object -Descending | Select-Object -First 1
    Invoke-LogMessage "Latest version found: $latestVersion"
   
    # Build YAML URL from Github to gather Installation URL
    $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/8/8x8/Work/$latestVersion/8x8.Work.installer.yaml"
    Invoke-LogMessage "Downloading YAML from: $yamlUrl"
  
    # Download YAML content
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
    $x64Download= "${folderPath}\8x8Work_x64.msi"
    $arm64Download = "${folderPath}\8x8Work_arm64.msi"
    # Download the installer
    if ($arch.CSDescription -eq "ARM processor family") {
        $Download.DownloadFile($latestUrlARM64, $arm64Download)
        Invoke-LogMessage "Downloaded ARM64 installer to $arm64Download"
    } 
    else {
        $Download.DownloadFile($installerUrl, $x64Download)
        Invoke-LogMessage "Downloaded x64 installer to $x64Download"
    }
    # Start installation here
    if ($arch -like "*ARM*") {
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$arm64Download`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
        Invoke-LogMessage "Downloaded x64 installer to $local:filearm64"
        $renamedFile = Join-Path -Path $local:folderPath -ChildPath "8x8Work_Installer_arm64.msi"
        Rename-Item -Path $local:filearm64 -NewName $renamedFile
        Invoke-LogMessage "Renamed installer to: $renamedFile"
        Start-Process -FilePath $renamedFile -ArgumentList "/quiet" -Wait -ErrorAction Stop
        Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
        Invoke-LogMessage "Removed installer: $renamedFile"
    } else {
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$x64Download`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
        Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
        $renamedFile = Join-Path -Path $local:folderPath -ChildPath "8x8Work_Installer_x64.msi"
        Rename-Item -Path $local:filex64 -NewName $renamedFile
        Invoke-LogMessage "Renamed installer to: $renamedFile"
        Start-Process -FilePath $renamedFile -ArgumentList "/quiet" -Wait -ErrorAction Stop
        Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
        Invoke-LogMessage "Removed installer: $renamedFile"
    }
    Invoke-LogMessage "Successfully installed 8x8 Work."
} catch {
    Invoke-LogMessage "Error installing 8x8 Work: $($_.Exception.Message)"
}
