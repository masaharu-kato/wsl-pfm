#!/bin/bash
ROOT_DIR=$(realpath "$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/..")

SRC_PATH="$ROOT_DIR/bin/wsl-pfm"
DEST_PATH="/usr/local/bin/wsl-pfm"

main() {
    if [[ -e "$DEST_PATH" ]]; then
        rm "$DEST_PATH" || return 1
    fi
    echo "#!/bin/bash" > "$DEST_PATH" || return 1
    echo "$SRC_PATH \$@" >> "$DEST_PATH"
    chmod a+x "$DEST_PATH"
    return 0
}

main
stat=$?

if [[ $stat != 0 ]]; then
    echo "Failed to install to '$DEST_PATH' on distro $WSL_DISTRO_NAME."
else
    echo "Successfully installed to '$DEST_PATH' on distro $WSL_DISTRO_NAME."
fi
exit $stat