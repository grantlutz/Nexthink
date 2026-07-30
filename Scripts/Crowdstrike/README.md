# Stop CrowdStrike Services PowerShell Script

## Description

This PowerShell script is designed to stop the CrowdStrike Falcon services (`csagent` and `csfalconservice`). It is built to be compatible with Nexthink Remote Actions.

## ⚠ Safety warning — read before running

**This script disables endpoint security protection.** While the Falcon services are stopped, the device is not protected and telemetry is not being reported.

- Stopping EDR services is a **security-affecting action**. Treat it as a change requiring approval, not a routine troubleshooting step.
- `Stop-Service -Force` also stops **dependent services**, which may affect more than the two named services.
- The script does **not** restart the services. Restoring protection is a separate, manual step — know how you will do it, and have a plan for devices that go offline while stopped.
- Falcon may be configured with tamper protection or service recovery that blocks or reverses the stop. Verify the actual outcome on the device; a `0` exit code means the script ran, not that the services stayed stopped.
- **Never target broadly.** Run against one lab device, verify, then a small pilot group. A fleet-wide execution leaves your whole estate unprotected simultaneously.

## Features

- Stops `csagent` and `csfalconservice`.
- Requires administrative privileges to run.
- Provides console output for actions taken.
- Handles cases where services are already stopped or do not exist.
- Exits with code `0` on success and `1` on error, for Nexthink RA compatibility.

## Files

| File | Status |
|---|---|
| `Stop-CrowdStrikeServices-v1.ps1` | ✅ **Compliant Remote Action** — use this one. |
| `stop-crowdstrike.ps1` | Original, kept unmodified for reference and rollback. |

## Remote Action compliance — `Stop-CrowdStrikeServices-v1.ps1`

Fully compliant per the [Windows reference](../../Markdowns/nexthink-remote-actions-windows-reference.md): UTF-8 BOM / CRLF encoding, `param()` block, `nxtremoteactions.dll` loaded, error `trap`, and a deterministic 8-field output schema written unconditionally as the final step.

### Inputs (as they appear in the Nexthink UI)

| Name | Default | Notes |
|---|---|---|
| `ServiceNames` | `csagent,csfalconservice` | Comma-separated service names. Split, trimmed, de-duplicated by the script. |
| `StopTimeoutSeconds` | `30` | Seconds to wait per service for the Stopped state. Range 1–600. |

### Outputs

| Name | Type | Meaning |
|---|---|---|
| `ServicesRequested` | UInt32 | Distinct service names supplied. |
| `ServicesStopped` | UInt32 | Services this run transitioned to Stopped. |
| `ServicesAlreadyStopped` | UInt32 | Already stopped; no action taken. |
| `ServicesNotFound` | UInt32 | Not installed on the device. |
| `ServicesFailed` | UInt32 | Present but could not be stopped. |
| `AllRequestedServicesStopped` | Bool | True when nothing requested is left running. |
| `ExecutionTime` | String | Completion time, `yyyy-MM-dd HH:mm:ss`. |
| `ExecutionSummary` | String | Per-service outcomes, pipe separated. |

The four outcome counts always sum exactly to `ServicesRequested`.

### What changed from the original

- Service names and the stop timeout became **input parameters** — the script is now generic and can be re-pointed without breaking its signature.
- Added the **Nexthink output schema**; the original only wrote to the console, so nothing reached the data layer.
- Added **post-stop verification**: the service state is re-read after the attempt rather than trusting `Stop-Service`. This matters because Falcon tamper protection can block or immediately reverse a stop — the original would have reported success in that case.
- Added a **wait-for-stopped timeout**; `Stop-Service` returns before the transition completes.
- A service that exists but will not stop is now a **real failure** (exit 1) instead of being silently absorbed.
- Absent or already-stopped services are explicitly **not** failures, so the action is idempotent.

### Execution context

**Local System (required).** Stopping a protected service needs administrative privileges.

## Usage

### Standalone Execution

1. Open a PowerShell terminal **as an Administrator**.
2. Navigate to the directory containing the `stop-crowdstrike.ps1` script.
3. Run the script:
   ```powershell
   .\stop-crowdstrike.ps1
   ```

### Nexthink Remote Action

1. Create a new Remote Action in the Nexthink web interface.
2. Upload **`Stop-CrowdStrikeServices-v1.ps1`** (sign it first for production use).
3. Nexthink detects the two parameters and the eight outputs automatically; set labels and defaults as needed.
4. Under Advanced Configuration, set the context to **Local System** and a timeout of roughly 120 seconds (worst case is `StopTimeoutSeconds` per requested service).
5. The script reports success or failure back to Nexthink based on its exit code, with detail in `ExecutionSummary`.

---

Provided **as is**, with no warranty. See the [repository README](../../README.md) and [LICENSE](../../LICENSE).
