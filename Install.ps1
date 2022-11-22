#Requires -RunAsAdministrator

Param(
    [string]$TaskName = "Start-WSL-PFM"
)

$global:ErrorActionPreference = 'Stop'
try {
    $ROOT_DIR = Resolve-Path "$(Split-path -parent $MyInvocation.MyCommand.Definition)"

    $WSL_PFM_SCRIPT_PATH = Resolve-Path "$ROOT_DIR\host\Start.ps1"

    if(Get-ScheduledTask -TaskName $TaskName -ErrorAction Ignore) {
        Write-Host "Notice: Scheduled Task '$TaskName' already exists"
    }

    # Trigger: Run at host (windows) startups
    $Trigger = New-ScheduledTaskTrigger -AtStartup

    # Action: Run WSL-PFM host script
    $Action = New-ScheduledTaskAction -Execute powershell -Argument "-ExecutionPolicy RemoteSigned -File `"$WSL_PFM_SCRIPT_PATH`""

    # Task settings
    $TaskSet = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden

    # Task principles (Run as SYSTEM without logon)
    $Principal = New-ScheduledTaskPrincipal -RunLevel Highest -UserId SYSTEM

    # Register
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $TaskSet -Principal $Principal -Force | Out-Null

    Write-Host "Successfully installed as a Scheduled Task '$TaskName'" -ForegroundColor Green

} catch {
    Write-Host "Failed to Install." -ForegroundColor Red
    Write-Host $_ -ForegroundColor Magenta
}
