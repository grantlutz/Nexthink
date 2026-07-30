# Scripts

PowerShell scripts organized one folder per target product. Each folder has its own README covering what the script does, what it affects, and how close it is to being a compliant Nexthink Remote Action.

| Folder | Remote Action script | Purpose | Risk |
|---|---|---|---|
| [Crowdstrike](Crowdstrike/) | `Stop-CrowdStrikeServices-v1.ps1` | Stops the CrowdStrike Falcon services (`csagent`, `csfalconservice`). | 🔴 High — disables endpoint security |
| [Tanium](Tanium/) | `Uninstall-TaniumClient-v1.ps1` | Fully removes the Tanium Client: processes, services, uninstaller, install directory, registry keys. | 🔴 High — irreversible removal |
| [Windows](Windows/) | `Get-LastLogonDays-v1.ps1` | Reports the last interactive logon (event ID 4624) and days elapsed. | 🟢 Low — read-only |

All three are **compliant Nexthink Remote Actions**: UTF-8 BOM / CRLF encoding, `param()` inputs, `nxtremoteactions.dll` loaded, an error `trap`, and a deterministic output schema written unconditionally as the final step. Each folder's README lists the exact inputs and outputs as they appear in the Nexthink UI.

### Versioning

Every folder keeps the **original script unmodified** alongside the compliant version, so any change can be reverted by falling back to it:

| Compliant version | Original |
|---|---|
| `Stop-CrowdStrikeServices-v1.ps1` | `stop-crowdstrike.ps1` |
| `Uninstall-TaniumClient-v1.ps1` | `uninstall_tanium.ps1` |
| `Get-LastLogonDays-v1.ps1` | `last_connected_to_AD.ps1` |

Later revisions increment the suffix (`-v2`, `-v3`, …) rather than overwriting, so each prior version stays available.

> **Two of these conversions fixed real bugs**, not just formatting: the last-logon script counted service and network logons as user logons (reporting "0 days" on idle machines) and reported success even when it could not read the event log. See the Windows folder README.

## Before you run anything

Read the [repository README](../README.md) first. In short: everything is provided **as is** with no warranty, two of these three scripts do serious damage if pointed at the wrong device, and Remote Actions execute across every device you target at once, with system privileges, without a prompt.

Test on a disposable lab device, then a small pilot group you control, and only then broadly.

## Converting these into Remote Actions

Most of these scripts still need input/output plumbing before Nexthink can pass them parameters or store their results. The references in [Markdowns/](../Markdowns/) document exactly what that requires for each platform, and each ends with a checklist to work through before uploading.

If you use an AI assistant for the conversion, read the AI verification warnings in the [Markdowns README](../Markdowns/README.md) — particularly for the destructive scripts here, where a broadened deletion or service stop is the most dangerous thing that can go wrong.
