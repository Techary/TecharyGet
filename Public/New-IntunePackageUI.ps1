function New-IntunePackageUI {
    [CmdletBinding()]
    param()

    # Load Windows Forms
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- UI SETUP ---
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "Techary Intune Packager (Lite)"
    $Form.Size = New-Object System.Drawing.Size(500, 300)
    $Form.StartPosition = "CenterScreen"
    $Form.FormBorderStyle = "FixedDialog"
    $Form.MaximizeBox = $false

    # -- App ID Field --
    $LblId = New-Object System.Windows.Forms.Label
    $LblId.Text = "Application ID (e.g. 7zip.7zip):"
    $LblId.Location = New-Object System.Drawing.Point(20, 20)
    $LblId.Size = New-Object System.Drawing.Size(400, 20)
    $Form.Controls.Add($LblId)

    $TxtId = New-Object System.Windows.Forms.TextBox
    $TxtId.Location = New-Object System.Drawing.Point(20, 45)
    $TxtId.Size = New-Object System.Drawing.Size(440, 25)
    $Form.Controls.Add($TxtId)

    # -- Output Folder Field --
    $LblOut = New-Object System.Windows.Forms.Label
    $LblOut.Text = "Output Folder:"
    $LblOut.Location = New-Object System.Drawing.Point(20, 90)
    $LblOut.Size = New-Object System.Drawing.Size(400, 20)
    $Form.Controls.Add($LblOut)

    $TxtOut = New-Object System.Windows.Forms.TextBox
    $TxtOut.Text = "C:\IntunePackages" # Default
    $TxtOut.Location = New-Object System.Drawing.Point(20, 115)
    $TxtOut.Size = New-Object System.Drawing.Size(350, 25)
    $Form.Controls.Add($TxtOut)

    $BtnBrowse = New-Object System.Windows.Forms.Button
    $BtnBrowse.Text = "..."
    $BtnBrowse.Location = New-Object System.Drawing.Point(380, 114)
    $BtnBrowse.Size = New-Object System.Drawing.Size(80, 27)
    $BtnBrowse.Add_Click({
        $Dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($Dialog.ShowDialog() -eq "OK") { $TxtOut.Text = $Dialog.SelectedPath }
    })
    $Form.Controls.Add($BtnBrowse)

    # -- Create Button --
    $BtnRun = New-Object System.Windows.Forms.Button
    $BtnRun.Text = "CREATE PACKAGE"
    $BtnRun.Location = New-Object System.Drawing.Point(20, 170)
    $BtnRun.Size = New-Object System.Drawing.Size(440, 50)
    $BtnRun.BackColor = [System.Drawing.Color]::CornflowerBlue
    $BtnRun.ForeColor = [System.Drawing.Color]::White
    $BtnRun.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    
    $BtnRun.Add_Click({
        $Id = $TxtId.Text
        $Out = $TxtOut.Text

        if (-not $Id) {
            [System.Windows.Forms.MessageBox]::Show("Please enter an App ID.", "Error", "OK", "Warning")
            return
        }

        $BtnRun.Text = "Packaging..."
        $BtnRun.Enabled = $false
        $Form.Update()

        try {
            # Call the backend function we created earlier
            New-IntunePackage -Id $Id -OutputFolder $Out
            
            [System.Windows.Forms.MessageBox]::Show("Package Created Successfully!", "Success", "OK", "Information")
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Error: $_", "Failed", "OK", "Error")
        }
        finally {
            $BtnRun.Text = "CREATE PACKAGE"
            $BtnRun.Enabled = $true
        }
    })
    $Form.Controls.Add($BtnRun)

    # Show
    $Form.ShowDialog() | Out-Null
    $Form.Dispose()
}