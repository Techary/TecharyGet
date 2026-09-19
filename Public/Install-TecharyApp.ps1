$ProgressPreference = 'SilentlyContinue'

function Install-TecharyApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Id,

        # Passed through to the winget-pkgs manifest lookup. Raises the GitHub
        # API allowance from 60 to 5000 requests/hour where one is available.
        [string]$GitHubToken = $env:TECHARYGET_GITHUB_TOKEN
    )

    $Pkg = $null

    # --- ATTEMPT 1: GITHUB ---
    try {
        $Pkg = Get-GitHubInstaller -Id $Id -GitHubToken $GitHubToken -ErrorAction Stop
    }
    catch {
        Write-PackagerLog -Message "Not found in GitHub ($Id). Checking Custom Catalog..." -Severity Info
    }

    # --- ATTEMPT 2: CUSTOM CATALOG ---
    if (-not $Pkg) {
        # Load the internal helper to check JSON
        # (Assuming Get-CustomApp is dot-sourced in .psm1)
        $CustomData = Get-CustomApp -Id $Id

        if ($CustomData) {
            Write-PackagerLog -Message "Found '$Id' in Custom Catalog."

            $DownloadPath = "$env:TEMP\AppPackager"
            if (Test-Path $DownloadPath) { Remove-Item "$DownloadPath\*" -Recurse -Force -ErrorAction SilentlyContinue }
            New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null

            $FileName = "$Id.$($CustomData.InstallerType)"
            $FullPath = Join-Path $DownloadPath $FileName

            Write-PackagerLog -Message "Downloading Custom App from: $($CustomData.Url)"
            Invoke-WebRequest -Uri $CustomData.Url -OutFile $FullPath -UseBasicParsing

            # Build the Package Object manually
            $Pkg = [PSCustomObject]@{
                Name          = $Id
                InstallerPath = $FullPath
                FileName      = $FileName
                SilentArgs    = $CustomData.SilentArgs
                InstallerType = $CustomData.InstallerType
            }
        }
    }

    if (-not $Pkg) {
        $Msg = "Application '$Id' not found in GitHub OR Custom Catalog."
        Write-PackagerLog -Message $Msg -Severity Error
        # Throw rather than return. A caller driving this from Intune or an RMM
        # remediation cannot distinguish a silent return from a successful
        # install, so a mistyped Id would be reported to the console as success.
        throw $Msg
    }

    # --- INSTALLATION ---
    # MSI Fallback Logic
    # Named InstallArgs, not Args: $Args is an automatic variable and assigning
    # to it is undefined behaviour under Set-StrictMode.
    $InstallArgs = $Pkg.SilentArgs
    if ([string]::IsNullOrWhiteSpace($InstallArgs) -and ($Pkg.InstallerPath -match "\.msi$" -or $Pkg.InstallerType -eq "msi")) {
        $InstallArgs = "/qb /norestart"
    }

    try {
        Install-AppPackage -Name $Pkg.Name -FilePath $Pkg.InstallerPath -Arguments $InstallArgs
    }
    finally {
        # Clean up even when the install throws, so a failed run does not
        # leave an installer behind for the next one to trip over.
        Invoke-PackagerCleanup -Paths "$env:TEMP\AppPackager" -Force
    }
}
