# Scripts

PowerShell scripts organized one folder per target product. Each folder has its own README covering what the script does, what it affects, and how close it is to being a compliant Nexthink Remote Action.

| Folder | Script | Purpose | Risk | RA compliance |
|---|---|---|---|---|
| [Crowdstrike](Crowdstrike/) | `stop-crowdstrike.ps1` | Stops the CrowdStrike Falcon services (`csagent`, `csfalconservice`). | 🔴 High — disables endpoint security | Partial (exit codes + trap; no inputs/outputs) |
| [Tanium](Tanium/) | `uninstall_tanium.ps1` | Fully removes the Tanium Client: processes, services, uninstaller, install directory, registry keys. | 🔴 High — irreversible removal | Not yet — standalone PowerShell |
| [Windows](Windows/) | `last_connected_to_AD.ps1` | Reports the last successful logon (event ID 4624) and days elapsed. | 🟢 Low — read-only | Not yet — no outputs, no exit code on failure |

## Before you run anything

Read the [repository README](../README.md) first. In short: everything is provided **as is** with no warranty, two of these three scripts do serious damage if pointed at the wrong device, and Remote Actions execute across every device you target at once, with system privileges, without a prompt.

Test on a disposable lab device, then a small pilot group you control, and only then broadly.

## Converting these into Remote Actions

Most of these scripts still need input/output plumbing before Nexthink can pass them parameters or store their results. The references in [Markdowns/](../Markdowns/) document exactly what that requires for each platform, and each ends with a checklist to work through before uploading.

If you use an AI assistant for the conversion, read the AI verification warnings in the [Markdowns README](../Markdowns/README.md) — particularly for the destructive scripts here, where a broadened deletion or service stop is the most dangerous thing that can go wrong.
