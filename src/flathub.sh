# Check if user is root
[ "$EUID" -ne 0 ] && {
  echo "Please run as root"
  exit
}

# Flathub installation
apt install -y flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo