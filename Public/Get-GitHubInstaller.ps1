function Get-GitHubInstaller {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Id,
        [string]$DownloadPath = "$env:TEMP\AppPackager"
    )

    Write-PackagerLog -Message "Querying GitHub Manifests for: $Id"

    try {
        # 1. Detect Architecture
        if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { $SysArch = "arm64" }
        elseif ([Environment]::Is64BitOperatingSystem) { $SysArch = "x64" }
        else { $SysArch = "x86" }
        Write-PackagerLog -Message "System Architecture: $SysArch"

        # 2. Construct API Path
        $IdPath = $Id.Replace(".", "/")
        $FirstChar = $Id.Substring(0,1).ToLower()
        $BaseApi = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$FirstChar/$IdPath"
        
        # 3. Get Version
        $VersionsResponse = Invoke-RestMethod -Uri $BaseApi -Method Get -ErrorAction Stop
        $LatestVersionObj = $VersionsResponse | 
            Where-Object { $_.type -eq "dir" } | 
            Select-Object *, @{N='ParsedVersion'; E={ try { [Version]$_.name } catch { $null } }} |
            Where-Object { $_.ParsedVersion -ne $null } | 
            Sort-Object ParsedVersion -Descending | 
            Select-Object -First 1
            
        if (-not $LatestVersionObj) { throw "Could not determine a valid numeric version." }
        $LatestVersion = $LatestVersionObj.Name
        Write-PackagerLog -Message "Latest Version Found: $LatestVersion"

        # 4. Get Manifest
        $VersionPath = "$BaseApi/$LatestVersion"
        $VersionFiles = Invoke-RestMethod -Uri $VersionPath -Method Get
        $InstallerFile = $VersionFiles | Where-Object { $_.name -like "*.installer.yaml" } | Select-Object -First 1
        if (-not $InstallerFile) { throw "No installer YAML found." }

        Write-PackagerLog -Message "Parsing Manifest: $($InstallerFile.name)"
        $YamlContent = Invoke-RestMethod -Uri $InstallerFile.download_url
        
        # --- PARSING LOGIC (Fixed Regex) ---
        $Blocks = $YamlContent -split 'Architecture:\s*'
        
        $SelectedUrl = $null
        $SelectedArgs = $null
        $SelectedType = "exe"
        
        # Search Blocks for Match
        foreach ($Block in $Blocks) {
            if ([string]::IsNullOrWhiteSpace($Block)) { continue }
            $BlockArch = $Block.Split("`r`n")[0].Trim()
            
            if ($BlockArch -eq $SysArch) {
                # We found our block!
                if ($Block -match 'InstallerUrl:\s*["'']?([^"''\r\n]+)["'']?') { $SelectedUrl = $Matches[1].Trim() }
                if ($Block -match 'InstallerType:\s*([a-zA-Z0-9]+)') { $SelectedType = $Matches[1].Trim() }
                
                # FIX: Greedy Regex to capture arguments with quotes (like /v"/qn")
                if ($Block -match 'Silent:\s*(.+)') { 
                    # Remove leading/trailing quotes from the YAML value itself, but keep internal quotes
                    $SelectedArgs = $Matches[1].Trim().Trim("'").Trim('"')
                }
                elseif ($Block -match 'SilentWithProgress:\s*(.+)') { 
                    $SelectedArgs = $Matches[1].Trim().Trim("'").Trim('"')
                }
                break 
            }
        }

        # Fallback: Scan Whole File if missing
        if (-not $SelectedUrl) {
           if ($YamlContent -match 'InstallerUrl:\s*["'']?([^"''\r\n]+)["'']?') { $SelectedUrl = $Matches[1].Trim() }
        }

        if (-not $SelectedArgs) {
             # FIX: Greedy Global Regex
             if ($YamlContent -match 'Silent:\s*(.+)') { 
                $SelectedArgs = $Matches[1].Trim().Trim("'").Trim('"')
                Write-PackagerLog -Message "Found Global Arguments."
             }
             elseif ($YamlContent -match 'SilentWithProgress:\s*(.+)') { 
                $SelectedArgs = $Matches[1].Trim().Trim("'").Trim('"')
             }
        }

        if (-not $SelectedUrl) { throw "Could not find an installer URL." }
        
        # --- DOWNLOAD ---
        $UriObj = [System.Uri]$SelectedUrl
        $RealExtension = [System.IO.Path]::GetExtension($UriObj.LocalPath).ToLower()
        if (-not $RealExtension) { $RealExtension = ".$SelectedType" }
        $FileName = "$Id-$LatestVersion-$SysArch$RealExtension"

        if (Test-Path $DownloadPath) { Remove-Item "$DownloadPath\*" -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
        $FullPath = Join-Path $DownloadPath $FileName
        
        Write-PackagerLog -Message "Downloading to $FullPath..."
        $UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        Invoke-WebRequest -Uri $SelectedUrl -OutFile $FullPath -UseBasicParsing -UserAgent $UserAgent
        
        return [PSCustomObject]@{
            Name = $Id; InstallerPath = $FullPath; FileName = $FileName; SilentArgs = $SelectedArgs; InstallerType = $SelectedType
        }
    }
    catch {
        Write-PackagerLog -Message "GitHub Scraping Failed: $_" -Severity Error
        throw $_
    }
}