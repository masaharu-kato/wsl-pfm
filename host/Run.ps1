#Requires -RunAsAdministrator

$ROOT_DIR = Resolve-Path "$(Split-path -parent $MyInvocation.MyCommand.Definition)\.."

# Create mutex object to avoid duplicate running of application
$mutexObject = New-Object System.Threading.Mutex -ArgumentList $false, "Global\WSL-PFM"

if (-not $mutexObject.WaitOne(0, $false)) {
    Write-Host "Error: WSL Port Forwarding Manager is already running." -ForegroundColor Red
    exit 1
}

try {
    
    # Prepare log directory
    New-Item "$ROOT_DIR\log" -ItemType Directory -Force | Out-Null

    # Run main program
    $logPath = "$ROOT_DIR\log\wsl-pfm_$(Get-Date -UFormat "%Y%m%d_%H%M%S").log"
    Write-Host "Notice: Redirecting outputs to '$logPath'." -ForegroundColor Cyan
    . $ROOT_DIR/host/WSL-PFM.ps1 | Tee-Object $logPath

}
catch [System.Threading.AbandonedMutexException] {
    # The previous execution was forcibly terminated.
}
finally {
    $mutexObject.ReleaseMutex()
    $mutexObject.Close()
}
