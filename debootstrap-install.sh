#!/bin/bash

# install dialog if not present
if ! command -v dialog >/dev/null 2>&1; then
    apt-get update
    apt-get install -y dialog
fi

# function to show progress
show_progress() {
    echo $2 | dialog --gauge "$1" 10 70 0
}

# check if root
if [ "$euid" -ne 0 ]; then
    dialog --title "error" --msgbox "please run this script as root." 8 40
    exit 1
fi

# check uefi/bios
if [ -d /sys/firmware/efi ]; then
    BOOT_MODE=uefi
else
    BOOT_MODE=bios
fi

# check internet connection
if ! ping -c 1 google.com &> /dev/null; then
    dialog --title "error" --msgbox "no internet connection. please connect to the internet and run the script again." 8 60
    exit 1
fi

# update system and install required packages
dialog --title "system update" --infobox "updating system and installing required packages..." 8 60

(
echo "10" ; sleep 1
apt-get update > /dev/null 2>&1
echo "40" ; sleep 1
apt-get install -y debootstrap parted figlet > /dev/null 2>&1
echo "100" ; sleep 1
) | dialog --title "progress" --gauge "installing required packages..." 10 70 0

dialog --title "ready" --msgbox "system updated and ready for debian installation." 8 50

# display warning
dialog --title "warning" --yes-label "continue" --no-label "exit" --yesno "this script will create uefi/bios and root partitions.\nthis will erase all data on the selected disk.\n\ndo you want to continue?" 10 60

if [ $? -ne 0 ]; then
    clear
    exit 1
fi


clear
# get hostname
hostname=$(dialog --title "hostname" \
    --inputbox "enter the hostname for your computer:" 8 50 \
    3>&1 1>&2 2>&3)

# exit if canceled
if [ $? -ne 0 ]; then
    clear
    exit 1
fi

# Ask user if they want to set up RAID
dialog --title "RAID" --yesno "Do you want to set up RAID?" 8 50
RAID=$?
if [ $RAID -eq 0 ]; then
    dialog --title "ERROR" --msgbox "RAID is not supported by this script yet." 8 50
    clear
fi

# select debian version
WERSJA=$(dialog --title "debian version" \
    --menu "select debian version to install:" 12 50 3 \
    "stable" "debian stable (recommended)" \
    "testing" "debian testing (not tested)" \
    "sid" "debian sid (not tested)" \
    3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    clear
    exit 1
fi

while true; do
    unset MENU_OPTIONS
    declare -a MENU_OPTIONS
    while IFS= read -r line; do
        FULL_NAME=$(echo "$line" | awk '{print $1}')
        SIZE=$(echo "$line" | awk '{print $2}')
        MENU_OPTIONS+=("$FULL_NAME" "($SIZE)")
    done < <(lsblk -d -n -o name,size -p | grep "^/dev")

    DYSK=$(dialog --title "disk selection" \
        --menu "select disk for debian installation:" 15 50 5 \
        "${MENU_OPTIONS[@]}" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        clear
        exit 1
    fi

    dialog --title "confirmation" --yesno "you selected disk: $DYSK\nis this correct?" 8 50

    if [ $? -eq 0 ]; then
        break
    fi
done

while true; do
    fs=$(dialog --title "Filesystem Selection" \
        --menu "Select filesystem to use:" 12 50 4 \
        "ext4" "Extended Filesystem 4" \
        "btrfs" "B-Tree Filesystem" \
        "xfs" "XFS Filesystem (not supported yet)" \
        "zfs" "ZFS Filesystem (not supported yet)" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        clear
        exit 1
    fi

    case $fs in
        "ext4")
            FS=ext4
            break
            ;;
        "btrfs") 
            FS=btrfs
            break
            ;;
        "xfs"|"zfs")
            dialog --title "ERROR" --msgbox "This filesystem is not supported yet." 8 50
            continue
            ;;
    esac
done

clear

while true; do
    dialog --title "WARNING" --yes-label "Continue" --no-label "Cancel" \
        --yesno "This will erase all data on $DYSK.\nAre you sure you want to continue?" 8 60

    case $? in
        0) # Yes
            break
            ;;
        1) # No
            clear
            exit 1
            ;;
    esac
done

clear
dialog --title "Creating Partitions" --infobox "Creating partitions on $DYSK..." 3 50
sleep 1

# Clear the disk first, force unmount any partitions
umount "$DYSK"* 2>/dev/null || true
swapoff "$DYSK"* 2>/dev/null || true
wipefs -af "$DYSK"

if [ "$BOOT_MODE" == "uefi" ]; then
    parted "$DYSK" --script mklabel gpt \
        mkpart boot fat32 1MiB 1001MiB \
        set 1 esp on \
        mkpart primary $FS 1001MiB 100%

    echo "UEFI boot partition created"
    lsblk "$DYSK"

    echo "Finished partitioning $DYSK."

    echo "Formatting partitions..."
    mkfs.vfat "${DYSK}1" 

    case $FS in
        ext4)
            mkfs.ext4 -F "${DYSK}2"
            echo "Mounting partitions..."
            mount "${DYSK}2" /mnt
            mkdir -p /mnt/boot/efi
            mount "${DYSK}1" /mnt/boot/efi
            ;;
        btrfs)
            mkfs.btrfs "${DYSK}2" -f
            echo "Creating subvolumes..."
            mount "${DYSK}2" /mnt
            btrfs subvolume create /mnt/@
            btrfs subvolume create /mnt/@home
            btrfs subvolume create /mnt/@root
            btrfs subvolume create /mnt/@var
            btrfs subvolume create /mnt/@tmp
            btrfs subvolume create /mnt/@snapshots

            echo "Mounting subvolumes..."
            mount -o noatime,compress=zstd,subvol=@ "$DYSK"2 /mnt
            mkdir -p /mnt/{home,root,var,tmp,.snapshots}
            mkdir -p /mnt/boot/efi
            mount -o noatime,compress=zstd,subvol=@home "$DYSK"2 /mnt/home
            mount -o noatime,compress=zstd,subvol=@var "$DYSK"2 /mnt/var
            mount -o noatime,compress=zstd,subvol=@tmp "$DYSK"2 /mnt/tmp
            mount -o noatime,compress=zstd,subvol=@snapshots "$DYSK"2 /mnt/.snapshots
            mount "${DYSK}"1 /mnt/boot/efi
            ;;
        *)
            ;;
    esac
else
    # Creating partitions for BIOS
    parted "$DYSK" --script mklabel msdos \
        mkpart primary $FS 1MiB 100% \
        set 1 boot on

    echo "BIOS boot partition created"
    lsblk "$DYSK"

    echo "Finished partitioning $DYSK."

    echo "Formatting partitions"
    case $FS in
        ext4)
            mkfs.ext4 -F "${DYSK}1"
            echo "Mounting partitions..."
            mount "${DYSK}1" /mnt
            ;;
        btrfs)
            mkfs.btrfs "${DYSK}1" -f
            echo "Creating subvolumes..."
            mount "${DYSK}1" /mnt
            btrfs subvolume create /mnt/@
            btrfs subvolume create /mnt/@home
            btrfs subvolume create /mnt/@root
            btrfs subvolume create /mnt/@var
            echo "Mounting subvolumes..."
            mount -o noatime,compress=zstd,subvol=@ "$DYSK"1 /mnt
            mkdir -p /mnt/{home,root,var,tmp,.snapshots}
            mount -o noatime,compress=zstd,subvol=@home "$DYSK"1 /mnt/home
            mount -o noatime,compress=zstd,subvol=@var "$DYSK"1 /mnt/var
            mount -o noatime,compress=zstd,subvol=@tmp "$DYSK"1 /mnt/tmp
            mount -o noatime,compress=zstd,subvol=@snapshots "$DYSK"1 /mnt/.snapshots
            ;;
        *)
            ;;
    esac
fi

dialog --title "Installing Debian" --infobox "Installing Debian $WERSJA on $DYSK..." 8 60
sleep 2

debootstrap $WERSJA /mnt

echo "deb http://deb.debian.org/debian $WERSJA main contrib non-free non-free-firmware" > /mnt/etc/apt/sources.list
if [ "$WERSJA" == "stable" ]; then
    echo "deb http://deb.debian.org/debian-security/ $WERSJA-security main contrib non-free non-free-firmware" >> /mnt/etc/apt/sources.list
    echo "deb http://deb.debian.org/debian $WERSJA-updates main contrib non-free non-free-firmware" >> /mnt/etc/apt/sources.list
fi

for dir in sys dev proc; do
    mount --rbind /$dir /mnt/$dir && mount --make-rslave /mnt/$dir
done

if [ "$BOOT_MODE" == "UEFI" ]; then
    chroot /mnt /bin/bash -c "apt-get update && apt-get upgrade -y && apt-get install -y linux-image-amd64 grub-efi-amd64 efibootmgr sudo grub2-common"
    chroot /mnt /bin/bash -c "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian && update-grub"
else
    chroot /mnt /bin/bash -c "apt-get update && apt-get upgrade -y && apt-get install -y linux-image-amd64 grub-pc sudo grub2-common"
    chroot /mnt /bin/bash -c "grub-install $DYSK && update-grub"
fi

if [ "$BOOT_MODE" == "UEFI" ]; then
    EFI_UUID=$(blkid -s UUID -o value "${DYSK}1")
    ROOT_UUID=$(blkid -s UUID -o value "${DYSK}2")

    case $FS in
        ext4)
            echo "UUID=$EFI_UUID /boot/efi vfat defaults 0 1" > /mnt/etc/fstab
            echo "UUID=$ROOT_UUID / ext4 defaults 0 1" >> /mnt/etc/fstab
            ;;
        btrfs)
            echo "UUID=$ROOT_UUID /           btrfs noatime,compress=zstd,subvol=@            0 0" > /mnt/etc/fstab
            echo "UUID=$ROOT_UUID /home       btrfs noatime,compress=zstd,subvol=@home        0 0" >> /mnt/etc/fstab
            echo "UUID=$ROOT_UUID /root       btrfs noatime,compress=zstd,subvol=@root        0 0" >> /mnt/etc/fstab
            echo "UUID=$ROOT_UUID /var        btrfs noatime,compress=zstd,subvol=@var         0 0" >> /mnt/etc/fstab
            echo "UUID=$ROOT_UUID /tmp        btrfs noatime,compress=zstd,subvol=@tmp         0 0" >> /mnt/etc/fstab
            echo "UUID=$ROOT_UUID /.snapshots btrfs noatime,compress=zstd,subvol=@snapshots   0 0" >> /mnt/etc/fstab
            echo "UUID=$EFI_UUID /boot/efi vfat defaults 0 1" >> /mnt/etc/fstab
            ;;
    esac
else
    ROOT_UUID=$(blkid -s UUID -o value "${DYSK}1")

    case $FS in
        ext4)
            echo "UUID=$ROOT_UUID / ext4 defaults 0 1" > /mnt/etc/fstab
            ;;
        btrfs)
            echo "UUID=$ROOT_UUID /           btrfs noatime,compress=zstd,subvol=@            0 0" > /mnt/etc/fstab
            echo "UUID=$ROOT_UUID /home       btrfs noatime,compress=zstd,subvol=@home        0 0" >> /mnt/etc/fstab
            echo "UUID=$ROOT_UUID /root       btrfs noatime,compress=zstd,subvol=@root        0 0" >> /mnt/etc/fstab
            echo "UUID=$ROOT_UUID /var        btrfs noatime,compress=zstd,subvol=@var         0 0" >> /mnt/etc/fstab
            echo "UUID=$ROOT_UUID /tmp        btrfs noatime,compress=zstd,subvol=@tmp         0 0" >> /mnt/etc/fstab
            echo "UUID=$ROOT_UUID /.snapshots btrfs noatime,compress=zstd,subvol=@snapshots   0 0" >> /mnt/etc/fstab
            ;;
    esac
fi

# Show progress dialog
dialog --title "Installing Base System" --infobox "Configuring system settings..." 8 60
sleep 1

# Generating locales
chroot /mnt /bin/bash -c "apt-get install -y locales && echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && locale-gen"

# Setting up timezone
chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/Europe/Warsaw /etc/localtime"

# Setting up keyboard layout
chroot /mnt /bin/bash -c "echo 'KEYMAP=pl' > /etc/vconsole.conf"

# Setting up old network naming
chroot /mnt /bin/bash -c "sed -i 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/' /etc/default/grub && update-grub"

# Network configuration
cat <<EOF > /mnt/etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Setting up hostname
echo "$HOSTNAME" > /mnt/etc/hostname
cat <<EOF > /mnt/etc/hosts
127.0.0.1 localhost
::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF


# Installing end enabling DHCP client
chroot /mnt /bin/bash -c "apt-get install -y dhcpcd && systemctl enable dhcpcd" 

if $FS == "btrfs"; then
    chroot /mnt /bin/bash -c "apt-get install -y btrfs-progs"
fi
clear

dialog --title "Base System Installed" --msgbox "Basic system configuration completed successfully." 8 60

dialog --title "Root Password" --msgbox "You must set the root password for your system." 8 50
while true; do
    # Get password
    password=$(dialog --title "Root Password" --insecure --passwordbox "Enter new root password:" 8 50 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        dialog --title "Error" --msgbox "Password is required. Please try again." 8 40
        continue
    fi

    # Confirm password
    confirm=$(dialog --title "Root Password" --insecure --passwordbox "Confirm root password:" 8 50 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        dialog --title "Error" --msgbox "Password is required. Please try again." 8 40
        continue
    fi

    # Check if passwords match
    if [ "$password" = "$confirm" ]; then
        echo "root:$password" | chroot /mnt chpasswd
        dialog --title "Success" --msgbox "Root password has been set successfully." 8 50
        break
    else
        dialog --title "Error" --msgbox "Passwords do not match. Please try again." 8 50
    fi
done

clear

while true; do
    read -p "Do you want to enable ssh? (yes/no): " SSH
    case $SSH in
        yes | y)
            chroot /mnt /bin/bash -c "apt-get install -y openssh-server"
            chroot /mnt /bin/bash -c "systemctl enable ssh"
            clear 
            while true; do
                read -p "Do you want to allow root login via SSH? (yes/no): " ROOTSSH
                case $ROOTSSH in
                    yes)
                        sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /mnt/etc/ssh/sshd_config
                        break
                        ;;
                    no)
                        echo "Root login disabled."
                        break
                        ;;
                    *)
                        echo "Invalid choice. Please select 'yes' or 'no'."
                        ;;
                esac
            done
            break
            ;;
        no | n)
            echo "SSH not enabled."
            break
            ;;
        *)
            echo "Invalid choice. Please select 'yes' or 'no'."
            ;;
    esac
done
clear

echo "Do you want to create a new user?"
while true; do
    read -p "Create a new user? (yes/no): " USER
    case $USER in
        yes | y)
            read -p "Enter the full name of the user: " FULLNAME
            read -p "Enter the username: " USERNAME
            chroot /mnt /bin/bash -c "useradd -m -G users -s /bin/bash -c \"$FULLNAME\" $USERNAME"
            while true; do
                read -p "Will $USERNAME be a sudo user? (yes/no): " SUDO
                case $SUDO in
                    yes | y)
                        chroot /mnt /bin/bash -c "usermod -aG sudo $USERNAME"
                        break
                        ;;
                    no | n)
                        break
                        ;;
                    *)
                        echo "Invalid choice. Please select 'yes' or 'no'."
                        ;;
                esac
            done
            echo "User password:"
            chroot /mnt /bin/bash -c "passwd $USERNAME"
            clear
            while true; do
                read "Do you want to predownload my setup scripts? (yes/no): " SCRIPTS
                case $SCRIPTS in
                    yes | y)
                        chroot /mnt /bin/bash -c "apt-get install -y git"
                        chroot /mnt /bin/bash -c "mkdir /home/$USERNAME/"
                        chroot /mnt /bin/bash -c "git clone https://github.com/Mordimmer/bookwork-scripts /home/$USERNAME/bookwork-scripts"
                        chroot /mnt /bin/bash -c "chown -R $USERNAME:$USERNAME /home/$USERNAME/bookwork-scripts"
                        break
                        ;;
                    no | n)
                        echo "No scripts downloaded."
                        break
                        ;;
                    *)
                        echo "Invalid choice. Please select 'yes' or 'no'."
                        ;;  
                esac
            done
            break
            ;;
        no | n)
            echo "No user created."
            break
            ;;
        *)
            echo "Invalid choice. Please select 'yes' or 'no'."
            ;;
    esac
done
clear

echo "Installation finished. You can now reboot your system."
ip -c -br a