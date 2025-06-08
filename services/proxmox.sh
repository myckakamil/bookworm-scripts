#!/bin/bash

while true; do
read -p "Would you like to change your currnet hostname $HOSTNAME? (y/n)" CONFIRM
    case $CONFIRM in
        yes | y)
            read -p "New hostname: " HOSTNAME
            break
            ;;
        no | n)
            echo "Hostname not changed"
            break
            ;;
        *)
            echo "Invalid choice. Please select 'yes' or 'no'."
            ;;
    esac
done

while true; do
    read -p "Provide your domain: " DOMAIN 
    read -p "Are you sure? $DOMAIN: (y/n)" CONFIRM
    case $CONFIRM in
        yes | y)
            break
            ;;
        no | n)
            ;;
        *)
            echo "Invalid choice. Please select 'yes' or 'no'."
            ;;
    esac
done

FQDN="${HOSTNAME}.${DOMAIN}"

INTERFACES=($(ip -o link show | awk -F': ' '{print $2}' | grep -v lo))

if [ ${#interfaces[@]} -eq 0 ]; then
    echo "No network interfaces found. Exiting."
    exit 1
fi

echo "Available network interfaces:"
PS3="Select interface for internet access: "
select INTERFACE in "${INTERFACES[@]}"; do
    if [[ -n "$INTERFACE" ]]; then
        break
    else
        echo "Invalid selection. Please choose a valid number."
    fi
done

IP=$(ip -o -4 a s | grep $INTERFACE | awk '{print $4}' | cut -d/ -f1)


echo $HOSTNAME > /etc/hostname

systemctl disable dhcpd
cp /etc/hosts /etc/hosts.bak

cat << EOF > /etc/hosts
127.0.0.1   localhost
$IP   $FQDN   $HOSTNAME
EOF

sed -i s/dhcp/static/g /etc/network/interfaces
tee -a /etc/network/interfaces << EOF
auto vmbr0
iface vmbr0 inet dhcp
    bridge-ports $INTERFACE
    bridge-stp off
    bridge-fd 0
EOF

echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list

wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg 
# verify
sha512sum /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg 
7da6fe34168adc6e479327ba517796d4702fa2f8b4f0a9833f5ea6e6b48f6507a6da403a274fe201595edc86a84463d50383d07f64bdde2e3658108db7d6dc87 /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg 

apt update && apt full-upgrade -y
apt install proxmox-default-kernel -y
apt install proxmox-ve postfix open-iscsi chrony -y
apt remove linux-image-amd64 'linux-image-6.1*' -y
sed -i 's/^/#/' /etc/apt/sources.list.d/pve-enterprise.list

update-grub
apt remove os-prober -y

echo "====================================="
echo "Proxmox have been installed"
echo "You can access it after reboot"
echo "It will be available at: https://${IP}:8006"
echo "or https://$FQDN:8006 if you set DNS records"
echo "====================================="
echo "System will reboot in 5 seconds"
sleep 5
systemctl reboot
