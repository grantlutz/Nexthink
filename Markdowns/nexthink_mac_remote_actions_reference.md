# Nexthink Remote Actions on Mac — Complete Script Component Reference

> **Sources:** [Writing scripts for remote actions on Mac](https://docs.nexthink.com/platform/user-guide/remote-actions/setting-up-and-managing-remote-actions/creating-remote-actions/writing-scripts-for-remote-actions-on-mac) • [Creating and configuring remote actions](https://docs.nexthink.com/platform/user-guide/remote-actions/setting-up-and-managing-remote-actions/creating-remote-actions) • [Monitoring specific remote action executions](https://docs.nexthink.com/platform/user-guide/remote-actions/using-remote-actions/monitoring-specific-remote-action-executions)
>
> **Purpose:** This document lists and describes every output component, input parameter, campaign function, and supporting detail required to write complete, correct remote action scripts for macOS.
>
> **Last verified against Nexthink documentation:** 2026-07-30

---

## Important Limitations & Platform Limits

- Remote actions are **not supported on macOS devices with Mobile Accounts enabled**. An action may appear successful, but no change is actually applied.
- Scripts are written in **Bash** (Zsh is also supported starting with Collector v6.27.2).
- All scripts must be **digitally signed** with `codesign` and packaged as `.tar.gz` for production use. Unsigned scripts should only be used in testing environments.
- **Script size limit:** 600 KB maximum.
- **Input limit:** up to **50 inputs**, maximum **30 KB** total characters.
- **Output limit:** up to **50 outputs** (value limits depend on type — see §3).
- The **Service** execution context is **Windows-only** — macOS remote actions run as local system or interactive user only (see §8).

---

## 1. Script Header (Required)

Every script that writes output must include this header at the top to load the Nexthink output helper functions:

```bash
#!/bin/bash
. "${NEXTHINK}"/bash/nxt_ra_script_output.sh
```

For Zsh scripts (Collector v6.27.2+), use the appropriate shebang:

```bash
#!/bin/zsh
. "${NEXTHINK}"/bash/nxt_ra_script_output.sh
```

> **Note:** Collector checks the first line of the script and executes it with the specified interpreter. A script without a shebang will be executed using Bash by default. Nexthink recommends always using a shebang and the standard interpreters.

---

## 2. Input Parameters

Input parameters allow customization of signed scripts without breaking the digital signature. Declare them between the special Nexthink comments:

```bash
# NXT_PARAMETERS_BEGIN
Parameter1=$1
Parameter2=$2
Parameter3=$3
# NXT_PARAMETERS_END
```

### 2.1 Key Rules

- Parameters are mapped to Bash positional parameters (`$1`, `$2`, `$3`, etc.).
- Actual values are **always passed as text (strings)**. If a parameter expects a non-string type, your script must handle the conversion.
- When uploading, the system parses the parameter block and lists each parameter in the **Parameters** section of the editor.
- Maximum **50 inputs**, **30 KB** total characters.

### 2.2 How Parameters Appear in the Web UI

For each detected parameter, the remote action editor exposes:

| Field | Behavior |
|---|---|
| **Name** | The label shown to the user when the system asks for a parameter value. |
| **Description** | A meaningful description of the parameter. |
| **Value** | List of permitted values, **one per line**. At least one value is required. **The first line is the default.** |
| **Allow the user to enter a custom value** | Optional toggle letting users supply a value not in the list. |

Design your parameter mapping and in-script validation with this in mind: values always arrive as strings, may come from a fixed list or free entry, and empty/invalid values must be handled by the script.

---

## 3. Output Write Methods (Complete List)

All write methods accept **two arguments**: the **name** of the output (a string) and the **value** to write. The editor recognizes the calls and lists them under **Outputs**; set each output's label to control how it appears in investigations and metrics. Maximum **50 outputs**.

**Syntax pattern:**

```bash
nxt_write_output_<type> '<OutputFieldName>' "$variable"
```

**Example:**

```bash
nxt_write_output_uint32 'FileNumber' $nfiles
```

### 3.1 `nxt_write_output_string`

| Attribute    | Detail                                          |
|--------------|--------------------------------------------------|
| **Method**   | `nxt_write_output_string`                        |
| **Data Type**| String / Text                                    |
| **Constraints** | 0–1024 bytes. Output is **truncated** if larger. |
| **Use Case** | Free-text values, paths, names, status messages. |

**Example:**

```bash
nxt_write_output_string 'DeviceName' "$hostname"
```

---

### 3.2 `nxt_write_output_bool`

| Attribute    | Detail                           |
|--------------|----------------------------------|
| **Method**   | `nxt_write_output_bool`          |
| **Data Type**| Boolean                          |
| **Constraints** | Accepts only: `true` / `false` |
| **Use Case** | Binary status flags (enabled/disabled, compliant/non-compliant). |

**Example:**

```bash
nxt_write_output_bool 'IsCompliant' true
```

---

### 3.3 `nxt_write_output_uint32`

| Attribute    | Detail                                |
|--------------|----------------------------------------|
| **Method**   | `nxt_write_output_uint32`              |
| **Data Type**| Unsigned 32-bit integer                |
| **Constraints** | Min: `0` · Max: `4,294,967,295`    |
| **Use Case** | Counts, quantities, version numbers, non-negative whole numbers. |

**Example:**

```bash
nxt_write_output_uint32 'FileCount' $nfiles
```

---

### 3.4 `nxt_write_output_float`

| Attribute    | Detail                                    |
|--------------|-------------------------------------------|
| **Method**   | `nxt_write_output_float`                   |
| **Data Type**| Floating-point number                      |
| **Constraints** | Min: `-3.4E+38` · Max: `3.4E+38`       |
| **Use Case** | Percentages, measurements, decimal values. |

**Example:**

```bash
nxt_write_output_float 'CpuUsage' $cpu_pct
```

---

### 3.5 `nxt_write_output_size`

| Attribute    | Detail                                       |
|--------------|-----------------------------------------------|
| **Method**   | `nxt_write_output_size`                        |
| **Data Type**| Size (interpreted as bytes by the platform)    |
| **Constraints** | Min: `0` · Max: `3.4E+38`                  |
| **Use Case** | Disk space, file sizes, memory usage.          |

**Example:**

```bash
nxt_write_output_size 'FreeDiskSpace' $free_bytes
```

---

### 3.6 `nxt_write_output_ratio`

| Attribute    | Detail                                  |
|--------------|-----------------------------------------|
| **Method**   | `nxt_write_output_ratio`                 |
| **Data Type**| Ratio (numeric)                          |
| **Constraints** | No explicit min/max documented.       |
| **Use Case** | Proportional values, ratios, rates.      |

**Example:**

```bash
nxt_write_output_ratio 'CompressionRatio' $ratio
```

---

### 3.7 `nxt_write_output_bitrate`

| Attribute    | Detail                                  |
|--------------|-----------------------------------------|
| **Method**   | `nxt_write_output_bitrate`               |
| **Data Type**| Bitrate (numeric)                        |
| **Constraints** | No explicit min/max documented.       |
| **Use Case** | Network throughput, bandwidth measurements. |

**Example:**

```bash
nxt_write_output_bitrate 'NetworkSpeed' $speed_bps
```

---

### 3.8 `nxt_write_output_duration`

| Attribute    | Detail                                                 |
|--------------|--------------------------------------------------------|
| **Method**   | `nxt_write_output_duration`                             |
| **Data Type**| Duration (in milliseconds)                              |
| **Constraints** | Min: `0 ms` · Max: `49 days` · Precision: milliseconds |
| **Use Case** | Elapsed times, boot times, response times.              |

**Example:**

```bash
nxt_write_output_duration 'BootTime' $boot_ms
```

---

### 3.9 `nxt_write_output_date_time`

| Attribute    | Detail                                       |
|--------------|-----------------------------------------------|
| **Method**   | `nxt_write_output_date_time`                   |
| **Data Type**| Date and time                                  |
| **Constraints** | **Input: Epoch time (integer, seconds)** · Stored/displayed as `YYYY-MM-DD HH:MM:SS` |
| **Use Case** | Timestamps, last-updated dates, event times.   |

**Example:**

```bash
nxt_write_output_date_time 'LastUpdate' "$(date +%s)"
```

> ⚠ **Correction (verified against current docs):** the value passed to this function must be an **epoch-time integer**, not a formatted date string. `YYYY-MM-DD HH:MM:SS` is the format Nexthink *stores and displays*, not the input format. Do not pass strings like `"2025-04-14 10:30:00"`.

---

### 3.10 `nxt_write_output_string_list`

| Attribute    | Detail                                          |
|--------------|--------------------------------------------------|
| **Method**   | `nxt_write_output_string_list`                    |
| **Data Type**| List of strings                                   |
| **Constraints** | 0–1024 bytes per string. Output is **truncated** if larger (same constraints as `nxt_write_output_string`). |
| **Use Case** | Lists of items (installed apps, user groups, tags). |

**Example:**

```bash
nxt_write_output_string_list 'InstalledBrowsers' "$browser_list"
```

---

## 4. Output Field Definition Rules

When developing scripts, you **must** follow these rules:

1. **Predefine the names of all output fields.** The script must populate the correct fields in the output table. Without predefined field names the script may fail due to an unknown output schema.
   - Output field names must always be provided as **strings** (quoted).
   - Example: `nxt_write_output_string 'output_field_name' "$output_value"`

2. **Define a fixed number of output fields.** Your script must always specify the same set of output fields on every execution.
   - **Do not** use dynamic fields. Dynamic output structures cause inconsistency and potential processing errors.
   - **Do not** use loops to define output fields at runtime.

---

## 5. Campaign Functions (Complete List)

Campaign functions let remote actions trigger interactive campaigns on employee devices. They require the Nexthink script header to be loaded.

### 5.1 Display Requirements

- The campaign must have a **Remote action** trigger and be **published**.
- The script can run either as the **interactive user** (no special privileges needed) or as **local system** (administrative privileges needed) — campaigns can be displayed from both contexts (see §8).

### 5.2 Campaign Identifier

Campaign functions require a campaign identifier, which can be either:

- **NQL ID** (recommended; requires Collector v23.5+)
- **Campaign UID** (classic option)

Pass the identifier as a script parameter:

```bash
# NXT_PARAMETERS_BEGIN
CampaignId=$1
# NXT_PARAMETERS_END
```

---

### 5.3 `nxt_run_campaign`

```bash
nxt_run_campaign( id )
```

| Attribute     | Detail |
|---------------|--------|
| **Behavior**  | Runs the campaign matching the given NQL ID or UID and saves the answers internally. **Blocks** execution until the employee completes or dismisses the campaign. |
| **Returns `0`** | Campaign status was received. |
| **Returns `1`** | All other cases; error is reported in logs. |

---

### 5.4 `nxt_run_campaign_with_timeout`

```bash
nxt_run_campaign_with_timeout( id timeout )
```

| Attribute     | Detail |
|---------------|--------|
| **Behavior**  | Runs the campaign with a timeout in seconds (`0 < T < 1 week`). **Blocks** execution until the employee completes, dismisses, or the timeout expires. |
| **Returns `0`** | Campaign status was received. |
| **Returns `1`** | All other cases; error is reported in logs. |

---

### 5.5 `nxt_run_standalone_campaign`

```bash
nxt_run_standalone_campaign( id )
```

| Attribute     | Detail |
|---------------|--------|
| **Behavior**  | Triggers the campaign and **continues script execution immediately** without waiting for the employee's response. The employee can dismiss the campaign at any point. |
| **Returns `0`** | Campaign status was received. |
| **Returns `1`** | All other cases; error is reported in logs. |
| **Use Case**  | Informational campaigns that don't require user input. |

---

### 5.6 `nxt_get_campaign_status`

```bash
nxt_get_campaign_status( res_var )
```

| Attribute     | Detail |
|---------------|--------|
| **Behavior**  | Extracts the status of the last campaign and stores it in `res_var`. |
| **Returns `0`** | Status stored successfully. |
| **Returns `1`** | Otherwise. |

**Possible status values stored in `res_var`:**

| Status               | Meaning |
|----------------------|---------|
| `fully`              | Employee fully answered all campaign questions. |
| `timeout`            | Campaign timed out before the user finished. |
| `postponed`          | Employee agreed to participate (postponed for later). |
| `declined`           | Employee declined to participate. |
| `connectionfailed`   | Script was unable to connect to the Collector component that controls campaign notifications. |
| `notificationfailed` | Campaign could not be displayed. Possible reasons: campaign definition not found (non-existent or unpublished), another campaign is already being displayed, or a non-urgent campaign was blocked by focus protection / do-not-disturb rules. |
| *(empty)*            | The last campaign failed. |

---

### 5.7 `nxt_get_response_answer`

```bash
nxt_get_response_answer( res_var question_key )
```

| Attribute     | Detail |
|---------------|--------|
| **Behavior**  | Queries the last campaign using a question label (`question_key`) and stores the answer in `res_var`. |
| **Returns `0`** | Answer stored successfully. |
| **Returns `1`** | Otherwise. |

> **Note:** Answers are represented by their corresponding numbered option. Bash arrays are 0-indexed; Zsh arrays are 1-indexed.

---

## 6. Code Examples

> ⚠ **Correction:** the official documentation's examples contain a Bash bug — they test `[[ status == "fully" ]]` (the literal word `status`, always false). The examples below use the correct form `[[ "$status" == "fully" ]]`.

### 6.1 Calling a Campaign

```bash
if nxt_run_campaign "#my_campaign_nql_id"; then
    nxt_get_campaign_status status
    if [[ "$status" == "fully" ]]; then
        echo "Campaign succeeded"
    else
        echo "Status is $status"
    fi
else
    echo "Campaign failed"
fi
```

### 6.2 Accessing Campaign Responses

```bash
nxt_get_campaign_status status
echo "The response status is $status"
nxt_get_response_answer answersArray key1
echo ${answersArray[1]}
```

### 6.3 Running a Campaign with Timeout

```bash
# timeout is in seconds (100s or 00:01:40)
if nxt_run_campaign_with_timeout "#my_campaign_nql_id" 100; then
    nxt_get_campaign_status status
    if [[ "$status" == "fully" ]]; then
        echo "Campaign succeeded"
    else
        echo "Status is $status"
    fi
else
    echo "Campaign failed"
fi
```

### 6.4 Running a Non-Blocking (Standalone) Campaign

```bash
if nxt_run_standalone_campaign "#my_campaign_nql_id"; then
    nxt_get_campaign_status status
    if [[ "$status" == "fully" ]]; then
        echo "Campaign succeeded"
    else
        echo "Status is $status"
    fi
else
    echo "Campaign failed"
fi
```

---

## 7. Script Encoding Requirements

| Requirement | Detail |
|-------------|--------|
| **Character encoding** | UTF-8, **without BOM** |
| **Line endings** | `LF` (Unix-style) — not `CRLF` |

Incorrect encoding will cause errors or non-functioning scripts.

---

## 8. Execution Context, Timeout & Subprocesses

### 8.1 Execution Context (Advanced Configuration)

| Context | When to Use |
|---|---|
| **Local system user** (default) | Tasks requiring system rights — e.g., modifying system configuration, reading system-wide settings. |
| **Interactive user** (logged-in employee) | Actions tied to a specific user — e.g., reading *their* files or preferences, displaying campaigns that interact with the user. Run as local system, such actions would act on the system account instead. |

> The third context offered in the web interface, **Service**, is **Windows-only** and cannot be used for macOS remote actions.

### 8.2 Script Timeout

- The timeout is set **in seconds** in the remote action's Advanced Configuration.
- If the script does not complete within the allotted time, **the system terminates it**.
- Budget for the worst-case device (slow disk, campaign wait times) when choosing the value.

### 8.3 Subprocess Termination

When a remote action script terminates or times out, Collector **automatically terminates** all subprocesses. To let a subprocess survive after the script ends, detach it:

```bash
some_script.sh -arg1 -arg2 &
```

---

## 9. Exit Codes & Error Surfacing

| Exit Code | Meaning |
|---|---|
| `0` | Successful execution |
| Non-zero | Error occurred |

- The platform judges success/failure **solely by the script's exit code** — always exit `0` on success and non-zero on failure, and guard against early termination paths that could exit without a meaningful code.
- Text written to **stderr** becomes the execution's **error message**. On the remote action details page, failed executions are aggregated under **Top 10 error messages** — hovering over an entry shows the complete message. Write clear error messages to stderr so failures are diagnosable from the UI.
- Campaign and script errors are also logged locally at `/Library/Logs/nxtcod.log` (path may vary according to your file structure).

---

## 10. Script Signing & Packaging

### 10.1 Why Sign, and Why `.tar.gz`

- Nexthink **requires** Bash scripts for macOS remote actions to be digitally signed with `codesign` for production. Unsigned scripts should only be used in testing environments.
- `codesign` stores the signature in the file's **extended attributes**. Packing the script as `.tar.gz` **preserves those extended attributes** — this is why the Nexthink web interface only accepts `.tar.gz` files when importing macOS remote action scripts.
- **Keychain guidance:** sign with certificates stored in the **login.keychain**. Certificates in the System.keychain may fail due to restricted private-key access, especially in automated or non-interactive environments.

### 10.2 Signing with `codesign`

```bash
codesign -s <identity> --timestamp --prefix=<prefix> --force <script.sh>
```

| Parameter | Purpose |
|-----------|---------|
| `-s <identity>` | Certificate subject common name or certificate hash from Keychain. |
| `--timestamp` | Adds a trusted timestamp to the signature. |
| `--prefix=<prefix>` | Prefix for the code signature identifier (e.g., `com.myorg.remote-action.macos.`). Makes the identifier unique. |
| `--force` | Rewrites the code signature if one already exists. |

**Example:**

```bash
codesign -s "RA scripts code signing certificate" --timestamp \
  --prefix=com.my-organisation.remote-action.macos. --force example_ra_script.sh
```

### 10.3 Packaging as `.tar.gz`

```bash
tar -czvf ./example_ra_script.tar.gz ./example_ra_script.sh
```

**Packaging rules:**

- The extension **must** be `.tar.gz`.
- Only **one script** per archive.
- The script must be in the **root** of the archive (not in a subdirectory — `./myscript/myscript.sh` is incorrect).
- The script must have the `.sh` extension.
- The script filename must be UTF-8 encoded.

**Sign + package in one step:** Nexthink provides a helper script (`script_signing.sh`, in the official docs) that runs `codesign` and `tar` together. Usage: `./script_signing.sh script.sh script.tar.gz "<Certificate Owner>" com.myorg.remote-action.macos.`

### 10.4 Verifying a Signature

**Option 1 — System Certificate Store (anchor trusted):**

```bash
codesign -vvvv -R="anchor trusted" example_ra_script.sh
```

**Option 2 — Certificate Pinning (certificate leaf trusted):**

```bash
codesign -vvvv -R="certificate leaf trusted" example_ra_script.sh
```

### 10.5 Signature Validation Approaches

Nexthink supports two approaches for validating signed scripts on macOS (plus one deprecated approach). Certificate pinning removes the dependency on macOS certificate trust and is more robust as Apple evolves its security model.

#### Approach A — Certificate Pinning (recommended by Nexthink; Collector ≥ 2025.9.1.x)

- Collector runs a script only if its **leaf certificate's SHA-256 fingerprint** matches the `cert_fingerprints` Collector installer option (comma-separated allow list, no spaces).
- Execution policies: `signed_pinned` and `signed_pinned_or_nexthink` (the latter always allows Nexthink Library scripts).
- **No certificate deployment to endpoints is required** — only the `cert_fingerprints` installer option.
- Any type of code-signing certificate is supported (Apple Developer, Certificate Assistant, private or public Root CA, etc.).
- Nexthink provides an extraction script in the docs (`codesign -d --extract-certificates` + `openssl x509 -fingerprint -sha256`) to obtain a signed script's leaf-certificate thumbprint.

#### Approach B — System Certificate Store (not recommended by Nexthink)

- ⚠ **macOS Sequoia (15) and later:** deploy the **Root CA of the signing certificate** to endpoints — deploying the signing certificate itself (as on Windows) no longer works, and **pre-installed public Root CAs will not work** either.
- Root-CA-based trusted-source validation requires **Collector Cloud ≥ 24.10.2.10** or **Collector on-prem ≥ 24.10.30.26**.
- Deploy the Root CA fleet-wide via configuration profiles (e.g., JAMF); it is marked trusted automatically.
- When testing on the machine where the Root CA was generated, copy the Root CA into the **System** keychain (`sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain Certificate.cer`) and mark it trusted.
- Verify on the endpoint with `codesign -vvvv -R="anchor trusted"`.

#### Approach C — Direct signing-certificate trust (deprecated)

- The pre-Sequoia approach: import the signing certificate itself into the endpoint's System keychain as trusted. **Not compatible with macOS Sequoia and newer**, and requires user interaction. Verify with `codesign -vvvv -R="certificate leaf trusted"`.

### 10.6 Execution Policies Summary (Collector ≥ 2025.9.1.x)

| Policy | Unsigned Scripts | Nexthink Library RA Scripts | Other Signed Scripts | `cert_fingerprints` Effect |
|--------|------------------|-----------------------------|----------------------|----------------------------|
| `signed_trusted` | Blocked | Blocked | Allowed if signed by trusted cert | No effect |
| `signed_trusted_or_nexthink` | Blocked | Always allowed | Allowed if signed by trusted cert | No effect |
| `signed_pinned` | Blocked | Allowed only if thumbprint is in allow list | Allowed only if thumbprint is in allow list | **Required** |
| `signed_pinned_or_nexthink` | Blocked | Always allowed | Allowed only if thumbprint is in allow list | **Required** |

> The `cert_fingerprints` installer option defines an allow list of **SHA-256 leaf-certificate** thumbprints (comma-separated, no spaces). It only applies to the `signed_pinned` and `signed_pinned_or_nexthink` policies.

### 10.7 Library Updates Overwrite Scripts

Library-pack updates **overwrite the script and all configuration** of a remote action installed from the Nexthink Library, so the action must be **re-signed (and re-packaged) after every update**. Nexthink recommends against modifying Library-installed and system remote actions in any way other than re-signing.

---

## 11. Script Comparison & Validation (Optional)

Before deploying a custom script, compare it against Nexthink Library reference scripts:

1. In the Nexthink Library, select **Content** → filter by **Remote action**.
2. Navigate to **Remote Actions** management.
3. Select a Library remote action matching the target OS (macOS).
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
- **More resources:** [Remote Actions security best practices](https://docs.nexthink.com/security/security-best-practices/remote-actions-security-best-practices) • [Remote actions group in Nexthink Community](https://community.nexthink.com/s/group/0F92p000000kI80CAE).

---

## 13. Quick-Reference: All Output Methods at a Glance

| # | Method | Type | Constraints |
|---|--------|------|-------------|
| 1 | `nxt_write_output_string` | String | 0–1024 bytes (truncated if larger) |
| 2 | `nxt_write_output_bool` | Boolean | `true` / `false` |
| 3 | `nxt_write_output_uint32` | Unsigned 32-bit int | 0 – 4,294,967,295 |
| 4 | `nxt_write_output_float` | Float | -3.4E+38 – 3.4E+38 |
| 5 | `nxt_write_output_size` | Size (bytes) | 0 – 3.4E+38 |
| 6 | `nxt_write_output_ratio` | Ratio | *(no explicit limits documented)* |
| 7 | `nxt_write_output_bitrate` | Bitrate | *(no explicit limits documented)* |
| 8 | `nxt_write_output_duration` | Duration (ms) | 0 ms – 49 days; precision: ms |
| 9 | `nxt_write_output_date_time` | DateTime | **Input: epoch seconds (integer)**; stored as `YYYY-MM-DD HH:MM:SS` |
| 10 | `nxt_write_output_string_list` | String list | 0–1024 bytes per string (truncated if larger) |

---

## 14. Quick-Reference: All Campaign Functions at a Glance

| # | Function | Blocking? | Returns |
|---|----------|-----------|---------|
| 1 | `nxt_run_campaign( id )` | Yes — waits for completion or dismissal | 0 = status received; 1 = error |
| 2 | `nxt_run_campaign_with_timeout( id timeout )` | Yes — waits up to `timeout` seconds (0 < T < 1 week) | 0 = status received; 1 = error |
| 3 | `nxt_run_standalone_campaign( id )` | No — fires and continues | 0 = status received; 1 = error |
| 4 | `nxt_get_campaign_status( res_var )` | N/A — reads last status | 0 = success; 1 = failure |
| 5 | `nxt_get_response_answer( res_var question_key )` | N/A — reads last answer | 0 = success; 1 = failure |

---

## 15. Quick-Reference Checklist

Use this checklist before uploading any macOS remote action script:

**File & format**
- [ ] Script is encoded as **UTF-8 without BOM**
- [ ] Line endings are **LF** (not CRLF)
- [ ] Shebang present: `#!/bin/bash` or `#!/bin/zsh` (Zsh requires Collector ≥ 6.27.2)
- [ ] Header sources the output helpers if writing outputs: `. "${NEXTHINK}"/bash/nxt_ra_script_output.sh`
- [ ] Script has the `.sh` extension and a UTF-8 filename
- [ ] Script size is **≤ 600 KB**
- [ ] Target devices do **not** use Mobile Accounts

**Inputs & outputs**
- [ ] Parameters declared between `# NXT_PARAMETERS_BEGIN` / `# NXT_PARAMETERS_END`, mapped to `$1`, `$2`, … (**≤ 50 inputs**, ≤ 30 KB total)
- [ ] Script validates/converts all inputs — every value arrives as a **string**
- [ ] All output field names are **predefined quoted strings** (not dynamic); **≤ 50 outputs**
- [ ] Output field count is **fixed** (no loop-generated fields)
- [ ] Each `nxt_write_output_*` call uses the correct type and respects its constraints
- [ ] String outputs are ≤ 1024 bytes (per string, including list elements)
- [ ] **`nxt_write_output_date_time` receives epoch seconds** (e.g., `$(date +%s)`), not a formatted string
- [ ] Duration outputs are between 0 ms and 49 days; UInt32 outputs between 0 and 4,294,967,295

**Campaigns**
- [ ] Campaign IDs are passed as parameters (NQL ID recommended, requires Collector ≥ 23.5)
- [ ] Campaign has a **Remote action** trigger and is **published**
- [ ] Status comparisons quote the variable: `[[ "$status" == "fully" ]]`
- [ ] Campaign timeouts are within `0 < T < 1 week`; array indexing accounts for Bash (0-based) vs. Zsh (1-based)

**Execution & error handling**
- [ ] Execution context chosen: **Local system** (default) or **Interactive user** (Service is Windows-only)
- [ ] Script **timeout** (seconds) set in Advanced Configuration with worst-case headroom
- [ ] Subprocesses detached with `&` **only** if they must survive script termination (Collector kills the rest)
- [ ] Exit `0` on success, non-zero on failure; errors written to **stderr** so they appear in execution details

**Signing & packaging**
- [ ] Script **signed** with `codesign -s <identity> --timestamp --prefix=<prefix> --force` using a **login.keychain** certificate (production; unsigned = testing only)
- [ ] Packaged as **`.tar.gz`** — one script, at archive root (preserves the signature's extended attributes)
- [ ] Trust path in place: `cert_fingerprints` SHA-256 allow list (pinning, recommended) **or** Root CA deployed to endpoints (required form on macOS Sequoia 15+)
- [ ] Library-installed remote actions are **re-signed and re-packaged after every library update**
