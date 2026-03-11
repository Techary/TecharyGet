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

        # 2. Construct API Path
        $IdPath = $Id.Replace(".", "/")
        $FirstChar = $Id.Substring(0,1).ToLower()
        $BaseApi = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$FirstChar/$IdPath"
        
        # 3. Get Version (Latest)
        $VersionsResponse = Invoke-RestMethod -Uri $BaseApi -Method Get -ErrorAction Stop
        $LatestVersionObj = $VersionsResponse | 
            Where-Object { $_.type -eq "dir" } | 
            Select-Object *, @{N='ParsedVersion'; E={ try { [Version]$_.name } catch { $null } }} |
            Where-Object { $_.ParsedVersion -ne $null } | 
            Sort-Object ParsedVersion -Descending | 
            Select-Object -First 1
            
        if (-not $LatestVersionObj) { throw "Could not determine a valid numeric version." }
        $LatestVersion = $LatestVersionObj.Name
        
        # 4. Get Manifest
        $VersionPath = "$BaseApi/$LatestVersion"
        $VersionFiles = Invoke-RestMethod -Uri $VersionPath -Method Get
        $InstallerFile = $VersionFiles | Where-Object { $_.name -like "*.installer.yaml" } | Select-Object -First 1
        if (-not $InstallerFile) { throw "No installer YAML found." }

        $YamlContent = Invoke-RestMethod -Uri $InstallerFile.download_url
        
        # --- PARSING LOGIC ---
        # We split by "- Architecture" to separate blocks, but keep the delimiter to help identification
        $Blocks = $YamlContent -split '(?=-\s*Architecture:)'
        
        $SelectedUrl = $null
        $SelectedArgs = $null
        $SelectedType = "exe"
        $SelectedCode = $null
        
        foreach ($Block in $Blocks) {
            if ([string]::IsNullOrWhiteSpace($Block)) { continue }
            
            # Extract Architecture from this block
            if ($Block -match 'Architecture:\s*([a-zA-Z0-9]+)') {
                $BlockArch = $Matches[1].Trim()
                
                # If this block matches our system, scrape it!
                if ($BlockArch -eq $SysArch) {
                    if ($Block -match 'InstallerUrl:\s*["'']?([^"''\r\n]+)["'']?') { $SelectedUrl = $Matches[1].Trim() }
                    if ($Block -match 'InstallerType:\s*([a-zA-Z0-9]+)') { $SelectedType = $Matches[1].Trim() }
                    
                    # Scrape Arguments
                    if ($Block -match 'Silent:\s*(.+)') { $SelectedArgs = $Matches[1].Trim().Trim("'").Trim('"') }
                    elseif ($Block -match 'SilentWithProgress:\s*(.+)') { $SelectedArgs = $Matches[1].Trim().Trim("'").Trim('"') }

                    # Scrape Product Code (Flexible Regex)
                    # This now matches "{GUID}" OR "SimpleString"
                    if ($Block -match 'ProductCode:\s*["'']?([^"''\r\n]+)["'']?') { 
                        $SelectedCode = $Matches[1].Trim() 
                    }
                    
                    # If we found a URL, we stop looking (we prefer the first match for our arch)
                    if ($SelectedUrl) { break }
                }
            }
        }

        # Fallbacks (Global properties if not in block)
        if (-not $SelectedUrl) { if ($YamlContent -match 'InstallerUrl:\s*["'']?([^"''\r\n]+)["'']?') { $SelectedUrl = $Matches[1].Trim() } }
        if (-not $SelectedArgs) {
             if ($YamlContent -match 'Silent:\s*(.+)') { $SelectedArgs = $Matches[1].Trim().Trim("'").Trim('"') }
        }
        if (-not $SelectedCode) {
            if ($YamlContent -match 'ProductCode:\s*["'']?([^"''\r\n]+)["'']?') { $SelectedCode = $Matches[1].Trim() }
        }

        # Special Override for Dell (Command Update)
        if ($Id -eq "Dell.CommandUpdate") { $SelectedArgs = '/s /l="C:\Windows\Temp\DellCommand.log" /v"/qn"' }

        # Special Override for 8x8 Work MSI
        if ($Id -eq "8x8.Work") { $SelectedArgs = "/qn /norestart" }

        # --- DOWNLOAD ---
        $UriObj = [System.Uri]$SelectedUrl
        $RealExtension = [System.IO.Path]::GetExtension($UriObj.LocalPath).ToLower()
        if (-not $RealExtension) { $RealExtension = ".$SelectedType" }
        $FileName = "$Id-$LatestVersion-$SysArch$RealExtension"

        if (Test-Path $DownloadPath) { Remove-Item "$DownloadPath\*" -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
        $FullPath = Join-Path $DownloadPath $FileName
        
        Write-PackagerLog -Message "Downloading to $FullPath..."
        Invoke-WebRequest -Uri $SelectedUrl -OutFile $FullPath -UseBasicParsing -UserAgent "Mozilla/5.0"
        
        return [PSCustomObject]@{
            Name = $Id
            InstallerPath = $FullPath
            FileName = $FileName
            SilentArgs = $SelectedArgs
            InstallerType = $SelectedType
            ProductCode = $SelectedCode
        }
    }
    catch {
        Write-PackagerLog -Message "GitHub Scraping Failed: $_" -Severity Error
        throw $_
    }

}
