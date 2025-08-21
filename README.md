# Stop CrowdStrike Services PowerShell Script

## Description

This PowerShell script is designed to stop the CrowdStrike Falcon services (`csagent` and `csfalconservice`). It is built to be compatible with Nexthink Remote Actions.

## Features

- Stops `csagent` and `csfalconservice`.
- Requires administrative privileges to run.
- Provides console output for actions taken.
- Handles cases where services are already stopped or do not exist.
- Exits with code `0` on success and `1` on error, for Nexthink RA compatibility.

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
