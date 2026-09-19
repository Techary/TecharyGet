function Test-AppxInstalledForAnyUser {
    <#
    .SYNOPSIS
        True when an MSIX package is actually installed for at least one user.

    .DESCRIPTION
        Get-AppxPackage -AllUsers lists packages that are merely Staged on the
        machine as well as ones a user has installed, so presence in that list
        is not evidence of installation.

        Removal is also asynchronous: a package stays listed for a period after
        Remove-AppxPackage returns. Callers should therefore poll this over a
        settle window rather than treat a single immediate result as final.

        PackageUserInformation carries the per-user InstallState, which is the
        distinction that matters. Where it is unavailable - not elevated, or an
        older build - this falls back to a plain Get-AppxPackage, which lists
        only what is installed for the caller.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'ByObject')]
        $Package,

        [Parameter(ParameterSetName = 'ByName')]
        [string]$PackageFullName
    )

    if (-not $Package -and $PackageFullName) {
        # Name is the segment before the first underscore of the full name, and
        # filtering on it avoids enumerating every package on the machine.
        $ShortName = $PackageFullName.Split('_')[0]
        try {
            $Package = Get-AppxPackage -AllUsers -Name $ShortName -ErrorAction Stop |
                       Where-Object { $_.PackageFullName -eq $PackageFullName } |
                       Select-Object -First 1
        } catch { }

        if (-not $Package) {
            try {
                $Package = Get-AppxPackage -Name $ShortName -ErrorAction SilentlyContinue |
                           Where-Object { $_.PackageFullName -eq $PackageFullName } |
                           Select-Object -First 1
            } catch { }
        }
    }

    # Not present at all, so certainly not installed.
    if (-not $Package) { return $false }

    $Info = $null
    try { $Info = $Package.PackageUserInformation } catch { }

    if ($Info) {
        foreach ($User in $Info) {
            if ("$($User.InstallState)" -eq 'Installed') { return $true }
        }
        return $false
    }

    try {
        $Mine = Get-AppxPackage -ErrorAction SilentlyContinue |
                Where-Object { $_.PackageFullName -eq $Package.PackageFullName }
        return [bool]$Mine
    } catch {
        return $false
    }
}
