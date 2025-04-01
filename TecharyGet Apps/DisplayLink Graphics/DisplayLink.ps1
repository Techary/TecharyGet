$folderPath = "c:\temp\DisplayLinkInstallation"
$logFile = "$folderPath\DisplayLink-Install.log"
$filex64 = "$folderPath\DisplayLink_Installer_x64.msi"
$filearm64 = "$folderPath\DisplayLink_Installer-arm64.msi"
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

# DisplayLink Installer Script with Dynamic Version from Winget GitHub
try {
    # Get latest version from GitHub API
    $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/d/DisplayLink/GraphicsDriver"
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
    $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/d/DisplayLink/GraphicsDriver/$latestVersion/DisplayLink.GraphicsDriver.installer.yaml"
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

    # Download the installer ZIP file
    if ($arch -like "*ARM*") {
        Invoke-WebRequest -Uri $installerUrl -OutFile $local:filearm64zip
        Invoke-LogMessage "Downloaded ARM64 ZIP installer to $filearm64zip"
        # Extract the ZIP file
        Expand-Archive -Path $filearm64zip -DestinationPath $folderPath -Force
        Invoke-LogMessage "Extracted ARM64 ZIP to $folderPath"
    } else {
        Invoke-WebRequest -Uri $installerUrl -OutFile $local:filex64zip
        Invoke-LogMessage "Downloaded x64 ZIP installer to $filex64zip"
        # Extract the ZIP file
        Expand-Archive -Path $filex64zip -DestinationPath $folderPath -Force
        Invoke-LogMessage "Extracted x64 ZIP to $folderPath"
    }

    # Locate the MSI file
    $msiFile = Get-ChildItem -Path $folderPath -Filter "*.msi" -Recurse | Select-Object -First 1
    if (-not $msiFile) {
        throw "MSI file not found in extracted ZIP."
    }
    Invoke-LogMessage "Found MSI file: $msiFile"


    # Start installation here
    if ($arch -like "*ARM*") {
        Invoke-LogMessage "Downloaded x64 installer to $local:filearm64"
        $renamedFile = Join-Path -Path $local:folderPath -ChildPath "DisplayLink_Installer_arm64.exe"
        Rename-Item -Path $local:filearm64 -NewName $renamedFile
        Invoke-LogMessage "Renamed installer to: $renamedFile"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
        Remove-Item -Path $renamedFile -Force # Remove the renamed file after installation
        Invoke-LogMessage "Removed installer: $renamedFile"
    } else {
        Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
        $renamedFile = Join-Path -Path $local:folderPath -ChildPath "DisplayLink_Installer_x64.exe"
        Rename-Item -Path $local:filex64 -NewName $renamedFile
        Invoke-LogMessage "Renamed installer to: $renamedFile"
        Start-Process -FilePath $renamedFile -ArgumentList "-silent" -Wait -NoNewWindow
        Remove-Item -Path $renamedFile -Force # Remove the renamed file after installation
        Invoke-LogMessage "Removed installer: $renamedFile"
    }
    Invoke-LogMessage "Successfully installed DisplayLink."
} catch {
    Invoke-LogMessage "Error installing DisplayLink: $($_.Exception.Message)"
}
