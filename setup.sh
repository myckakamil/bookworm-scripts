#!/bin/bash
# Script to install dependencies

USERNAME=$(logname)

# Check if user is root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Run dependenc install script
bash basic-dependencies.sh

# Installing dotfiles
read -p "Do you want to install dotfiles? [y/n]: " DOTFILES
if [ $DOTFILES == "y" ]; then
    echo "WORK IN PROGRESS"
    #git clone https://github.com/Mordimmer/dotfiles /home/$USERNAME/Git/dotfiles
    #bash /home/$USERNAME/Git/dotfiles/setup.sh
fi

# Installing dwm
read -p "Do you want to install dwm? [y/n]: " DWM
if [ $DWM == "y" ]; then
    echo "WORK IN PROGRESS"
    # git clone https://github.com/Mordimmer/dwm-config /home/$USERNAME/Git/dwm-config
    # bash /home/$USERNAME/Git/dwm-config/install.sh
fi