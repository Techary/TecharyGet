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
$form.Size = New-Object System.Drawing.Size(460, 400)
$form.StartPosition = "CenterScreen"

$label = New-Object System.Windows.Forms.Label
$label.Text = "Select an app to package:"
$label.Location = New-Object System.Drawing.Point(20, 20)
$label.AutoSize = $true
$form.Controls.Add($label)

$comboBox = New-Object System.Windows.Forms.ComboBox
$comboBox.Location = New-Object System.Drawing.Point(20, 50)
$comboBox.Size = New-Object System.Drawing.Size(400, 30)
$comboBox.DropDownStyle = "DropDownList"
$form.Controls.Add($comboBox)

# === Dynamic Fields for "nable" app ===
$extraFields = @{}
$fieldDefinitions = @(
    @{ Name = "CustomerID";     Label = "Customer ID:";     Y = 100 },
    @{ Name = "Token";          Label = "Token:";           Y = 130 },
    @{ Name = "CustomerName";   Label = "Customer Name:";   Y = 160 },
    @{ Name = "ServerAddress";  Label = "Server Address:";  Y = 190 }
)

foreach ($field in $fieldDefinitions) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $field.Label
    $label.Location = New-Object System.Drawing.Point(20, $field.Y)
    $label.Size = New-Object System.Drawing.Size(120, 20)
    $label.Visible = $false
    $form.Controls.Add($label)

    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Location = New-Object System.Drawing.Point(150, $field.Y)
    $textbox.Size = New-Object System.Drawing.Size(270, 20)
    $textbox.Visible = $false
    $form.Controls.Add($textbox)

    $extraFields[$field.Name] = @{ Label = $label; TextBox = $textbox }
}

# === Button ===
$button = New-Object System.Windows.Forms.Button
$button.Text = "Create IntuneWin Package"
$button.Location = New-Object System.Drawing.Point(20, 230)
$button.Size = New-Object System.Drawing.Size(400, 40)
$form.Controls.Add($button)

# === Status ===
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20, 290)
$statusLabel.Size = New-Object System.Drawing.Size(400, 60)
$form.Controls.Add($statusLabel)

# === Load and Populate App List ===
Load-TecharyApps
$comboBox.Items.AddRange(@($script:TecharyApps.Keys | Sort-Object))

# === ComboBox Change - show/hide "nable" fields ===
$comboBox.Add_SelectedIndexChanged({
    $selected = $comboBox.SelectedItem
    $isNable = $selected -eq "nable"
    foreach ($field in $extraFields.Values) {
        $field.Label.Visible = $isNable
        $field.TextBox.Visible = $isNable
    }
})

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

        # === Prepare install script
        $installScript = Join-Path $appFolder "install-$appName.ps1"
        if ($appName -eq "nable") {
            $params = @{}
            foreach ($key in $extraFields.Keys) {
                $value = $extraFields[$key].TextBox.Text
                if (-not $value) {
                    $statusLabel.Text = "$key is required for 'nable'."
                    return
                }
                $params[$key] = $value
            }

            $installContent = @"
Install-TecharyApp -AppName `"nable`" -Parameters @{
    CustomerID    = `'$($params.CustomerID)`'
    Token         = `'$($params.Token)`'
    CustomerName  = `'$($params.CustomerName)`'
    ServerAddress = `'$($params.ServerAddress)`'
}
"@
        } else {
            $installContent = "Install-TecharyApp -AppName `"$appName`""
        }

        # === Create uninstall script
        $uninstallScript = Join-Path $appFolder "uninstall-$appName.ps1"
        $uninstallContent = "Uninstall-TecharyApp -AppName `"$appName`""

        # === Write Scripts
        Set-Content -Path $installScript -Value $installContent -Encoding UTF8
        Set-Content -Path $uninstallScript -Value $uninstallContent -Encoding UTF8

        # === Package using IntuneWinAppUtil
        $intuneWinAppUtil = Get-IntuneWinAppUtil
        $outputPath = Join-Path $OutputRoot $appName
        $null = New-Item -ItemType Directory -Path $outputPath -Force

        $statusLabel.Text = "Packaging $appName..."
        & $intuneWinAppUtil -c $appFolder -s ("install-$appName.ps1") -o $outputPath | Out-Null

        $statusLabel.Text = "$appName packaged successfully. Output: $outputPath"
    }
    catch {
        $statusLabel.Text = "Error: $($_.Exception.Message)"
    }
})

# === Show GUI ===
$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
