Param(
    [alias("d")][string]$Distro
)

$ROOT_DIR = Resolve-Path "$(Split-path -parent $MyInvocation.MyCommand.Definition)\.."

. $ROOT_DIR/host/Run-on-WSL.ps1 -w $ROOT_DIR -d $Distro -u root -s bin/uninstall.sh -o -colout
