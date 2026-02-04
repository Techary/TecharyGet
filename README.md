Here is a professional, comprehensive `README.md` file for your module. It covers all the advanced features we built (Cloud Catalog, Intune Packaging, Smart Uninstall, etc.).

You can copy-paste this directly into the root of your project.

---

```markdown
# TecharyGet

**TecharyGet** is an enterprise-grade PowerShell module designed for modern software deployment. It bridges the gap between ad-hoc installations and formal Intune packaging, allowing IT Admins to deploy the latest versions of software dynamically without maintaining massive local repositories.

## 🚀 Key Features

* **Smart Installation:** Automatically fetches the latest version of apps from GitHub (WinGet Manifests) or your Private Cloud Catalog.
* **Architecture Detection:** Automatically selects the correct installer (x64, x86, ARM64) for the target machine.
* **Enterprise Logging:** Writes detailed logs to both `C:\ProgramData\TecharyGet\InstallLogs.log` and the **Windows Event Log** (Source: `TecharyGet`) for RMM monitoring.
* **Intune Packaging:** Instantly generates `.intunewin` files with "Thin" scripts that trigger installs dynamically.
* **Smart Uninstall:** Removes apps by searching Registry (MSI/EXE), Modern Apps (MSIX), and Custom Display Names.
* **Private Catalog:** Supports a cloud-hosted `CustomApps.json` (e.g., GitHub Raw) for proprietary apps not found in public repos.

---

## 📦 Installation

1.  Copy the `TecharyGet` folder to your PowerShell Modules directory:
    * `C:\Program Files\WindowsPowerShell\Modules\`
2.  Import the module:
    ```powershell
    Import-Module TecharyGet -Force
    ```

---

## 🛠️ Usage Examples

### 1. Installing Applications
The `Install-SmartApp` command is the primary workhorse. It attempts to find the app in the public GitHub repo first, then falls back to your Private Catalog.

```powershell
# Install a standard app (Latest Version)
Install-SmartApp -Id "7zip.7zip"

# Install a specific ID from your private catalog
Install-SmartApp -Id "MyDPD"

# Install a complex app (e.g. Dell Command Update) - Handles Exit Code 4 automatically
Install-SmartApp -Id "Dell.CommandUpdate"

```

### 2. Uninstalling Applications

The uninstaller intelligently searches the Registry (HKLM/HKCU) and Appx packages.

```powershell
# Uninstall by Display Name
Uninstall-SmartApp -Name "Google Chrome"

# Uninstall using a Custom ID (looks up real name in JSON)
Uninstall-SmartApp -Name "MyDPD"

# Test run (Safe Mode)
Uninstall-SmartApp -Name "Windows365" -WhatIf

```

### 3. Creating Intune Packages

You can generate ready-to-upload `.intunewin` files that contain "Thin" scripts (One-Liners). These scripts assume `TecharyGet` is installed on the target machine and trigger a live download/install.

**GUI Method:**

```powershell
New-IntunePackageUI

```

**CLI Method:**

```powershell
New-IntunePackage -Id "Dell.CommandUpdate" -OutputFolder "C:\IntunePackages"

```

* **Install Command:** `powershell.exe -ExecutionPolicy Bypass -File Install.ps1`
* **Uninstall Command:** `powershell.exe -ExecutionPolicy Bypass -File Uninstall.ps1`

### 4. Special N-able Agent Deployment

N-able requires dynamic parameters (Token, CustomerID). Use the dedicated function:

```powershell
Install-NableAgent -CustomerID "123" `
                   -Token "abc-123-xyz" `
                   -CustomerName "ClientA" `
                   -ServerAddress "rmm.example.com"

```

---

## ☁️ Private Catalog Configuration

For apps that are not in the public WinGet repo (e.g., licensed software, internal tools), use the **Private Catalog**.

### 1. The JSON Structure

Create a `CustomApps.json` file:

```json
[
  {
    "Id": "MyDPD",
    "Url": "[https://www.mydpd.co.uk/downloads/MyDPD_Installer.exe](https://www.mydpd.co.uk/downloads/MyDPD_Installer.exe)",
    "SilentArgs": "/S /v/qn",
    "InstallerType": "exe",
    "DisplayName": "MyDPD Desktop Client"
  },
  {
    "Id": "InternalTool",
    "Url": "[https://storage.mycompany.com/tools/internal.msi](https://storage.mycompany.com/tools/internal.msi)",
    "SilentArgs": "/qb",
    "InstallerType": "msi",
    "DisplayName": "Techary Internal Tool v2"
  }
]

```

### 2. Hosting (Cloud Sync)

Host this file on a raw URL (e.g., GitHub Raw, Azure Blob). The module automatically caches this file locally and syncs it every 60 minutes.

**To configure the URL:**
Edit `Private\Get-CustomApp.ps1` and update the `$CloudUrl` variable:

```powershell
$CloudUrl = "[https://raw.githubusercontent.com/Techary/TecharyGet/BETA/TecharyGet/Private/CustomApps.json](https://raw.githubusercontent.com/Techary/TecharyGet/BETA/TecharyGet/Private/CustomApps.json)"

```

---

## 🔍 Logging & Telemetry

The module provides full observability for RMM tools (N-able, Datto, NinjaOne).

* **Log File:** `C:\ProgramData\TecharyGet\InstallLogs.log`
* **Event Log:** Windows Logs -> Application
* **Source:** `TecharyGet`
* **Event IDs:**
* `100`: Information (Started, Success)
* `200`: Warning (Reboot Required, Retry)
* `300`: Error (Download Failed, Install Failed)





---

## ⚠️ Troubleshooting

**"Access Denied" on Download:**
The module uses User-Agent spoofing (Chrome/120) to bypass Akamai/Vendor blocks (e.g., Dell, Adobe).

**Exit Code 4 (Dell):**
The module treats Exit Code `4` as "Success (Reboot Required)" specifically for Dell installers, preventing false failure reports.

**"WindowsApp" Uninstall Failures:**
Store Apps often have internal names different from their display names. Use `Get-StartApps` to find the internal ID (e.g., `MicrosoftCorporationII.Windows365`).

```

```
