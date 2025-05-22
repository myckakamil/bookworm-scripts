DOMENA="test.mycka.net"
HOSTNAME="proxmox"
INTERFACE=ens18
IP=$(ip -o -4 a s | grep $INTERFACE | awk '{print $4}' | cut -d/ -f1)
FQDN="${HOSTNAME}.${DOMENA}"

echo $HOSTNAME > /etc/hostname

systemctl disable dhcpd
cp /etc/hosts /etc/hosts.bak

cat << EOF > /etc/hosts
127.0.0.1   localhost
$IP   $FQDN   $HOSTNAME
EOF

echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list

wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg 
# verify
sha512sum /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg 
7da6fe34168adc6e479327ba517796d4702fa2f8b4f0a9833f5ea6e6b48f6507a6da403a274fe201595edc86a84463d50383d07f64bdde2e3658108db7d6dc87 /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg 

apt update && apt full-upgrade
apt install proxmox-default-kernel -y
apt install proxmox-ve postfix open-iscsi chrony -y
apt remove linux-image-amd64 'linux-image-6.1*' -y
update-grub
apt remove os-prober

echo "Proxmox have been installed. You can access it after reboot"
echo "It will be available at: ${IP}:8006"
echo "System will reboot in 5 seconds"
sleep 5
systemctl reboot
