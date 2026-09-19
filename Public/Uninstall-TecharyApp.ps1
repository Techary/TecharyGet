function Uninstall-TecharyApp {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [switch]$WhatIf
    )

    Write-PackagerLog -Message "Searching for installed application: $Name"

    # 1. SEARCH REGISTRY (Classic Apps)
    $Paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $App = $null
    foreach ($Path in $Paths) {
        $App = Get-ItemProperty $Path -ErrorAction SilentlyContinue |
               Where-Object { $_.DisplayName -like "*$Name*" } |
               Select-Object -First 1
        if ($App) { break }
    }

    # 2. IF NOT IN REGISTRY, CHECK MSIX (Modern Apps)
    if (-not $App) {
        Write-PackagerLog -Message "Not found in Registry. Checking Modern Apps (MSIX)..."

        # SYSTEM has essentially no packages of its own, so a plain
        # Get-AppxPackage run from an RMM found nothing and reported the app as
        # absent. -AllUsers is what makes this work in the context the module is
        # actually driven from. It needs elevation, so fall back without it.
        $IsElevated = $false
        try {
            $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $IsElevated = (New-Object Security.Principal.WindowsPrincipal($Identity)).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)
        } catch {}

        $MsixResults = @()
        if ($IsElevated) {
            # Filtered to packages actually installed for someone. -AllUsers also
            # lists packages that are merely Staged on the machine, and a staged
            # package remains listed after a successful removal, so an unfiltered
            # list makes a completed uninstall look like it did nothing.
            try { $MsixResults = @(Get-AppxPackage -AllUsers -Name "*$Name*" -ErrorAction Stop |
                                   Where-Object { Test-AppxInstalledForAnyUser -Package $_ }) }
            catch {
                Write-PackagerLog -Message "Could not enumerate packages for all users ($($_.Exception.Message)). Falling back to the current user." -Severity Warning
                $MsixResults = @(Get-AppxPackage -Name "*$Name*" -ErrorAction SilentlyContinue)
            }
        } else {
            Write-PackagerLog -Message "Not elevated, so only the current user's packages are visible." -Severity Warning
            $MsixResults = @(Get-AppxPackage -Name "*$Name*" -ErrorAction SilentlyContinue)
        }

        # A provisioned package is what seeds new user profiles. Leaving it in
        # place meant a removed app reappeared for the next user who signed in.
        $Provisioned = @()
        if ($IsElevated) {
            try {
                $Provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop |
                                 Where-Object { $_.DisplayName -like "*$Name*" })
            } catch {
                Write-PackagerLog -Message "Could not enumerate provisioned packages: $($_.Exception.Message)" -Severity Warning
            }
        }

        if ($MsixResults.Count -gt 0 -or $Provisioned.Count -gt 0) {
            # Handle cases where multiple apps match (Array vs Single Object)
            foreach ($Package in $MsixResults) {
                Write-PackagerLog -Message "Found Modern App: $($Package.Name) ($($Package.PackageFullName))"

                if ($WhatIf) {
                    $Scope = if ($IsElevated) { "for all users" } else { "for the current user only" }
                    Write-Host "[WhatIf] Would remove $Scope`: $($Package.PackageFullName)" -ForegroundColor Yellow
                    continue
                }

                try {
                    if ($IsElevated) {
                        Remove-AppxPackage -Package $Package.PackageFullName -AllUsers -ErrorAction Stop
                        $Scope = "for all users"
                    } else {
                        Remove-AppxPackage -Package $Package.PackageFullName -ErrorAction Stop
                        $Scope = "for the current user"
                    }

                    # Confirm rather than infer, but give it time to settle.
                    # Removal completes asynchronously: the package is still
                    # listed for a short period after Remove-AppxPackage returns,
                    # so an immediate check reports a false failure.
                    $Deadline = (Get-Date).AddSeconds(30)
                    $StillThere = $true
                    while ($StillThere -and (Get-Date) -lt $Deadline) {
                        $StillThere = Test-AppxInstalledForAnyUser -PackageFullName $Package.PackageFullName
                        if ($StillThere) { Start-Sleep -Seconds 2 }
                    }

                    if ($StillThere) {
                        # Not asserted as a failure: removal may still be pending.
                        # Reported so it is visible rather than assumed successful.
                        Write-PackagerLog -Message "Removed $($Package.Name) $Scope, but it is still registered after 30s. Removal may be pending a reboot or sign-out." -Severity Warning
                    } else {
                        Write-PackagerLog -Message "Success: Removed $($Package.Name) $Scope, confirmed."
                    }
                }
                catch {
                    # -AllUsers is unsupported on some builds. A per-user removal
                    # still beats reporting an outright failure.
                    Write-PackagerLog -Message "All-users removal failed for $($Package.Name): $($_.Exception.Message). Retrying for the current user." -Severity Warning
                    try {
                        Remove-AppxPackage -Package $Package.PackageFullName -ErrorAction Stop
                        Write-PackagerLog -Message "Success: Removed $($Package.Name) for the current user."
                    }
                    catch {
                        Write-PackagerLog -Message "Failed to remove $($Package.Name): $($_.Exception.Message)" -Severity Error
                    }
                }
            }

            foreach ($Prov in $Provisioned) {
                if ($WhatIf) {
                    Write-Host "[WhatIf] Would deprovision: $($Prov.PackageName)" -ForegroundColor Yellow
                    continue
                }

                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $Prov.PackageName -ErrorAction Stop | Out-Null
                    Write-PackagerLog -Message "Deprovisioned $($Prov.DisplayName), so it will not return for new users."
                }
                catch {
                    Write-PackagerLog -Message "Failed to deprovision $($Prov.DisplayName): $($_.Exception.Message)" -Severity Error
                }
            }

            return
        }

        Write-PackagerLog -Message "Application '$Name' not found on this system." -Severity Warning
        return
    }

    # 3. DETERMINE UNINSTALL COMMAND (Classic Apps)
    # Both must be initialised: an unset $Arguments previously reached
    # Start-Process as $null whenever the MSI branch failed to match a GUID.
    $UninstallString = $null
    $Arguments = ""
    $Type = "EXE"

    if ($App.UninstallString -match "MsiExec.exe") {
        $Type = "MSI"
        if ($App.UninstallString -match '{[A-F0-9-]+}') {
            $Guid = $Matches[0]
            $UninstallString = "msiexec.exe"
            $Arguments = "/x $Guid /qn /norestart"
        }
        else {
            Write-PackagerLog -Message "MSI uninstall string for '$($App.DisplayName)' contains no product code: $($App.UninstallString)" -Severity Error
            return
        }
    }
    else {
        # EXE Uninstaller logic
        # QuietUninstallString is silent by definition. Appending our own
        # switches to it passed contradictory flags to the uninstaller, which
        # made some vendors' uninstallers fail or fall back to a UI prompt.
        $UsedQuietString = [bool]$App.QuietUninstallString

        if ($UsedQuietString) {
            $RawString = $App.QuietUninstallString
        } else {
            $RawString = $App.UninstallString
        }

        if ($RawString -match '^(?:"([^"]+)"|([^ ]+))(.*)$') {
            $Exe = if ($Matches[1]) { $Matches[1] } else { $Matches[2] }
            $ArgsPart = $Matches[3].Trim()

            $UninstallString = $Exe
            $Arguments = $ArgsPart

            if (-not $UsedQuietString -and -not ($Arguments -match "/S|/silent|/qn|/quiet")) {
                $Arguments = "$Arguments /S /silent /quiet /norestart"
            }
        }
    }

    if (-not $UninstallString) {
        Write-PackagerLog -Message "Could not derive an uninstall command for '$($App.DisplayName)' from: $($App.UninstallString)" -Severity Error
        return
    }

    Write-PackagerLog -Message "Found: $($App.DisplayName) ($Type)"
    Write-PackagerLog -Message "Command: $UninstallString $Arguments"

    if ($WhatIf) {
        Write-Host "[WhatIf] Would execute: $UninstallString $Arguments" -ForegroundColor Yellow
        return
    }

    # 4. EXECUTE REMOVAL
    try {
        if ([string]::IsNullOrWhiteSpace($Arguments)) {
            $Process = Start-Process -FilePath $UninstallString -PassThru -Wait -NoNewWindow
        } else {
            $Process = Start-Process -FilePath $UninstallString -ArgumentList $Arguments -PassThru -Wait -NoNewWindow
        }

        if ($Process.ExitCode -eq 0 -or $Process.ExitCode -eq 3010) {
            Write-PackagerLog -Message "Uninstallation Successful."
        } else {
            Write-PackagerLog -Message "Uninstallation finished with Exit Code: $($Process.ExitCode)" -Severity Warning
        }
    }
    catch {
        Write-PackagerLog -Message "Uninstallation Failed: $_" -Severity Error
    }
}
