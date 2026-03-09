function Test-TecharyApp {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name # App ID (e.g. "MyDPD") or Display Name
    )

    # 1. RESOLVE ID -> DISPLAY NAME
    # Check if this ID exists in your Custom Catalog with a specific DisplayName mapping
    $CustomApp = Get-CustomApp -Id $Name
    if ($CustomApp -and $CustomApp.DisplayName) {
        $Name = $CustomApp.DisplayName
    }

    # 2. SEARCH REGISTRY (Classic Apps)
    $Paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($Path in $Paths) {
        $Match = Get-ItemProperty $Path -ErrorAction SilentlyContinue | 
                 Where-Object { $_.DisplayName -like "*$Name*" } | 
                 Select-Object -First 1
        
        if ($Match) {
            Write-Verbose "Found Registry Match: $($Match.DisplayName)"
            return $true
        }
    }

    # 3. SEARCH MSIX (Modern Apps)
    $Msix = Get-AppxPackage -Name "*$Name*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Msix) {
        Write-Verbose "Found MSIX: $($Msix.Name)"
        return $true
    }

    # 4. NOT FOUND
    return $false
}