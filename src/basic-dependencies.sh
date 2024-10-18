#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

apt update && apt upgrade -y

# Must have packages
apt install -y aptitude nala htop vim neovim git curl wget ncdu 