# Bookworm scripts

> **Note**  
> This project is still a work in progress. Expect frequent updates and breaking changes.

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
    git clone https://github.com/myckakamil/bookwork-scripts
    ```
2. Run the installation script:
    ```bash
    cd bookwork-scripts
    chmod +x debootstrap-install.sh
    sudo ./debootstrap-install.sh
    ```
## Scripts Overview
Core Installer
- `debootstrap-install.sh` - Primary script for base Debian system installation using debootstrap
Application Scripts
- `applications/neovim.sh` - Installing latest version of Neovim on Debian
Services Deployment Scripts
- `services/asterisk.sh` - Full Asterisk PBX system instalation, with lua dialplan
- `services/bookstack.sh` - BookStack wiki/documentation platform instalation
- `services/gnugk.sh` - GNU Gatekeeper instalation for H.323 VoIP networks
- `services/nextcloud.sh` - Nextcloud instance deployment with basic configuration
- `services/opensips.sh` - OpenSIPS SIP server installation
- `services/proxmox.sh` - Proxmox VE virtualization environment setup

## Development Roadmap
### Debootstrap
- ZFS
- XFS
- BTRFS (fix issues)
- RAID configuration
- LUKS encryption
- Interactive locale settings
- Desktop enviroment options

### Services
- Create TUI and checks for proxmox install
- Fix bugs in opensips and GNU Gk scripts