# Nexthink Remote Actions on Windows — Complete Component Reference

> **Sources:** [Nexthink Platform Documentation — Writing Scripts for Remote Actions on Windows](https://docs.nexthink.com/platform/user-guide/remote-actions/setting-up-and-managing-remote-actions/creating-remote-actions/writing-scripts-for-remote-actions-on-windows) • [Creating and configuring remote actions](https://docs.nexthink.com/platform/user-guide/remote-actions/setting-up-and-managing-remote-actions/creating-remote-actions) • [Monitoring specific remote action executions](https://docs.nexthink.com/platform/user-guide/remote-actions/using-remote-actions/monitoring-specific-remote-action-executions)
>
> **Purpose:** This document is a complete, authoritative reference of every component, method, type, constraint, and convention required when writing PowerShell scripts for Nexthink remote actions on Windows. Use it as a checklist to ensure nothing is missed.
>
> **Last verified against Nexthink documentation:** 2026-07-30

---

## 1. Prerequisites & Environment

| Requirement | Detail |
|---|---|
| **Scripting language** | PowerShell (built on the Windows .NET Framework) |
| **PowerShell compatibility** | The Collector's PowerShell executable/bitness is **not documented**. The docs describe PowerShell as .NET Framework-based and Nexthink Library templates guard on version 5 — write scripts compatible with **Windows PowerShell 5.1** and do not rely on PowerShell 7-only features. |
| **Language mode** | **Full Language Mode** required. Constrained Language Mode is **not supported** — most actions will not execute. |
| **File encoding** | **UTF-8 with BOM** (byte order mark). The BOM is the three-byte hex sequence `EF BB BF` at the start of the file. |
| **Line endings** | Windows-style **CR+LF** (`\r\n`) |
| **Script size limit** | **600 KB maximum** |
| **Input limit** | Up to **50 inputs**, maximum **30 KB** total characters |
| **Output limit** | Up to **50 outputs** (value limits depend on type — see §4) |
| **Primary use cases** | On-demand data collection, self-healing tasks, configuration changes |

---

## 2. Required .NET Assemblies (DLLs)

Two assemblies ship with the Nexthink Collector and must be loaded before using their respective classes.

### 2.1 Remote Actions DLL

```powershell
Add-Type -Path "$env:NEXTHINK\RemoteActions\nxtremoteactions.dll"
```

- **Provides:** the `[Nxt]` class (output write methods).
- **Must be loaded** before any `[Nxt]::WriteOutput*` call.

### 2.2 Campaign Actions DLL

```powershell
Add-Type -Path "$env:NEXTHINK\RemoteActions\nxtcampaignaction.dll"
```

- **Provides:** the `[Nxt.CampaignAction]` class (campaign control methods).
- **Must be loaded** before any campaign interaction.

> **Note:** The docs show the path unquoted; Nexthink Library scripts use the quoted form (`"$env:NEXTHINK\..."`). Both work — prefer the quoted form and test that the DLL file exists before calling `Add-Type` (see the template in §7).

---

## 3. Input Variables (Script Parameters)

Declare formal parameters at the top of the script using a `param()` block. This keeps the script generic and signature-safe — actual values are supplied through the Nexthink web interface at remote action configuration time.

```powershell
param(
    [string]$filePath,
    [string]$regPath
)
```

### 3.1 Key Rules

- The Nexthink platform auto-detects parameters from the uploaded script and displays them in the **Parameters** section.
- **All actual values are passed as text (strings).** If the script declares a non-string type, the script itself must handle the conversion.
- Modifying a **signed** script breaks its signature. Using parameters lets you change behavior without modifying (and re-signing) the script.
- Maximum **50 inputs**, **30 KB** total characters (see §1).

### 3.2 How Parameters Appear in the Web UI

For each detected parameter, the remote action editor exposes:

| Field | Behavior |
|---|---|
| **Name** | The label shown to the user when the system asks for a parameter value. |
| **Description** | A meaningful description of the parameter. |
| **Value** | List of permitted values, **one per line**. At least one value is required. **The first line is the default.** |
| **Allow the user to enter a custom value** | Optional toggle letting users supply a value not in the list. |

Design your `param()` names and in-script validation with this in mind: values always arrive as strings, may come from a fixed list or free entry, and empty/invalid values must be handled by the script.

---

## 4. Output Variables — `[Nxt]` Write Methods

These are the methods used to write results back to the Nexthink data layer. The platform auto-detects `WriteOutput*` calls in the uploaded script and lists them under the **Outputs** section. Set each output's label in the UI to control how it appears in investigations and dashboards. Maximum **50 outputs** per remote action.

### 4.1 Complete Method Reference

Every method accepts exactly **two arguments**: the output field name (`string`) and the value.

| # | Nxt Write Method | PowerShell Type | Constraints / Notes |
|---|---|---|---|
| 1 | `WriteOutputString` | `[string]` | 0–1024 bytes. Output is **truncated** if larger. |
| 2 | `WriteOutputBool` | `[bool]` | `$true` / `$false` |
| 3 | `WriteOutputUInt32` | `[uint32]` | Min: `0`  •  Max: `4,294,967,295` |
| 4 | `WriteOutputFloat` | `[float]` | Min: `-3.4E+38`  •  Max: `3.4E+38` |
| 5 | `WriteOutputSize` | `[float]` | Min: `0`  •  Max: `3.4E+38` (non-negative float) |
| 6 | `WriteOutputRatio` | `[float]` | No explicit constraints documented. |
| 7 | `WriteOutputBitRate` | `[float]` | No explicit constraints documented. |
| 8 | `WriteOutputDateTime` | `[DateTime]` | Format: `DD.MM.YYYY@HH:MM` |
| 9 | `WriteOutputDuration` | `[TimeSpan]` | Min: `0 ms`  •  Max: `49 days`  •  Precision: milliseconds |
| 10 | `WriteOutputStringList` | `[string[]]` | Array of strings. Same per-element constraints as `WriteOutputString` (0–1024 bytes each, truncated if larger). |

### 4.2 Usage Syntax

```powershell
[Nxt]::WriteOutputString("FieldName", $stringValue)
[Nxt]::WriteOutputBool("FieldName", $boolValue)
[Nxt]::WriteOutputUInt32("FieldName", $uint32Value)
[Nxt]::WriteOutputFloat("FieldName", $floatValue)
[Nxt]::WriteOutputSize("FieldName", $floatValue)
[Nxt]::WriteOutputRatio("FieldName", $floatValue)
[Nxt]::WriteOutputBitRate("FieldName", $floatValue)
[Nxt]::WriteOutputDateTime("FieldName", $dateTimeValue)
[Nxt]::WriteOutputDuration("FieldName", $timeSpanValue)
[Nxt]::WriteOutputStringList("FieldName", $stringArrayValue)
```

### 4.3 Output Field Rules

These rules are critical — violating them will cause runtime failures or unpredictable results.

1. **Predefine all output field names.** The script must populate known, pre-declared fields. An unknown output schema causes failures.
2. **Output field names must be strings.** Always pass the name as a quoted string literal, e.g., `'Output_Field_Name'`.
3. **Use a fixed number of output fields.** The schema must be static and predictable.
4. **Do NOT use dynamic fields.** Dynamic output structures cause inconsistency and processing errors.
5. **Do NOT define output fields inside loops.** All `WriteOutput*` calls that define the output schema should be deterministic and unconditional.

---

## 5. Execution Context & Timeout (Advanced Configuration)

### 5.1 Execution Context

The remote action's **Advanced Configuration** offers **three** execution contexts:

| Context | When to Use |
|---|---|
| **Local system user** (default) | Tasks requiring system rights — e.g., uninstalling software, reading system-wide registry keys or drivers. |
| **Interactive user** (logged-in employee) | Actions tied to a specific user — e.g., reading *their* recycle bin size, closing *their* applications, displaying campaigns that interact with the user. Run as Local system, such actions would act on the system account instead. |
| **Service** (Windows only) | Runs the remote action within a dedicated Windows service under a service account — e.g., on a Windows server (proxy) with permissions to update Active Directory. Requires PowerShell (Windows script), [prior service setup on the target device](https://docs.nexthink.com/platform/user-guide/remote-actions/setting-up-and-managing-remote-actions/creating-remote-actions/running-remote-actions-as-a-service-on-server-devices-windows-only), and the service name field set to the `--service-name` value used during setup. |

### 5.2 Script Timeout

- The timeout is set **in seconds** in the remote action's Advanced Configuration.
- If the script does not complete within the allotted time, **the system terminates it**.
- The API documents a minimum of 1 second; no default or maximum is documented.
- Budget for the worst-case device (slow disk, cold WMI, campaign wait times) when choosing the value.

---

## 6. Campaign Integration — `[Nxt.CampaignAction]` Methods

Campaigns let you interact with the employee to guide issue resolution.

### 6.1 Display Requirements

- The campaign must have a **Remote action** trigger and be **published**.
- The script can run either as the **interactive user** (no special privileges needed) or as **Local system** (administrative privileges needed) — campaigns can be displayed from both contexts. Choose per §5.1.

### 6.2 Campaign Identifier

Pass the campaign identifier as a script parameter. Two forms are accepted:

| Identifier Type | Format | Notes |
|---|---|---|
| **NQL ID** (recommended) | e.g., `#my_campaign_nql_id` | Requires Collector version **23.5 or later**. |
| **UID** (classic) | GUID format | Works on all Collector versions. |

### 6.3 Campaign Control Methods

#### `RunCampaign` (blocking, no timeout)

```powershell
[Nxt.CampaignAction]::RunCampaign([string]$campaignUid)
```

- Runs the campaign and **blocks** until the employee finishes answering.
- `$campaignUid` accepts either UID or NQL ID.
- Returns an `NxTrayResp` object.

#### `RunCampaign` (blocking, with timeout)

```powershell
[Nxt.CampaignAction]::RunCampaign([string]$campaignUid, [int]$timeout)
```

- Same as above, but also stops waiting after `$timeout` **seconds** elapse.
- Returns an `NxTrayResp` object.

#### `RunStandAloneCampaign` (non-blocking)

```powershell
[Nxt.CampaignAction]::RunStandAloneCampaign([string]$campaignUid)
```

- Triggers the campaign and **returns immediately** (does not wait for employee response).
- Useful for informational campaigns where no answer is needed.

#### `GetResponseStatus`

```powershell
[Nxt.CampaignAction]::GetResponseStatus([NxTrayResp]$response)
```

Returns a `string` with one of these status values:

| Status Value | Meaning |
|---|---|
| `fully` | Employee has fully answered all campaign questions. |
| `declined` | Employee declined to participate. |
| `postponed` | Employee agreed to participate (postponed). |
| `timeout` | System timed out the campaign before the employee finished. |
| `connectionfailed` | Script could not connect to the Collector campaign notification component (technical/communication error). |
| `notificationfailed` | Campaign could not be displayed. Possible causes: campaign does not exist, campaign is not published, another campaign is already being displayed, or a non-urgent campaign was blocked by focus protection / do-not-disturb rules. |

#### `GetResponseAnswer`

```powershell
[Nxt.CampaignAction]::GetResponseAnswer([NxTrayResp]$response, [string]$questionLabel)
```

- Returns a `string[]` (string array) of answers for the given question label.
- **Single-answer question:** Array has one element.
- **Multiple-answer question:** Array has as many elements as answers selected. **Optional free text is ignored** (security restriction for self-help scenarios).
- **If status ≠ `fully`:** Array is **empty**.

> **Security note:** For self-help remote actions, optional free text answers from multiple-answer or opinion-scale questions are deliberately ignored.

> **Syntax note:** Class names are case-insensitive — official examples use both `[Nxt.CampaignAction]` and `[nxt.campaignaction]`.

---

## 7. Official Nexthink Library Script Template

The example scripts in the official documentation (and all Nexthink Library remote actions) follow a canonical structure. Use it as the syntax reference for production-grade scripts:

```powershell
#
# Input parameters definition
#
param(
    [Parameter(Mandatory = $true)][string]$input_name
)
# End of parameters definition

$env:Path = 'C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0\'

#
# Constants definition
#
$ERROR_EXCEPTION_TYPE = @{Environment = '[Environment error]'
    Input = '[Input error]'
    Internal = '[Internal error]'
}
Set-Variable -Name 'ERROR_EXCEPTION_TYPE' -Option ReadOnly -Scope Script -Force

$LOCAL_SYSTEM_IDENTITY = 'S-1-5-18'
Set-Variable -Name 'LOCAL_SYSTEM_IDENTITY' -Option ReadOnly -Scope Script -Force

$REMOTE_ACTION_DLL_PATH = "$env:NEXTHINK\RemoteActions\nxtremoteactions.dll"
Set-Variable -Name 'REMOTE_ACTION_DLL_PATH' -Option ReadOnly -Scope Script -Force

#
# Invoke Main
#
function Invoke-Main ([hashtable]$InputParameters) {
    $exitCode = 0
    $outputs = @{ 'output_field' = '-' }   # default value for every output field
    try {
        Add-NexthinkRemoteActionDLL
        Test-RunningAsLocalSystem            # or Test-RunningAsInteractiveUser
        Test-MinimumSupportedOSVersion -WindowsVersion 'Windows10'
        Test-InputParameter -InputParameters $InputParameters

        $outputs = Invoke-MainWork -InputParameters $InputParameters
    } catch {
        Write-StatusMessage -Message $_      # writes to stderr → shown as the execution error message
        $exitCode = 1
    } finally {
        Update-EngineOutputVariables -OutputData $outputs
    }

    return $exitCode
}

# ... template guard/validation helpers (see below) ...

#
# Nexthink Output management
#
function Update-EngineOutputVariables ([hashtable]$OutputData) {
    [Nxt]::WriteOutputString('output_field', $OutputData.output_field)
}

#
# Main script flow
#
[environment]::Exit((Invoke-Main -InputParameters $MyInvocation.BoundParameters))
```

### 7.1 Key Structural Elements

| Element | Detail |
|---|---|
| **Mandatory parameters** | `[Parameter(Mandatory = $true)][string]$name` in the `param()` block. |
| **`$env:Path` hardening** | Reset to the standard system paths so the script never depends on a tampered PATH. |
| **Read-only constants** | Declared with `Set-Variable -Option ReadOnly -Scope Script -Force`. |
| **DLL existence check** | `Test-Path` the DLL before `Add-Type`; throw an `[Environment error]` if missing. |
| **Context guards** | `Test-RunningAsLocalSystem` / `Test-RunningAsInteractiveUser` compare `[security.principal.windowsidentity]::GetCurrent().User` against the Local System SID `S-1-5-18`. |
| **OS guards** | `Test-MinimumSupportedOSVersion` reads `Win32_OperatingSystem` `Version` + `ProductType` (`ProductType -ne 1` = server) to enforce minimum Windows version and workstation/server compatibility. |
| **Input validation** | Helpers such as `Test-StringNullOrEmpty`, `Test-ParamIsInteger`, `Test-ValidPath`, and `Test-CampaignID` (accepts a GUID or the NQL-ID regex `^[#]*([a-zA-Z0-9_]+_)*[a-zA-Z0-9_#]*$`), each throwing typed `[Input error]` messages. |
| **Error typing** | Every `throw` is prefixed with `[Environment error]`, `[Input error]`, or `[Internal error]` from `$ERROR_EXCEPTION_TYPE`. |
| **`Write-StatusMessage`** | Writes failures to **stderr** via `$host.ui.WriteErrorLine`, including script version and line number. |
| **Single output function** | All `WriteOutput*` calls live in one `Update-EngineOutputVariables` function. |
| **Exit pattern** | `[environment]::Exit((Invoke-Main -InputParameters $MyInvocation.BoundParameters))` guarantees the process exit code. |

### 7.2 Outputs on the Error Path

The official examples call `Update-EngineOutputVariables` in the **`finally`** block with pre-set default values, so **every output field is written even when the script fails** (the non-zero exit code still marks the execution as failed). The platform judges success **solely by the exit code**, so writing outputs only on the success path is also accepted — but the `finally` pattern keeps investigations and dashboards free of missing fields. Whichever you choose, the schema must remain static (§4.3).

---

## 8. Script Signing

### 8.1 Why Sign

Nexthink recommends signing all scripts in production. Unsigned scripts should only be used in testing environments. Modifying a signed script invalidates the signature.

### 8.2 Signing Procedure

```powershell
# 1. Obtain a code-signing certificate
# Option A — from the certificate store:
$cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert

# Option B — from a PFX file:
$cert = Get-PfxCertificate -FilePath C:\Test\Mysign.pfx

# 2. Sign the script (with timestamp so it survives certificate expiry)
Set-AuthenticodeSignature -FilePath .\remoteaction.ps1 `
    -Certificate $cert `
    -IncludeChain All `
    -TimestampServer "http://timestamp.digicert.com"

# 3. (Optional) Verify the signature
Get-AuthenticodeSignature .\remoteaction.ps1 -Verbose | fl
```

### 8.3 Certificate Deployment to Endpoints

| Execution Policy | What You Must Do |
|---|---|
| `signed_trusted_or_nexthink` (default) | Nexthink Library scripts work out of the box. For **custom** scripts, add your signing certificate to **Local Computer → Trusted Publishers**. |
| `signed_trusted` (strict) | Either re-sign Library/system scripts with your own certificate, **or** deploy the Nexthink code signing certificate to **Local Computer → Trusted Publishers**. |

**Additional certificate store requirements:**

- If your CA root is **not** already in **Local Computer → Trusted Root Certification Authorities**, add it.
- If you used an **intermediate certificate**, include the full chain in **Local Computer → Intermediate Certification Authorities**.
- Deploy certificates fleet-wide with an administration tool (GPO, Microsoft Intune policy).

> **Error if missing:** *"The remote action could not be executed: the script signature is invalid or the certificate is not trusted."*

### 8.4 Library Updates Overwrite Scripts

Library-pack updates **overwrite the script and all configuration** of a remote action installed from the Nexthink Library, so the action must be **re-signed after every update**. Nexthink recommends against modifying Library-installed and system remote actions in any way other than re-signing.

---

## 9. Error Handling

### 9.1 Exit Codes

| Exit Code | Meaning |
|---|---|
| `0` | Successful execution |
| Non-zero | Error occurred |

Success/failure is determined **solely** by the exit code of the PowerShell process. Unhandled exceptions may terminate the script without returning an appropriate exit code — always use a trap (or the §7 template's try/catch).

### 9.2 Recommended Default Error Trap

Place this immediately after loading the DLL dependencies (and after any `param()` block):

```powershell
trap {
    $host.ui.WriteErrorLine($_.ToString())
    exit 1
}
```

This catches unhandled exceptions and ensures the process returns a non-zero exit code so Nexthink correctly marks the action as failed.

### 9.3 How Errors Surface in the Web Interface

Text written to **stderr** (`$host.ui.WriteErrorLine`, or PowerShell errors) becomes the execution's **error message**. On the remote action details page, failed executions are aggregated under **Top 10 error messages** — hovering over an entry shows the complete message. Write clear, prefixed error messages (see `$ERROR_EXCEPTION_TYPE` in §7) so failures are diagnosable from the UI.

---

## 10. Performance Measurement

Enable debug-level Collector logging to measure script performance and resource consumption:

```
nxtcfg.exe /s logmode=2
```

Output is written to the `nxtcod.log` file.

---

## 11. Script Comparison & Validation (Optional)

Before deploying a custom script, compare it against Nexthink Library reference scripts:

1. In the Nexthink Library, select **Content** → filter by **Remote action**.
2. Navigate to **Remote Actions** management.
3. Select a Library remote action matching your target OS.
4. Export and compare syntax with your script.

Nexthink recommends starting from Library content (install or copy a Library remote action) before creating custom remote actions from scratch.

---

## 12. Platform Context (Configuration Around the Script)

Facts about the surrounding remote action configuration that affect how scripts are triggered and behave:

- **Triggering mechanisms:** **Manual** (web interface), **API**, **Workflow** (Remote action Thinklet), **Schedule** (NQL query at scheduled time), **Spark** (requires granting Spark permission to run the action). On-demand executions (manual/workflow/API) are **prioritized over scheduled** executions.
- **Targeting:** **Devices** or **VDI sessions**. For VDI sessions, choose whether to target the **VDI** device or the **Client** device (Collector must be installed on the client); optionally allow the user to override.
- **Purpose:** Declared as **Data collection** or **Remediation**.
- **Execution status values** (seen when monitoring): `Success`, `Cancelled`, `Old collector`, `No script`, `Expired`, `Failed`, `Waiting on device`.
- **API executions** expire if the targeted device does not come online within `expiresInMinutes` (60–10,080 minutes, i.e., 1 hour–7 days).
- **Security guidance:** [Remote Actions security best practices](https://docs.nexthink.com/security/security-best-practices/remote-actions-security-best-practices).

---

## 13. Quick-Reference Checklist

Use this checklist before uploading any remote action script:

**File & format**
- [ ] Script is encoded as **UTF-8 with BOM** (`EF BB BF`)
- [ ] Line endings are **CR+LF**
- [ ] Script size is **≤ 600 KB**
- [ ] Script is compatible with **Windows PowerShell 5.1** (no PowerShell 7-only features)
- [ ] PowerShell is running in **Full Language Mode** (not Constrained)

**Inputs & outputs**
- [ ] All input parameters are declared in a `param()` block at the top (**≤ 50 inputs**, ≤ 30 KB total)
- [ ] Script validates/converts all inputs — every value arrives as a **string**
- [ ] `nxtremoteactions.dll` is loaded if using any `[Nxt]::WriteOutput*` method
- [ ] All output field names are **predefined strings** (not dynamic); **≤ 50 outputs**
- [ ] Output field count is **fixed** (no loop-generated fields)
- [ ] Each `WriteOutput*` call uses the correct PowerShell type and respects its constraints
- [ ] String outputs are ≤ 1024 bytes
- [ ] DateTime outputs use `DD.MM.YYYY@HH:MM` format
- [ ] Duration outputs are between 0 ms and 49 days
- [ ] UInt32 outputs are between 0 and 4,294,967,295

**Campaigns**
- [ ] `nxtcampaignaction.dll` is loaded if using any `[Nxt.CampaignAction]::` method
- [ ] Campaign IDs are passed as parameters (NQL ID recommended, requires Collector ≥ 23.5)
- [ ] `GetResponseAnswer` return values are handled as `string[]`
- [ ] Free text in campaign answers is understood to be **ignored** in self-help scenarios

**Error handling & context**
- [ ] A `trap` block (or the §7 template's try/catch) guarantees a non-zero exit code on failure
- [ ] Errors are written to **stderr** so they appear as the execution error message in the UI
- [ ] Exit `0` on success, non-zero on failure
- [ ] Execution context chosen: **Local system** (default), **Interactive user**, or **Service** (Windows-only, requires service setup)
- [ ] Script **timeout** (seconds) set in Advanced Configuration with worst-case headroom

**Signing & deployment**
- [ ] Script is **signed** (production) or unsigned is acceptable (testing only)
- [ ] Signing certificate is deployed to **Trusted Publishers** on endpoints
- [ ] Library-installed remote actions are **re-signed after every library update**
