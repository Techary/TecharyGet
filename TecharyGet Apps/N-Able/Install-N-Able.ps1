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

            C:\temp\WindowsAgentSetup.exe /silent /v" /qn CUSTOMERID=$CustomerID CUSTOMERNAME='\"$customername\"' CUSTOMERSPECIFIC=1 REGISTRATION_TOKEN=$Token SERVERPROTOCOL=HTTPS SERVERADDRESS=$serveraddress SERVERPORT=443 "

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