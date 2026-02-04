$ProgressPreference = 'SilentlyContinue'

function Install-SmartApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Id
    )
    
    $Pkg = $null

    # --- ATTEMPT 1: GITHUB ---
    try {
        $Pkg = Get-GitHubInstaller -Id $Id -ErrorAction Stop
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
            
            # Use the Web Installer logic to download it
            # We can reuse the logic or call Get-WebInstaller if you created it.
            # Here is the inline logic for simplicity:
            
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
        Write-PackagerLog -Message "Application '$Id' not found in GitHub OR Custom Catalog." -Severity Error
        return
    }
    
    # --- INSTALLATION ---
    # MSI Fallback Logic
    $Args = $Pkg.SilentArgs
    if ([string]::IsNullOrWhiteSpace($Args) -and ($Pkg.InstallerPath -match ".msi$" -or $Pkg.InstallerType -eq "msi")) {
        $Args = "/qb /norestart"
    }
    
    Install-AppPackage -Name $Pkg.Name -FilePath $Pkg.InstallerPath -Arguments $Args
    Invoke-PackagerCleanup -Paths "$env:TEMP\AppPackager" -Force
}