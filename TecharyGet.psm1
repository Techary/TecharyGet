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
    [string]$customerID,
    [string]$token,
    [string]$serveraddress,
    [string]$customername
)

# Initialize variables
$arch = (Get-ComputerInfo).CSDescription
$ProgressPreference = 'SilentlyContinue'
# Initialize logFile here, but with a default value
$script:logFile = Join-Path -Path $folderPath -ChildPath "TecharyGetinstalls.log"

#Set up to use a similar logic of WinGet
function TecharyGet {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateSet("Install", "Uninstall", "Update", "help")]
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
        "help" {
            Help-TecharyGet @RemainingArgs
        }
        "search" {
            search-TecharyGet @RemainingArgs
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
        [string]$AppName,
        [string]$customerID,
        [string]$token,
        [string]$serveraddress,
        [string]$customername
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
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Chrome_Installer_arm64.msi"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Chrome_Installer_x64.msi"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
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
            $DisplayLinkFolder = "C:\temp\TecharyGetInstallationLogs\PublicSoftware - DisplayLink\DisplayLink_Win10RS.msi"

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
            Invoke-LogMessage "Found MSI file: $msiFile.FullName"

            # Start installation here
            if ($arch -like "*ARM*") {
                $renamedFile = Join-Path -Path $folderPath -ChildPath "DisplayLink_arm64.msi"
                Move-Item -Path $msiFile.FullName -Destination $renamedFile -Force
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
                Remove-Item -Path $renamedFile -Force # Remove the renamed file after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                $renamedFile = Join-Path -Path $folderPath -ChildPath "DisplayLink_x64.msi"
                Move-Item -Path $msiFile.FullName -Destination $renamedFile -Force
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
                Remove-Item -Path $renamedFile -Force # Remove the renamed file after installation
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
            # Get latest version from GitHub API
            $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/o/OpenJS/NodeJS"
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
            $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/o/OpenJS/NodeJS/${latestVersion}/OpenJS.NodeJS.installer.yaml"
            Invoke-LogMessage "Downloading YAML from: $yamlUrl"
        
            # Download YAML content
            $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
            $yamlText = $yamlContent.Content
        
            # Find the InstallerUrls for x64 and arm64
            $patternX64 = 'InstallerUrl:\s*(\S*/node-v\S*-x64\.msi)'
            $patternARM64 = 'InstallerUrl:\s*(\S*/node-v\S*-arm64\.msi)'
        
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
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Nodejs_Installer_arm64.exe"
                Rename-Item -Path $local:filearm64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Nodejs_Installer_x64.exe"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
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
                    Invoke-WebRequest -Uri $installerUrlarm64  -OutFile $filearm64
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
############################################################################################################################################
############################################################################################################################################
    ############## Microsoft PowerToys Installer ######################
    elseif($AppName -eq "PowerToys"){
        try {
            # Get latest version from GitHub API
            $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/m/Microsoft/PowerToys"
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
            $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/m/Microsoft/PowerToys/${latestVersion}/Microsoft.PowerToys.installer.yaml"
            Invoke-LogMessage "Downloading YAML from: $yamlUrl"
        
            # Download YAML content
            $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
            $yamlText = $yamlContent.Content
        
            # Find the InstallerUrls for x64 and arm64
            $patternX64 = 'InstallerUrl:\s*(\S*/PowerToysSetup-\S*-x64\.exe)'
            $patternARM64 = 'InstallerUrl:\s*(\S*/PowerToysSetup-\S*-arm64\.exe)'
        
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
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "PowerToys_Installer_arm64.exe"
                Rename-Item -Path $local:filearm64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/quiet /norestart" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "PowerToys_Installer_x64.exe"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/quiet /norestart" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            }
            Invoke-LogMessage "Successfully installed Microsoft Powertoys."
        } catch {
            Invoke-LogMessage "Error installing Microsoft PowerToys: $($_.Exception.Message)"
        }
    }
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## Zoom Installer ######################
    elseif($appname -eq "Zoom"){
        try {
            # Get latest version from GitHub API
            $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/z/Zoom/Zoom"
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
            $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/z/Zoom/Zoom/${latestVersion}/Zoom.Zoom.installer.yaml"
            Invoke-LogMessage "Downloading YAML from: $yamlUrl"
        
            # Download YAML content
            $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
            $yamlText = $yamlContent.Content
        
            # Find the InstallerUrls for x64 and arm64
            $patternX64 = 'InstallerUrl:\s*(\S*/ZoomInstallerFull\.msi\?archType=x64)'
            $patternARM64 = 'InstallerUrl:\s*(\S*/ZoomInstallerFull\.msi\?archType=winarm64)'
        
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
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Zoom_Installer_arm64.msi"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /qn" -Wait -NoNewWindow
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Zoom_Installer_x64.msi"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /qn" -Wait -NoNewWindow
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            }
            Invoke-LogMessage "Successfully installed Zoom."
        } catch {
            Invoke-LogMessage "Error installing Zoom: $($_.Exception.Message)"
        }
    }
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## Wireshark Installer ######################
    elseif($AppName -eq "Wireshark"){
        try {
            # Get latest version from GitHub API
            $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/w/WiresharkFoundation/Wireshark"
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
            $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/w/WiresharkFoundation/Wireshark/${latestVersion}/WiresharkFoundation.Wireshark.installer.yaml"
            Invoke-LogMessage "Downloading YAML from: $yamlUrl"
        
            # Download YAML content
            $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
            $yamlText = $yamlContent.Content
        
            # Find the InstallerUrls for x64 and arm64
            $patternX64 = 'InstallerUrl:\s*(\S*/Wireshark-\S*-x64\.msi)'
            $patternARM64 = 'InstallerUrl:\s*(\S*/Wireshark-\S*-x64\.msi)'
        
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
                Invoke-LogMessage "Downloaded arm64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Wireshark_Installer_arm64.msi"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /qn" -Wait -NoNewWindow
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Wireshark_Installer_x64.msi"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" ALLUSERS=1 /qn" -Wait -NoNewWindow
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            }
            Invoke-LogMessage "Successfully installed Wireshark."
        } catch {
            Invoke-LogMessage "Error installing Wireshark: $($_.Exception.Message)"
        }
    }
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## Techary Nable Installer ######################
    elseif($AppName -eq "Nable"){
        if (-not (Test-Path "C:\temp")) 
            {New-Item -ItemType Directory -Path "C:\temp"
            write-host "C:\temp directory created"}
            else
                {write-host "C:\temp already exists - continuing"}

        Start-Transcript "C:\temp\rmminstall.log"

        function Get-InstallStatus 
            {

                if (get-service | Where-Object {$_.displayname -like "Windows Agent Service"})
                    {write-host $(Get-Date -Format u) "[Information] N-Able already installed, exiting..."
                    Stop-Transcript
                    exit 0}
            }


        function Get-RMMInstaller 
            {try
                {$script:RMMParams = @{
                        uri = "https://$serveraddress/download/current/winnt/N-central/WindowsAgentSetup.exe"
                        outfile = "C:\temp\WindowsAgentSetup.exe"
                                        }
                    $ProgressPreference = 'SilentlyContinue'
                    Invoke-WebRequest @RMMParams -ErrorAction stop
                }
            catch
                {

                    if ($null -eq $DownloadErrorcount)
                        {
                            write-host $(Get-Date -Format u) "[Warning] Unable to download RMM, trying again..."
                            $DownloadErrorcount++
                            get-rmminstaller
                        }
                    else
                        {

                            write-host $(Get-Date -Format u) "[Warning] Unable to download RMM" $error.exception[0]
                            Stop-Transcript
                            exit 0

                        }

                }

        }

        function Invoke-RMMInstaller {

            try
                {

                C:\temp\WindowsAgentSetup.exe /qn /v" /qn CUSTOMERID=$CustomerID CUSTOMERNAME=$customername CUSTOMERSPECIFIC=1 REGISTRATION_TOKEN=$Token SERVERPROTOCOL=HTTPS SERVERADDRESS=$serveraddress SERVERPORT=443 "

                }
            catch
                {

                    if ($null -eq $InstallError)
                        {

                            write-host $(Get-Date -Format u) "[Warning] Unable to install RMM, trying again..."
                            $InstallError++
                            invoke-rmminstaller

                        }
                    else
                        {

                            write-host $(Get-Date -Format u) "[Warning] Unable to install RMM" $error.exception[0]
                            Stop-Transcript
                            exit 0

                        }

                }

        }

        Get-InstallStatus
        write-host $(Get-Date -Format u) "[Information] ID set to $customerID"
        write-host $(Get-Date -Format u) "[Information] Token set to $token"
        write-host $(Get-Date -Format u) "[Information] CUSTOMERNAME set to $customername"
        write-host $(Get-Date -Format u) "[Information] Server set to $serveraddress"
        write-host $(Get-Date -Format u) "[Information] Protocol set to HTTPS"
        write-host $(Get-Date -Format u) "[Information] Port set to 443"
        get-rmminstaller
        if (test-path $RMMParams.outfile)
            {

                write-host $(Get-Date -Format u) "[Information] RMM downloaded succesfully, attempting install..."

            }
        invoke-rmminstaller

        start-sleep -seconds 120

        if (get-service | Where-Object {$_.displayname -like "Windows Agent Service"})
            {write-host $(Get-Date -Format u) "[Information] N-Able successfully installed, exiting."
            Stop-Transcript
            exit 0}
            else
                {Write-Host "Installation failed - check event viewer."
                Stop-Transcript
                exit 0}
    }
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## Bitwarden Installer ######################
    elseif($AppName -eq "Bitwarden"){
        try {
            # Get latest version from GitHub API
            $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/b/Bitwarden/Bitwarden"
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
            $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/b/Bitwarden/Bitwarden/${latestVersion}/Bitwarden.Bitwarden.installer.yaml"
            Invoke-LogMessage "Downloading YAML from: $yamlUrl"
        
            # Download YAML content
            $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
            $yamlText = $yamlContent.Content
        
            # Find the InstallerUrls for x64 and arm64
            $patternX64 = 'InstallerUrl:\s*(\S*/Bitwarden-Installer-\S+\.exe)'
            $patternARM64 = 'InstallerUrl:\s*(\S*/Bitwarden-Installer-\S+\.exe)'
        
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
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Bitwarden_Installer_arm64.exe"
                Rename-Item -Path $local:filearm64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/allusers /S" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Bitwarden_Installer_x64.exe"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/allusers /S" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            }
            Invoke-LogMessage "Successfully installed Bitwarden."
        } catch {
            Invoke-LogMessage "Error installing Bitwarden: $($_.Exception.Message)"
        }
    }
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## Logi Options + Installer ######################
    elseif($AppName -eq "LogiOptions"){
        Try {
            # Get latest version from GitHub API
    $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/l/Logitech/OptionsPlus"
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
    $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/l/Logitech/OptionsPlus/${latestVersion}/Logitech.OptionsPlus.installer.yaml"
    Invoke-LogMessage "Downloading YAML from: $yamlUrl"

    # Download YAML content
    $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
    $yamlText = $yamlContent.Content

    # Find the InstallerUrls for x64 and arm64
    $patternX64 = 'InstallerUrl:\s*(\S*/logioptionsplus_installer\.exe)'
    $patternARM64 = 'InstallerUrl:\s*(\S*/logioptionsplus_installer\.exe)'

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
        $renamedFile = Join-Path -Path $local:folderPath -ChildPath "LogiOptions_Installer_arm64.exe"
        Rename-Item -Path $local:filearm64 -NewName $renamedFile
        Invoke-LogMessage "Renamed installer to: $renamedFile"
        Start-Process -FilePath $renamedFile -ArgumentList "/quiet /analytics no" -Wait -ErrorAction Stop
        Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
        Invoke-LogMessage "Removed installer: $renamedFile"
    } else {
        Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
        $renamedFile = Join-Path -Path $local:folderPath -ChildPath "LogiOptions_Installer_x64.exe"
        Rename-Item -Path $local:filex64 -NewName $renamedFile
        Invoke-LogMessage "Renamed installer to: $renamedFile"
        Start-Process -FilePath $renamedFile -ArgumentList "/quiet /analytics no" -Wait -ErrorAction Stop
        Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
        Invoke-LogMessage "Removed installer: $renamedFile"
    }
    Invoke-LogMessage "Successfully installed Logi Option."
} catch {
    Invoke-LogMessage "Error installing Logi Options: $($_.Exception.Message)"
}
    }
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## reMarkable Companion App Installer ######################
    elseif ($AppName -eq "reMarkable"){
        try {
            # Get latest version from GitHub API
            $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/r/reMarkable/reMarkableCompanionApp"
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
            $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/r/reMarkable/reMarkableCompanionApp/${latestVersion}/reMarkable.reMarkableCompanionApp.installer.yaml"
            Invoke-LogMessage "Downloading YAML from: $yamlUrl"
        
            # Download YAML content
            $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
            $yamlText = $yamlContent.Content
        
            # Find the InstallerUrls for x64 and arm64
            $patternX64 = 'InstallerUrl:\s*(\S*/reMarkable-\S*-win64\.exe)'
            $patternARM64 = 'InstallerUrl:\s*(\S*/reMarkable-\S*-win64\.exe)'
        
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
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "reMarkable_Installer_arm64.exe"
                Rename-Item -Path $local:filearm64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "in --al --da -c" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "reMarkable_Installer_x64.exe"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "in --al --da -c" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            }
            Invoke-LogMessage "Successfully installed reMarkable."
        } catch {
            Invoke-LogMessage "Error installing reMarkable: $($_.Exception.Message)"
        }
    }
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## Notion Installer ######################
    elseif ($AppName -eq "Notion"){
        try {
            # Get latest version from GitHub API
            $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/n/Notion/Notion"
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
            $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/n/Notion/Notion/${latestVersion}/Notion.Notion.installer.yaml"
            Invoke-LogMessage "Downloading YAML from: $yamlUrl"
        
            # Download YAML content
            $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
            $yamlText = $yamlContent.Content
        
            # Find the InstallerUrls for x64 and arm64
            $patternX64 = 'InstallerUrl:\s*(\S*/Notion%20Setup%20\S+\.exe)'
            $patternARM64 = 'InstallerUrl:\s*(\S*/Notion%20Setup%20\S+%20arm64\.exe)'
        
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
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Notion_Installer_arm64.exe"
                Rename-Item -Path $local:filearm64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/S" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Notion_Installer_x64.exe"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/S" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            }
            Invoke-LogMessage "Successfully installed Notion."
        } catch {
            Invoke-LogMessage "Error installing Notion: $($_.Exception.Message)"
        }
    }
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## PowerBI Installer ######################
    elseif ($AppName -eq "PowerBI"){
        try {
            # Get latest version from GitHub API
            $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/m/Microsoft/PowerBI"
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
            $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/m/Microsoft/PowerBI/${latestVersion}/Microsoft.PowerBI.installer.yaml"
            Invoke-LogMessage "Downloading YAML from: $yamlUrl"
        
            # Download YAML content
            $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
            $yamlText = $yamlContent.Content
        
            # Find the InstallerUrls for x64 and arm64
            $patternX64 = 'InstallerUrl:\s*(\S*/PBIDesktopSetup-\d{4}-\d{2}_x64\.exe)'
            $patternARM64 = 'InstallerUrl:\s*(\S*/PBIDesktopSetup-\d{4}-\d{2}_x64\.exe)'
        
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
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "PowerBI_Installer_arm64.exe"
                Rename-Item -Path $local:filearm64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "-silent ACCEPT_EULA=1" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "PowerBI_Installer_x64.exe"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "-silent ACCEPT_EULA=1" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            }
            Invoke-LogMessage "Successfully installed PowerBI."
        } catch {
            Invoke-LogMessage "Error installing PowerBI: $($_.Exception.Message)"
        }
    }
    ############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## 7Zip Installer ######################
    elseif ($AppName -eq "7Zip"){
        try {
            # Get latest version from GitHub API
            $apiUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/7/7zip/7zip"
            $headers = @{
                "User-Agent" = "PowerShell"
                "Accept" = "application/vnd.github.v3+json"
            }
            $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers
        
##         $versions = $response | Where-Object { $_.type -eq "dir" } | ForEach-Object {
##              try { [version]$_.name } catch { $null }
##          } | Where-Object { $_ -ne $null }
        
            $latestVersion = ($response | Where-Object { $_.type -eq "dir" } | Sort-Object name -Descending | Select-Object -First 2 | Select-Object -Last 1).name
            Invoke-LogMessage "Latest version found: $latestVersion"
        
            # Build YAML URL from Github to gather Installation URL
            $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/7/7zip/7zip/${latestVersion}/7zip.7zip.installer.yaml"
            Invoke-LogMessage "Downloading YAML from: $yamlUrl"
        
            # Download YAML content
            $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
            $yamlText = $yamlContent.Content
        
            # Find the InstallerUrls for x64 and arm64
            $patternX64 = 'InstallerUrl:\s*(\S*/7z\d+-x64\.exe)'
            $patternARM64 = 'InstallerUrl:\s*(\S*/7z\d+-arm64\.exe)'
        
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
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "7zip_Installer_arm64.exe"
                Rename-Item -Path $local:filearm64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/S" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "7zip_Installer_x64.exe"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/S" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            }
            Invoke-LogMessage "Successfully installed 7zip."
        } catch {
            Invoke-LogMessage "Error installing 7zip: $($_.Exception.Message)"
        }
    }
############################################################################################################################################
    else {
        Invoke-LogMessage "Unknown application: $AppName"
        Write-Error "Error: Unknown application '$AppName'. Please check the application name and try again."
    }
}

function Uninstall-TecharyGet {
    param(
        [string]$AppName
    )

    # Check if the application is installed
    $installedApps = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*$AppName*" }
    
    if ($installedApps) {
        foreach ($app in $installedApps) {
            Write-Host "Uninstalling $($app.Name)..."
            $app.Uninstall() | Out-Null
            Write-Host "$($app.Name) uninstalled successfully."
        }
    } else {
        Write-Host "No applications found matching '$AppName'."
    }
}

function Help-TecharyGet {
param( 
    [string]$HelpType
)

if ($HelpType -eq "Install"){
    Write-Host "TecharyGet - A PowerShell module for managing Application Packages."
    Write-Host "How to install an available application"
    Write-Host "TecharyGet install <ApplicationName>"
    write-Host "Available Applications:"
    Write-Host "1. Jabra Direct"
    Write-Host "2. Adobe Acrobat Reader"
    Write-Host "3. Microsoft PowerToys"
    Write-Host "4. Zoom"
    Write-Host "5. Wireshark"
    Write-Host "6. Nable"
    Write-Host "7. 8x8 Work"
    Write-Host "8. DisplayLink"
    Write-Host "9. Google Chrome"
    Write-Host "10. Jabra Direct"
    Write-Host "11. Mozilla Firefox"
    Write-Host "12. Node.js"
    Write-Host "13. Microsoft Visual Studio Code"
    Write-Host "14. Slack"
}
elseif ($HelpType -eq "Uninstall"){
    Write-Host "TecharyGet - A PowerShell module for managing Application Packages."
    Write-Host "How to uninstall an available application"
    Write-Host "TecharyGet uninstall <ApplicationName>"
    write-Host "Available Applications:"
    write-Host "Available Applications:"
    Write-Host "1. Jabra Direct"
    Write-Host "2. Adobe Acrobat Reader"
    Write-Host "3. Microsoft PowerToys"
    Write-Host "4. Zoom"
    Write-Host "5. Wireshark"
    Write-Host "6. Nable"
    Write-Host "7. 8x8 Work"
    Write-Host "8. DisplayLink"
    Write-Host "9. Google Chrome"
    Write-Host "10. Jabra Direct"
    Write-Host "11. Mozilla Firefox"
    Write-Host "12. Node.js"
    Write-Host "13. Microsoft Visual Studio Code"
    Write-Host "14. Slack"
}
else {
    Write-Host "Invalid HelpType. Please specify 'Install' or 'Uninstall'."
}
}
