#Requires -RunAsAdministrator
Param(
    [alias("d")][string]$Distro,
    [string]$TaskName = "Start-WSL-PFM"
)

$ROOT_DIR = Resolve-Path "$(Split-path -parent $MyInvocation.MyCommand.Definition)"

# Stop the Scheduled Task (if the task exists)
try {
    Stop-ScheduledTask -TaskName $TaskName | Out-Null
    Write-Host "Stopped Scheduled Task." -ForegroundColor Yellow
}
catch {}

# Unregister the Scheduled Task
. $ROOT_DIR/host/Unregister-ScheduledTask.ps1

# Uninstall on WSL
. $ROOT_DIR/host/Uninstall-on-WSL.ps1 -d $Distro
