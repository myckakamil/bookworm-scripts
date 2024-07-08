echo "Debian installation script"
echo "Works only on UEFI systems, and create only two partitions: EFI and root."

show_menu() {
    echo "What Debian version do you want to install?"
    echo "1. Stable"
    echo "2. Testing"
    echo "3. Sid"
}

while true; do
    show_menu
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



# Zapytaj o preferowany system plików
while true; do
    echo "Which filesystem do you want to use?"
    echo "1. ext4"
    echo "2. btrfs TODO"
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
            FS=xfs
            break
            ;;
        4)
            FS=zfs
            break
            ;;
        *)
            echo "Invalid choice. Please select a valid number."
            ;;
    esac
done

read -p "WARNING: This will erase all data on $DYSK. Continue? (yes/no): " confirm
case $confirm in
    yes)
        ;;
    no)
        echo "Operation cancelled."
        exit 1
        ;;
    *)
        echo "Invalid choice. Please select 'yes' or 'no'."
        ;;
esac

# Tworzenie partycji na wybranym dysku
echo "Creating partitions on $DYSK..."

# Komendy parted
parted "$DYSK" --script mklabel gpt \
    mkpart boot fat32 1MiB 1001MiB \
    set 1 esp on \
    mkpart primary $FS 1001MiB 100%

# Wyświetlenie informacji o utworzonych partycjach
echo "Partitions created:"
lsblk "$DYSK"

# Zmienna 'DYSK' przechowuje teraz pełną nazwę wybranego dysku
echo "Finished partitioning $DYSK."

# Formatowanie partycji
echo "Formatting partitions..."
mkfs.vfat "${DYSK}1"
mkfs."$FS" "${DYSK}2"

mount "${DYSK}2" /mnt
mkdir -p /mnt/boot/efi
mount "${DYSK}1" /mnt/boot/efi

apt-get update && apt-get upgrade -y
apt-get install -y debootstrap

# Instalacja systemu
debootstrap $WERSJA /mnt

cat <<EOF > /mnt/etc/apt/sources.list
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware

deb http://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
EOF

for dir in sys dev proc; do
    mount --rbind /$dir /mnt/$dir && mount --make-rslave /mnt/$dir
done

chroot /mnt /bin/bash -c "apt-get update && apt-get upgrade -y && apt-get install -y linux-image-amd64 grub-efi-amd64 efibootmgr"
chroot /mnt /bin/bash -c "grub-install /dev/${DYSK}1 && update-grub"


EFI_UUID=$(blkid -s UUID -o value "${DYSK}1")
ROOT_UUID=$(blkid -s UUID -o value "${DYSK}2")

cat <<EOF > /mnt/etc/fstab
UUID=$ROOT_UUID / $FS defaults 0 1
UUID=$EFI_UUID /boot/efi vfat defaults 0 1
EOF

echo "Installation finished. Change your root password and reboot."
echo "Root password:"
chroot /mnt /bin/bash -c "passwd"