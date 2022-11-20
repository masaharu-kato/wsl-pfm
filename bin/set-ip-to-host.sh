#!/bin/bash

DIR_WSL_PFM="/mnt/c/etc/wsl-pfm"

DISTRO="$WSL_DISTRO_NAME"
DIR_DISTRO="$DIR_WSL_PFM/distro/$DISTRO"

mkdir -p "$DIR_WSL_PFM"
mkdir -p "$DIR_DISTRO"

my_ip=$(ip a show eth0 | grep -w -m1 inet | awk '{print $2}' | awk -F'/' '{print $1}')

echo -n "$my_ip" > "$DIR_DISTRO/ip"
