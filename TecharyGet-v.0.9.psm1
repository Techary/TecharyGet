param (
    [string]$AppVersion,
    [string]$AppArchitecture,
    [string]$AppDownloadUrl,
    [string]$AppInstallerPath,
    [string]$AppInstallerArguments,
    [string]$AppLogPath,
    [string]$LogFile,
    [string]$AppLogFilePath,
    [string]$AppLogFileNameWithDate,
    [string]$AppLogFilePathWithDate,
    [string]$folderPath = "c:\temp\TecharyGetInstallationLogs",
    [string]$arch,
    [System.Net.WebClient]$Download
)

# Initialize variables
$arch = (Get-ComputerInfo).CSDescription
$Download = New-Object System.Net.WebClient
# Initialize logFile here, but with a default value
$script:logFile = Join-Path -Path $folderPath -ChildPath "TecharyGetinstalls.log"

#Set up to use a similar logic of WinGet
function TecharyGet {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateSet("Install", "Uninstall", "Update")]
        [string]$Command,

        [Parameter(ValueFromRemainingArguments = $true)]
        $RemainingArgs
    )

    switch ($Command.ToLower()) {
        "install" {
            Install-TecharyGetPackage @RemainingArgs
        }
        "uninstall" {
            Uninstall-TecharyGetPackage @RemainingArgs
        }
        "update" {
            Update-TecharyGetPackage @RemainingArgs
        }
        default {
            Write-Error "Unknown command: $Command"
        }
    }
}

# Function to log messages
function Invoke-LogMessage {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $script:logFile -Value "[$timestamp] $Message"
}

# Ensure the folder exists
if (-not (Test-Path -Path $script:folderPath)) {
    try {
        New-Item -ItemType Directory -Path $script:folderPath -Force
        Invoke-LogMessage "Created folder: $($script:folderPath)"
    }
    catch {
        Write-Error "Failed to create folder $($script:folderPath). $($_.Exception.Message)"
        Throw
    }

}

# Main function to handle installation
function Install-TecharyGetPackage {
    param (
        [string]$AppName
    )

    # Construct file paths using Join-Path and the AppName
    $script:logFile = Join-Path -Path $script:folderPath -ChildPath "TecharyGetinstalls.log"
    $local:filex64 = Join-Path -Path $script:folderPath -ChildPath "${AppName}_x64.msi"
    $local:filearm64 = Join-Path -Path $script:folderPath -ChildPath "${AppName}_arm64.msi"
    $local:filex64zip = Join-Path -Path $script:folderPath -ChildPath "${AppName}_x64.zip"
    $local:filearm64zip = Join-Path -Path $script:folderPath -ChildPath "${AppName}_arm64.zip"
    $local:folderPath = $script:folderPath

    if (-not (Test-Path -Path $local:folderPath)) {
        try {
            New-Item -ItemType Directory -Path $local:folderPath -Force
            Invoke-LogMessage "Created folder: $local:folderPath"
        }
        catch {
            Write-Error "Failed to create folder $local:folderPath. $($_.Exception.Message)"
            Throw
        }
    }
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## Google Chrome Installer ######################
    if ($AppName -eq "Chrome") {
# Google Chrome Installer Script with Dynamic Version from Winget GitHub
try {
    # Get latest version from GitHub API
    $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/g/Google/Chrome"
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
    $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/g/Google/Chrome/${latestVersion}/Google.Chrome.installer.yaml"
    Invoke-LogMessage "Downloading YAML from: $yamlUrl"

    # Download YAML content
    $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
    $yamlText = $yamlContent.Content

    # Find the InstallerUrls for x64 and arm64
    $patternX64 = 'InstallerUrl:\s*(\S+.*64.*\.msi)'
    $patternARM64 = 'InstallerUrl:\s*(\S+.*arm64.*\.msi)'

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
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$filearm64`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
        Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
        $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Chrome_Installer_arm64.msi"
        Rename-Item -Path $local:filex64 -NewName $renamedFile
        Invoke-LogMessage "Renamed installer to: $renamedFile"
        Start-Process -FilePath $renamedFile -ArgumentList "/quiet" -Wait -ErrorAction Stop
        Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
        Invoke-LogMessage "Removed installer: $renamedFile"
    } else {
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$filex64`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
        Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
        $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Chrome_Installer_x64.msi"
        Rename-Item -Path $local:filex64 -NewName $renamedFile
        Invoke-LogMessage "Renamed installer to: $renamedFile"
        Start-Process -FilePath $renamedFile -ArgumentList "/quiet" -Wait -ErrorAction Stop
        Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
        Invoke-LogMessage "Removed installer: $renamedFile"
    }
    Invoke-LogMessage "Successfully installed Google Chrome."
} catch {
    Invoke-LogMessage "Error installing Google Chrome: $($_.Exception.Message)"
}
    }
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## Firfox Installer ######################
    elseif ($AppName -eq "Firefox") {
        try {
            # Get latest version from GitHub API
            $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/m/Mozilla/Firefox"
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
            $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/m/Mozilla/Firefox/${latestVersion}/Mozilla.Firefox.installer.yaml"
            Invoke-LogMessage "Downloading YAML from: $yamlUrl"
        
            # Download YAML content
            $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
            $yamlText = $yamlContent.Content
        
            # Find the InstallerUrls for x64 and arm64
            $patternX64 = 'InstallerUrl:\s*(\S*win64\S*/en[-_]us/\S*\.(exe|msi))'
            $patternARM64 = 'InstallerUrl:\s*(\S*in64-aarch64\S*/en[-_]us/\S*\.(exe|msi))'
        
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
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Firefox_Installer_arm64.exe"
                Rename-Item -Path $local:filearm64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/S /PreventRebootRequired=true" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Firefox_Installer_x64.exe"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/S /PreventRebootRequired=true" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            }
            Invoke-LogMessage "Successfully installed Mozilla Firefox."
        } catch {
            Invoke-LogMessage "Error installing Mozilla Firefox: $($_.Exception.Message)"
        }
    } 
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## Slack Installer ######################
    elseif ($AppName -eq "Slack") {
        try {
            # Get latest version from GitHub API
            $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/s/SlackTechnologies/Slack"
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
            $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/s/SlackTechnologies/Slack/${latestVersion}/SlackTechnologies.Slack.installer.yaml"
            Invoke-LogMessage "Downloading YAML from: $yamlUrl"
        
            # Download YAML content
            $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
            $yamlText = $yamlContent.Content
        
            # Find the InstallerUrls for x64 and arm64
            $patternX64 = 'InstallerUrl:\s*(\S*/x64/\S*/slack-standalone-\S+\.msi)'
            $patternARM64 = 'InstallerUrl:\s*(\S*/x64/\S*/slack-standalone-\S+\.msi)'
        
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
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Slack_Installer_arm64.msi"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /qn" -Wait -NoNewWindow
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Slack_Installer_x64.msi"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /qn" -Wait -NoNewWindow
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            }
            Invoke-LogMessage "Successfully installed Slack."
        } catch {
            Invoke-LogMessage "Error installing Slack: $($_.Exception.Message)"
        }
    } 
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## VSCode Installer ######################
    elseif ($AppName -eq "VSCode") {
        try {
            # Get latest version from GitHub API
            $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/m/Microsoft/VisualStudioCode"
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
            $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/m/Microsoft/VisualStudioCode/${latestVersion}/Microsoft.VisualStudioCode.installer.yaml"
            Invoke-LogMessage "Downloading YAML from: $yamlUrl"
        
            # Download YAML content
            $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
            $yamlText = $yamlContent.Content
        
            # Find the InstallerUrls for x64 and arm64
            $patternX64 = 'InstallerUrl:\s*(\S*VSCodeSetup\S*x64\S*\.(exe|msi))'
            $patternARM64 = 'InstallerUrl:\s*(\S*VSCodeSetup\S*arm64\S*\.(exe|msi))'
        
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
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "VSCode_Installer_arm64.exe"
                Rename-Item -Path $local:filearm64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/VERYSILENT /MERGETASKS=!runcode" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "VSCode_Installer_x64.exe"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/VERYSILENT /MERGETASKS=!runcode" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            }
            Invoke-LogMessage "Successfully installed VS Code."
        } catch {
            Invoke-LogMessage "Error installing VS Code: $($_.Exception.Message)"
        }
    } 
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## 8x8 Work Installer ######################
elseif ($AppName -eq "8x8Work") {
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
            Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
            $renamedFile = Join-Path -Path $local:folderPath -ChildPath "8x8Work_Installer_arm64.msi"
            Rename-Item -Path $local:filex64 -NewName $renamedFile
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
}
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## DisplayLink Installer ######################
elseif ($AppName -eq "DisplayLink") {
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
            Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
            $renamedFile = Join-Path -Path "$local:folderPath/PublicSoftware - DisplayLink" -ChildPath "DisplayLink_Win10RS.msi"
            Rename-Item -Path "$local:folderPath/PublicSoftware - DisplayLink\DisplayLink_Win10RS.msi" -NewName $renamedFile
            Invoke-LogMessage "Renamed installer to: $renamedFile"
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
            Remove-Item -Path "$local:folderPath/PublicSoftware - DisplayLink" -Force # Remove the renamed file after installation
            Invoke-LogMessage "Removed installer: $renamedFile"
        } else {
            Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
            $renamedFile = Join-Path -Path "$local:folderPath/PublicSoftware - DisplayLink" -ChildPath "DisplayLink_Win10RS.msi"
            Rename-Item -Path "$local:folderPath/PublicSoftware - DisplayLink\DisplayLink_Win10RS.msi" -NewName $renamedFile
            Invoke-LogMessage "Renamed installer to: $renamedFile"
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
            Remove-Item -Path "$local:folderPath/PublicSoftware - DisplayLink" -Force # Remove the renamed file after installation
            Invoke-LogMessage "Removed installer: $renamedFile"
        }
        Invoke-LogMessage "Successfully installed DisplayLink."
    } catch {
        Invoke-LogMessage "Error installing DisplayLink: $($_.Exception.Message)"
    }
    
}
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## GitHub Desktop Installer ######################
elseif ($AppName -eq "GitHubDesktop") {
    try {
        # Get latest version from GitHub API
        $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/g/GitHub/GitHubDesktop"
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
        $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/g/GitHub/GitHubDesktop/${latestVersion}/GitHub.GitHubDesktop.installer.yaml"
        Invoke-LogMessage "Downloading YAML from: $yamlUrl"
    
        # Download YAML content
        $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
        $yamlText = $yamlContent.Content
    
        # Find the InstallerUrls for x64 and arm64
        $patternX64 = 'InstallerUrl:\s*(\S+.*64.*\.msi)'
        $patternARM64 = 'InstallerUrl:\s*(\S+.*arm64.*\.msi)'
    
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
            Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
            $renamedFile = Join-Path -Path $local:folderPath -ChildPath "GitHubDesktop_Installer_arm64.msi"
            Rename-Item -Path $local:filex64 -NewName $renamedFile
            Invoke-LogMessage "Renamed installer to: $renamedFile"
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
            Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
            Invoke-LogMessage "Removed installer: $renamedFile"
        } else {
            Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
            $renamedFile = Join-Path -Path $local:folderPath -ChildPath "GitHubDesktop_Installer_x64.msi"
            Rename-Item -Path $local:filex64 -NewName $renamedFile
            Invoke-LogMessage "Renamed installer to: $renamedFile"
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
            Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
            Invoke-LogMessage "Removed installer: $renamedFile"
        }
        Invoke-LogMessage "Successfully installed GitHub Desktop."
    } catch {
        Invoke-LogMessage "Error installing GitHub Desktop: $($_.Exception.Message)"
    }    
}
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## Node.js Installer ######################
elseif ($AppName -eq "Nodejs"){
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
}
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## Jabra Direct Installer ######################
elseif ($AppName -eq "JabraDirect"){
    try {
        # Get latest version from GitHub API
        $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/j/Jabra/Direct"
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
        $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/j/Jabra/Direct/${latestVersion}/Jabra.Direct.installer.yaml"
        Invoke-LogMessage "Downloading YAML from: $yamlUrl"
    
        # Download YAML content
        $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
        $yamlText = $yamlContent.Content
    
        # Find the InstallerUrls for x64 and arm64
        $patternX64 = 'InstallerUrl:\s*(\S*/JabraDirectSetup\.exe)'
        $patternARM64 = 'InstallerUrl:\s*(\S*/JabraDirectSetup\.exe)'
    
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
            $renamedFile = Join-Path -Path $local:folderPath -ChildPath "JabraDirect_Installer_arm64.exe"
            Rename-Item -Path $local:filearm64 -NewName $renamedFile
            Invoke-LogMessage "Renamed installer to: $renamedFile"
            Start-Process -FilePath $renamedFile -ArgumentList "/install /quiet /norestart" -Wait -ErrorAction Stop
            Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
            Invoke-LogMessage "Removed installer: $renamedFile"
        } else {
            Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
            $renamedFile = Join-Path -Path $local:folderPath -ChildPath "JabraDirect_Installer_x64.exe"
            Rename-Item -Path $local:filex64 -NewName $renamedFile
            Invoke-LogMessage "Renamed installer to: $renamedFile"
            Start-Process -FilePath $renamedFile -ArgumentList "/install /quiet /norestart" -Wait -ErrorAction Stop
            Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
            Invoke-LogMessage "Removed installer: $renamedFile"
        }
        Invoke-LogMessage "Successfully installed Jabra Direct."
    } catch {
        Invoke-LogMessage "Error installing Jabra Direct: $($_.Exception.Message)"
    }
}
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## Adobe Reader Installer ######################
elseif($AppName -eq "AdobeReader"){
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
}
############################################################################################################################################
    else {
        Invoke-LogMessage "Unknown application: $AppName"
        Write-Error "Error: Unknown application '$AppName'. Please check the application name and try again."
    }
}