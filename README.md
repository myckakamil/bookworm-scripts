# Bookworm scripts

> **Note**  
> This project is currently in maintenance mode. Since I started this repo, I’ve discovered Ansible and migrated most scripts to it 😄
> The `debootstrap` script will eventually be moved to its own repository.

A collection of automated scripts for installing and configuring Debian systems. Ideal for quickly setting up new installations with various configurations.

## Installation
Installing Debian using debootstrap

### Prerequisites
- Debian-based live environment (e.g., Finnix or Linux Mint)
- Root privileges
- Internet connection

### Quick Start
1. Clone the repository (recommended location):
    ```bash
    mkdir -p ~/Git && cd ~/Git
    git clone https://github.com/myckakamil/bookworm-scripts
    ```
2. Run the installation script:
    ```bash
    cd bookworm-scripts
    chmod +x debootstrap-install.sh
    sudo ./debootstrap-install.sh
    ```
## Scripts Overview
Core Installer
- `debootstrap-install.sh` - Primary script for base Debian system installation using debootstrap
Application Scripts
- `applications/neovim.sh` - Installing latest version of Neovim on Debian
- `services/asterisk.sh` - Full Asterisk PBX system installation, with lua dialplan
- `services/bookstack.sh` - BookStack wiki/documentation platform installation
- `services/gnugk.sh` - GNU Gatekeeper installation for H.323 VoIP networks
- `services/nextcloud.sh` - Nextcloud instance deployment with basic configuration
- `services/opensips.sh` - OpenSIPS SIP server installation
- `services/proxmox.sh` - Proxmox VE virtualization environment setup

