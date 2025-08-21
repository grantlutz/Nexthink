#requires -RunAsAdministrator

<#
.SYNOPSIS
    This script uninstalls the Tanium Client from a Windows system.

.DESCRIPTION
    This script is designed to completely remove the Tanium Client and all its components from a Windows system.
    It performs the following actions:
    1. Stops all Tanium services and processes.
    2. Executes the Tanium uninstaller if it exists.
    3. Removes the Tanium installation directory.
    4. Deletes Tanium-related registry keys.
    5. Logs all actions to a transcript file.

.NOTES
    Author: Jules
    Date: 2025-08-21
#>

# Function to check for administrator privileges
function Test-IsAdmin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "This script must be run with Administrator privileges. Please re-run the script as an Administrator." -ForegroundColor Red
    exit 1
}

# Start logging
$transcriptPath = "C:\Tanium_Uninstall_Log.txt"
Start-Transcript -Path $transcriptPath -Force

Write-Host "Starting Tanium Client uninstallation process." -ForegroundColor Yellow

# Define Tanium-related information
$taniumProcesses = @(
    "TaniumClient",
    "TaniumEndpointIndex",
    "TPython",
    "TaniumCX",
    "TaniumDetectEngine",
    "TaniumDriverSvc"
)

$taniumServices = @(
    "Tanium Client",
    "Tanium Index",
    "Tanium Detect",
    "TaniumRecorderDrv",
    "TaniumClientBootstrap"
)

$taniumPath = "C:\Program Files (x86)\Tanium"
$uninstallerPath = Join-Path $taniumPath "Tanium Client\uninst.exe"

$registryKeys = @(
    "HKLM:\SYSTEM\CurrentControlSet\Services\TaniumRecorderDrv",
    "HKLM:\SYSTEM\CurrentControlSet\Services\TaniumClientBootstrap",
    "HKLM:\SOFTWARE\WOW6432Node\Tanium",
    "HKLM:\SOFTWARE\Tanium"
)

# Stop Tanium processes
Write-Host "Stopping Tanium processes..." -ForegroundColor Cyan
foreach ($processName in $taniumProcesses) {
    try {
        Get-Process -Name $processName -ErrorAction Stop | Stop-Process -Force -ErrorAction Stop
        Write-Host "  - Stopped process: $processName"
    }
    catch {
        Write-Host "  - Process $processName not found or could not be stopped. Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Stop Tanium services
Write-Host "Stopping Tanium services..." -ForegroundColor Cyan
foreach ($serviceName in $taniumServices) {
    try {
        Get-Service -Name $serviceName -ErrorAction Stop | Stop-Service -Force -ErrorAction Stop
        Write-Host "  - Stopped service: $serviceName"
    }
    catch {
        Write-Host "  - Service $serviceName not found or could not be stopped. Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Run the uninstaller
if (Test-Path $uninstallerPath) {
    Write-Host "Running Tanium uninstaller..." -ForegroundColor Cyan
    try {
        Start-Process -FilePath $uninstallerPath -ArgumentList "/S /Y" -Wait -ErrorAction Stop
        Write-Host "  - Uninstaller completed."
    }
    catch {
        Write-Host "  - Uninstaller failed to run. Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "Tanium uninstaller not found at $uninstallerPath" -ForegroundColor Yellow
}

# Remove Tanium installation directory
if (Test-Path $taniumPath) {
    Write-Host "Removing Tanium installation directory..." -ForegroundColor Cyan
    try {
        Remove-Item -Path $taniumPath -Recurse -Force -ErrorAction Stop
        Write-Host "  - Removed directory: $taniumPath"
    }
    catch {
        Write-Host "  - Failed to remove directory $taniumPath. Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Remove registry keys
Write-Host "Removing Tanium registry keys..." -ForegroundColor Cyan
foreach ($key in $registryKeys) {
    try {
        if (Test-Path $key) {
            Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
            Write-Host "  - Removed registry key: $key"
        }
        else {
            Write-Host "  - Registry key not found: $key" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  - Failed to remove registry key $key. Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Final verification
Write-Host "Performing final verification..." -ForegroundColor Cyan
if (Test-Path $taniumPath) {
    Write-Host "  - Tanium directory still exists at $taniumPath. Manual removal may be required." -ForegroundColor Red
}
else {
    Write-Host "  - Tanium directory successfully removed." -ForegroundColor Green
}

Write-Host "Tanium Client uninstallation process finished." -ForegroundColor Green
Write-Host "Log file created at $transcriptPath"

Stop-Transcript
