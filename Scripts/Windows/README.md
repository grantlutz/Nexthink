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

## Remote Action compliance status

**Not yet a compliant Remote Action.** It is standalone PowerShell:

- No Nexthink outputs — results go to the console via `Write-Host`, so nothing reaches the data layer. This script is a natural fit for outputs like a `DateTime` field for the logon timestamp and a `UInt32` for days elapsed.
- No `param()` block — the event ID and lookback behavior are fixed.
- The `catch` block writes an error but does **not** set a non-zero exit code, so a failed run would still report success to Nexthink.

See the [Windows reference](../../Markdowns/nexthink-remote-actions-windows-reference.md) for what a compliant conversion requires.

## Usage

Run from an **elevated** PowerShell session:

```powershell
.\last_connected_to_AD.ps1
```

Example output:

```
Last successful logon (Event ID 4624) was on: 2026-07-28 08:14:22
Days since last logon: 2
```

---

Provided **as is**, with no warranty. See the [repository README](../../README.md) and [LICENSE](../../LICENSE).
