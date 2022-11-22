#Requires -RunAsAdministrator

$ROOT_DIR = Resolve-Path "$(Split-path -parent $MyInvocation.MyCommand.Definition)\.."

New-Item "$ROOT_DIR\log" -ItemType Directory -Force | Out-Null

Start-Process -FilePath powershell -ArgumentList @("$ROOT_DIR\host\WSL-PFM.ps1", ">", "$ROOT_DIR\log\log_$(Get-Date -UFormat "%Y%m%d_%H%M%S").txt") -WindowStyle Hidden
