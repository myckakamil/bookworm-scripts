apt-get install -y build-essential openssl libssl-dev libcurl4-openssl-dev libxml2-dev libpcre3-dev mariadb-server mariadb-client mysql-common git bison gcc make pkg-config libncurses-dev flex
git clone --recurse-submodules https://github.com/OpenSIPS/opensips.git -b 3.5 opensips-3.5
cd opensips-3.5
make all
make install

# Systemd unit don't work. Not sure why. Besides that, all seems to be fine
cat > /etc/systemd/system/opensips.service << EOF
[Unit]
Description=OpenSIPS is a very fast and flexible SIP (RFC3261) server
Documentation=man:opensips
After=network.target mysqld.service postgresql.service rtpproxy.service

[Service]
Type=forking
User=opensips
Group=opensips
RuntimeDirectory=opensips
RuntimeDirectoryMode=775
Environment=P_MEMORY=32 S_MEMORY=32
EnvironmentFile=-/etc/default/opensips
PermissionsStartOnly=yes
PIDFile=%t/opensips/opensips.pid
ExecStart=/usr/sbin/opensips -P %t/opensips/opensips.pid -f /etc/opensips/opensips.cfg -m $S_MEMORY -M $P_MEMORY $OPTIONS
ExecStop=/usr/bin/pkill --pidfile %t/opensips/opensips.pid
Restart=always
TimeoutStopSec=30s
LimitNOFILE=262144

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable opensips
systemctl start opensips

clear
echo "Now you can edit config file, located at - /usr/local/etc/opensips"
