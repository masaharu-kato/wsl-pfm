#!/bin/bash

DEST_PATH="/usr/local/bin/wsl-pfm"

main() {
    if [[ -e "$DEST_PATH" ]]; then
        rm "$DEST_PATH" || return 1
    else
        return 255
    fi
    return 0
}

main
stat=$?

if [[ $stat == 255 ]]; then
    echo "Nothing to uninstall ('$DEST_PATH' does not exists) on distro $WSL_DISTRO_NAME."
elif [[ $stat != 0 ]]; then
    echo "Failed to uninstall from '$DEST_PATH' on distro $WSL_DISTRO_NAME."
else
    echo "Successfully uninstalled from '$DEST_PATH' on distro $WSL_DISTRO_NAME."
fi
exit $stat