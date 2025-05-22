DOMAIN="domain.net"
DB_PASSWORD="password"
SERVER_IP="127.0.0.1"

apt update && apt upgrade -y
apt install -y sudo git apache2 mariadb-server php php8.2 php8.2-common php8.2-mysql \
php-curl php-mbstring php-gd php-xml php-zip \
php-tidy php-dom php-mysql php-fpm php-intl \
composer unzip libapache2-mod-php

systemctl start apache2 mariadb
systemctl enable apache2 mariadb

mysql_secure_installation <<EOF
y
y
${DB_PASSWORD}
${DB_PASSWORD}
y
y
y
y
EOF

mysql -e "DROP DATABASE IF EXISTS bookstack;"
mysql -e "CREATE DATABASE bookstack CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
mysql -e "CREATE USER 'bookstack'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
mysql -e "GRANT ALL PRIVILEGES ON bookstack.* TO 'bookstack'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

cd /var/www
git clone https://github.com/BookStackApp/BookStack.git --branch release --single-branch
cd BookStack

sudo -u www-data composer install --no-dev --no-interaction

cp .env.example .env
sed -i "s@APP_URL=.*@APP_URL=http://${DOMAIN}@" .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=bookstack/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=bookstack/" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" .env

# Generate application keys
sudo -u www-data php artisan key:generate --force
sudo -u www-data php artisan config:cache
sudo -u www-data php artisan route:cache

# Set permissions
chown -R www-data:www-data /var/www/BookStack
find /var/www/BookStack -type d -exec chmod 755 {} \;
find /var/www/BookStack -type f -exec chmod 644 {} \;
chmod -R 775 /var/www/BookStack/storage
chmod -R 775 /var/www/BookStack/bootstrap/cache

# Configure Apache for reverse proxy backend
cat > /etc/apache2/sites-available/bookstack.conf <<EOF
<VirtualHost ${SERVER_IP}:80>
    ServerName ${DOMAIN}
    ServerAlias www.${DOMAIN}
    DocumentRoot /var/www/BookStack/public

    <Directory /var/www/BookStack/public>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
        <IfModule mod_php8.c>
            php_admin_value engine On
        </IfModule>
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/bookstack_error.log
    CustomLog \${APACHE_LOG_DIR}/bookstack_access.log combined

    # Reverse proxy headers (optional)
    RequestHeader set X-Forwarded-Proto "http"
    RequestHeader set X-Forwarded-Port "80"
</VirtualHost>
EOF

a2dissite 000-default.conf
a2ensite bookstack.conf
a2enmod rewrite headers php8.2

echo "Listen ${SERVER_IP}:80" > /etc/apache2/ports.conf

systemctl restart apache2 mariadb
sudo -u www-data php artisan migrate --force