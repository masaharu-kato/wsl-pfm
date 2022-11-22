#Requires -RunAsAdministrator

Param(
    [string]$TaskName = "Start-WSL-PFM",
    [parameter(mandatory=$true)][string]$WinUserForWSL
)

$ROOT_DIR = Resolve-Path "$(Split-path -parent $MyInvocation.MyCommand.Definition)\.."

$WSL_PFM_SCRIPT_PATH = Resolve-Path "$ROOT_DIR\host\Start.ps1"

# Trigger: Run when the target user (which has the WSL) logined
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $WinUserForWSL

# Action: Run WSL-PFM host script
$Action = New-ScheduledTaskAction -Execute powershell -Argument "-ExecutionPolicy RemoteSigned -File `"$WSL_PFM_SCRIPT_PATH`""

# Task settings
$TaskSet = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden

# Task principles (Run as SYSTEM without logon)
$Principal = New-ScheduledTaskPrincipal -RunLevel Highest -UserId SYSTEM

# Register
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $TaskSet -Principal $Principal -Force
