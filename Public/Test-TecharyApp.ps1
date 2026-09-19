function Test-TecharyApp {
    <#
    .SYNOPSIS
        Reports whether an application is installed.

    .DESCRIPTION
        Detection order, most precise first:

          1. ProductCode from the manifest index or cache. winget records the
             ARP subkey name here (for example "7-Zip", or an MSI product GUID),
             so this is a direct key lookup and is definitive.
          2. Exact DisplayName, from the custom catalogue or from -Name itself.
          3. Substring DisplayName match, which is what this function used to do
             exclusively. Retained so existing callers do not start returning
             false, but reported as imprecise because it produces false
             positives: "Teams" matches "Microsoft Teams Meeting Add-in for
             Microsoft Office" on a machine with no Teams desktop app.
          4. MSIX package name.

        Makes no network calls. The manifest index and custom catalogue are
        read from their existing on-disk caches only, because this runs on a
        schedule on every endpoint.

    .PARAMETER Name
        A winget package ID ("7zip.7zip"), a custom catalogue ID ("MyDPD"),
        or a display name.

    .PARAMETER Detailed
        Return an object describing what matched instead of a boolean.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [switch]$Detailed
    )

    $Hives = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
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

    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { $SysArch = "arm64" }
    elseif ([Environment]::Is64BitOperatingSystem) { $SysArch = "x64" }
    else { $SysArch = "x86" }

    # --- 1. PRODUCT CODE / PACKAGE FAMILY (definitive) -----------------
    # Three sources, most complete first: the full detection index covers
    # every package in the winget repository; the curated manifest index and
    # the local manifest cache cover what this machine has installed before.
    $ProductCodes = New-Object System.Collections.Generic.List[string]
    $Pfns         = New-Object System.Collections.Generic.List[string]

    try {
        $Entry = Get-DetectionEntry -Id $Name -NoRefresh
        if ($Entry) {
            foreach ($Code in $Entry.ProductCodes) { if ($Code) { $ProductCodes.Add($Code) } }
            foreach ($Family in $Entry.Pfns) { if ($Family) { $Pfns.Add($Family) } }
            Write-Verbose "Detection index: $($ProductCodes.Count) product code(s), $($Pfns.Count) package family name(s) for '$Name'"
        }
    } catch {}

    try {
        $Indexed = Get-IndexedManifest -Id $Name -SysArch $SysArch -NoRefresh
        if ($Indexed -and $Indexed.ProductCode) { $ProductCodes.Add($Indexed.ProductCode) }
    } catch {}

    $CachedManifest = Join-Path $env:ProgramData ("TecharyGet\ManifestCache\" + ($Name -replace '[\\/:*?"<>|]', '_') + ".json")
    if (Test-Path $CachedManifest) {
        try {
            $Local = (Get-Content $CachedManifest -Raw | ConvertFrom-Json).ProductCode
            if ($Local) { $ProductCodes.Add($Local) }
        } catch {}
    }

    if ($ProductCodes.Count -gt 0) {
        # Enumerate the machine's uninstall key NAMES once and hash-look-up each
        # candidate, rather than probing the registry per code.
        #
        # The winget source carries every product code a package has ever
        # shipped: Mozilla.Firefox alone has 5205, one per locale and version.
        # Probing those across three hives is 15,615 registry reads and took
        # ~384 seconds measured, which would exceed an N-central scan interval
        # on its own. This is ~230 reads regardless of how many codes a package
        # has. Ordinal-ignore-case because the index stores codes normalised to
        # lower case ("7-zip") while the real key is "7-Zip", and the registry
        # itself is case-insensitive.
        $ArpKeys = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($Hive in $Hives) {
            foreach ($Key in (Get-ChildItem -Path $Hive -ErrorAction SilentlyContinue)) {
                if (-not $ArpKeys.ContainsKey($Key.PSChildName)) { $ArpKeys[$Key.PSChildName] = $Key.PSPath }
            }
        }

        foreach ($Code in $ProductCodes) {
            $Path = $null
            if ($ArpKeys.TryGetValue($Code, [ref]$Path)) {
                $Item = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue
                Write-Verbose "Matched on ProductCode '$Code' at $Path"
                $R = New-Result $true 'ProductCode' $Item.DisplayName $Item.DisplayVersion $Path
                if ($Detailed) { return $R } else { return $true }
            }
        }
    }

    if ($Pfns.Count -gt 0) {
        $Elevated = $false
        try {
            $Ident = [Security.Principal.WindowsIdentity]::GetCurrent()
            $Elevated = (New-Object Security.Principal.WindowsPrincipal($Ident)).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)
        } catch {}

        try {
            # -AllUsers when we can: SYSTEM sees almost none of its own packages.
            if ($Elevated) { $Installed = @(Get-AppxPackage -AllUsers -ErrorAction Stop) }
            else { $Installed = @(Get-AppxPackage -ErrorAction SilentlyContinue) }

            foreach ($Family in $Pfns) {
                $Hit = $Installed | Where-Object { $_.PackageFamilyName -eq $Family } | Select-Object -First 1
                if ($Hit) {
                    Write-Verbose "Matched on PackageFamilyName '$Family'"
                    $R = New-Result $true 'PackageFamilyName' $Hit.Name $Hit.Version $Hit.PackageFullName
                    if ($Detailed) { return $R } else { return $true }
                }
            }
        } catch {}
    }

    # --- 2. EXACT DISPLAY NAME ----------------------------------------
    # A custom catalogue entry carries the real ARP DisplayName for its ID.
    # Two lists, because a name safe to compare exactly is not safe to compare
    # as a substring.
    #
    # The detection index carries each package's canonical display name, which
    # is what bridges an ID to its ARP entry: "Google.Chrome" never matches
    # "Google Chrome" on its own, and product codes alone do not cover it
    # because Chrome's installed code varies by build.
    #
    # Those names are short and generic, so they are used for exact comparison
    # ONLY. Feeding them to the substring tier reports anything that merely
    # contains them: "Steam" matches the MSIX package "MSTeams", and "Git"
    # matches "GitHub CLI". Both were observed.
    $ExactCandidates = New-Object System.Collections.Generic.List[string]
    $LooseCandidates = New-Object System.Collections.Generic.List[string]

    $ExactCandidates.Add($Name)
    $LooseCandidates.Add($Name)

    try {
        $CustomApp = Get-CustomApp -Id $Name -NoRefresh
        if ($CustomApp -and $CustomApp.DisplayName) {
            $ExactCandidates.Add($CustomApp.DisplayName)
            $LooseCandidates.Add($CustomApp.DisplayName)
        }
    } catch {}

    if ($Entry -and $Entry.Name) { $ExactCandidates.Add($Entry.Name) }

    $AllArp = foreach ($Hive in $Hives) {
        Get-ItemProperty -Path (Join-Path $Hive '*') -ErrorAction SilentlyContinue
    }

    foreach ($Candidate in $ExactCandidates) {
        $Exact = $AllArp | Where-Object { $_.DisplayName -eq $Candidate } | Select-Object -First 1
        if ($Exact) {
            Write-Verbose "Matched exactly on DisplayName '$Candidate'"
            $R = New-Result $true 'ExactName' $Exact.DisplayName $Exact.DisplayVersion $Exact.PSPath
            if ($Detailed) { return $R } else { return $true }
        }
    }

    # --- 3. SUBSTRING (imprecise, kept for compatibility) -------------
    # Loose list only. A canonical name from the index is too generic to
    # widen with wildcards.
    foreach ($Candidate in $LooseCandidates) {
        # Escaped: an unescaped name containing [ or ] is a wildcard pattern,
        # which previously made the comparison silently match nothing.
        $Pattern = "*" + [System.Management.Automation.WildcardPattern]::Escape($Candidate) + "*"
        $Loose = $AllArp | Where-Object { $_.DisplayName -like $Pattern } | Select-Object -First 1
        if ($Loose) {
            Write-Verbose "Matched '$Candidate' only as a substring of '$($Loose.DisplayName)'. This is imprecise; add the package to the manifest index for an exact ProductCode match."
            $R = New-Result $true 'Substring' $Loose.DisplayName $Loose.DisplayVersion $Loose.PSPath
            if ($Detailed) { return $R } else { return $true }
        }
    }

    # --- 4. MSIX ------------------------------------------------------
    # SYSTEM sees almost no packages of its own, so enumerate for all users
    # when we are able to.
    $IsElevated = $false
    try {
        $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $IsElevated = (New-Object Security.Principal.WindowsPrincipal($Identity)).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {}

    # Loose list only, for the same reason: "Steam" as a wildcard matches the
    # MSIX package MSTeams, which was reported as Valve.Steam being installed
    # on a machine that has never had it.
    foreach ($Candidate in $LooseCandidates) {
        $Pattern = "*" + [System.Management.Automation.WildcardPattern]::Escape($Candidate) + "*"
        $Msix = $null
        try {
            if ($IsElevated) { $Msix = Get-AppxPackage -AllUsers -Name $Pattern -ErrorAction SilentlyContinue | Select-Object -First 1 }
            if (-not $Msix)  { $Msix = Get-AppxPackage -Name $Pattern -ErrorAction SilentlyContinue | Select-Object -First 1 }
        } catch {}

        if ($Msix) {
            Write-Verbose "Matched MSIX package '$($Msix.Name)'"
            $R = New-Result $true 'Msix' $Msix.Name $Msix.Version $Msix.PackageFullName
            if ($Detailed) { return $R } else { return $true }
        }
    }

    # --- 5. NOT FOUND -------------------------------------------------
    $R = New-Result $false 'None' $null $null $null
    if ($Detailed) { return $R } else { return $false }
}
