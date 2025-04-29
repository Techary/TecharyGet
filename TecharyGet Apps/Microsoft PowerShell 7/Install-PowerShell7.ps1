$folderPath = "c:\temp\PowerShell7Installation"
$logFile = "$folderPath\PowerShell7-Install.log"
$filex64 = "$folderPath\PowerShell7_Installer_x64.msi"
$filearm64 = "$folderPath\PowerShell7_Installer-arm64.msi"
$arch = (Get-ComputerInfo).CSDescription

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

# Google Chrome Installer Script with Dynamic Version from Winget GitHub
try {
    # Get latest version from GitHub API
    $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/m/Microsoft/PowerShell"
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
    $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/m/Microsoft/PowerShell/${latestVersion}/Microsoft.PowerShell.installer.yaml"
    Invoke-LogMessage "Downloading YAML from: $yamlUrl"

    # Download YAML content
    $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
    $yamlText = $yamlContent.Content

    # Find the InstallerUrls for x64 and arm64
    $patternX64 = 'InstallerUrl:\s*(\S*/PowerShell-\d+\.\d+\.\d+-win-x64\.msi)'
    $patternARM64 = 'InstallerUrl:\s*(\S*/PowerShell-\d+\.\d+\.\d+-win-arm64\.msi)'

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

    if ($arch -eq "ARM processor family") {
        if (-not $installerUrlARM64) {
            throw "ARM64 installer URL not found in YAML."
        }
        try {
            Invoke-WebRequest -Uri $installerUrlarm64 -OutFile $filearm64
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
        Invoke-LogMessage "Downloaded arm64 installer to $local:filearm64"
        $renamedFile = Join-Path -Path $local:folderPath -ChildPath "PowerShell_Installer_arm64.exe"
        Rename-Item -Path $local:filearm64 -NewName $renamedFile
        Invoke-LogMessage "Renamed installer to: $renamedFile"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /qn" -Wait -NoNewWindow
        Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
        Invoke-LogMessage "Removed installer: $renamedFile"
    } else {
        Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
        $renamedFile = Join-Path -Path $local:folderPath -ChildPath "PowerShell_Installer_x64.exe"
        Rename-Item -Path $local:filex64 -NewName $renamedFile
        Invoke-LogMessage "Renamed installer to: $renamedFile"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /qn" -Wait -NoNewWindow
        Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
        Invoke-LogMessage "Removed installer: $renamedFile"
    }
    Invoke-LogMessage "Successfully installed Google Chrome."
} catch {
    Invoke-LogMessage "Error installing Google Chrome: $($_.Exception.Message)"
}
