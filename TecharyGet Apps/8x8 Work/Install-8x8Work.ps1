$folderPath = "c:\temp\8x8workInstallation"
#$logFile = "$folderPath\8x8work.log"
$filex64 = "$folderPath\8x8workx64.msi"
$filearm64 = "$folderPath\8x8workarm64.msi"
$arch = get-computerinfo

# Function to log messages
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

# Download YAML content
$yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
$yamlText = $yamlContent.Content

# Find the InstallerUrls for x64 and arm64
$patternX64 = 'InstallerUrl:\s*(\S+)'
$patternARM64 = 'InstallerUrl:\s*(\S+)'

$installerUrlX64 = $null
$installerUrlARM64 = $null

if ($yamlText -match $patternX64) {
    $installerUrlX64 = $matches[1]
    Invoke-LogMessage "x64 Installer URL: $installerUrlX64"
}

if ($yamlText -match $patternARM64) {
    $installerUrlARM64 = $matches[1]
    Invoke-LogMessage "ARM64 Installer URL: $installerUrlARM64"
}

if (-not $installerUrlX64 -and -not $installerUrlARM64) {
    throw "Installer URLs not found in YAML."
}

# Determine architecture and download the correct installer
$arch = (Get-ComputerInfo).CSDescription

if ($arch -like "*ARM*") {
    if (-not $installerUrlARM64) {
        throw "ARM64 installer URL not found in YAML."
    }
    try {
        Invoke-WebRequest -Uri $installerUrlARM64 -OutFile $filearm64
        Invoke-LogMessage "Downloaded ARM64 installer to $filearm64"
    } catch {
        Invoke-LogMessage "Error downloading ARM64 installer: $($_.Exception.Message)"
        throw
    }

    # Verify the file exists
    if (-not (Test-Path -Path $filearm64)) {
        throw "The ARM64 installer file does not exist at $filearm64. Download may have failed."
    }

} else {
    if (-not $installerUrlX64) {
        throw "x64 installer URL not found in YAML."
    }
    try {
        Invoke-WebRequest -Uri $installerUrlX64 -OutFile $filex64
        Invoke-LogMessage "Downloaded x64 installer to $filex64"
    } catch {
        Invoke-LogMessage "Error downloading x64 installer: $($_.Exception.Message)"
        throw
    }

    # Verify the file exists
    if (-not (Test-Path -Path $filex64)) {
        throw "The x64 installer file does not exist at $filex64. Download may have failed."
    }
}
# Start installation here
if ($arch -like "*ARM*") {
    Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
    $renamedFile = Join-Path -Path $local:folderPath -ChildPath "8x8Work_Installer_arm64.msi"
    Rename-Item -Path $local:filex64 -NewName $renamedFile
    Invoke-LogMessage "Renamed installer to: $renamedFile"
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
    Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
    Invoke-LogMessage "Removed installer: $renamedFile"
} else {
    Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
    $renamedFile = Join-Path -Path $local:folderPath -ChildPath "8x8Work_Installer_x64.msi"
    Rename-Item -Path $local:filex64 -NewName $renamedFile
    Invoke-LogMessage "Renamed installer to: $renamedFile"
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
    Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
    Invoke-LogMessage "Removed installer: $renamedFile"
}
Invoke-LogMessage "Successfully installed 8x8 Work."
catch {
Invoke-LogMessage "Error installing 8x8 Work: $($_.Exception.Message)"
}
