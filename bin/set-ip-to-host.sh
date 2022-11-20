#!/bin/bash

DIR_WSL_PFM="/mnt/c/etc/wsl-pfm"

DISTRO="$WSL_DISTRO_NAME"
DIR_DISTRO="$DIR_WSL_PFM/distro/$DISTRO"

mkdir -p "$DIR_WSL_PFM"
mkdir -p "$DIR_DISTRO"

c_ip=$(ip a show eth0 | grep -w -m1 inet | awk '{print $2}' | awk -F'/' '{print $1}')
saved_ip=""
if [[ -e "$DIR_DISTRO/ip" ]]; then
    saved_ip=$(cat "$DIR_DISTRO/ip")
fi
if [[ "$c_ip" != "$saved_ip" ]]; then
    echo -n "$c_ip" > "$DIR_DISTRO/ip"
fi
