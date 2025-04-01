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
            if ($arch -like "*ARM*") {
                $Download.DownloadFile("https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprisearm64.msi", $local:filearm64)
                Invoke-LogMessage "Downloaded ARM64 installer to $local:filearm64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Chrome_Installer_ARM64.msi"
                Rename-Item -Path $local:filearm64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/quiet" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                $Download.DownloadFile("https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi", $local:filex64)
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Chrome_Installer_x64.msi"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/quiet" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            }
            Invoke-LogMessage "Successfully installed Chrome"
        }
        catch {
            Invoke-LogMessage "Error installing Chrome: $($_.Exception.Message)"
            Write-Error "Error installing Chrome: $($_.Exception.Message)"
        }
    }
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## Firfox Installer ######################
    elseif ($AppName -eq "Firefox") {
        try {
            if ($arch -like "*ARM*") {
                $Download.DownloadFile("https://download.mozilla.org/?product=firefox-latest-ssl&os=win64-aarch64&lang=en-GB", $local:filearm64)
                Invoke-LogMessage "Downloaded ARM64 installer to $local:filearm64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Firefox_Installer_ARM64.exe"
                Rename-Item -Path $local:filearm64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/S /PreventRebootRequired=true" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                $Download.DownloadFile("https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-GB", $local:filex64)
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Firefox_Installer_x64.exe"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/S /PreventRebootRequired=true" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            }
            Invoke-LogMessage "Successfully installed Firefox"
        }
        catch {
            Invoke-LogMessage "Error installing Firefox: $($_.Exception.Message)"
            Write-Error "Error installing Firefox: $($_.Exception.Message)"
        }
    } 
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## Slack Installer ######################
    elseif ($AppName -eq "Slack") {
        try {
            $Download.DownloadFile("https://slack.com/ssb/download-win64-msi", $local:filex64)
            Invoke-LogMessage "Downloaded Slack installer to $local:filex64"
            $renamedFile = Join-Path -Path $local:folderPath -ChildPath "Slack_Installer_x64.msi"
            Rename-Item -Path $local:filex64 -NewName $renamedFile
            Invoke-LogMessage "Renamed installer to: $renamedFile"
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$renamedFile`" /qn /norestart" -Wait -NoNewWindow -ErrorAction Stop
            Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
            Invoke-LogMessage "Removed installer: $renamedFile"
            Invoke-LogMessage "Successfully installed Slack"
        } catch {
            Invoke-LogMessage "Error installing Slack: $($_.Exception.Message)"
            Write-Error "Error installing Slack: $($_.Exception.Message)"
        }
    } 
############################################################################################################################################
############################################################################################################################################
############################################################################################################################################
    ############## VSCode Installer ######################
    elseif ($AppName -eq "VSCode") {
        try {
            if ($arch -like "*ARM*") {
                $Download.DownloadFile("https://code.visualstudio.com/sha/download?build=stable&os=win32-arm64", $local:filearm64)
                Invoke-LogMessage "Downloaded ARM64 installer to $local:filearm64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "VSCode_Installer_ARM64.exe"
                Rename-Item -Path $local:filearm64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/VERYSILENT /MERGETASKS=!runcode" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            } else {
                $Download.DownloadFile("https://code.visualstudio.com/sha/download?build=stable&os=win32-x64", $local:filex64)
                Invoke-LogMessage "Downloaded x64 installer to $local:filex64"
                $renamedFile = Join-Path -Path $local:folderPath -ChildPath "VSCode_Installer_x64.exe"
                Rename-Item -Path $local:filex64 -NewName $renamedFile
                Invoke-LogMessage "Renamed installer to: $renamedFile"
                Start-Process -FilePath $renamedFile -ArgumentList "/VERYSILENT /MERGETASKS=!runcode" -Wait -ErrorAction Stop
                Remove-Item -Path $renamedFile -Force # Remove the renamed MSI after installation
                Invoke-LogMessage "Removed installer: $renamedFile"
            }
            Invoke-LogMessage "Successfully installed Visual Studio Code"
        } catch {
            Invoke-LogMessage "Error installing Visual Studio Code: $($_.Exception.Message)"
            Write-Error "Error installing Visual Studio Code: $($_.Exception.Message)"
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
        if ($arch.CSDescription -eq "ARM processor family") {
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$arm64Download`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
        } else {
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$x64Download`" ALLUSERS=1 /quiet" -Wait -NoNewWindow
        }
        Invoke-LogMessage "Successfully installed 8x8 Work."
    } catch {
        Invoke-LogMessage "Error installing 8x8 Work: $($_.Exception.Message)"
    }
}

    else {
        Invoke-LogMessage "Unknown application: $AppName"
        Write-Error "Error: Unknown application '$AppName'. Please check the application name and try again."
    }
}