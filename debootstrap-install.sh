clear
echo -e "Debian installation script\n\nWorks only on UEFI systems, and creates only two partitions: EFI and root.\nThis script will erase all data on the selected disk.\n"


echo -n "Updating system"
while true; do
    for s in / - \\ \|; do
        printf "\rUpdating system and installing packages %s" "$s"
        sleep 0.1
    done
done &
SPIN_PID=$!

apt-get update > /dev/null
apt-get install -y debootstrap parted figlet > /dev/null

kill $SPIN_PID
printf "\rSystem updated and packages installed \n"


# Checking if the script is running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

# Checking if the system is running in UEFI mode
if [ -d /sys/firmware/efi ]; then
    echo "You are using UEFI system."
    BOOT_MODE=UEFI
    else
    echo "You are using BIOS system."
    BOOT_MODE=BIOS
fi

# Checking if the system is connected to the internet
if ! ping -c 1 google.com &> /dev/null; then
    echo "No internet connection. Please connect to the internet and run the script again."
    exit 1
fi

clear

echo "How do you want to name your computer?"
read -p "Enter the hostname: " HOSTNAME

while true; do
    echo "What Debian version do you want to install?"
    echo "1. Stable"
    echo "2. Testing NOT TESTED YET"
    echo "3. Sid NOT TESTED YET"
    read -p "Choose your preferred Debian version: " WERSJA
    case $WERSJA in
        1)
            WERSJA="stable"
            echo "You selected Debian Stable."
            break
            ;;
        2)
            WERSJA="testing"
            echo "You selected Debian Testing."
            break
            ;;
        3)
            WERSJA="sid"
            echo "You selected Debian Sid."
            break
            ;;
        *)
            echo "Invalid choice. Please select 1, 2, or 3."
            ;;
    esac
done
clear

while true; do
    DYSKI=($(lsblk -d -n -o NAME))

    echo "Enter the disk where you want to install Debian:"
    for i in "${!DYSKI[@]}"; do
        echo "$((i+1)). ${DYSKI[$i]}"
    done

    read -p "Enter the number of your choice: " WYBOR

    if [[ "$WYBOR" =~ ^[0-9]+$ ]] && [ "$WYBOR" -ge 1 ] && [ "$WYBOR" -le "${#DYSKI[@]}" ]; then
        DYSK="/dev/${DYSKI[$((WYBOR-1))]}"
        echo "You selected disk: $DYSK."
        break
    else
        echo "Invalid choice. Please select a valid number."
    fi
done
clear

while true; do
    echo "Which filesystem do you want to use?"
    echo "1. ext4"
    echo "2. btrfs"
    echo "3. xfs   TODO"
    echo "4. zfs   TODO"
    read -p "Enter the number of your choice: " FS

    case $FS in
        1)
            FS=ext4
            break
            ;;
        2)
            FS=btrfs
            break
            ;;
        3)
            echo "XFS is not supported by this script yet."
            ;;
        4)
            echo "ZFS is not supported by this script yet."
            ;;
        *)
            echo "Invalid choice. Please select a valid number."
            ;;
    esac
done
clear

while true; do
    read -p "WARNING: This will erase all data on $DYSK. Continue? (yes/no): " confirm
    case $confirm in
        yes | y)
            break
            ;;
        no | n)
            echo "Operation cancelled."
            exit 1
            ;;
        *)
            echo "Invalid choice. Please select 'yes' or 'no'."
            ;;
    esac
done
clear

echo "Creating partitions on $DYSK..."

if [ "$BOOT_MODE" == "UEFI" ]; then
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
            mkfs.ext4 "${DYSK}2"
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
    parted "$DYSK" --script mkpart biosboot 1MiB 2MiB
    parted "$DYSK" --script set 1 bios_grub on
    echo "BIOS boot partition created."

    
    echo "Creating partitions on $DYSK..."

    # Tworzenie tablicy partycji GPT i podstawowych partycji
    parted "$DYSK" --script mklabel gpt \
        mkpart boot fat32 2MiB 1002MiB \
        set 2 esp on \
        mkpart primary $FS 1002MiB 100%

    # Tworzenie partycji BIOS Boot
    create_and_format_bios_partition

    echo "Partitions created:"
    lsblk "$DYSK"

    echo "Finished partitioning $DYSK."

    echo "Formatting partitions..."
    mkfs.vfat "${DYSK}2" 
    case $FS in
        ext4)
            mkfs.ext4 "${DYSK}3"
            echo "Mounting partitions..."
            mount "${DYSK}3" /mnt
            mkdir -p /mnt/boot/efi
            mount "${DYSK}2" /mnt/boot/efi
            ;;
        btrfs)
            mkfs.btrfs "${DYSK}3" -f
            echo "Creating subvolumes..."
            mount "${DYSK}3" /mnt
            btrfs subvolume create /mnt/@
            btrfs subvolume create /mnt/@home
            btrfs subvolume create /mnt/@root
            btrfs subvolume create /mnt/@var
            btrfs subvolume create /mnt/@tmp
            btrfs subvolume create /mnt/@snapshots

            echo "Mounting subvolumes..."
            mount -o noatime,compress=zstd,subvol=@ "$DYSK"3 /mnt
            mkdir -p /mnt/{home,root,var,tmp,.snapshots}
            mkdir -p /mnt/boot/efi
            mount -o noatime,compress=zstd,subvol=@home "$DYSK"3 /mnt/home
            mount -o noatime,compress=zstd,subvol=@var "$DYSK"3 /mnt/var
            mount -o noatime,compress=zstd,subvol=@tmp "$DYSK"3 /mnt/tmp
            mount -o noatime,compress=zstd,subvol=@snapshots "$DYSK"3 /mnt/.snapshots
            mount "${DYSK}"2 /mnt/boot/efi
            ;;
        *)
            ;;
    esac
fi

    clear

figlet "Installing Debian" 
echo "$WERSJA on $DYSK"

debootstrap $WERSJA /mnt

echo "deb http://deb.debian.org/debian $WERSJA main contrib non-free non-free-firmware" > /mnt/etc/apt/sources.list
if [ "$WERSJA" == "stable" ]; then
    echo "deb http://deb.debian.org/debian-security/ $WERSJA-security main contrib non-free non-free-firmware" >> /mnt/etc/apt/sources.list
    echo "deb http://deb.debian.org/debian $WERSJA-updates main contrib non-free non-free-firmware" >> /mnt/etc/apt/sources.list
fi

for dir in sys dev proc; do
    mount --rbind /$dir /mnt/$dir && mount --make-rslave /mnt/$dir
done

chroot /mnt /bin/bash -c "apt-get update && apt-get upgrade -y && apt-get install -y linux-image-amd64 grub-efi-amd64 efibootmgr sudo"
chroot /mnt /bin/bash -c "grub-install /dev/${DYSK}1 && update-grub"

# Setting up fstab
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

echo "Change your root password"
echo "Root password:"
chroot /mnt /bin/bash -c "passwd"
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

# Creating a new user
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