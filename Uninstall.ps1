#Requires -RunAsAdministrator

Param(
    [string]$TaskName = "Start-WSL-PFM"
)

$global:ErrorActionPreference = 'Stop'
try {
    # Unregister
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
 
    Write-Host "Successfully Uninstalled." -ForegroundColor Green

} catch {
    Write-Host "Failed to install." -ForegroundColor Red
    Write-Host $_ -ForegroundColor Magenta
}
