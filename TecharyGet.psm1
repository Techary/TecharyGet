#region Globals
$script:folderPath = "C:\Logs\TecharyGetLogs"
$ProgressPreference = 'SilentlyContinue'
#endregion

#region Logging
function Invoke-LogMessage {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = Join-Path $script:folderPath "TecharyGet.log"
    Add-Content -Path $logFile -Value "[$timestamp] $Message"
}
#endregion

#region Install App
function Install-TecharyApp {
    param (
        [string]$AppName,
        [hashtable]$Parameters
    )

    #If AppMap.ps1 exists, remove it to ensure we get the latest version
    $AppMapexists = Test-Path "$PSScriptRoot\AppMap.ps1"
    if ($AppMapexists) {
        Remove-Item "$PSScriptRoot\AppMap.ps1" -Force
    }

    # Download the latest AppMap.ps1
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Techary/TecharyGet/refs/heads/main/AppMap.ps1" -OutFile "$PSScriptRoot\AppMap.ps1" -UseBasicParsing

    if (-not $script:TecharyApps) {
        . "$PSScriptRoot\AppMap.ps1"
    }

    $AppKey = $AppName.ToLower()
    if (-not $script:TecharyApps.ContainsKey($AppKey)) {
        throw "[TecharyGet] Application '$AppName' not found in AppMap."
    }

    $app = $script:TecharyApps[$AppKey]

    if (-not $app.MsiInstallArgs) { $app.MsiInstallArgs = "ALLUSERS=1 /quiet" }
    if (-not $app.ExeInstallArgs) { $app.ExeInstallArgs = "/S" }

    if (-not (Test-Path $script:folderPath)) {
        New-Item -Path $script:folderPath -ItemType Directory -Force | Out-Null
    }

    # Handle special app logic or fallback
if ($AppKey -eq "nable") {
    $required = @("CustomerID", "Token", "CustomerName", "ServerAddress")
    foreach ($key in $required) {
        if (-not $Parameters.ContainsKey($key)) {
            throw "[Nable] Missing required parameter: $key"
        }
    }

    $customerID    = $Parameters.CustomerID
    $token         = $Parameters.Token
    $customerName  = $Parameters.CustomerName
    $serverAddress = $Parameters.ServerAddress

    # Ensure folder exists
    if (-not (Test-Path $script:folderPath)) {
        New-Item -Path $script:folderPath -ItemType Directory -Force | Out-Null
    }

    $fileName = "Nable_RMMInstaller.exe"
    $installerPath = Join-Path $script:folderPath $fileName
    $downloadUrl = "https://$serverAddress/download/current/winnt/N-central/WindowsAgentSetup.exe"

    Invoke-LogMessage "[Nable] Downloading installer from: $downloadUrl"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing

    $msiArgs = "/qn CUSTOMERID=$customerID CUSTOMERNAME=$customerName CUSTOMERSPECIFIC=1 REGISTRATION_TOKEN=$token SERVERPROTOCOL=HTTPS SERVERADDRESS=$serverAddress SERVERPORT=443"
    $arguments = "/S /v`"$msiArgs`""

    Invoke-LogMessage "[Nable] Installing with arguments: $arguments"
    Start-Process -FilePath $installerPath -ArgumentList $arguments -Wait -NoNewWindow

    Remove-Item $installerPath -Force
    Invoke-LogMessage "[Nable] Installed and cleaned up"
    return
}


    # Custom static download
    if (-not $app.IsWinget -and $app.DownloadUrl) {
        $arch = (Get-ComputerInfo).CSArchitecture
        $suffix = if ($arch -like "*ARM*") { "arm64" } else { "x64" }

        $ext = [System.IO.Path]::GetExtension($app.DownloadUrl)
        if (-not $ext) { $ext = ".exe" }

        $fileName = "${AppKey}_Installer_${suffix}${ext}"
        $installerPath = Join-Path $script:folderPath $fileName

        Invoke-LogMessage "[$AppName] Downloading installer from: $($app.DownloadUrl)"
        Invoke-WebRequest -Uri $app.DownloadUrl -OutFile $installerPath -UseBasicParsing

        switch ($app.InstallerType) {
            "exe" {
                Start-Process -FilePath $installerPath -ArgumentList $app.ExeInstallArgs -Wait -NoNewWindow
            }
            "msi" {
                Start-Process "msiexec.exe" -ArgumentList "/i `"$installerPath`" $($app.MsiInstallArgs)" -Wait -NoNewWindow
            }
            "msix" {
                Add-AppxProvisionedPackage -Online -PackagePath $installerPath -SkipLicense
            }
            default {
                throw "[$AppName] Unsupported installer type for custom app."
            }
        }

        Invoke-LogMessage "[$AppName] Installed successfully."
        Remove-Item $installerPath -Force
        return
    }

    # Winget-based install
    Install-TecharyWingetApp `
        -AppName        $AppName `
        -RepoPath       $app.RepoPath `
        -YamlFileName   $app.YamlFile `
        -PatternX64     $app.PatternX64 `
        -PatternARM64   $app.PatternARM64 `
        -InstallerType  $app.InstallerType `
        -ExeInstallArgs $app.ExeInstallArgs `
        -MsiInstallArgs $app.MsiInstallArgs
}
#endregion

#region Uninstall App
function Uninstall-TecharyApp {
    param (
        [string]$AppName
    )

    #If AppMap.ps1 exists, remove it to ensure we get the latest version
    $AppMapexists = Test-Path "$PSScriptRoot\AppMap.ps1"
    if ($AppMapexists) {
        Remove-Item "$PSScriptRoot\AppMap.ps1" -Force
    }

    # Download the latest AppMap.ps1
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Techary/TecharyGet/refs/heads/main/AppMap.ps1" -OutFile "$PSScriptRoot\AppMap.ps1" -UseBasicParsing

    if (-not $script:TecharyApps) {
        . "$PSScriptRoot\AppMap.ps1"
    }

    $AppKey = $AppName.ToLower()
    if (-not $script:TecharyApps.ContainsKey($AppKey)) {
        throw "[TecharyGet] Application '$AppName' not found in AppMap."
    }

    $app = $script:TecharyApps[$AppKey]
    $displayName = $app.DisplayName

    # Determine if using winget
    if ($app.IsWinget -and $app.WingetID) {
        $arch = (Get-ComputerInfo).CSArchitecture
        $wingetBasePath = if ($arch -like "*ARM*") {
            "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_arm64__8wekyb3d8bbwe"
        } else {
            "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
        }

        $resolveWinget = Resolve-Path -Path $wingetBasePath -ErrorAction SilentlyContinue | Sort-Object -Descending | Select-Object -First 1
        if ($resolveWinget) {
            $wingetExe = Join-Path $resolveWinget.Path "winget.exe"
        }

        if (-not (Test-Path $wingetExe)) {
            throw "[Uninstall] Winget executable not found."
        }

        Invoke-LogMessage "[Uninstall] Uninstalling '$displayName' via winget ID: $($app.WingetID)"
        & $wingetExe uninstall --id $($app.WingetID) --silent --scope machine --exact | Out-Null
        Invoke-LogMessage "[Uninstall] Winget uninstall complete for $displayName"
        return
    }

    # Otherwise fallback to registry-based uninstall logic
    $uninstallKeys = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $uninstallEntry = $null
    foreach ($key in $uninstallKeys) {
        $uninstallEntry = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -like "*$displayName*"
        } | Select-Object -First 1

        if ($uninstallEntry) { break }
    }

    if (-not $uninstallEntry) {
        throw "[Uninstall] Could not find uninstall entry for $displayName"
    }

    $uninstallCommand = $uninstallEntry.UninstallString
    if (-not $uninstallCommand) {
        throw "[Uninstall] No uninstall command found for $displayName"
    }

# MSI uninstall via ProductCode
if ($uninstallCommand -match "msiexec\.exe.*" -or $uninstallEntry.PSChildName -match "^\{.*\}$") {
    $productCode = $uninstallEntry.PSChildName
    if ($productCode -match "^\{.*\}$") {
        $msiArgs = "/x $productCode /qn REBOOT=ReallySuppress"
        Invoke-LogMessage "[Uninstall] Executing MSI uninstall: msiexec.exe $msiArgs"
        Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -NoNewWindow
        Invoke-LogMessage "[Uninstall] MSI uninstall completed for $displayName"
        return
    }
}


    #  EXE uninstallers (including quoted paths and arguments)
    if ($uninstallCommand -match '^(\"?[^"]+\.exe\"?)\s*(.*)$') {
        $exePathRaw = $matches[1]
        $args = $matches[2]

        $exePath = $exePathRaw.Trim('"').Trim()

        if (-not (Test-Path $exePath)) {
            try {
                $exePath = (Get-Item $exePath -ErrorAction Stop).FullName
            } catch {
                throw "Uninstall EXE not found: `"$exePath`""
            }
        }

        Invoke-LogMessage "[Uninstall] Executing EXE uninstall: $exePath $args"
        Start-Process -FilePath $exePath -ArgumentList $args -Wait -NoNewWindow
        Invoke-LogMessage "[Uninstall] Uninstall completed for $displayName"
        return
    }

    throw "[Uninstall] Uninstall command not recognized for $displayName"
}
#endregion

#region Install-TecharyWingetApp
function Install-TecharyWingetApp {
    param (
        [string]$AppName,
        [string]$RepoPath,
        [string]$YamlFileName,
        [string]$PatternX64,
        [string]$PatternARM64,
        [ValidateSet("msi", "exe", "zip", "msix")] [string]$InstallerType,
        [string]$ExeInstallArgs = "/S",
        [string]$MsiInstallArgs = "ALLUSERS=1 /quiet"
    )

    $arch = (Get-ComputerInfo).CSDescription
    $isARM = $arch -like "*ARM*"
    $suffix = if ($isARM) { "arm64" } else { "x64" }

    $versionUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$RepoPath"
    $headers = @{ "User-Agent" = "PowerShell" }
    $response = Invoke-RestMethod -Uri $versionUrl -Headers $headers

    $versions = $response | Where-Object { $_.type -eq "dir" } | ForEach-Object {
        try { [version]$_.name } catch { $null }
    } | Where-Object { $_ -ne $null }

    $latestVersion = $versions | Sort-Object -Descending | Select-Object -First 1
    Invoke-LogMessage "[$AppName] Latest version detected: $latestVersion"

    $yamlUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/$RepoPath/$latestVersion/$YamlFileName"
    Invoke-LogMessage "[$AppName] YAML URL: $yamlUrl"

    try {
        $yamlContent = Invoke-WebRequest -Uri $yamlUrl -UseBasicParsing
        $yamlText = $yamlContent.Content
    } catch {
        throw "[$AppName] Failed to download YAML: $_"
    }

    $installerUrl = $null
    if ($isARM -and $yamlText -match $PatternARM64) {
        $installerUrl = $matches[1]
    } elseif ($yamlText -match $PatternX64) {
        $installerUrl = $matches[1]
    } else {
        throw "[$AppName] Installer URL not found in YAML."
    }

    # Clean the filename from the URL (removing query parameters like ?archType=x64)
    $cleanInstallerUrl = $installerUrl -split '\?' | Select-Object -First 1
    $ext = [System.IO.Path]::GetExtension($cleanInstallerUrl)

    if (-not $ext) { $ext = ".exe" }

    $fileName = "${AppName}_Installer_${suffix}${ext}"
    $installerPath = Join-Path $script:folderPath $fileName
`
    # Now download the file using the full URL
    Invoke-LogMessage "[$AppName] Downloading installer from: $installerUrl"
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing

    switch ($InstallerType) {
        "msi" {
            Start-Process "msiexec.exe" -ArgumentList "/i `"$installerPath`" $MsiInstallArgs" -Wait -NoNewWindow
        }
        "exe" {
            Start-Process -FilePath $installerPath -ArgumentList $ExeInstallArgs -Wait -NoNewWindow
        }
        "msix" {
            Add-AppxProvisionedPackage -Online -PackagePath $installerPath -SkipLicense
        }
        "zip" {
            $extractPath = Join-Path $script:folderPath "$AppName-$suffix"
            Expand-Archive -Path $installerPath -DestinationPath $extractPath -Force
            $allMsis = Get-ChildItem -Path $extractPath -Recurse -Filter *.msi

            $preferredMsi = $allMsis | Where-Object {
                $osArch = (Get-ComputerInfo).OSArchitecture
                if ($osArch -like "*ARM*") {
                    $_.Name -match "arm64"
                } else {
                    $_.Name -match "x64"
                }
            } | Select-Object -First 1

            if (-not $preferredMsi) {
                $preferredMsi = $allMsis | Select-Object -First 1
            }

            Start-Process "msiexec.exe" -ArgumentList "/i `"$($preferredMsi.FullName)`" $MsiInstallArgs" -Wait -NoNewWindow
            Remove-Item -Path $extractPath -Recurse -Force
        }
    }

    Remove-Item $installerPath -Force
    Invoke-LogMessage "[$AppName] Installed successfully."
}
#endregion

#region Help
function Help-TecharyApp {
    Write-Host ""
    Write-Host "TecharyApp PowerShell Module Help" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Available Commands:" -ForegroundColor Yellow
    Write-Host "  Install-TecharyApp -AppName <name> [-Parameters <hashtable>]" -ForegroundColor Green
    Write-Host "  Uninstall-TecharyApp -AppName <name>" -ForegroundColor Green
    Write-Host "  Get-TecharyAppList" -ForegroundColor Green
    Write-Host "  Help-TecharyApp" -ForegroundColor Green
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host '  Install-TecharyApp -AppName "7zip"'
    Write-Host '  Uninstall-TecharyApp -AppName "chrome"'
    Write-Host '  Install-TecharyApp -AppName "nable" -Parameters @{ CustomerID="123"; Token="abc"; CustomerName="Org"; ServerAddress="control.example.com" }'
    Write-Host ""
    Write-Host "Tip:" -ForegroundColor Yellow
    Write-Host "  Use Get-TecharyAppList to see all available AppNames."
    Write-Host ""
}
#endregion

#region Get-TecharyAppList
function Get-TecharyAppList {

    #If AppMap.ps1 exists, remove it to ensure we get the latest version
    $AppMapexists = Test-Path "$PSScriptRoot\AppMap.ps1"
    if ($AppMapexists) {
        Remove-Item "$PSScriptRoot\AppMap.ps1" -Force
    }

    # Download the latest AppMap.ps1
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Techary/TecharyGet/refs/heads/main/AppMap.ps1" -OutFile "$PSScriptRoot\AppMap.ps1" -UseBasicParsing

    if (-not $script:TecharyApps) {
        . "$PSScriptRoot\AppMap.ps1"
    }

    $script:TecharyApps.Keys | Sort-Object | ForEach-Object {
        $app = $script:TecharyApps[$_]
        [PSCustomObject]@{
            AppKey      = $_
            DisplayName = $app.DisplayName
            InstallerType = $app.InstallerType
            IsWinget    = $app.IsWinget
            WingetID    = $app.WingetID
        }
    }
}
#endregion
