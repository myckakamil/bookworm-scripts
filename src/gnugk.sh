apt update
apt install -y build-essential cmake libssl-dev libexpat1-dev libpcre3-dev libx11-dev libasound2-dev libv4l-dev libssl-dev flex bison autoconf

git clone https://github.com/willamowius/ptlib.git
cd ptlib
./configure --prefix=/usr/local
make
make install
cd ..

git clone https://github.com/willamowius/h323plus.git
cd h323plus
./configure --prefix=/usr/local --with-ptlib=/usr/local
make
make install
cd ..


git clone https://github.com/willamowius/gnugk
cd gnugk
./configure
make
make install

export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/local.conf
sudo ldconfig

useradd -r -s /bin/false gnugk
mkdir -p /etc/gnugk
chown -R gnugk:gnugk /etc/gnugk

cat >> /etc/systemd/system/gnugk.service <<EOF
[Unit]
Description=GNU Gatekeeper
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/gnugk -c /etc/gnugk/gnugk.ini
WorkingDirectory=/etc/gnugk
Restart=always
RestartSec=5
User=gnugk
Group=gnugk

[Install]
WantedBy=multi-user.target
EOF

