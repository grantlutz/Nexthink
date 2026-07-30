# Last Logon / Last Connected to AD PowerShell Script

## Description

Reads the newest successful logon event (Security event ID 4624) from the local Windows Security event log and reports both the timestamp and the number of days since it occurred.

Useful for spotting devices that haven't seen an interactive logon recently — stale machines, unused VDI images, or devices that may have lost domain connectivity.

## Safety notes

🟢 **Read-only.** The script queries the event log and makes no changes to the device.

Accuracy caveats worth knowing before you act on the result:

- Event ID 4624 covers **all** successful logon types, including service, network, and batch logons — not just interactive user sign-ins. The newest 4624 event is frequently a machine or service logon, so "days since last logon" can read as `0` on a device nobody has signed into. Filter by logon type if you need interactive logons specifically.
- The Security log **rolls over**. On a busy device, the oldest retained events may be recent, so "no events found" can mean "log wrapped," not "never logged on."
- Despite the filename, this reads **local** logon events — it does not query Active Directory for a `lastLogon` / `lastLogonTimestamp` attribute.
- Requires permission to read the Security log; run elevated.

## Files

| File | Status |
|---|---|
| `Get-LastLogonDays-v1.ps1` | ✅ **Compliant Remote Action** — use this one. |
| `last_connected_to_AD.ps1` | Original, kept unmodified for reference and rollback. |

## Remote Action compliance — `Get-LastLogonDays-v1.ps1`

Fully compliant per the [Windows reference](../../Markdowns/nexthink-remote-actions-windows-reference.md): UTF-8 BOM / CRLF encoding, `param()` block, `nxtremoteactions.dll` loaded, error `trap`, and a deterministic 8-field output schema written unconditionally as the final step.

### Inputs (as they appear in the Nexthink UI)

| Name | Default | Notes |
|---|---|---|
| `LogonTypes` | `2,10,11` | Interactive, RemoteInteractive, CachedInteractive. Use `2,3,4,5,7,8,9,10,11` to count every type. |
| `MaxEventsToScan` | `1000` | 4624 events to read, newest first. Range 1–100000. |

### Outputs

| Name | Type | Meaning |
|---|---|---|
| `LastLogonFound` | Bool | **Check this first** — false means "not in the retained log", not "never". |
| `LastLogonTime` | DateTime | Timestamp of the most recent matching logon. |
| `DaysSinceLastLogon` | UInt32 | Whole days elapsed. |
| `LastLogonUser` | String | `DOMAIN\user` for that logon. |
| `LastLogonType` | String | e.g. `10 (RemoteInteractive)`. |
| `EventsScanned` | UInt32 | 4624 events actually examined. |
| `ExecutionTime` | String | Completion time, `yyyy-MM-dd HH:mm:ss`. |
| `ExecutionSummary` | String | Result summary, pipe separated. |

### What changed from the original

- **Fixed the core accuracy bug.** The original took the newest 4624 event of *any* type. Because service and network logons occur constantly, it reported "0 days since last logon" on machines nobody had signed into for months — the opposite of what the script is used to find. The compliant version filters to interactive logon types by default and excludes machine accounts (`NAME$`) and well-known system accounts.
- Added the **Nexthink output schema**; the original wrote only to the console.
- Added **`LastLogonFound` and `EventsScanned`** so an empty result is distinguishable from a genuinely idle device. If `EventsScanned` equals `MaxEventsToScan` and nothing was found, the scan window was too small — the result is inconclusive.
- **Fixed the silent-failure bug.** The original's `catch` wrote an error but never set a non-zero exit code, so a device that denied access to the Security log still reported success to Nexthink.
- Logon types and scan depth became **input parameters**.
- Clock skew is handled: a future-dated event reports 0 rather than a negative value the UInt32 output cannot represent.

### Execution context

**Local System (required).** Reading the Security event log needs administrative privileges.

## Usage

### Nexthink Remote Action

1. Upload **`Get-LastLogonDays-v1.ps1`** (sign it first for production use).
2. Set the context to **Local System** and a timeout of roughly 120 seconds.
3. When hunting stale devices, filter on `LastLogonFound = true` **and** a high `DaysSinceLastLogon`. Never act on `LastLogonFound = false` alone.

### Standalone

Run the original from an **elevated** PowerShell session:

```powershell
.\last_connected_to_AD.ps1
```

---

Provided **as is**, with no warranty. See the [repository README](../../README.md) and [LICENSE](../../LICENSE).
