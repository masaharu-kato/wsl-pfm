#Requires -RunAsAdministrator

Param(
    [string]$TaskName = "Start-WSL-PFM"
)

$global:ErrorActionPreference = 'Stop'

# Check existence
$taskExists = $false
try {
    Get-ScheduledTask -TaskName $TaskName | Out-Null
    $taskExists = $true
}
catch {
    Write-Host "Nothing to unregister (Scheduled Task '$TaskName' does not registered)." -ForegroundColor Yellow
}

if ($taskExists) {

    # Unregister
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    
        Write-Host "Successfully unregistered a Scheduled Task." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to unregister." -ForegroundColor Red
        Write-Host $_ -ForegroundColor Magenta
    }

}