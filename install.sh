#!/bin/sh
# @file install.sh
# @author Cody Sork <codysork@gmail.com>
# @created 2026-10-20
# @modified 2026-10-29
# @description Installs all scripts in this repo to the system

# Require root
if [ "$(id -u)" != "0" ]; then
    echo "[ERROR] This script must be run as root"
    exit 1
fi

# Install scripts
for file in $(ls *.sh); do
    echo "[[INFO] Installing $file"
    sudo install -m 755 $file /usr/local/bin
done

# Install config file
echo "[INFO] Installing config file"
if [ ! -d ~/.my-scripts ]; then
    mkdir ~/.my-scripts
fi
sudo install -m 644 config ~/.my-scripts/config
