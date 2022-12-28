Param(
    [alias("w")][string]$WorkingDir,
    [alias("d")][string]$Distro,
    [alias("u")][string]$User,
    [alias("s")][string]$Script,
    [alias("o")][switch]$EnableOutput,
    [alias("colout")][switch]$EnableColorOutput,
    [string]$ErrorColor = "Red",
    [string]$SuccessColor = "Green",
    [string]$WarningColor = "Yellow",
    [string]$WarningCode = 255
)

if ($WorkingDir) {
    Push-Location $WorkingDir
}

if ($Distro) {
    if ($User) {
        $res = wsl -d $Distro -u $User -- $Script
    }
    else {
        $res = wsl -d $Distro -- $Script
    }
}
else {
    if ($User) {
        $res = wsl -u root -- $Script
    }
    else {
        $res = wsl -- $Script
    }
}

$exitCode = $LASTEXITCODE

if ($EnableOutput) {
    if ($EnableColorOutput) {
        if ($LASTEXITCODE -eq $WarningCode) {
            Write-Host $res -ForegroundColor $WarningColor
        }
        elseif ($LASTEXITCODE) {
            Write-Host $res -ForegroundColor $ErrorColor
        }
        else {
            Write-Host $res -ForegroundColor $SuccessColor
        }
    }
    else {
        Write-Output $res
    }
}

if ($WorkingDir) {
    Pop-Location
}

exit $exitCode