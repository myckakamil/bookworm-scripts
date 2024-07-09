#!/bin/bash
# Script to install dependencies

# Check if user is root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Run dependenc install script
bash basic-dependencies.sh