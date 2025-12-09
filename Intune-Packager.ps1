$ProgressPreference = 'SilentlyContinue'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# === Configurable Paths ===
$global:SourceRoot = "C:\IntuneApps\Source"
$global:OutputRoot = "C:\IntuneApps\Output"
$global:WinAppToolDir = "C:\IntuneApps\IntuneWinAppTool"
$global:WinAppToolExe = Join-Path $WinAppToolDir "Microsoft-Win32-Content-Prep-Tool-1.8.7\IntuneWinAppUtil.exe"
$global:RemoteAppMapUrl = "https://raw.githubusercontent.com/Techary/TecharyGet/refs/heads/main/AppMap.ps1"

# === Ensure Required Folders Exist ===
$null = New-Item -ItemType Directory -Path $SourceRoot -Force
$null = New-Item -ItemType Directory -Path $OutputRoot -Force
$null = New-Item -ItemType Directory -Path $WinAppToolDir -Force

# === Download IntuneWinAppUtil ===
function Get-IntuneWinAppUtil {
    if (-Not (Test-Path $global:WinAppToolExe)) {
        Write-Host "Downloading IntuneWinAppUtil..."
        $zipUrl = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/tags/v1.8.7.zip"
        $zipPath = Join-Path $WinAppToolDir "tool.zip"
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $WinAppToolDir -Force
        Remove-Item $zipPath -Force
    }

    return $global:WinAppToolExe
}

# === Load Remote AppMap ===
function Load-TecharyApps {
    $tempAppMap = Join-Path $env:TEMP "AppMap.ps1"
    Invoke-WebRequest -Uri $global:RemoteAppMapUrl -OutFile $tempAppMap -UseBasicParsing

    $script:TecharyApps = @{}
    . $tempAppMap
    Remove-Item $tempAppMap -Force
}

# === Build GUI ===
$form = New-Object System.Windows.Forms.Form
$form.Text = "TecharyGet Intune App Packager"
$form.Size = New-Object System.Drawing.Size(450, 250)
$form.StartPosition = "CenterScreen"

$label = New-Object System.Windows.Forms.Label
$label.Text = "Select an app to package:"
$label.Location = New-Object System.Drawing.Point(20, 20)
$label.AutoSize = $true
$form.Controls.Add($label)

$comboBox = New-Object System.Windows.Forms.ComboBox
$comboBox.Location = New-Object System.Drawing.Point(20, 50)
$comboBox.Size = New-Object System.Drawing.Size(380, 30)
$comboBox.DropDownStyle = "DropDownList"
$form.Controls.Add($comboBox)

$button = New-Object System.Windows.Forms.Button
$button.Text = "Create IntuneWin Package"
$button.Location = New-Object System.Drawing.Point(20, 100)
$button.Size = New-Object System.Drawing.Size(380, 40)
$form.Controls.Add($button)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20, 160)
$statusLabel.Size = New-Object System.Drawing.Size(400, 40)
$form.Controls.Add($statusLabel)

# === Load and Populate App List ===
Load-TecharyApps
$comboBox.Items.AddRange(@($script:TecharyApps.Keys | Sort-Object))

# === Button Logic ===
$button.Add_Click({
    $appName = $comboBox.SelectedItem
    if (-not $appName) {
        $statusLabel.Text = "Please select an app."
        return
    }

    try {
        $appFolder = Join-Path $SourceRoot $appName
        $null = New-Item -ItemType Directory -Path $appFolder -Force

        # Create install/uninstall scripts
        $installScript = Join-Path $appFolder "install-$appName.ps1"
        $uninstallScript = Join-Path $appFolder "uninstall-$appName.ps1"

        Set-Content -Path $installScript -Value "Install-TecharyApp -AppName `"$appName`"" -Encoding UTF8
        Set-Content -Path $uninstallScript -Value "Uninstall-TecharyApp -AppName `"$appName`"" -Encoding UTF8

        # Package using IntuneWinAppUtil
        $intuneWinAppUtil = Get-IntuneWinAppUtil
        $outputPath = Join-Path $OutputRoot $appName
        $null = New-Item -ItemType Directory -Path $outputPath -Force

        $statusLabel.Text = "Packaging $appName..."
        & $intuneWinAppUtil -c $appFolder `
                            -s ("install-$appName.ps1") `
                            -o $outputPath | Out-Null

        $statusLabel.Text = "$appName packaged successfully."
    }
    catch {
        $statusLabel.Text = "Error: $($_.Exception.Message)"
    }
})

$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()