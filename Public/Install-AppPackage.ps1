function Install-AppPackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$false)][object]$Arguments = @(),
        [string]$Name = "Unknown Application"
    )

    $Extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    if (Test-Path $FilePath) { Unblock-File -Path $FilePath }
    
    Write-PackagerLog -Message "Starting installation flow for: $Name ($Extension)"

    # --- ROUTING LOGIC ---
    switch ($Extension) {
        ".zip" {
            Write-PackagerLog -Message "Detected ZIP. Extracting..."
            $ZipName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
            $DestPath = Join-Path (Split-Path $FilePath) "Extracted_$ZipName"
            if (Test-Path $DestPath) { Remove-Item $DestPath -Recurse -Force }
            Expand-Archive -Path $FilePath -DestinationPath $DestPath -Force
            
            $Candidates = Get-ChildItem -Path $DestPath -Include *.exe,*.msi -Recurse
            $Installer = $Candidates | Where-Object { $_.Name -match "setup" -or $_.Name -match "install" } | Select-Object -First 1
            if (-not $Installer) { $Installer = $Candidates | Sort-Object Length -Descending | Select-Object -First 1 }
            if (-not $Installer) { throw "Extracted ZIP but could not find installer." }

            Write-PackagerLog -Message "Found installer inside ZIP: $($Installer.Name)"
            Install-AppPackage -Name $Name -FilePath $Installer.FullName -Arguments $Arguments
            return 
        }
        { $_ -in ".msix", ".appx", ".msixbundle", ".appxbundle" } {
            Write-PackagerLog -Message "Detected Modern App. Sideloading..."

            # Try provisioning as the machine is configured, before changing
            # anything. A correctly signed package normally needs no policy
            # change at all, and the previous code relaxed sideloading policy
            # unconditionally on every MSIX install and never put it back,
            # permanently weakening every machine the module touched.
            $Provisioned = $false
            try {
                Add-AppxProvisionedPackage -Online -PackagePath $FilePath -SkipLicense -ErrorAction Stop | Out-Null
                Write-PackagerLog -Message "MSIX Provisioned Successfully."
                $Provisioned = $true
            }
            catch {
                Write-PackagerLog -Message "Provisioning refused under current policy ($($_.Exception.Message)). Relaxing sideloading policy temporarily." -Severity Warning
            }

            if (-not $Provisioned) {
                $PolicyState = $null
                try {
                    $PolicyState = Push-SideloadPolicy
                    if (-not $PolicyState.Success) {
                        Write-PackagerLog -Message "Could not fully relax sideloading policy: $($PolicyState.Errors -join '; ')" -Severity Warning
                    }

                    Add-AppxProvisionedPackage -Online -PackagePath $FilePath -SkipLicense -ErrorAction Stop | Out-Null
                    Write-PackagerLog -Message "MSIX Provisioned Successfully."
                    $Provisioned = $true
                }
                catch {
                    Write-PackagerLog -Message "Provisioning Failed ($($_.Exception.Message)). Trying Per-User..." -Severity Warning
                    try { Add-AppxPackage -Path $FilePath -ErrorAction Stop } catch { throw $_ }
                }
                finally {
                    # Always, including on the throw above.
                    Pop-SideloadPolicy -State $PolicyState
                    Write-PackagerLog -Message "Sideloading policy restored to its previous state."
                }
            }
            return
        }
        ".msi" {
            Write-PackagerLog -Message "Detected MSI. Switching to msiexec."
            $MsiPath = $FilePath
            $FilePath = "msiexec.exe"
            # Logic to ensure /i is prepended cleanly
            if ($Arguments -is [string]) { $Arguments = "/i `"$MsiPath`" $Arguments" }
            else { $Arguments = @("/i", $MsiPath) + $Arguments }
        }
    }

    # --- SAFE EXECUTION ---
    # 1. Sanitize Arguments (The Fix for the Null Crash)
    if ($null -eq $Arguments) { $Arguments = @() }
    
    if ($Arguments -is [string]) {
        # Regex split that respects quotes
        $Regex = ' (?=(?:[^"]*"[^"]*")*[^"]*$)'
        $ArgList = [regex]::Split($Arguments, $Regex) 
    } else { 
        $ArgList = $Arguments 
    }

    # Filter out nulls/empties from the array
    $ArgList = $ArgList | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    Write-PackagerLog -Message "Executor: $FilePath"
    Write-PackagerLog -Message "Final Args: $($ArgList -join ' | ')"

    try {
        # If ArgList is empty, pass $null explicitly to avoid binding errors
        if ($ArgList.Count -eq 0) {
            $Process = Start-Process -FilePath $FilePath -PassThru -Wait -NoNewWindow
        } else {
            $Process = Start-Process -FilePath $FilePath -ArgumentList $ArgList -PassThru -Wait -NoNewWindow
        }

        $ExitCode = $Process.ExitCode
        Write-PackagerLog -Message "Finished. Exit Code: $ExitCode"

        switch ($ExitCode) {
            0    { Write-PackagerLog -Message "Success." }
            3010 { Write-PackagerLog -Message "Success (Reboot Required)." -Severity Warning }
            1641 { Write-PackagerLog -Message "Success (Hard Reboot Initiated)." -Severity Warning }
            4    { Write-PackagerLog -Message "Success (Reboot Required - Vendor Specific)." -Severity Warning }
            default { throw "Failed with code $ExitCode" }
        }
    }
    catch {
        Write-PackagerLog -Message "Installation Failure: $_" -Severity Error
        throw $_
    }
}