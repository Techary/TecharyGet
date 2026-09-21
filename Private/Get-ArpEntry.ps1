function Get-ArpEntry {
    <#
    .SYNOPSIS
        The machine's Add/Remove Programs entries, enumerated as winget does.

    .DESCRIPTION
        Mirrors ARPHelper::PopulateIndexFromARP. Three views, and the skip
        rules matter: a divergence here means our inventory differs from
        winget's before any matching happens.

          machine  HKLM\...\Uninstall            64-bit view
          machine  HKLM\WOW6432Node\...\Uninstall 32-bit view
          user     HKCU\...\Uninstall             native view only

        There is deliberately no 32-bit view for user scope -- the
        KEY_WOW64_32KEY branch is gated on machine scope (ARPHelper.cpp:167).

        ProductCode is the SUBKEY NAME, not a value (ARPHelper.cpp:396).

        Note the skip rules are exactly three. The source also appears to
        skip entries with no version, but DetermineVersion returns
        "Unknown" rather than empty, so that branch never fires; adding it
        here would drop entries winget keeps.
    #>
    [CmdletBinding()]
    param()

    $Hives = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    foreach ($Hive in $Hives) {
        foreach ($Key in (Get-ChildItem -LiteralPath $Hive -ErrorAction SilentlyContinue)) {
            $Item = $null
            try { $Item = Get-ItemProperty -LiteralPath $Key.PSPath -ErrorAction Stop } catch { continue }

            # 1. SystemComponent non-zero
            if ($Item.PSObject.Properties['SystemComponent'] -and [int]$Item.SystemComponent -ne 0) { continue }
            # 2 and 3. DisplayName absent, or empty
            $Display = $Item.PSObject.Properties['DisplayName'] | ForEach-Object { $_.Value }
            if ([string]::IsNullOrEmpty($Display)) { continue }

            $Publisher = $null
            if ($Item.PSObject.Properties['Publisher']) { $Publisher = [string]$Item.Publisher }

            # UpgradeCode is only looked up for MSI entries (ARPHelper.cpp:472).
            $IsMsi = $false
            if ($Item.PSObject.Properties['WindowsInstaller']) {
                try { $IsMsi = ([int]$Item.WindowsInstaller -ne 0) } catch { }
            }

            [PSCustomObject]@{
                ProductCode      = $Key.PSChildName
                DisplayName      = [string]$Display
                Publisher        = $Publisher
                DisplayVersion   = $(if ($Item.PSObject.Properties['DisplayVersion']) { [string]$Item.DisplayVersion } else { $null })
                WindowsInstaller = $IsMsi
                Path             = $Key.PSPath
            }
        }
    }
}

function ConvertTo-PackedGuid {
    <#
        MSI's packed GUID form: the first three groups are reversed whole,
        the last two are reversed bytewise. ARPHelper.cpp:15-60.
    #>
    param([Parameter(Mandatory)][string]$Guid)
    $g = $Guid.Trim().Trim('{', '}')
    $p = $g.Split('-')
    if ($p.Count -ne 5) { return $null }
    $r  = ($p[0][7,6,5,4,3,2,1,0] -join '')
    $r += ($p[1][3,2,1,0] -join '')
    $r += ($p[2][3,2,1,0] -join '')
    $r += ($p[3][1,0] -join '') + ($p[3][3,2] -join '')
    for ($i = 0; $i -lt 12; $i += 2) { $r += ($p[4][($i + 1), $i] -join '') }
    return $r.ToUpperInvariant()
}

function ConvertFrom-PackedGuid {
    param([Parameter(Mandatory)][string]$Packed)
    if ($Packed.Length -ne 32) { return $null }
    $a = ($Packed[7,6,5,4,3,2,1,0] -join '')
    $b = ($Packed[11,10,9,8] -join '')
    $c = ($Packed[15,14,13,12] -join '')
    $d = ($Packed[17,16] -join '') + ($Packed[19,18] -join '')
    $e = ''
    for ($i = 20; $i -lt 32; $i += 2) { $e += ($Packed[($i + 1), $i] -join '') }
    return ('{{{0}-{1}-{2}-{3}-{4}}}' -f $a, $b, $c, $d, $e).ToLowerInvariant()
}

function Get-UpgradeCodeMap {
    <#
    .SYNOPSIS
        Packed product code -> upgrade code, for MSI entries.

    .DESCRIPTION
        UpgradeCode is not a value on the uninstall key. It lives under
        Installer\UpgradeCodes keyed the opposite way round: the key name is
        the packed upgrade code and its VALUES are the packed product codes
        it covers (ARPHelper.cpp:63-105). Built once and inverted, because
        walking it per entry would be far slower.

        There is no UpgradeCodes key in the 32-bit view (ARPHelper.cpp:82).
    #>
    [CmdletBinding()]
    param()

    $Map = @{}
    $Root = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UpgradeCodes'
    foreach ($Key in (Get-ChildItem -LiteralPath $Root -ErrorAction SilentlyContinue)) {
        $Upgrade = ConvertFrom-PackedGuid $Key.PSChildName
        if (-not $Upgrade) { continue }
        $Props = $null
        try { $Props = Get-ItemProperty -LiteralPath $Key.PSPath -ErrorAction Stop } catch { continue }
        foreach ($p in $Props.PSObject.Properties) {
            if ($p.Name -like 'PS*') { continue }
            if (-not $Map.ContainsKey($p.Name)) { $Map[$p.Name] = $Upgrade }
        }
    }
    return $Map
}

function Get-ArpCorrelationSet {
    <#
    .SYNOPSIS
        ARP entries with winget's correlation keys precomputed.

    .DESCRIPTION
        Normalising every entry costs real time, so this is done once per
        call to Test-TecharyApp rather than once per candidate key.
    #>
    [CmdletBinding()]
    param()

    $Upgrades = @{}
    try { $Upgrades = Get-UpgradeCodeMap } catch { }

    foreach ($e in Get-ArpEntry) {
        $n = $null
        try { $n = Get-WgNormalizedName -Name $e.DisplayName } catch { }
        if (-not $n) { continue }

        $upgrade = $null
        if ($e.WindowsInstaller) {
            $packed = ConvertTo-PackedGuid $e.ProductCode
            if ($packed -and $Upgrades.ContainsKey($packed)) { $upgrade = $Upgrades[$packed] }
        }

        # Both forms: winget stores an extra arch-suffixed row for ARP
        # display names, and matches against whichever the package carries.
        $names = [Collections.Generic.List[string]]::new()
        if ($n.Name) { $names.Add($n.Name) }
        $withArch = Get-WgNameWithArchitecture $n
        if ($withArch -and $withArch -ne $n.Name) { $names.Add($withArch) }

        $pub = ''
        if (-not [string]::IsNullOrEmpty($e.Publisher)) {
            try { $pub = Get-WgNormalizedPublisher -Publisher $e.Publisher } catch { $pub = '' }
        }

        [PSCustomObject]@{
            Entry         = $e
            UpgradeCode   = $upgrade
            NormNames     = $names
            NormPublisher = $pub
        }
    }
}
