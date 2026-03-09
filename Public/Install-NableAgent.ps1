function Install-NableAgent {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$CustomerID,
        [Parameter(Mandatory=$true)][string]$Token,
        [Parameter(Mandatory=$true)][string]$CustomerName,
        [Parameter(Mandatory=$true)][string]$ServerAddress,
        [int]$TimeoutSeconds = 1200 # 20 minutes
    )

    $Name = "N-able RMM Agent"
    $DownloadUrl = "https://$ServerAddress/download/current/winnt/N-central/WindowsAgentSetup.exe"
    $DownloadPath = "$env:TEMP\AppPackager"
    $FileName = "Nable_RMMInstaller.exe"
    $InstallerPath = Join-Path $DownloadPath $FileName

    Write-PackagerLog -Message "Starting N-able Deployment for Customer: $CustomerName"

    try {
        # 1. Download
        if (Test-Path $DownloadPath) { Remove-Item "$DownloadPath\*" -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null

        Write-PackagerLog -Message "Downloading installer from: $DownloadUrl"
        
        # We use a spoofed UserAgent just in case N-able blocks scripts, though usually not required here.
        $UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -UseBasicParsing -UserAgent $UserAgent

        if (-not (Test-Path $InstallerPath)) { throw "Download failed. File not found." }

        # 2. Build Arguments (Standard InstallShield format)
        # /S = Silent for the wrapper
        # /v = Pass arguments to internal MSI
        # We quote the MSI arguments carefully so Install-AppPackage regex keeps them together.
        
        $MsiArgs = "/qn CUSTOMERID=$CustomerID CUSTOMERNAME=$CustomerName CUSTOMERSPECIFIC=1 REGISTRATION_TOKEN=$Token SERVERPROTOCOL=HTTPS SERVERADDRESS=$ServerAddress SERVERPORT=443"
        
        # NOTE: We construct the final string. Install-AppPackage's Regex will see "/v"..." " as one argument.
        $FinalArgs = "/S /v`"$MsiArgs`""

        # 3. Install (Using your module's executor)
        Install-AppPackage -Name $Name -FilePath $InstallerPath -Arguments $FinalArgs

        # 4. Cleanup Installer immediately
        Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue

        # 5. Validation Loop (The "Is it actually working?" check)
        Write-PackagerLog -Message "Starting Post-Install Validation (Timeout: ${TimeoutSeconds}s)..."
        
        $StartTime = Get-Date
        
        while ($true) {
            # Check Services and Files
            $Service1 = Get-Service -Name "Windows Agent Service" -ErrorAction SilentlyContinue
            $Service2 = Get-Service -Name "N-able Take Control Service (N-Central)" -ErrorAction SilentlyContinue
            $FileCheck = Test-Path "C:\Program Files (x86)\BeAnywhere Support Express\GetSupportService_N-Central\uninstall.exe"

            if ($Service1 -and $Service2 -and $FileCheck) {
                Write-PackagerLog -Message "Validation Successful: N-able services are running."
                return # Success!
            }

            # Check Timeout
            $Elapsed = (Get-Date) - $StartTime
            if ($Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                Write-PackagerLog -Message "Validation Timed Out. Services did not start in time." -Severity Error
                throw "N-able installation finished, but validation failed (Timeout)."
            }

            Write-PackagerLog -Message "Waiting for services to start..."
            Start-Sleep -Seconds 10
        }

    }
    catch {
        Write-PackagerLog -Message "N-able Deployment Failed: $_" -Severity Error
        throw $_
    }
}