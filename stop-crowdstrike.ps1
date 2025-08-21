#Requires -RunAsAdministrator

# Strict mode
Set-Strictmode -Version Latest

# Error handling
trap {
    $host.ui.WriteErrorLine($_.ToString())
    exit 1
}

# Service names
$serviceNames = @("csagent", "csfalconservice")

# Stop services
foreach ($serviceName in $serviceNames) {
    try {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        if ($service.Status -ne 'Stopped') {
            Write-Host "Stopping service: $($serviceName)..."
            Stop-Service -Name $serviceName -Force -ErrorAction Stop
            Write-Host "Service $($serviceName) stopped successfully."
        } else {
            Write-Host "Service $($serviceName) is already stopped."
        }
    }
    catch [Microsoft.PowerShell.Commands.ServiceCommandException] {
        # This error is thrown when the service does not exist.
        Write-Host "Service $($serviceName) not found. Skipping."
    }
    catch {
        # Catch any other errors
        $host.ui.WriteErrorLine("Failed to stop service $($serviceName): $($_.Exception.Message)")
        exit 1
    }
}

Write-Host "All specified CrowdStrike services have been processed."
exit 0
