apt-get install -y build-essential openssl libssl-dev libcurl4-openssl-dev libxml2-dev libpcre3-dev mariadb-server mariadb-client mysql-common git bison gcc make pkg-config libncurses-dev flex
git clone --recurse-submodules https://github.com/OpenSIPS/opensips.git -b 3.5 opensips-3.5
cd opensips-3.5
make all
make install

# Systemd unit don't work. Not sure why. Besides that, all seems to be fine
cat > /etc/systemd/system/opensips.service << EOF
[Unit]
Description=OpenSIPS - Open SIP Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/sbin/opensips -f /usr/local/etc/opensips/opensips.cfg -m 128 -M 16
ExecStop=/usr/local/sbin/opensipsctl stop
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable opensips
systemctl start opensips