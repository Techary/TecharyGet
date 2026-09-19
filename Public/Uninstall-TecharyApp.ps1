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
        $MsixResults = Get-AppxPackage -Name "*$Name*" -ErrorAction SilentlyContinue

        if ($MsixResults) {
            # FIX: Handle cases where multiple apps match (Array vs Single Object)
            foreach ($Package in $MsixResults) {
                Write-PackagerLog -Message "Found Modern App: $($Package.Name)"

                if ($WhatIf) {
                    Write-Host "[WhatIf] Would remove: $($Package.PackageFullName)" -ForegroundColor Yellow
                    continue
                }

                try {
                    Remove-AppxPackage -Package $Package.PackageFullName -ErrorAction Stop
                    Write-PackagerLog -Message "Success: Removed $($Package.Name)"
                }
                catch {
                    Write-PackagerLog -Message "Failed to remove $($Package.Name): $_" -Severity Error
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
