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
---

## 🛠️ Usage Examples

### 1. Installing Applications
The `Install-SmartApp` command is the primary workhorse. It attempts to find the app in the public GitHub repo first, then falls back to your Private Catalog.

```powershell
# Install a standard app (Latest Version)
Install-SmartApp -Id "7zip.7zip"

# Install a specific ID from your private catalog
Install-SmartApp -Id "MyDPD"
