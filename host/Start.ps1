#Requires -RunAsAdministrator

$ROOT_DIR = Resolve-Path "$(Split-path -parent $MyInvocation.MyCommand.Definition)\.."

New-Item "$ROOT_DIR\log" -ItemType Directory -Force | Out-Null

Set-Location $ROOT_DIR
Start-Process -FilePath powershell -ArgumentList @(".\host\WSL-PFM.ps1", ">", ".\log\log_$(Get-Date -UFormat "%Y%m%d_%H%M%S").txt") -WindowStyle Hidden
