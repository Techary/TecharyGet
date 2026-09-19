# TecharyGet

A PowerShell module for deploying, detecting and removing software across an MSP estate. It resolves the latest version of an application from the public winget manifest repository or a private catalogue, so there is no local package repository to maintain.

Designed to be driven unattended as SYSTEM from an RMM, and to be honest about failure: an install that did not install reports failure rather than a silent success.

---

## Installation

Copy the module folder to a PowerShell modules directory:

```
C:\Program Files\WindowsPowerShell\Modules\TecharyGet\
```

Then `Import-Module TecharyGet`. Requires PowerShell 5.1 or later.

Endpoints managed through the N-central policies below do not need this step — the policies fetch the module themselves.

---

## Commands

| Command | Purpose |
|---|---|
| `Install-TecharyApp -Id <id>` | Install an application |
| `Test-TecharyApp -Name <id>` | Report whether an application is installed |
| `Uninstall-TecharyApp -Name <name>` | Remove an application |
| `Install-NableAgent` | Install the N-central agent |
| `Get-GitHubInstaller -Id <id>` | Resolve and download an installer without running it |
| `New-IntunePackage` / `New-IntunePackageUI` | Build `.intunewin` packages |
| `Write-PackagerLog` | Write to the module log and Windows event log |

> The parameter names differ by design of history, not intent: `Install-TecharyApp` takes `-Id`, while `Test-TecharyApp` and `Uninstall-TecharyApp` take `-Name`. All three accept a winget package ID.

### Installing

```powershell
# Any package in the winget community repository
Install-TecharyApp -Id "7zip.7zip"

# An entry from the private catalogue
Install-TecharyApp -Id "MyDPD"
```

`Install-TecharyApp` is **not** limited to a curated list. It resolves any winget package ID live, and falls back to `Private/CustomApps.json` for applications that are not in the public repository. An unknown ID throws rather than returning quietly, so a typo cannot be reported as a successful install.

The N-central agent takes its own parameters:

```powershell
Install-NableAgent `
    -CustomerID "<Customer ID>" `
    -Token "<Token>" `
    -ServerAddress "<N-central Server Address>"
```

### Detecting

```powershell
Test-TecharyApp -Name "7zip.7zip"            # -> True
Test-TecharyApp -Name "7zip.7zip" -Detailed  # -> object describing the match
```

`-Detailed` returns `Installed`, `MatchedBy`, `DisplayName`, `InstalledVersion` and `RegistryKey`. `MatchedBy` is worth reading: `Substring` means the result is a guess, not an identification.

Detection makes **no network calls** — it reads only the caches already on disk, because it runs on a schedule on every endpoint.

### Removing

```powershell
Uninstall-TecharyApp -Name "7-Zip"
Uninstall-TecharyApp -Name "7-Zip" -WhatIf
```

Handles MSI, EXE and MSIX. When elevated it removes MSIX packages for all users and deprovisions them, so a removed application does not reappear for the next user who signs in.

---

## How resolution works

Resolving a package from the GitHub API costs two requests, against an allowance of **60 per hour per source IP**. That allowance is shared by every endpoint behind a customer's NAT, so a rollout would exhaust it. Four layers sit in front of it:

| Layer | Cost | Covers |
|---|---|---|
| Local manifest cache | no network | anything installed on this machine before |
| Prebuilt index | one CDN file, no rate limit | the curated catalogue |
| Live GitHub API | 2 requests | any package |
| Stale cache | no network | last known good, when the API is unreachable |

Every layer is optional and falls through to the next, so a rate-limited or offline site keeps working.

Set `TECHARYGET_GITHUB_TOKEN`, or pass `-GitHubToken`, to raise the live allowance from 60 to 5,000 per hour.

### How detection works

Detection tries the most precise signal first:

1. **ARP product code or MSIX package family name** — definitive
2. **Exact display name**, including the package's canonical name from the index
3. **Substring display name** — imprecise, reported as such
4. **MSIX package name**

Tiers 1 and 2 are driven by an index built nightly from Microsoft's own published winget source, covering roughly **14,900 packages**. It is one CDN download and costs no GitHub API allowance.

Product codes alone are not enough on their own — Chrome's installed product code varies by build — which is why the canonical display name is carried too.

---

## The indexes

A scheduled GitHub Action publishes two files to the `manifest-index` branch, which endpoints read from `raw.githubusercontent.com`:

| File | Built from | Contents |
|---|---|---|
| `Detection.json` | the winget source index | product codes and package family names for every package |
| `Manifests.json` | `Index/Catalog.json` | installer URL and silent arguments for curated packages |

To take a package off the live API path for installs, add its ID to `Index/Catalog.json`. That is the only step; the Action does the rest. Detection needs no such step — every package is already covered.

> Scheduled workflows only run from the repository's default branch.

---

## The private catalogue

`Private/CustomApps.json` holds applications that are not in the winget repository:

```json
{
    "Id": "MyDPD",
    "Url": "https://apis.my.dpd.co.uk/apps/download/public",
    "SilentArgs": "--Silent",
    "InstallerType": "exe",
    "DisplayName": "MyDPD"
}
```

`DisplayName` should match the Add/Remove Programs entry, since that is what detection compares against.

---

## Logging

| Destination | Path |
|---|---|
| Module log | `C:\ProgramData\TecharyGet\InstallLogs.log` |
| Windows event log | Application, source `TecharyGet` — 100 info, 200 warning, 300 error |
| N-central policy log | `C:\ProgramData\Techary\AutomationManager\Logs\` |

Logging never aborts an install. Event logging is best effort, because creating an event source requires elevation and enumerating the log can be refused outright for a non-elevated caller.

### Cached state

Everything the module caches lives under `C:\ProgramData\TecharyGet\`:

```
DetectionIndex.json        full package to ARP mapping (12h)
ManifestIndex.json         curated install metadata (12h)
ManifestCache\<id>.json    per package, resolved on install (24h)
CustomApps_Cache.json      private catalogue (60m)
```

Deleting any of them is safe; they are re-fetched on next use.

---

## N-central

Three Automation Manager policies wrap the module. Each fetches it on demand, so nothing needs pre-staging on the endpoint.

| Policy | Input | Output |
|---|---|---|
| TecharyGet detection template | `AppId` | `Installed` |
| TecharyGet install template | `AppId` | `InstallSucceeded` |
| TecharyGet uninstall template | `AppName` | `UninstallSucceeded` |

Pair detection with install as self-healing. **Do not** attach uninstall as self-healing: a detection service goes red when the application *is* present, so the pair would remove it every time it is found. Use uninstall from Tools > Task Execution.
