$folderPath = "c:\logs\TecharyGetLogs\Installs\AdobeReader"
$logFile = "$folderPath\Install-AdobeReader.log"
$filex64 = "$folderPath\AdobeReaderx64.msi"
$filearm64 = "$folderPath\AdobeReaderarm64.msi"
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
    # Get latest version from GitHub API
    $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/a/Adobe/Acrobat/Reader/64-bit"
    $headers = @{
        "User-Agent" = "PowerShell"
        "Accept" = "application/vnd.github.v3+json"
    }
    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers
    
    # Keep version strings as-is and sort them descending using string comparison
    $versions = $response | Where-Object { $_.type -eq "dir" } | ForEach-Object {
        $_.name
    }
    
    # Sort using string comparison that works for versioning
    $latestVersion = $versions | Sort-Object { [version]$_ } -Descending | Select-Object -First 1
    Invoke-LogMessage "Latest version found: $latestVersion"
    
    # Build YAML URL with correct version string
    $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/a/Adobe/Acrobat/Reader/64-bit/$latestVersion/Adobe.Acrobat.Reader.64-bit.installer.yaml"
    Invoke-LogMessage "Downloading YAML from: $yamlUrl"

    # Download YAML content
    $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
    $yamlText = $yamlContent.Content

    # Find the InstallerUrls for x64 and arm64
    $patternX64 = 'InstallerUrl:\s*(\S*/AcroRdrDCx64\S*\.exe)'
    $patternARM64 = 'InstallerUrl:\s*(\S*/AcroRdrDCx64\S*\.exe)'

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

    if ($arch -eq "ARM processor family") {
        if (-not $installerUrlARM64) {
            throw "ARM64 installer URL not found in YAML."
        }
        try {
            $Download = New-Object System.Net.WebClient
            $Download.DownloadFile($installerUrlARM64, $filearm64)
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
            $Download = New-Object System.Net.WebClient
            $Download.DownloadFile($installerUrlX64, $filex64)
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
        $renamedFile = Join-Path -Path $local:folderPath -ChildPath "AdobeReader_Installer_arm64.exe"
        Rename-Item -Path $local:filearm64 -NewName $renamedFile
        Invoke-LogMessage "Renamed installer to: $renamedFile"
        Start-Process -FilePath $renamedFile -ArgumentList "-sfx_nu /sAll /rs /msi" -Wait -ErrorAction Stop
        Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
        Invoke-LogMessage "Removed installer: $renamedFile"
    } else {
        Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
        $renamedFile = Join-Path -Path $local:folderPath -ChildPath "AdobeReader_Installer_x64.exe"
        Rename-Item -Path $local:filex64 -NewName $renamedFile
        Invoke-LogMessage "Renamed installer to: $renamedFile"
        Start-Process -FilePath $renamedFile -ArgumentList "-sfx_nu /sAll /rs /msi" -Wait -ErrorAction Stop
        Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
        Invoke-LogMessage "Removed installer: $renamedFile"
    }
    Invoke-LogMessage "Successfully installed Adobe Reader."
} catch {
    Invoke-LogMessage "Error installing Adobe Reader: $($_.Exception.Message)"
}
