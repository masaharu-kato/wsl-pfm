#Requires -RunAsAdministrator

$ROOT_DIR = Resolve-Path "$(Split-path -parent $MyInvocation.MyCommand.Definition)\.."

Start-Process -FilePath powershell -ArgumentList @("$ROOT_DIR\host\Run.ps1") -WindowStyle Hidden
