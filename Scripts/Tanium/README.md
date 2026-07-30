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

## Remote Action compliance status

**Not yet a compliant Remote Action.** It is standalone PowerShell:

- No `param()` block — paths and names are hard-coded, so nothing can be configured from the Nexthink web interface.
- No Nexthink outputs (`nxtremoteactions.dll` / `[Nxt]::WriteOutput*`) — results are written to the console and transcript only, not to the data layer.
- Uses `Start-Transcript` and colored `Write-Host` output, which suit interactive use rather than an unattended Remote Action.
- Does not guarantee a meaningful exit code on all paths, which is how Nexthink judges success or failure.

See the [Windows reference](../../Markdowns/nexthink-remote-actions-windows-reference.md) for what a compliant conversion requires.

## Usage

Run from an **elevated** PowerShell session:

```powershell
.\uninstall_tanium.ps1
```

The script checks for administrator privileges and exits if they are missing.

---

Provided **as is**, with no warranty. See the [repository README](../../README.md) and [LICENSE](../../LICENSE).
