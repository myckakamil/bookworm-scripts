[ "$EUID" -ne 0 ] && {
  echo "Please run as root"
  exit
}

echo > /etc/X11/xorg.conf.d/40-libinput.conf <<EOF
Section "InputClass"
    Identifier "libinput pointer catchall"
    MatchIsPointer "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    Option "AccelProfile" "flat"
EndSection
EOF

echo "Flat mouse acceleration profile set. Please restart your X session."