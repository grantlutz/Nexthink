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

## Remote Action compliance status

Partially compliant. The script has the error `trap` and correct exit-code behavior, but it has **no `param()` block and no Nexthink outputs** — it does not load `nxtremoteactions.dll` or call `[Nxt]::WriteOutput*`, so results are printed to the console rather than stored in the data layer.

To make it fully compliant (parameterized service names, output fields for per-service results), see the [Windows reference](../../Markdowns/nexthink-remote-actions-windows-reference.md).

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
2. Upload the `stop-crowdstrike.ps1` script.
3. The script requires no parameters.
4. Ensure the Remote Action is configured to run with `Local System` privileges.
5. The script will report success or failure back to Nexthink based on its exit code.

---

Provided **as is**, with no warranty. See the [repository README](../../README.md) and [LICENSE](../../LICENSE).
