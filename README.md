<img width="1536" height="1024" alt="ChatGPT Image Oct 30, 2025, 09_09_28 AM" src="https://github.com/user-attachments/assets/fb7f9529-9ab6-4f86-a33f-bcfce081be86" />

# TecharyGet PowerShell Module

> **Author:** Adam Sweetapple

> **Purpose:** Install and uninstall software using custom Winget logic and external installer definitions (including EXE, MSI, ZIP, MSIX).

## Features

* Installs apps from Winget using GitHub-hosted YAMLs

* Supports MSI, EXE, ZIP, and MSIX installers

* Custom app support with static URLs and parameters (e.g. N-Able, myDPD)

* Works with Intune deployments and SYSTEM-level context

* Full uninstall logic via Winget or Registry fallback

* Architecture-aware (x64, ARM64)

## Available Commands
**Install an App**
```Powershell
Install-TecharyApp -AppName "7zip"
```

**Install with Parameters (e.g. N-Able)**
```Powershell
Install-TecharyApp -AppName "nable" -Parameters @{
    CustomerID    = "123"
    Token         = "abcdef-12345"
    CustomerName  = '\"customer name\"'
    ServerAddress = "nable.serveraddress.com"
}
```
**Update TecharyGet Module**

To get the latest TecharyGet Module, please run the following:
```Powershell
Update-TecharyGetModule
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
Help-TecharyApp
```

## AppMap Configuration

Apps are defined in a separate file, AppMap.ps1, hosted in the GitHub Repository.

The following structure lists the available Winget apps:
``` Powershell
"bitwarden" = @{
    DisplayName     = "Bitwarden"
    RepoPath        = "b/Bitwarden/Bitwarden"
    YamlFile        = "Bitwarden.Bitwarden.installer.yaml"
    PatternX64      = 'InstallerUrl:\s*(\S*/Bitwarden-Installer-\S+\.exe)'
    PatternARM64    = 'InstallerUrl:\s*(\S*/Bitwarden-Installer-\S+\.exe)'
    InstallerType   = "exe"
    ExeInstallArgs  = "/allusers /S"
    IsWinget        = $true
    WingetID        = "Bitwarden.Bitwarden"
}
```

For custom apps that are not available in Winget are structured similar like this:
```Powershell
"mydpd" = @{
    DisplayName     = "MyDPD Customer"
    IsWinget        = $false
    DownloadUrl     = "https://apis.my.dpd.co.uk/apps/download/public"
    InstallerType   = "exe"
    ExeInstallArgs  = "--Silent"
}
```
## Notes

* The module detects CPU architecture and installs the correct version.

* All downloads are logged to C:\Logs\TecharyGetLogs\TecharyGet.log

* Apps not in Winget can be defined with a static DownloadUrl and installed with logic from the module.

* You can run winget.exe directly (e.g. for SYSTEM context via Intune) using its resolved path in C:\Program Files\WindowsApps\...

* Hosting the AppMap.ps1 file means that we can manage all app installs from a centralised location for ALL of out customers.

## 🧪 Tested With

* Intune deployments (System context)

* Windows 10/11 x64 + ARM64

* PowerShell 5.1 and 7+

## Troubleshooting

* ❗ App not found? → Make sure it's defined in AppMap.ps1

* ❗ Duplicate key error? → Ensure there are no repeated properties in app maps (like IsWinget or WingetID)

* ❗ Winget not running in SYSTEM? → Use the direct winget.exe path resolution
