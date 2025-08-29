<#
.SYNOPSIS
    This script retrieves the timestamp of the last successful logon event (Event ID 4624)
    from the Windows Security event log and calculates the number of days since that logon.

.DESCRIPTION
    The script queries the Security event log for the newest event with ID 4624, which
    indicates a successful account logon. It then calculates the difference between the
    event's creation time and the current date and displays the result.

    This can be useful for determining the last time a user logged into a Windows machine.

.EXAMPLE
    .\last_connected_to_AD.ps1

    This will run the script and output the date of the last logon and the number of days
    since that logon.

.NOTES
    - The script must be run with sufficient permissions to read the Security event log.
      It is recommended to run this script as an administrator.
    - This script looks for logon events on the local machine where the script is run.
#>

try {
    # Get the most recent event with ID 4624 (Successful Logon) from the Security log
    $lastLogonEvent = Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        ID      = 4624
    } -MaxEvents 1 -ErrorAction Stop

    if ($null -ne $lastLogonEvent) {
        # Get the date of the last logon
        $lastLogonDate = $lastLogonEvent.TimeCreated

        # Get the current date
        $currentDate = Get-Date

        # Calculate the timespan between the last logon and the current date
        $timeSpan = New-TimeSpan -Start $lastLogonDate -End $currentDate

        # Get the number of days
        $daysSinceLastLogon = $timeSpan.Days

        # Output the result
        Write-Host "Last successful logon (Event ID 4624) was on: $($lastLogonDate.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Host "Days since last logon: $daysSinceLastLogon"
    }
    else {
        Write-Host "No successful logon events (Event ID 4624) found in the Security log."
    }
}
catch {
    Write-Error "An error occurred while trying to read the event log."
    Write-Error "Please make sure you are running this script with administrative privileges."
    Write-Error "Error details: $($_.Exception.Message)"
}
