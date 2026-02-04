function Get-CustomApp {
    param (
        [string]$Id
    )

    # --- 1. CLOUD SOURCE ---
    # We use the "Raw" GitHub URL so we get just the JSON text.
    # Structure: https://raw.githubusercontent.com/<User>/<Repo>/<Branch>/<PathToFile>
    $CloudUrl = "https://raw.githubusercontent.com/Techary/TecharyGet/BETA/TecharyGet/Private/CustomApps.json"
    
    # --- 2. LOCAL CACHE ---
    # We cache the file locally so the script works even if GitHub is briefly down
    # or if the machine is offline (using the last known good copy).
    $CacheDir = "$env:PROGRAMDATA\TecharyGet"
    $CachePath = "$CacheDir\CustomApps_Cache.json"
    
    # --- 3. SYNC LOGIC ---
    try {
        if (-not (Test-Path $CacheDir)) { New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null }
        
        # Logic: Only download if the cache doesn't exist OR it's older than 60 minutes.
        # This prevents spamming GitHub every time you run a command.
        $NeedUpdate = $true
        if (Test-Path $CachePath) {
            $LastWrite = (Get-Item $CachePath).LastWriteTime
            if ((Get-Date) -lt $LastWrite.AddMinutes(60)) { $NeedUpdate = $false }
        }

        if ($NeedUpdate) {
            Write-PackagerLog -Message "Syncing Custom Catalog from GitHub..." -Severity Info
            Invoke-WebRequest -Uri $CloudUrl -OutFile $CachePath -UseBasicParsing -ErrorAction Stop
        }
    }
    catch {
        Write-PackagerLog -Message "Could not sync from GitHub (Offline?). Using local cache." -Severity Warning
    }

    # --- 4. READ DATA ---
    $JsonContent = $null

    # Prefer the fresh Cache
    if (Test-Path $CachePath) {
        $JsonContent = Get-Content -Path $CachePath -Raw
    }
    # Fallback to the file shipped with the module (if cache is empty/broken)
    else {
        $LocalModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Private\CustomApps.json"
        if (Test-Path $LocalModulePath) { 
            $JsonContent = Get-Content -Path $LocalModulePath -Raw 
        }
    }

    # --- 5. PARSE & RETURN ---
    if ($JsonContent) {
        try {
            $Data = $JsonContent | ConvertFrom-Json
            $Match = $Data | Where-Object { $_.Id -eq $Id }
            return $Match
        }
        catch {
            Write-PackagerLog -Message "Error parsing CustomApps.json: $_" -Severity Error
            return $null
        }
    }
    
    return $null
}