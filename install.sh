#!/bin/sh
# @file install.sh
# @author Cody Sork <codysork@gmail.com>
# @created 2026-10-20
# @modified 2026-10-20
# @description Installs all scripts in this repo to the system

# Require root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exit 1
fi

for file in $(ls *.sh); do
    echo "Installing $file"
    sudo install -m 755 $file /usr/local/bin
done
