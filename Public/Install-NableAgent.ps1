function Install-NableAgent {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$CustomerID,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $false)]
        [string]$CustomerName,

        [Parameter(Mandatory = $true)]
        [string]$ServerAddress,

        [int]$TimeoutSeconds = 600
    )

    $Name = "N-able RMM Agent"
    $DownloadPath = "C:\Temp\AppPackager"
    $FileName = "Nable_RMMInstaller.exe"
    $InstallerPath = Join-Path $DownloadPath $FileName
    $DownloadUrl = "https://$ServerAddress/download/current/winnt/N-central/WindowsAgentSetup.exe"

    try {
        Write-PackagerLog -Message "Starting N-able Deployment for Customer: $CustomerName"

        if (-not (Test-Path $DownloadPath)) {
            New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
        }

        if (Test-Path $InstallerPath) {
            Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue
        }

        Write-PackagerLog -Message "Downloading installer from: $DownloadUrl"

        Invoke-WebRequest `
            -Uri $DownloadUrl `
            -OutFile $InstallerPath `
            -UseBasicParsing `
            -UserAgent "Mozilla/5.0"

        if (-not (Test-Path $InstallerPath)) {
            throw "Download failed. File not found."
        }

        Unblock-File -Path $InstallerPath -ErrorAction SilentlyContinue

        # If N-able requires the customer name value literally as:
        # '\"Techary Internal\"'
        # $FormattedCustomerName = "\`"$CustomerName\`""

        # Build arguments EXACTLY like the working script pattern
        $MsiArgs = "/qn CUSTOMERID=$CustomerID CUSTOMERSPECIFIC=1 REGISTRATION_TOKEN=$Token SERVERPROTOCOL=HTTPS SERVERADDRESS=$ServerAddress SERVERPORT=443"
        $Arguments = "/S /v`"$MsiArgs`""

        Write-PackagerLog -Message "Executing N-able installer..."
        Write-PackagerLog -Message "Executor: $InstallerPath"
        Write-PackagerLog -Message "Final Args: $Arguments"

        $Process = Start-Process `
            -FilePath $InstallerPath `
            -ArgumentList $Arguments `
            -Wait `
            -PassThru `
            -NoNewWindow

        Write-PackagerLog -Message "Installer finished with exit code: $($Process.ExitCode)"

        # Do NOT fail immediately on exit code.
        # The working script's real success criteria is service validation.
        Write-PackagerLog -Message "Starting Post-Install Validation (Timeout: ${TimeoutSeconds}s)..."

        $StartTime = Get-Date

        while ($true) {
            # Check Services and Files
            $Service1 = Get-Service -Name "Windows Agent Service" -ErrorAction SilentlyContinue
            $Service2 = Get-Service -Name "N-able Take Control Service (N-Central)" -ErrorAction SilentlyContinue
            $FileCheck = Test-Path "C:\Program Files (x86)\BeAnywhere Support Express\GetSupportService_N-Central\uninstall.exe"

            $Service1Running = $Service1 -and $Service1.Status -eq "Running"
            $Service2Running = $Service2 -and $Service2.Status -eq "Running"

            if ($Service1Running -and $Service2Running -and $FileCheck) {
                Write-PackagerLog -Message "Validation Successful: N-able services are running."
                Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue
                return
            }

            # Check Timeout
            $Elapsed = (Get-Date) - $StartTime
            if ($Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                Write-PackagerLog -Message "Validation Timed Out. Services did not start in time." -Severity Error
                throw "N-able installation finished, but validation failed (Timeout). ExitCode=$($Process.ExitCode)"
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
