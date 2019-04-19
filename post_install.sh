#!/bin/sh

# Create user
pw useradd -n smarthome -c "SmartHomeNG user" -s /usr/local/bin/bash -m

# Install missing python packages and upgrade existing
ln -s /usr/local/bin/pip-3.6 /usr/local/bin/pip
pip install --upgrade pip setuptools wheel pymysql

# Install SmartHomeNG
mkdir /usr/local/smarthome
cd /usr/local
git clone https://github.com/smarthomeNG/smarthome.git
git clone git://github.com/smarthomeNG/plugins.git smarthome/plugins
chown -R smarthome:smarthome /usr/local/smarthome
cd smarthome
pip install -r requirements/base.txt
echo 'me:\' >> /home/smarthome/.login_conf
echo '    :lang=en_US.UTF-8:' >> /home/smarthome/.login_conf

# Configure Database
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1 > /root/dbpassword
USER="smarthome"
DB="smarthome"
PASS=`cat /root/dbpassword`
mysql -u root <<-EOF
UPDATE mysql.user SET Password=PASSWORD('${PASS}') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';

CREATE USER '${USER}'@'localhost' IDENTIFIED BY '${PASS}';
CREATE DATABASE ${DB};
GRANT ALL PRIVILEGES ON ${DB}.* TO '${USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Install SmartVISU
mkdir -p /usr/local/www/data
git clone https://github.com/Martin-Gleiss/smartvisu.git /usr/local/www/data
chown -R www:smarthome /usr/local/www/data
chmod 775 /usr/local/www/data

# Configure PHP
cp /usr/local/etc/php.ini-production /usr/local/etc/php.ini

# Install KNXD
mkdir /usr/local/knxd
cd /usr/local
git clone https://github.com/knxd/knxd.git
cd knxd
./bootstrap.sh

# Enable services
sysrc sshd_enable=yes
sysrc php_fpm_enable=yes
sysrc mysql_enable=yes
sysrc lighttpd_enable=yes

# Start services
service sshd start 2>/dev/null
service php-fpm start 2>/dev/null
service mysql-server start 2>/dev/null
service lighttpd start 2>/dev/null
