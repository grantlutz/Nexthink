<#
.SYNOPSIS
    Nexthink Remote Action — Uninstall the Tanium Client and report exactly
    what was removed.

.DESCRIPTION
    Removes the Tanium Client from a Windows device in four ordered stages,
    then verifies the result by re-reading the device rather than trusting the
    individual operations:

      1. Stop Tanium processes (force).
      2. Stop Tanium services (force).
      3. Run the vendor uninstaller silently, if it is present.
      4. Remove the install directory and Tanium registry keys, each gated by
         its own parameter so the destructive stages can be disabled.

    The install directory size is measured BEFORE removal so SpaceReclaimed
    reports a real number, and the directory is re-tested afterwards so the
    reported result reflects what is actually on disk.

    Individual failures do not abort the run — the script continues to the next
    item so a single locked file cannot leave the device half-processed without
    a report. If anything essential is still present at the end,
    TaniumStillPresent is true and the action exits 1.

    ⚠ This action is destructive and irreversible. See the safety flag block
    below.

.PARAMETER TaniumInstallPath
    Full path to the Tanium install directory.
    Default: 'C:\Program Files (x86)\Tanium'.
    Must be an absolute path. As a guard against catastrophic mistargeting the
    script REFUSES paths shorter than 4 characters, drive roots (such as 'C:\'),
    and the Windows, System32, Program Files and Program Files (x86) roots
    themselves.

.PARAMETER RemoveInstallDirectory
    'true' or 'false'. When 'true' (default) the install directory is deleted
    recursively after the uninstaller runs. Set to 'false' to stop the services
    and run the uninstaller without deleting leftover files.

.PARAMETER RemoveRegistryKeys
    'true' or 'false'. When 'true' (default) the Tanium registry keys are
    deleted. Set to 'false' to leave the registry untouched.

.OUTPUTS
    Nexthink output fields (auto-detected from the [Nxt]::WriteOutput* calls;
    the schema is fixed at 9 fields, written as the script's final step once
    all results have been gathered):

    ProcessesStopped        (UInt32)  Tanium processes force-stopped.
    ServicesStopped         (UInt32)  Tanium services force-stopped.
    UninstallerExecuted     (Bool)    True when the vendor uninstaller was
                                      found and ran to completion.
    InstallDirectoryRemoved (Bool)    True when the install directory is gone
                                      after the run (verified by re-testing
                                      the path).
    RegistryKeysRemoved     (UInt32)  Tanium registry keys deleted and
                                      verified as gone.
    SpaceReclaimed          (Size)    Bytes freed, measured from the install
                                      directory before removal.
    TaniumStillPresent      (Bool)    True when the install directory or any
                                      targeted registry key still exists.
    ExecutionTime           (String)  Completion time of the run, formatted
                                      "yyyy-MM-dd HH:mm:ss".
    ExecutionSummary        (String)  Stage outcomes joined with " | ";
                                      "No actions performed." if none.

    Notes on output values:
    - SpaceReclaimed is the on-disk size of the install directory measured
      before deletion. [Math]::Abs preserves the magnitude of any anomalous
      negative length value — the number is kept, only the sign dropped. The
      [math]::Max(0, ...) at write time is a defensive type guard only; values
      are already non-negative, so it never changes a real number. The value is
      reported only when the directory is verified as removed; a failed removal
      reports 0 because nothing was actually reclaimed.
    - InstallDirectoryRemoved and RegistryKeysRemoved are verified by
      re-testing each path after deletion, not by the return of Remove-Item.
    - TaniumStillPresent is the field to alert on: false means the device is
      clean, true means manual remediation is needed.
    - On an unhandled error the trap reports the error message to Nexthink and
      exits 1, marking the action as failed; outputs are not written in that
      case.

.NOTES
    Version           : 1  (iterate the -v<N> filename suffix on each change)
                        v1: initial Nexthinkified version of the raw
                            uninstall_tanium.ps1 (kept unmodified in
                            uninstall_tanium.ps1). Adds input parameters with
                            path guards, a deterministic 9-field output schema,
                            post-removal verification, and size measurement.
                            Replaces Start-Transcript and coloured Write-Host
                            output, which suit interactive use rather than an
                            unattended remote action.
    Execution context : Local System (REQUIRED). Stopping services, running the
                        uninstaller, and writing to HKLM all need
                        administrative privileges.
    Encoding          : UTF-8 with BOM, CRLF line endings (Nexthink requirement).
    Signing           : Sign with a code-signing certificate before production
                        use; deploy the certificate to Trusted Publishers on
                        endpoints.
    Timeout           : The vendor uninstaller dominates the runtime and is
                        capped at 300 seconds by the script. A 600-second
                        remote action timeout gives comfortable headroom.
    Environment       : Process names, service names, install path and registry
                        keys reflect one Tanium version in one environment.
                        VERIFY EACH AGAINST YOUR OWN DEVICES before deploying —
                        a mismatch means the script silently does less than
                        expected.
#>

# =============================================================================
# ⚠ NEXTHINK SAFETY FLAG — REVIEW BEFORE DEPLOYMENT
#
# This script performs destructive, IRREVERSIBLE actions BY DESIGN. They are
# intentional, are NOT removed, and are individually flagged inline:
#
#   1. PERMANENT RECURSIVE DELETION OF THE INSTALL DIRECTORY: the entire
#      TaniumInstallPath tree is deleted with -Recurse -Force. Deletion is
#      irreversible and includes any local logs, configuration, or content
#      staged under that path.
#      Impact: anything stored under the path is lost. If the parameter is
#      pointed at the wrong directory, THAT directory is destroyed instead —
#      the script guards against drive roots and well-known system paths, but
#      it cannot know which application directory you meant.
#
#   2. PERMANENT DELETION OF REGISTRY KEYS: four HKLM keys are deleted with
#      -Recurse -Force, including two CurrentControlSet\Services entries.
#      Impact: irreversible without a registry backup or system restore.
#      Removing service entries affects the device's service configuration.
#
#   3. LOSS OF ENDPOINT MANAGEMENT AND VISIBILITY: removing the Tanium Client
#      removes the management, patching, and visibility that agent provides.
#      Impact: the device drops out of Tanium reporting and can no longer be
#      managed or remediated through it. Confirm the device is covered another
#      way, and that removal is genuinely intended, before targeting.
#
#   4. FORCED PROCESS AND SERVICE TERMINATION: processes and services are
#      stopped with -Force, without waiting for graceful shutdown.
#      Impact: in-flight Tanium operations are aborted; forced termination can
#      leave partially written files behind.
#
# TARGET NARROWLY. This action cannot be undone by re-running it.
# =============================================================================

#
# Input parameters definition
#
param(
    [string]$TaniumInstallPath = 'C:\Program Files (x86)\Tanium',
    [string]$RemoveInstallDirectory = 'true',
    [string]$RemoveRegistryKeys = 'true'
)
# End of parameters definition

# Nexthink remote action output library — required for all [Nxt]::WriteOutput* calls.
Add-Type -Path "$env:NEXTHINK\RemoteActions\nxtremoteactions.dll"

# Default error trap: report the error to Nexthink and exit non-zero so the
# remote action is marked as failed.
trap {
    $host.ui.WriteErrorLine($_.ToString())
    exit 1
}

# All output values, initialized to safe defaults and populated as the script runs.
$script:Outputs = @{
    'ProcessesStopped'        = [uint32]0
    'ServicesStopped'         = [uint32]0
    'UninstallerExecuted'     = $false
    'InstallDirectoryRemoved' = $false
    'RegistryKeysRemoved'     = [uint32]0
    'SpaceReclaimed'          = 0
    'TaniumStillPresent'      = $false
    'ExecutionTime'           = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

$script:SummaryLines = @()

# Tanium components targeted by this action. Verify against your own devices.
$taniumProcesses = @(
    'TaniumClient',
    'TaniumEndpointIndex',
    'TPython',
    'TaniumCX',
    'TaniumDetectEngine',
    'TaniumDriverSvc'
)

$taniumServices = @(
    'Tanium Client',
    'Tanium Index',
    'Tanium Detect',
    'TaniumRecorderDrv',
    'TaniumClientBootstrap'
)

$taniumRegistryKeys = @(
    'HKLM:\SYSTEM\CurrentControlSet\Services\TaniumRecorderDrv',
    'HKLM:\SYSTEM\CurrentControlSet\Services\TaniumClientBootstrap',
    'HKLM:\SOFTWARE\WOW6432Node\Tanium',
    'HKLM:\SOFTWARE\Tanium'
)

# Paths this script must never delete, whatever the parameter says.
$protectedPaths = @(
    $env:SystemDrive,
    "$env:SystemDrive\",
    $env:WINDIR,
    "$env:WINDIR\System32",
    $env:ProgramFiles,
    ${env:ProgramFiles(x86)},
    $env:ProgramData
)

$UNINSTALLER_TIMEOUT_SECONDS = 300

#
# Input parameter validation — every value arrives from Nexthink as text.
#
$installPath = $TaniumInstallPath.Trim().TrimEnd('\')

if ([string]::IsNullOrWhiteSpace($installPath)) {
    throw "[Input error] 'TaniumInstallPath' cannot be empty."
}

if (-not [System.IO.Path]::IsPathRooted($installPath)) {
    throw "[Input error] 'TaniumInstallPath' must be an absolute path. Received: '$TaniumInstallPath'."
}

# Guard against catastrophic mistargeting: refuse drive roots, very short
# paths, and well-known system directories.
if ($installPath.Length -lt 4) {
    throw "[Input error] 'TaniumInstallPath' is too short to be a valid application directory: '$TaniumInstallPath'."
}

foreach ($protected in $protectedPaths) {
    if (-not [string]::IsNullOrWhiteSpace($protected)) {
        if ($installPath -eq $protected.TrimEnd('\')) {
            throw "[Input error] Refusing to operate on the protected system path '$installPath'."
        }
    }
}

$removeDirectory = $null
switch ($RemoveInstallDirectory.Trim().ToLower()) {
    'true'  { $removeDirectory = $true }
    'false' { $removeDirectory = $false }
    default { throw "[Input error] 'RemoveInstallDirectory' must be 'true' or 'false'. Received: '$RemoveInstallDirectory'." }
}

$removeRegistry = $null
switch ($RemoveRegistryKeys.Trim().ToLower()) {
    'true'  { $removeRegistry = $true }
    'false' { $removeRegistry = $false }
    default { throw "[Input error] 'RemoveRegistryKeys' must be 'true' or 'false'. Received: '$RemoveRegistryKeys'." }
}

$uninstallerPath = Join-Path $installPath 'Tanium Client\uninst.exe'

#
# Stage 1 — Stop Tanium processes
#
$processesStopped = 0
foreach ($processName in $taniumProcesses) {
    $processes = @(Get-Process -Name $processName -ErrorAction SilentlyContinue)
    if ($processes.Count -eq 0) { continue }

    try {
        #
        # ⚠ NEXTHINK SAFETY FLAG: forced process termination — aborts any
        # in-flight Tanium operation without a graceful shutdown.
        #
        $processes | Stop-Process -Force -ErrorAction Stop
        $processesStopped += $processes.Count
    } catch {
        $script:SummaryLines += ("Process {0}: failed to stop - {1}" -f $processName, $_.Exception.Message)
    }
}
$script:Outputs['ProcessesStopped'] = [uint32]$processesStopped
if ($processesStopped -gt 0) {
    $script:SummaryLines += ("Processes stopped: {0}" -f $processesStopped)
}

#
# Stage 2 — Stop Tanium services
#
$servicesStopped = 0
foreach ($serviceName in $taniumServices) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($null -eq $service) { continue }
    if ($service.Status -eq 'Stopped') { continue }

    try {
        #
        # ⚠ NEXTHINK SAFETY FLAG: forced service stop — also stops any
        # dependent services.
        #
        Stop-Service -Name $serviceName -Force -ErrorAction Stop
        $service.Refresh()
        if ($service.Status -eq 'Stopped') {
            $servicesStopped += 1
        } else {
            $script:SummaryLines += ("Service {0}: still {1} after stop attempt" -f $serviceName, $service.Status)
        }
    } catch {
        $script:SummaryLines += ("Service {0}: failed to stop - {1}" -f $serviceName, $_.Exception.Message)
    }
}
$script:Outputs['ServicesStopped'] = [uint32]$servicesStopped
if ($servicesStopped -gt 0) {
    $script:SummaryLines += ("Services stopped: {0}" -f $servicesStopped)
}

#
# Stage 3 — Run the vendor uninstaller
#
if (Test-Path -Path $uninstallerPath -PathType Leaf) {
    try {
        #
        # ⚠ NEXTHINK SAFETY FLAG: runs the vendor uninstaller silently — removes
        # the Tanium Client and the endpoint management it provides.
        #
        $uninstallProcess = Start-Process -FilePath $uninstallerPath -ArgumentList '/S', '/Y' `
            -PassThru -ErrorAction Stop

        if ($uninstallProcess.WaitForExit($UNINSTALLER_TIMEOUT_SECONDS * 1000)) {
            $script:Outputs['UninstallerExecuted'] = $true
            $script:SummaryLines += ("Uninstaller completed (exit code {0})" -f $uninstallProcess.ExitCode)
        } else {
            $script:SummaryLines += ("Uninstaller did not finish within {0}s" -f $UNINSTALLER_TIMEOUT_SECONDS)
        }
    } catch {
        $script:SummaryLines += ("Uninstaller failed to run - {0}" -f $_.Exception.Message)
    }
} else {
    $script:SummaryLines += 'Uninstaller not found; continuing with file and registry cleanup.'
}

#
# Stage 4a — Remove the install directory
#
if (Test-Path -Path $installPath) {

    # Measure before deletion so the reclaimed size is a real number.
    # [Math]::Abs preserves the magnitude of any anomalous negative length.
    $measuredBytes = 0
    try {
        $measuredBytes = (Get-ChildItem -Path $installPath -Recurse -Force -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        if ($null -eq $measuredBytes) { $measuredBytes = 0 }
        $measuredBytes = [Math]::Abs([double]$measuredBytes)
    } catch {
        $measuredBytes = 0
    }

    if ($removeDirectory) {
        try {
            #
            # ⚠ NEXTHINK SAFETY FLAG: PERMANENT, irreversible recursive deletion
            # of the entire install directory tree.
            #
            Remove-Item -Path $installPath -Recurse -Force -ErrorAction Stop
        } catch {
            $script:SummaryLines += ("Install directory removal error - {0}" -f $_.Exception.Message)
        }

        # Verify against the device rather than trusting Remove-Item.
        if (Test-Path -Path $installPath) {
            $script:SummaryLines += ("Install directory still present: {0}" -f $installPath)
        } else {
            $script:Outputs['InstallDirectoryRemoved'] = $true
            $script:Outputs['SpaceReclaimed'] = $measuredBytes
            $script:SummaryLines += ("Install directory removed ({0:N2} MB)" -f ($measuredBytes / 1MB))
        }
    } else {
        $script:SummaryLines += 'Install directory removal skipped by parameter.'
    }
} else {
    # Nothing to remove: the directory is already gone.
    $script:Outputs['InstallDirectoryRemoved'] = $true
    $script:SummaryLines += 'Install directory not present.'
}

#
# Stage 4b — Remove Tanium registry keys
#
$registryKeysRemoved = 0
$registryKeysRemaining = 0

if ($removeRegistry) {
    foreach ($key in $taniumRegistryKeys) {
        if (-not (Test-Path -Path $key)) { continue }

        try {
            #
            # ⚠ NEXTHINK SAFETY FLAG: PERMANENT, irreversible deletion of an
            # HKLM registry key and everything under it.
            #
            Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
        } catch {
            $script:SummaryLines += ("Registry key {0}: removal error - {1}" -f $key, $_.Exception.Message)
        }

        # Verify against the device rather than trusting Remove-Item.
        if (Test-Path -Path $key) {
            $registryKeysRemaining += 1
        } else {
            $registryKeysRemoved += 1
        }
    }

    $script:Outputs['RegistryKeysRemoved'] = [uint32]$registryKeysRemoved
    if ($registryKeysRemoved -gt 0) {
        $script:SummaryLines += ("Registry keys removed: {0}" -f $registryKeysRemoved)
    }
    if ($registryKeysRemaining -gt 0) {
        $script:SummaryLines += ("Registry keys still present: {0}" -f $registryKeysRemaining)
    }
} else {
    # Report keys that remain because removal was disabled, so the operator can
    # see the device is not fully clean.
    foreach ($key in $taniumRegistryKeys) {
        if (Test-Path -Path $key) { $registryKeysRemaining += 1 }
    }
    $script:SummaryLines += 'Registry key removal skipped by parameter.'
}

#
# Final verification — does anything targeted still exist on the device?
#
$stillPresent = $false
if (Test-Path -Path $installPath) { $stillPresent = $true }
if ($registryKeysRemaining -gt 0) { $stillPresent = $true }
$script:Outputs['TaniumStillPresent'] = $stillPresent

if ($stillPresent) {
    $script:SummaryLines += 'Tanium components remain; manual removal may be required.'
} else {
    $script:SummaryLines += 'Tanium fully removed.'
}

$script:Outputs['ExecutionTime'] = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Nexthink truncates String outputs at 1024 bytes. Truncating here instead means
# the value ends with a clear marker rather than being cut mid-word by the platform.
function Limit-NxtString ([string]$Value, [int]$MaxBytes = 1024) {
    if ([System.Text.Encoding]::UTF8.GetByteCount($Value) -le $MaxBytes) { return $Value }

    $marker = '...[truncated]'
    $budget = $MaxBytes - [System.Text.Encoding]::UTF8.GetByteCount($marker)
    $result = $Value.Substring(0, [math]::Min($Value.Length, $budget))
    while ([System.Text.Encoding]::UTF8.GetByteCount($result) -gt $budget -and $result.Length -gt 0) {
        $result = $result.Substring(0, $result.Length - 1)
    }
    return ($result + $marker)
}

# Output final results — every field is written unconditionally (deterministic schema)
function Update-EngineOutputVariables {
    [Nxt]::WriteOutputUInt32('ProcessesStopped', [uint32]$script:Outputs['ProcessesStopped'])
    [Nxt]::WriteOutputUInt32('ServicesStopped', [uint32]$script:Outputs['ServicesStopped'])
    [Nxt]::WriteOutputBool('UninstallerExecuted', [bool]$script:Outputs['UninstallerExecuted'])
    [Nxt]::WriteOutputBool('InstallDirectoryRemoved', [bool]$script:Outputs['InstallDirectoryRemoved'])
    [Nxt]::WriteOutputUInt32('RegistryKeysRemoved', [uint32]$script:Outputs['RegistryKeysRemoved'])
    [Nxt]::WriteOutputSize('SpaceReclaimed', [uint64][math]::Max(0, $script:Outputs['SpaceReclaimed']))
    [Nxt]::WriteOutputBool('TaniumStillPresent', [bool]$script:Outputs['TaniumStillPresent'])
    [Nxt]::WriteOutputString('ExecutionTime', [string]$script:Outputs['ExecutionTime'])

    $summary = if ($script:SummaryLines.Count -gt 0) { $script:SummaryLines -join ' | ' } else { 'No actions performed.' }
    [Nxt]::WriteOutputString('ExecutionSummary', (Limit-NxtString -Value $summary))
}

Update-EngineOutputVariables

# Leftover components mean the uninstall did not fully succeed: report it to
# Nexthink with a non-zero exit code, after the outputs have been written.
if ($stillPresent) {
    $host.ui.WriteErrorLine(("Tanium components remain after uninstall: {0}" -f ($script:SummaryLines -join ' | ')))
    exit 1
}

exit 0
