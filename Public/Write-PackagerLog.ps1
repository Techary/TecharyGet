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
    # Never let logging take down the caller. A locked log file or a
    # read-only ProgramData must not abort an install half way through.
    try {
        $LogDir = Split-Path $LogPath
        if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory $LogDir -Force -ErrorAction Stop | Out-Null }
        Add-Content -Path $LogPath -Value $Line -ErrorAction Stop
    }
    catch {
        Write-Warning "TecharyGet: could not write to $LogPath ($($_.Exception.Message))."
    }

    # 3. ENTERPRISE EVENT LOGGING
    # N-able can pick this up easily.
    # Source: "TecharyGet", ID: 100 (Info), 200 (Warn), 300 (Error)
    #
    # SourceExists() enumerates the whole event-log registry key and throws a
    # SecurityException when the caller cannot read it, which is the normal
    # case for a non-elevated user. Unguarded, that turned every single log
    # call into a terminating error.
    try {
        $EventSource = "TecharyGet"

        if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
            # Creating a source requires admin. Skip quietly if we cannot.
            New-EventLog -LogName Application -Source $EventSource -ErrorAction Stop
        }

        $EventID = switch ($Severity) { "Info" {100} "Warning" {200} "Error" {300} }
        $EntryType = switch ($Severity) { "Info" {"Information"} "Warning" {"Warning"} "Error" {"Error"} }

        Write-EventLog -LogName Application -Source $EventSource -EventId $EventID -EntryType $EntryType -Message $Message -ErrorAction Stop
    }
    catch {
        # Event logging is best-effort; the file log above is the system of record.
    }
}
