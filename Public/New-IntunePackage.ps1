function New-IntunePackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Id,  # e.g. "Dell.CommandUpdate" or "Nable"

        [string]$OutputFolder = "C:\IntunePackages"
    )

    # --- 1. SETUP WORKSPACE ---
    $PackagerTemp = "$env:TEMP\IntunePackager_Working\$Id"
    $SourceDir = "$PackagerTemp\Source"
    $IntuneUtil = "$env:TEMP\IntuneWinAppUtil.exe"

    if (Test-Path $PackagerTemp) { Remove-Item $PackagerTemp -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -Path $SourceDir -ItemType Directory -Force | Out-Null
    if (-not (Test-Path $OutputFolder)) { New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null }
    
    if (-not (Test-Path $IntuneUtil)) {
        Write-PackagerLog -Message "Downloading IntuneWinAppUtil..."
        Invoke-WebRequest "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe" -OutFile $IntuneUtil
    }

    # ==========================================
    #      SPECIAL LOGIC: N-ABLE AGENT
    # ==========================================
    if ($Id -eq "Nable") {
        # 1. Prompt User for N-able Details (GUI)
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $Form = New-Object System.Windows.Forms.Form
        $Form.Text = "N-able Configuration"
        $Form.Size = New-Object System.Drawing.Size(400, 350)
        $Form.StartPosition = "CenterScreen"

        $Inputs = @{}
        $Top = 20
        foreach ($Field in @("CustomerName", "CustomerID", "Token", "ServerAddress")) {
            $Lbl = New-Object System.Windows.Forms.Label
            $Lbl.Text = $Field
            $Lbl.Location = New-Object System.Drawing.Point(20, $Top)
            $Form.Controls.Add($Lbl)

            $Box = New-Object System.Windows.Forms.TextBox
            $Box.Location = New-Object System.Drawing.Point(20, $Top + 25)
            $Box.Size = New-Object System.Drawing.Size(340, 25)
            $Form.Controls.Add($Box)
            $Inputs[$Field] = $Box
            $Top += 60
        }

        $Btn = New-Object System.Windows.Forms.Button
        $Btn.Text = "Generate Package"
        $Btn.Location = New-Object System.Drawing.Point(20, $Top)
        $Btn.Size = New-Object System.Drawing.Size(340, 40)
        $Btn.DialogResult = "OK"
        $Form.Controls.Add($Btn)

        $Result = $Form.ShowDialog()
        if ($Result -ne "OK") { throw "Cancelled by user." }

        # 2. Extract Values
        $CName = $Inputs["CustomerName"].Text
        $CId   = $Inputs["CustomerID"].Text
        $CToken= $Inputs["Token"].Text
        $CServer=$Inputs["ServerAddress"].Text

        if (-not $CName -or -not $CId -or -not $CToken -or -not $CServer) { throw "All N-able fields are required." }

        # 3. Generate Install Script (With HARDCODED Values)
        $InstallContent = @"
`$ErrorActionPreference = 'Stop'
Import-Module TecharyGet -ErrorAction SilentlyContinue

Write-Host "Installing N-able Agent for $CName..."
Install-NableAgent -CustomerName "$CName" -CustomerID "$CId" -Token "$CToken" -ServerAddress "$CServer"
"@
        Set-Content -Path "$SourceDir\Install.ps1" -Value $InstallContent

        # 4. Generate Uninstall Script
        Set-Content -Path "$SourceDir\Uninstall.ps1" -Value "`$ErrorActionPreference = 'Stop'; Import-Module TecharyGet; Uninstall-SmartApp -Name 'Windows Agent'"

        # 5. Generate Detection Script (Service Check)
        $DetectContent = @"
`$Service = Get-Service -Name "Windows Agent Service" -ErrorAction SilentlyContinue
if (`$Service) {
    Write-Output "Detected N-able Agent Service"
    exit 0
} else {
    exit 1
}
"@
        Set-Content -Path "$SourceDir\Detect.ps1" -Value $DetectContent
        
        # Override output name so you can have multiple packages (e.g. "Nable-ClientA.intunewin")
        $PackageName = "Nable-$CName"

    }
    # ==========================================
    #      STANDARD LOGIC: GENERIC APPS
    # ==========================================
    else {
        # ... (Previous Logic for 7zip, Dell, etc.) ...
        
        # 1. Gather Info
        $ProductCode = $null
        $DisplayName = $Id
        try {
            if (Get-Command Get-CustomApp -ErrorAction SilentlyContinue) {
                $Custom = Get-CustomApp -Id $Id
                if ($Custom) {
                    if ($Custom.DisplayName) { $DisplayName = $Custom.DisplayName }
                    if ($Custom.ProductCode) { $ProductCode = $Custom.ProductCode }
                }
            }
            if (-not $ProductCode) {
                $Pkg = Get-GitHubInstaller -Id $Id -DownloadPath "$PackagerTemp\Probe" -ErrorAction SilentlyContinue
                if ($Pkg.ProductCode) { $ProductCode = $Pkg.ProductCode }
            }
        } catch {}

        # 2. Generate Scripts
        Set-Content -Path "$SourceDir\Install.ps1" -Value "`$ErrorActionPreference = 'Stop'; Import-Module TecharyGet -ErrorAction SilentlyContinue; Install-SmartApp -Id `"$Id`""
        Set-Content -Path "$SourceDir\Uninstall.ps1" -Value "`$ErrorActionPreference = 'Stop'; Import-Module TecharyGet -ErrorAction SilentlyContinue; Uninstall-SmartApp -Name `"$Id`""

        # 3. Generate Detection
        $DetectScript = @"
`$TargetCode = '$ProductCode'
`$TargetName = '$DisplayName'
`$Found = `$false

if (-not [string]::IsNullOrEmpty(`$TargetCode)) {
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\`$TargetCode") { `$Found = `$true }
    elseif (Test-Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\`$TargetCode") { `$Found = `$true }
    if (`$Found) { Write-Output "Detected via Key"; exit 0 }
}

`$Paths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*")
foreach (`$Path in `$Paths) {
    `$Match = Get-ItemProperty `$Path -ErrorAction SilentlyContinue | Where-Object { `$_.DisplayName -like "*`$TargetName*" } | Select-Object -First 1
    if (`$Match) { Write-Output "Detected via Name"; exit 0 }
}
exit 1
"@
        Set-Content -Path "$SourceDir\Detect.ps1" -Value $DetectScript
        
        $PackageName = $Id
    }

    # --- FINAL PACKAGING STEP ---
    Write-PackagerLog -Message "Packaging $PackageName..."
    Start-Process -FilePath $IntuneUtil -ArgumentList "-c `"$SourceDir`"", "-s `"Install.ps1`"", "-o `"$OutputFolder`"", "-q" -Wait -NoNewWindow
    
    # Rename Output
    $Original = Join-Path $OutputFolder "Install.intunewin"
    $Final = Join-Path $OutputFolder "$PackageName.intunewin"
    if (Test-Path $Original) { Move-Item $Original $Final -Force }
    
    # Copy Detect Script
    Copy-Item "$SourceDir\Detect.ps1" -Destination "$OutputFolder\$PackageName-Detect.ps1" -Force
    
    Write-PackagerLog -Message "SUCCESS: Created $Final"
    Invoke-Item $OutputFolder
}