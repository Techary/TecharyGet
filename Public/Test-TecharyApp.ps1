function Test-TecharyApp {
    <#
    .SYNOPSIS
        Reports whether an application is installed.

    .DESCRIPTION
        Reproduces winget's own correlation rather than guessing at names.

        winget decides an installed entry corresponds to a package using four
        exact-equality keys, OR'd together -- PackageFamilyName, ProductCode,
        UpgradeCode and NormalizedNameAndPublisher (CompositeSource.cpp:937).
        There is no fuzzy matching anywhere in that path. The edit-distance
        code in ARPCorrelation.cpp is post-install only and is not used here.

        Order below is:

          1. Strong identifiers  - product code, package family name
          2. Name and publisher  - winget's normalised keys, the only thing
                                   that covers the 6,443 packages declaring
                                   no identifier at all
          3. Custom catalogue    - display-name match, for applications that
                                   are not winget packages
          4. MSIX by name        - last resort

        Makes no network calls beyond refreshing the index when absent: this
        runs on a schedule on every endpoint.

    .PARAMETER Name
        A winget package ID, a custom catalogue ID, or a display name.

    .PARAMETER Detailed
        Return an object describing what matched instead of a boolean.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [switch]$Detailed
    )

    function New-Result {
        param($Installed, $MatchedBy, $DisplayName, $Version, $Key)
        [PSCustomObject]@{
            Name             = $Name
            Installed        = [bool]$Installed
            MatchedBy        = $MatchedBy
            DisplayName      = $DisplayName
            InstalledVersion = $Version
            RegistryKey      = $Key
        }
    }

    if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { $SysArch = 'arm64' }
    elseif ([Environment]::Is64BitOperatingSystem) { $SysArch = 'x64' }
    else { $SysArch = 'x86' }

    $Entry = $null
    try { $Entry = Get-DetectionEntry -Id $Name -NoRefresh } catch { }

    # Normalising every ARP entry is the expensive part, so it is done once.
    $Arp = @(Get-ArpCorrelationSet)

    # ---- 1. STRONG IDENTIFIERS --------------------------------------
    $Codes    = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $Pfns     = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $Upgrades = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    if ($Entry) {
        foreach ($c in $Entry.ProductCodes) { if ($c) { [void]$Codes.Add($c) } }
        foreach ($f in $Entry.Pfns)         { if ($f) { [void]$Pfns.Add($f) } }
        foreach ($u in $Entry.UpgradeCodes) { if ($u) { [void]$Upgrades.Add($u) } }
    }

    # A manifest resolved on this machine earlier also carries a product code.
    $Cached = Join-Path $env:ProgramData ("TecharyGet\ManifestCache\" + ($Name -replace '[\\/:*?"<>|]', '_') + ".json")
    if (Test-Path $Cached) {
        try {
            $c = (Get-Content $Cached -Raw | ConvertFrom-Json).ProductCode
            if ($c) { [void]$Codes.Add($c) }
        } catch { }
    }

    foreach ($a in $Arp) {
        if ($Codes.Count -gt 0 -and $Codes.Contains($a.Entry.ProductCode)) {
            Write-Verbose "ProductCode '$($a.Entry.ProductCode)'"
            $R = New-Result $true 'ProductCode' $a.Entry.DisplayName $a.Entry.DisplayVersion $a.Entry.Path
            if ($Detailed) { return $R } else { return $true }
        }
        if ($Upgrades.Count -gt 0 -and $a.UpgradeCode -and $Upgrades.Contains($a.UpgradeCode)) {
            Write-Verbose "UpgradeCode '$($a.UpgradeCode)'"
            $R = New-Result $true 'UpgradeCode' $a.Entry.DisplayName $a.Entry.DisplayVersion $a.Entry.Path
            if ($Detailed) { return $R } else { return $true }
        }
    }

    if ($Pfns.Count -gt 0) {
        $Elevated = $false
        try {
            $Id = [Security.Principal.WindowsIdentity]::GetCurrent()
            $Elevated = (New-Object Security.Principal.WindowsPrincipal($Id)).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)
        } catch { }
        try {
            # -AllUsers when we can: SYSTEM sees almost none of its own.
            $Pkgs = if ($Elevated) { @(Get-AppxPackage -AllUsers -ErrorAction Stop) }
                    else           { @(Get-AppxPackage -ErrorAction SilentlyContinue) }
            foreach ($p in $Pkgs) {
                if ($Pfns.Contains($p.PackageFamilyName)) {
                    Write-Verbose "PackageFamilyName '$($p.PackageFamilyName)'"
                    $R = New-Result $true 'PackageFamilyName' $p.Name $p.Version $p.PackageFullName
                    if ($Detailed) { return $R } else { return $true }
                }
            }
        } catch { }
    }

    # ---- 2. NORMALISED NAME AND PUBLISHER ---------------------------
    if ($Entry -and $Entry.NormNames.Count -gt 0 -and $Entry.NormPublishers.Count -gt 0) {

        # Architecture override: if the package carries any arch-suffixed
        # name, ONLY those are used. Winget erases the plain filters rather
        # than falling back to them (Interface_2_0.cpp:483).
        $ArchNames = @($Entry.NormNames | Where-Object { $_ -match '\((X64|X86)\)$' })
        $Query = if ($ArchNames.Count -gt 0) { $ArchNames } else { @($Entry.NormNames) }

        $QuerySet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($q in $Query) { if ($q) { [void]$QuerySet.Add($q) } }

        $PubSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($p in $Entry.NormPublishers) { if ($p) { [void]$PubSet.Add($p) } }

        $Ambiguous = $null
        try { $Ambiguous = Get-AmbiguousPairSet -NoRefresh } catch { }

        foreach ($a in $Arp) {
            # An entry with no publisher can never match by name: the filters
            # are a cartesian product of names x publishers, and an empty
            # publisher list yields nothing.
            if ([string]::IsNullOrEmpty($a.NormPublisher)) { continue }
            if (-not $PubSet.Contains($a.NormPublisher)) { continue }

            foreach ($n in $a.NormNames) {
                if ([string]::IsNullOrEmpty($n)) { continue }
                if (-not $QuerySet.Contains($n)) { continue }

                # Reverse-correlation veto: winget drops a weak match when the
                # installed entry correlates to more than one available
                # package (CompositeSource.cpp:1651). A shared name+publisher
                # pair is exactly that case -- mozillathunderbird+mozilla is
                # carried by 133 package ids, and without this one Thunderbird
                # entry reports all 133 as installed.
                #
                # Packages with a real identifier are unaffected: a strong
                # match returns above and is never vetoed. That is how Google
                # Chrome still resolves despite sharing its pair with
                # Google.Chrome.EXE -- it matches on UpgradeCode first.
                if ($Ambiguous -and $Ambiguous.Contains($n + '|' + $a.NormPublisher)) {
                    Write-Verbose "Vetoed: '$n' + '$($a.NormPublisher)' is shared by more than one package"
                    continue
                }

                Write-Verbose "NormalizedNameAndPublisher '$n' + '$($a.NormPublisher)'"
                $R = New-Result $true 'NameAndPublisher' $a.Entry.DisplayName $a.Entry.DisplayVersion $a.Entry.Path
                if ($Detailed) { return $R } else { return $true }
            }
        }
    }

    # ---- 3. CUSTOM CATALOGUE ----------------------------------------
    # Applications that are not winget packages have no index entry, so
    # correlation cannot help. Their catalogue DisplayName is authoritative.
    $CustomName = $null
    try {
        $Custom = Get-CustomApp -Id $Name -NoRefresh
        if ($Custom -and $Custom.DisplayName) { $CustomName = $Custom.DisplayName }
    } catch { }

    foreach ($candidate in @($CustomName, $Name)) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        foreach ($a in $Arp) {
            if ($a.Entry.DisplayName -eq $candidate) {
                Write-Verbose "Exact display name '$candidate'"
                $R = New-Result $true 'ExactName' $a.Entry.DisplayName $a.Entry.DisplayVersion $a.Entry.Path
                if ($Detailed) { return $R } else { return $true }
            }
        }
    }

    # ---- 4. MSIX BY NAME --------------------------------------------
    foreach ($candidate in @($CustomName, $Name)) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        $Pattern = '*' + [Management.Automation.WildcardPattern]::Escape($candidate) + '*'
        try {
            $Msix = Get-AppxPackage -Name $Pattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($Msix) {
                Write-Verbose "MSIX '$($Msix.Name)'"
                $R = New-Result $true 'Msix' $Msix.Name $Msix.Version $Msix.PackageFullName
                if ($Detailed) { return $R } else { return $true }
            }
        } catch { }
    }

    $R = New-Result $false 'None' $null $null $null
    if ($Detailed) { return $R } else { return $false }
}
