
# Create mutex object to check the application is running
$mutexObject = New-Object System.Threading.Mutex -ArgumentList $false, "Global\WSL-PFM"

if (-not $mutexObject.WaitOne(0, $false)) {
    Write-Host "WSL Port Forwarding Manager is currently running." -ForegroundColor Green
    exit 0
}

Write-Host "WSL Port Forwarding Manager is not currently running." -ForegroundColor Yellow

$mutexObject.ReleaseMutex()
$mutexObject.Close()
exit 1
