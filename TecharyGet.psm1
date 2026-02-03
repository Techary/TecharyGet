#region Globals
$script:folderPath = "C:\Logs\TecharyGetLogs"
$ProgressPreference = 'SilentlyContinue'
$script:AppMapCache = $null
#endregion

#region Logging System
function Invoke-LogMessage {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO",
        
        [string]$Source = "General"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level.PadRight(7)] [$Source] $Message"
    $logFile = Join-Path $script:folderPath "TecharyGet.log"

    # 1. Write to Console with helpful colors
    $consoleColor = switch ($Level) {
        "INFO"    { "Cyan" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
    }
    Write-Host "[$Level] $Message" -ForegroundColor $consoleColor

    # 2. Write to Log File safely
    try {
        if (-not (Test-Path $script:folderPath)) { 
            New-Item -Path $script:folderPath -ItemType Directory -Force | Out-Null 
        }
        Add-Content -Path $logFile -Value $logLine -ErrorAction Stop
    } catch {
        # Fallback if logging fails (e.g., file locked)
        Write-Warning "LOGGING FAILURE: Could not write to $logFile. Original Message: $Message"
    }
}
#endregion

#region Helper: Load AppMap with Caching
function Get-TecharyAppMap {
    Invoke-LogMessage -Message "Loading AppMap..." -Level "INFO" -Source "Get-TecharyAppMap"
    
    if ($script:AppMapCache) { 
        Invoke-LogMessage -Message "Using cached AppMap." -Level "INFO" -Source "Get-TecharyAppMap"
        return $script:AppMapCache 
    }

    $localMap = "$PSScriptRoot\AppMap.ps1"
    
    try {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Techary/TecharyGet/refs/heads/main/AppMap.ps1" -OutFile $localMap -UseBasicParsing -ErrorAction Stop
        Invoke-LogMessage -Message "AppMap downloaded from GitHub." -Level "SUCCESS" -Source "Get-TecharyAppMap"
    } catch {
        Invoke-LogMessage -Message "Failed to download AppMap from GitHub: $($_.Exception.Message). Attempting local cache." -Level "WARN" -Source "Get-TecharyAppMap"
    }

    if (-not (Test-Path $localMap)) {
        $err = "AppMap.ps1 missing locally and download failed."
        Invoke-LogMessage -Message $err -Level "ERROR" -Source "Get-TecharyAppMap"
        throw $err
    }

    try {
        . $localMap
        $script:AppMapCache = $script:TecharyApps
    } catch {
        Invoke-LogMessage -Message "Failed to dot-source AppMap.ps1: $($_.Exception.Message)" -Level "ERROR" -Source "Get-TecharyAppMap"
        throw
    }
    
    return $script:AppMapCache
}
#endregion

#region Helper: Robust Version Sorter
function Get-SortedVersions {
    param([array]$Versions)
    return $Versions | Sort-Object -Property @{
        Expression = { 
            $parts = $_.ToString().Split('.') 
            if ($parts.Count -lt 4) { $parts += ,0 * (4 - $parts.Count) }
            # Safe sort that ignores non-numeric suffixes or 5th digits preventing crashes
            [version](($parts[0..3] -join '.'))
        } 
    } -Descending
}
#endregion

#region Install App
function Install-TecharyApp {
    param (
        [Parameter(Mandatory=$true)]
        [string]$AppName,
        [hashtable]$Parameters,
        [string]$GitHubToken
    )

    $FunctionName = "Install-TecharyApp"
    Invoke-LogMessage -Message "Starting installation sequence for: $AppName" -Level "INFO" -Source $FunctionName

    try {
        $apps = Get-TecharyAppMap
        $AppKey = $AppName.ToLower()

        if (-not $apps.ContainsKey($AppKey)) {
            Invoke-LogMessage -Message "Application '$AppName' is not defined in AppMap." -Level "ERROR" -Source $FunctionName
            return
        }

        $app = $apps[$AppKey]

        # Defaults
        if (-not $app.MsiInstallArgs) { $app.MsiInstallArgs = "ALLUSERS=1 /quiet" }
        if (-not $app.ExeInstallArgs) { $app.ExeInstallArgs = "/S" }

        # --- N-ABLE LOGIC ---
        if ($AppKey -eq "nable") {
            try {
                Invoke-LogMessage -Message "Starting N-Able Installation Logic" -Level "INFO" -Source "N-Able"
                
                # 1. Validate Parameters
                $required = @("CustomerID", "Token", "CustomerName", "ServerAddress")
                foreach ($key in $required) {
                    if (-not $Parameters.ContainsKey($key)) { throw "Missing required parameter: $key" }
                }

                # 2. Download Installer
                $fileName = "Nable_RMMInstaller.exe"
                $installerPath = Join-Path $script:folderPath $fileName
                $downloadUrl = "https://$($Parameters.ServerAddress)/download/current/winnt/N-central/WindowsAgentSetup.exe"

                Invoke-LogMessage -Message "Downloading N-Able Agent from $downloadUrl" -Level "INFO" -Source "N-Able"
                try {
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
                } catch {
                    throw "Failed to download N-Able installer. Verify ServerAddress or Network."
                }

                # 3. Execute Installer
                $msiArgs = "/qn CUSTOMERID=$($Parameters.CustomerID) CUSTOMERNAME=$($Parameters.CustomerName) CUSTOMERSPECIFIC=1 REGISTRATION_TOKEN=$($Parameters.Token) SERVERPROTOCOL=HTTPS SERVERADDRESS=$($Parameters.ServerAddress) SERVERPORT=443"
                $arguments = "/S /v`"$msiArgs`""

                Invoke-LogMessage -Message "Executing N-Able Installer..." -Level "INFO" -Source "N-Able"
                Start-Process -FilePath $installerPath -ArgumentList $arguments -Wait -NoNewWindow
                
                # 4. Wait for Services (Verification Loop)
                # We wait up to 10 minutes (600 seconds) for the services to appear
                $timeoutSeconds = 600
                $startTime = Get-Date
                $agentServiceName = "Windows Agent Service"
                $takeControlServiceName = "N-able Take Control Service (N-Central)"
                
                Invoke-LogMessage -Message "Waiting for N-Able services to start (Timeout: 10 mins)..." -Level "INFO" -Source "N-Able"

                while ($true) {
                    $agentStatus = Get-Service -Name $agentServiceName -ErrorAction SilentlyContinue
                    $takeControlStatus = Get-Service -Name $takeControlServiceName -ErrorAction SilentlyContinue

                    # Check if BOTH services exist
                    if ($agentStatus -and $takeControlStatus) {
                        Invoke-LogMessage -Message "Verified: '$agentServiceName' is present." -Level "INFO" -Source "N-Able"
                        Invoke-LogMessage -Message "Verified: '$takeControlServiceName' is present." -Level "INFO" -Source "N-Able"
                        
                        # Optional: Wait for them to be 'Running' specifically?
                        # if ($agentStatus.Status -eq 'Running') { ... } 
                        
                        Invoke-LogMessage -Message "N-Able fully installed and services detected." -Level "SUCCESS" -Source "N-Able"
                        break
                    }

                    # Check Timeout
                    if ((Get-Date) -gt $startTime.AddSeconds($timeoutSeconds)) {
                        Invoke-LogMessage -Message "TIMED OUT waiting for N-Able services." -Level "ERROR" -Source "N-Able"
                        Invoke-LogMessage -Message "Debug: Agent Found? $([bool]$agentStatus) | TakeControl Found? $([bool]$takeControlStatus)" -Level "WARN" -Source "N-Able"
                        throw "N-Able installation timed out. Services did not start within $timeoutSeconds seconds."
                    }

                    Start-Sleep -Seconds 10
                }

                # Cleanup
                Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                return

            } catch {
                Invoke-LogMessage -Message "N-Able Installation Failed: $($_.Exception.Message)" -Level "ERROR" -Source "N-Able"
                throw $_
            }
        }

        # --- STATIC URL INSTALL ---
        if (-not $app.IsWinget -and $app.DownloadUrl) {
            $arch = (Get-ComputerInfo).CSArchitecture
            $suffix = if ($arch -like "*ARM*") { "arm64" } else { "x64" }
            $ext = [System.IO.Path]::GetExtension($app.DownloadUrl)
            if (-not $ext) { $ext = ".exe" }
            
            $fileName = "${AppKey}_Installer_${suffix}${ext}"
            $installerPath = Join-Path $script:folderPath $fileName

            Invoke-LogMessage -Message "Downloading static installer from: $($app.DownloadUrl)" -Level "INFO" -Source $FunctionName
            
            try {
                Invoke-WebRequest -Uri $app.DownloadUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
            } catch {
                Invoke-LogMessage -Message "Download failed. Server responded: $($_.Exception.Message)" -Level "ERROR" -Source $FunctionName
                throw
            }

            Invoke-LogMessage -Message "Executing static installer ($($app.InstallerType))..." -Level "INFO" -Source $FunctionName
            
            switch ($app.InstallerType) {
                "exe" { Start-Process -FilePath $installerPath -ArgumentList $app.ExeInstallArgs -Wait -NoNewWindow }
                "msi" { Start-Process "msiexec.exe" -ArgumentList "/i `"$installerPath`" $($app.MsiInstallArgs)" -Wait -NoNewWindow }
                "msix"{ Add-AppxProvisionedPackage -Online -PackagePath $installerPath -SkipLicense }
            }

            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            Invoke-LogMessage -Message "$AppName installed successfully." -Level "SUCCESS" -Source $FunctionName
            return
        }

        # --- WINGET INSTALL ---
        if ($app.IsWinget) {
            Install-TecharyWingetApp `
                -AppName        $AppName `
                -RepoPath       $app.RepoPath `
                -YamlFileName   $app.YamlFile `
                -PatternX64     $app.PatternX64 `
                -PatternARM64   $app.PatternARM64 `
                -InstallerType  $app.InstallerType `
                -ExeInstallArgs $app.ExeInstallArgs `
                -MsiInstallArgs $app.MsiInstallArgs `
                -GitHubToken    $GitHubToken
        }

    } catch {
        # Catch-all for top level errors
        Invoke-LogMessage -Message "Fatal error processing $AppName. Details: $($_.Exception.Message)" -Level "ERROR" -Source $FunctionName
        throw $_
    }
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
        [string]$InstallerType,
        [string]$ExeInstallArgs,
        [string]$MsiInstallArgs,
        [string]$GitHubToken
    )
    
    $LogSrc = "Winget-Install"

    try {
        $arch = (Get-ComputerInfo).CsSystemType
        $isARM = $arch -like "*ARM*"
        $suffix = if ($isARM) { "arm64" } else { "x64" }

        # 1. FETCH VERSIONS
        $versionUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$RepoPath"
        $headers = @{ "User-Agent" = "PowerShell" }
        if ($GitHubToken) { $headers["Authorization"] = "token $GitHubToken" }

        Invoke-LogMessage -Message "Fetching version list from: $versionUrl" -Level "INFO" -Source $LogSrc
        
        try {
            $response = Invoke-RestMethod -Uri $versionUrl -Headers $headers -ErrorAction Stop
        } catch {
            Invoke-LogMessage -Message "GitHub API Error: $($_.Exception.Message). (Rate limit likely exceeded?)" -Level "ERROR" -Source $LogSrc
            throw
        }

        # 2. SORT VERSIONS
        $rawVersions = $response | Where-Object { $_.type -eq "dir" } | ForEach-Object { $_.name } | Where-Object { $_ -match '^\d' }
        if (-not $rawVersions) { 
            Invoke-LogMessage -Message "No valid version folders found in repo path." -Level "ERROR" -Source $LogSrc
            throw "Version parsing failed"
        }

        # Robust Sort Logic
        $latestVersion = $rawVersions | Sort-Object { 
            $parts = $_.ToString().Split('.')
            $cleanVer = ($parts[0..([Math]::Min($parts.Count, 3))] -join '.')
            try { [version]$cleanVer } catch { [version]"0.0.0.0" }
        } -Descending | Select-Object -First 1

        Invoke-LogMessage -Message "Latest version identified: $latestVersion" -Level "SUCCESS" -Source $LogSrc

        # 3. LOCATE YAML
        $manifestUrl = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$RepoPath/$latestVersion"
        $manifestFiles = Invoke-RestMethod -Uri $manifestUrl -Headers $headers

        $targetFileObj = $manifestFiles | Where-Object { $_.name -eq $YamlFileName } | Select-Object -First 1
        if (-not $targetFileObj) {
            Invoke-LogMessage -Message "Exact YAML match '$YamlFileName' not found. searching generic 'installer.yaml'..." -Level "WARN" -Source $LogSrc
            $targetFileObj = $manifestFiles | Where-Object { $_.name -like "*installer.yaml" } | Select-Object -First 1
        }

        if (-not $targetFileObj) {
            Invoke-LogMessage -Message "CRITICAL: No valid installer YAML found for version $latestVersion." -Level "ERROR" -Source $LogSrc
            throw "YAML Missing"
        }

        # 4. PARSE YAML
        $yamlContent = Invoke-WebRequest -Uri $targetFileObj.download_url -UseBasicParsing
        $yamlText = $yamlContent.Content
        
        $installerUrl = $null
        if ($isARM -and $yamlText -match $PatternARM64) {
            $installerUrl = $matches[1]
        } elseif ($yamlText -match $PatternX64) {
            $installerUrl = $matches[1]
        }

        if (-not $installerUrl) {
            Invoke-LogMessage -Message "Regex failed to find InstallerURL in YAML." -Level "ERROR" -Source $LogSrc
            Invoke-LogMessage -Message "Debug: PatternX64 was '$PatternX64'" -Level "INFO" -Source $LogSrc
            throw "Regex Parse Failed"
        }

        # 5. DOWNLOAD
        $cleanInstallerUrl = $installerUrl -split '\?' | Select-Object -First 1
        $ext = [System.IO.Path]::GetExtension($cleanInstallerUrl)
        if (-not $ext) { $ext = ".exe" }

        $fileName = "${AppName}_${latestVersion}_${suffix}${ext}"
        $installerPath = Join-Path $script:folderPath $fileName

        Invoke-LogMessage -Message "Downloading binary: $installerUrl" -Level "INFO" -Source $LogSrc
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop

        # 6. INSTALL
        Invoke-LogMessage -Message "Running installer..." -Level "INFO" -Source $LogSrc
        
        switch ($InstallerType) {
            "msi" {
                $p = Start-Process "msiexec.exe" -ArgumentList "/i `"$installerPath`" $MsiInstallArgs" -Wait -NoNewWindow -PassThru
                if ($p.ExitCode -eq 0) {
                    Invoke-LogMessage -Message "MSI Install Success." -Level "SUCCESS" -Source $LogSrc
                } else {
                    Invoke-LogMessage -Message "MSI exited with code $($p.ExitCode). This might be an error." -Level "WARN" -Source $LogSrc
                }
            }
            "exe" {
                Start-Process -FilePath $installerPath -ArgumentList $ExeInstallArgs -Wait -NoNewWindow
                Invoke-LogMessage -Message "EXE Install command finished." -Level "SUCCESS" -Source $LogSrc
            }
            "msix" {
                Add-AppxProvisionedPackage -Online -PackagePath $installerPath -SkipLicense
                Invoke-LogMessage -Message "MSIX Provisioned." -Level "SUCCESS" -Source $LogSrc
            }
            "zip" {
                Invoke-LogMessage -Message "Extracting ZIP..." -Level "INFO" -Source $LogSrc
                $extractPath = Join-Path $script:folderPath "$AppName-$suffix"
                Expand-Archive -Path $installerPath -DestinationPath $extractPath -Force
                
                $allMsis = Get-ChildItem -Path $extractPath -Recurse -Filter *.msi
                $preferredMsi = $allMsis | Where-Object { $_.Name -match $suffix } | Select-Object -First 1
                if (-not $preferredMsi) { $preferredMsi = $allMsis | Select-Object -First 1 }

                if ($preferredMsi) {
                    Invoke-LogMessage -Message "Found MSI in ZIP: $($preferredMsi.Name)" -Level "INFO" -Source $LogSrc
                    Start-Process "msiexec.exe" -ArgumentList "/i `"$($preferredMsi.FullName)`" $MsiInstallArgs" -Wait -NoNewWindow
                } else {
                    Invoke-LogMessage -Message "No MSI found inside the ZIP archive." -Level "ERROR" -Source $LogSrc
                }
                Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

    } catch {
        Invoke-LogMessage -Message "Winget Install Failed. Exception: $($_.Exception.Message)" -Level "ERROR" -Source $LogSrc
        Invoke-LogMessage -Message "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR" -Source $LogSrc
        throw $_
    }
}
#endregion

#region Uninstall App
function Uninstall-TecharyApp {
    param ([string]$AppName)

    Invoke-LogMessage -Message "Starting Uninstall: $AppName" -Level "INFO" -Source "Uninstall"
    $apps = Get-TecharyAppMap
    $AppKey = $AppName.ToLower()
    
    if (-not $apps.ContainsKey($AppKey)) { 
        Invoke-LogMessage -Message "App not found in map." -Level "ERROR" -Source "Uninstall"
        return 
    }
    
    $app = $apps[$AppKey]

    if ($app.IsWinget -and $app.WingetID) {
        Invoke-LogMessage -Message "Attempting Winget uninstall for ID: $($app.WingetID)" -Level "INFO" -Source "Uninstall"
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        
        if ($winget) {
            & winget uninstall --id $($app.WingetID) --silent --accept-source-agreements --accept-package-agreements
            Invoke-LogMessage -Message "Winget uninstall command issued." -Level "SUCCESS" -Source "Uninstall"
            return
        } else {
            Invoke-LogMessage -Message "Winget executable not found in PATH." -Level "WARN" -Source "Uninstall"
        }
    }
    
    Invoke-LogMessage -Message "Manual registry uninstall logic not fully implemented yet for this version." -Level "WARN" -Source "Uninstall"
}
#endregion

#region Get-TecharyAppList
function Get-TecharyAppList {
    try {
        $apps = Get-TecharyAppMap
        $apps.Keys | Sort-Object | ForEach-Object {
            $app = $apps[$_]
            [PSCustomObject]@{
                AppKey      = $_
                DisplayName = $app.DisplayName
                WingetID    = $app.WingetID
            }
        }
    } catch {
        Invoke-LogMessage -Message "Failed to list apps: $($_.Exception.Message)" -Level "ERROR" -Source "Get-AppList"
    }
}
#endregion
