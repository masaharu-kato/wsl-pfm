#Requires -RunAsAdministrator
Param(
    [alias("d")][string]$Distro,
    [string]$TaskName = "Start-WSL-PFM",
    [switch]$noStart
)

$ROOT_DIR = Resolve-Path "$(Split-path -parent $MyInvocation.MyCommand.Definition)"

Write-Host "WSL Port Forwarding Manager Installer (Ver 0.2.0)"

# Register a Scheduled Task
. $ROOT_DIR/host/Register-ScheduledTask.ps1 -TaskName $TaskName

# Install on WSL
. $ROOT_DIR/host/Install-on-WSL.ps1 -d $Distro

if (!$noStart) {
    # Start a Scheduled Task
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Successfully started WSL Port Forwarding Manager." -ForegroundColor Green
}
else {
    Write-Host "Reboot the host computer to start WSL Port Forwarding Manager." -ForegroundColor Yellow
}
