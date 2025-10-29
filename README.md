# 📦 TecharyGet PowerShell Module

> **Author:** Adam Sweetapple

> **Purpose:** Install and uninstall software using custom Winget logic and external installer definitions (including EXE, MSI, ZIP, MSIX).

## 🛠️ Features

* Installs apps from Winget using GitHub-hosted YAMLs

* Supports MSI, EXE, ZIP, and MSIX installers

* Custom app support with static URLs and parameters (e.g. N-Able, myDPD)

* Works with Intune deployments and SYSTEM-level context

* Full uninstall logic via Winget or Registry fallback

* Architecture-aware (x64, ARM64)

## 📥 Installation Commands
**Install an App**
```Powershell
Install-TecharyApp -AppName "7zip"
```

**Install with Parameters (e.g. N-Able)**
```Powershell
Install-TecharyApp -AppName "nable" -Parameters @{
    CustomerID    = "123"
    Token         = "abcdef-12345"
    CustomerName  = "My Company"
    ServerAddress = "control.example.com"
}
```
**Uninstall an App**
```Powershell
Uninstall-TecharyApp -AppName "bitwarden"
```
**List All Supported Apps**
```Powershell
Get-TecharyAppList
```

🔧 Example Output of Get-TecharyAppList
| AppKey | DisplayName | InstallerType | IsWinget | WingetID |
|  ----- |  ---------- | ------------- | -------- | -------- |
| 7zip   |	7Zip       | exe           | true     | 7zip.7zip |
| bitwarden | Bitwarden | exe | true | Bitwarden.Bitwarden |
| vscode | Microsoft Visual Studio Code | exe | true | Microsoft.VisualStudioCode |
| nable | N-Able RMM | exe | false | (custom) |
| powerbi | Microsoft Power BI | exe | true | Microsoft.PowerBI |

**Show Help**
```Powershell
Get-TecharyHelp
```

## 📦 AppMap Configuration

Apps are defined in a separate file AppMap.ps1, with the following structure:
``` Poweshell
"7zip" = @{
    DisplayName     = "7Zip"
    RepoPath        = "7/7zip/7zip"
    YamlFile        = "7zip.7zip.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/7z\d+-x64\.exe)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/7z\d+-arm64\.exe)'
    InstallerType   = "exe"
    ExeInstallArgs  = "/S"
    IsWinget        = $true
    WingetID        = "7zip.7zip"
}
```
## 💡 Notes

* The module detects CPU architecture and installs the correct version.

* All downloads are logged to C:\Logs\TecharyGetLogs\TecharyGet.log

* Apps not in Winget can be defined with a static DownloadUrl and installed with logic from the module.

* You can run winget.exe directly (e.g. for SYSTEM context via Intune) using its resolved path in C:\Program Files\WindowsApps\...

## 🧪 Tested With

* Intune deployments (System context)

* Windows 10/11 x64 + ARM64

* PowerShell 5.1 and 7+

## 🧯 Troubleshooting

* ❗ App not found? → Make sure it's defined in AppMap.ps1

* ❗ Duplicate key error? → Ensure there are no repeated properties in app maps (like IsWinget or WingetID)

* ❗ Winget not running in SYSTEM? → Use the direct winget.exe path resolution
