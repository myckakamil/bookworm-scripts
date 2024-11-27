#!/bin/bash
clear
echo -e "Nextcloud installation script"

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

echo "Updating system and installing dependencies"
apt-get update && apt-get dist-upgrade -y > /dev/null
apt-get install -y mariadb-server unzip php php-apcu php-bcmath php-cli php-common php-curl php-gd php-gmp php-imagick php-intl php-mbstring php-mysql php-zip php-xml certbot python3-certbot-apache libmagickcore-6.q16-6-extra
phpenmod bcmath gmp imagick intl

echo "Securing MySQL"
mysql_secure_installation

read -sp "Enter the MySQL root password: " MYSQL_ROOT_PASSWORD
read -sp "Provide password for 'nextcloud' database: " DB_PASSWORD

mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE DATABASE nextcloud;
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
FLUSH PRIVILEGES;
EOF

echo "Downloading Nextcloud"
wget https://download.nextcloud.com/server/releases/latest.zip
unzip latest.zip
rm latest.zip

read -p "Please, provide your website domain name: " WEBSITE

mv nextcloud "$WEBSITE"
chown www-data:www-data -R "$WEBSITE"
mv "$WEBSITE" /var/www/

a2dissite 000-default
cat >/etc/apache2/sites-available/$WEBSITE.conf <<EOF
<VirtualHost *:80>
    DocumentRoot "/var/www/$WEBSITE"
    ServerName $WEBSITE

    <Directory "/var/www/$WEBSITE">
        Options MultiViews FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    TransferLog /var/log/apache2/${WEBSITE}_access.log
    ErrorLog /var/log/apache2/${WEBSITE}_error.log
</VirtualHost>
EOF
a2ensite "$WEBSITE.conf"
a2enmod dir env headers mime rewrite ssl
systemctl restart apache2.service

sed -i \
    -e 's/^memory_limit = .*/memory_limit = 512M/' \
    -e 's/^upload_max_filesize = .*/upload_max_filesize = 200M/' \
    -e 's/^max_execution_time = .*/max_execution_time = 60/' \
    -e 's/^post_max_size = .*/post_max_size = 200M/' \
    -e 's|^date.timezone = .*|date.timezone = Europe/Warsaw|' \
    -e 's/^opcache.enable=.*/opcache.enable=1/' \
    -e 's/^opcache.memory_consumption=.*/opcache.memory_consumption=128/' \
    -e 's/^opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=16/' \
    -e 's/^opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/' \
    -e 's/^opcache.revalidate_freq=.*/opcache.revalidate_freq=2/' \
    -e 's/^opcache.save_comments=.*/opcache.save_comments=1/' \
    "/etc/php/8.2/apache2/php.ini"

read -p "Do you want to run certbot to acquire an SSL certificate? (y/n): " CERTBOT

if [[ "$CERTBOT" == "y" || "$CERTBOT" == "Y" ]]; then
    echo "Starting certbot..."
    certbot --apache
    if [[ $? -eq 0 ]]; then
        echo "SSL certificate successfully acquired."
    else
        echo "An error occurred while acquiring the SSL certificate."
    fi
else
    echo "Skipping SSL certificate acquisition."
fi