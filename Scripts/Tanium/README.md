# Uninstall Tanium Client PowerShell Script

## Description

Completely removes the Tanium Client and its components from a Windows device. The script stops Tanium processes and services, runs the vendor uninstaller, deletes the installation directory, and removes Tanium registry keys, logging everything to a transcript.

## ⚠ Safety warning — read before running

**This script is destructive and irreversible.** It removes a management agent and deletes files and registry keys. There is no undo.

- **Deletes the entire Tanium install directory** (`C:\Program Files (x86)\Tanium`) recursively with `-Force`.
- **Deletes registry keys** under `HKLM:\SOFTWARE\Tanium`, `HKLM:\SOFTWARE\WOW6432Node\Tanium`, and two `CurrentControlSet\Services` entries.
- **Force-stops Tanium processes and services**, including the recorder driver service.
- Removing Tanium means the device **loses management, patching, and visibility** provided by that agent. Confirm this is intended and that the device is covered another way.
- The hard-coded paths, service names, and process names reflect one environment and one Tanium version. **Verify every one of them against your own devices** — a mismatch means the script silently does less than you expect, or acts on the wrong thing.
- Writes a transcript to `C:\Tanium_Uninstall_Log.txt`. Check it after every run; the script continues past individual failures rather than stopping.
- Run against one lab device first, confirm the outcome, then pilot on a small controlled group before anything broader.

## Files

| File | Status |
|---|---|
| `Uninstall-TaniumClient-v1.ps1` | ✅ **Compliant Remote Action** — use this one. |
| `uninstall_tanium.ps1` | Original, kept unmodified for reference and rollback. |

## Remote Action compliance — `Uninstall-TaniumClient-v1.ps1`

Fully compliant per the [Windows reference](../../Markdowns/nexthink-remote-actions-windows-reference.md): UTF-8 BOM / CRLF encoding, `param()` block, `nxtremoteactions.dll` loaded, error `trap`, and a deterministic 9-field output schema written unconditionally as the final step.

### Inputs (as they appear in the Nexthink UI)

| Name | Default | Notes |
|---|---|---|
| `TaniumInstallPath` | `C:\Program Files (x86)\Tanium` | Absolute path. Drive roots and system directories are refused. |
| `RemoveInstallDirectory` | `true` | `true`/`false`. Set `false` to uninstall without deleting leftover files. |
| `RemoveRegistryKeys` | `true` | `true`/`false`. Set `false` to leave the registry untouched. |

### Outputs

| Name | Type | Meaning |
|---|---|---|
| `ProcessesStopped` | UInt32 | Tanium processes force-stopped. |
| `ServicesStopped` | UInt32 | Tanium services force-stopped. |
| `UninstallerExecuted` | Bool | Vendor uninstaller found and completed. |
| `InstallDirectoryRemoved` | Bool | Directory gone, verified by re-testing the path. |
| `RegistryKeysRemoved` | UInt32 | Keys deleted and verified as gone. |
| `SpaceReclaimed` | Size | Bytes freed, measured before removal. |
| `TaniumStillPresent` | Bool | **Alert on this** — true means manual remediation needed. |
| `ExecutionTime` | String | Completion time, `yyyy-MM-dd HH:mm:ss`. |
| `ExecutionSummary` | String | Stage outcomes, pipe separated. |

### What changed from the original

- Install path and the two destructive stages became **input parameters**, so removal of files and registry keys can each be disabled.
- Added **path guards**: the script refuses drive roots, paths shorter than 4 characters, and the Windows/System32/Program Files/ProgramData roots. The original would have recursively deleted whatever path it was given.
- Added the **Nexthink output schema**; the original wrote only to the console and a transcript file.
- Added **post-removal verification** — the directory and each registry key are re-tested after deletion rather than trusting `Remove-Item`.
- `SpaceReclaimed` is measured **before** deletion and reported only when removal is verified, so it is a real number.
- Added a **300-second cap** on the vendor uninstaller; the original `-Wait` could hang for the entire remote action timeout.
- Removed `Start-Transcript` and coloured `Write-Host`, which suit interactive use rather than an unattended action.
- Leftover components now produce a **non-zero exit code**; the original always finished silently regardless of outcome.

### Execution context

**Local System (required).** Stopping services, running the uninstaller, and writing to HKLM all need administrative privileges.

## Usage

### Nexthink Remote Action

1. Upload **`Uninstall-TaniumClient-v1.ps1`** (sign it first for production use).
2. Set the context to **Local System** and a timeout of roughly 600 seconds.
3. Alert on `TaniumStillPresent = true` to find devices needing manual cleanup.

### Standalone

Run the original from an **elevated** PowerShell session:

```powershell
.\uninstall_tanium.ps1
```

---

Provided **as is**, with no warranty. See the [repository README](../../README.md) and [LICENSE](../../LICENSE).
