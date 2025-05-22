apt-get install -y build-essential openssl libssl-dev libcurl4-openssl-dev libxml2-dev libpcre3-dev mariadb-server mariadb-client mysql-common git bison gcc make pkg-config libncurses-dev flex
git clone --recurse-submodules https://github.com/OpenSIPS/opensips.git -b 3.5 opensips-3.5
cd opensips-3.5
make all
make install

useradd -r -s /bin/false opensips
mv /usr/local/etc/opensips /etc/opensips
chown -R opensips:opensips /etc/opensips


cat > /etc/systemd/system/opensips.service << EOF
[Unit]
Description=OpenSIPS SIP Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/opensips -f /etc/opensips/opensips.cfg -P /var/run/opensips.pid
WorkingDirectory=/etc/opensips
Restart=always
RestartSec=5
User=gnugk
Group=gnugk


[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable opensips
systemctl start opensips

clear
echo "Now you can edit config file, located at - /etc/opensips"
