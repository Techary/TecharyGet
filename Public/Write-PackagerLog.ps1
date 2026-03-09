function Write-PackagerLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet("Info", "Warning", "Error")][string]$Severity = "Info"
    )

    $LogPath = "$env:ProgramData\TecharyGet\InstallLogs.log"
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Line = "[$Timestamp] [$Severity] $Message"

    # 1. Console Output
    $Color = switch ($Severity) { "Info" {"Green"} "Warning" {"Yellow"} "Error" {"Red"} }
    Write-Host $Line -ForegroundColor $Color

    # 2. File Log
    if (-not (Test-Path (Split-Path $LogPath))) { New-Item -ItemType Directory (Split-Path $LogPath) -Force | Out-Null }
    Add-Content -Path $LogPath -Value $Line

    # 3. ENTERPRISE EVENT LOGGING (New!)
    # N-able can pick this up easily.
    # Source: "TecharyGet", ID: 100 (Info), 200 (Warn), 300 (Error)
    
    $EventSource = "TecharyGet"
    if (-not ([System.Diagnostics.EventLog]::SourceExists($EventSource))) {
        # Requires Admin to create source once. 
        # If not admin, this skips silently to avoid crashing.
        try { New-EventLog -LogName Application -Source $EventSource -ErrorAction SilentlyContinue } catch {}
    }

    if ([System.Diagnostics.EventLog]::SourceExists($EventSource)) {
        $EventID = switch ($Severity) { "Info" {100} "Warning" {200} "Error" {300} }
        $EntryType = switch ($Severity) { "Info" {"Information"} "Warning" {"Warning"} "Error" {"Error"} }
        
        Write-EventLog -LogName Application -Source $EventSource -EventId $EventID -EntryType $EntryType -Message $Message
    }
}