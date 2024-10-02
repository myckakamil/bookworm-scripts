echo "Asterisk installation script" 

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

apt-get update && apt-get -y install build-essential git curl wget libnewt-dev libssl-dev libncurses5-dev subversion libsqlite3-dev libjansson-dev libxml2-dev uuid-dev default-libmysqlclient-dev libedit-dev liblua5.2-dev lua5.4 libopus-dev xmlstarlet 

# Download and extract Asterisk
cd /usr/src/
wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-20-current.tar.gz
tar xvf asterisk-20-current.tar.gz
cd /usr/src/asterisk-20.*
./configure
manuselect/menuselect --enable pbx_lua menuselect --enable codec_opus menuselect --enable codec_g729
make
make install
make config
make install-logrotate