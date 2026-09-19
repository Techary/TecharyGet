function Push-SideloadPolicy {
    <#
    .SYNOPSIS
        Relaxes the Appx sideloading policy and returns enough state to undo it.

    .DESCRIPTION
        Records, for each value it touches, whether the key already existed,
        whether the value already existed, and what the value was. Pass the
        result to Pop-SideloadPolicy to put the machine back as it was found.

        This deliberately never throws. If it did, the state describing what
        had already been changed would be lost with it and the caller's finally
        block would have nothing to restore from, leaving the policy relaxed.
        Failures are recorded and reported through the returned object instead.

        Paths are parameters so the round trip can be tested against a scratch
        key without touching real machine policy.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Paths = @(
            "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
        ),
        [string]$ValueName = "AllowAllTrustedApps"
    )

    $Changed = New-Object System.Collections.Generic.List[object]
    $Ok = $true
    $Errors = New-Object System.Collections.Generic.List[string]

    foreach ($Path in $Paths) {
        $KeyExisted = Test-Path $Path
        $ValueExisted = $false
        $PriorValue = $null

        if ($KeyExisted) {
            $Existing = Get-ItemProperty -Path $Path -Name $ValueName -ErrorAction SilentlyContinue
            if ($null -ne $Existing) {
                $ValueExisted = $true
                $PriorValue = $Existing.$ValueName
            }
        }

        try {
            if (-not $KeyExisted) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }

            # Record before writing, so anything we manage to change is undoable
            # even if a later step fails.
            $Changed.Add([PSCustomObject]@{
                Path         = $Path
                ValueName    = $ValueName
                KeyExisted   = $KeyExisted
                ValueExisted = $ValueExisted
                PriorValue   = $PriorValue
            })

            New-ItemProperty -Path $Path -Name $ValueName -Value 1 -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
        }
        catch {
            $Ok = $false
            $Errors.Add("$Path : $($_.Exception.Message)")
        }
    }

    return [PSCustomObject]@{
        Changed = $Changed
        Success = $Ok
        Errors  = $Errors
    }
}

function Pop-SideloadPolicy {
    <#
    .SYNOPSIS
        Restores whatever Push-SideloadPolicy changed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        $State
    )

    if (-not $State -or -not $State.Changed -or $State.Changed.Count -eq 0) { return }

    # Indexed directly rather than wrapped in @(). On PowerShell 7.6 / .NET 10,
    # @() over a List[object] throws "Argument types do not match", which would
    # abort the restore and leave sideloading policy relaxed - the exact failure
    # this function exists to prevent.
    for ($i = $State.Changed.Count - 1; $i -ge 0; $i--) {
        $Item = $State.Changed[$i]

        try {
            if ($Item.ValueExisted) {
                New-ItemProperty -Path $Item.Path -Name $Item.ValueName -Value $Item.PriorValue -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
            }
            elseif ($Item.KeyExisted) {
                Remove-ItemProperty -Path $Item.Path -Name $Item.ValueName -Force -ErrorAction Stop
            }
            else {
                # We created the key, so take the whole thing back out.
                Remove-Item -Path $Item.Path -Force -Recurse -ErrorAction Stop
            }
        }
        catch {
            Write-PackagerLog -Message "Could not restore sideload policy at $($Item.Path): $($_.Exception.Message)" -Severity Warning
        }
    }
}
