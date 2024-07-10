# Bookworm script
## A selection of scripts to install and setup Debian system

### STILL WORK IN PROGRESS
For now suggested location to download the scripts is /home/$USER/Git directory.

## Installation
This script is intended to be used on a live CD to install a Debian system. 
```bash
git clone https://github.com/Mordimmer/bookwork-scripts
cd bookwork-scripts
chmod +x debootstrap-install.sh
sudo ./debootstrap-install.sh
```

## Setup
After the installation, you can run the setup script to configure the system.
```bash
git clone https://github.com/Mordimmer/bookwork-scripts
cd bookwork-scripts
chmod +x setup.sh
sudo ./setup.sh
```