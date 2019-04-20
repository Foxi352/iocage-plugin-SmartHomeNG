#!/bin/sh

# Create user
pw useradd -n smarthome -c "SmartHomeNG user" -s /bin/csh -m

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
sysrc mysql_enable=yes
service mysql-server start
openssl rand -base64 15 > /root/dbpassword
USER="smarthome"
DB="smarthome"
PASS=`cat /root/dbpassword`
mysql -u root <<-EOF
UPDATE mysql.user SET Password=PASSWORD('${PASS}') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
DROP DATABASE test;

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
sed -i '' 's/.*listen =.*/listen = \/var\/run\/php-fpm.sock/'  /usr/local/etc/php-fpm.d/www.conf
sed -i '' 's/.*listen.owner =.*/listen.owner = www/'  /usr/local/etc/php-fpm.d/www.conf
sed -i '' 's/.*listen.group =.*/listen.group = www/'  /usr/local/etc/php-fpm.d/www.conf
sed -i '' 's/.*listen.mode =.*/listen.mode = 0660/'  /usr/local/etc/php-fpm.d/www.conf
sed -i '' 's/.*cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/'  /usr/local/etc/php.ini


# Configure lighthttpd
sed -i '' 's/.*server.use-ipv6 =.*/server.use-ipv6 = "disable"/'  /usr/local/etc/lighttpd/lighttpd.conf
sed -i '' 's/.*include \"conf.d\/fastcgi.conf\".*/include \"conf.d\/fastcgi.conf\"/'  /usr/local/etc/lighttpd/modules.conf
cat <<EOF >> /usr/local/etc/lighttpd/conf.d/fastcgi.conf
fastcgi.server += ( ".php" =>
        ((
                "socket" => "/var/run/php-fpm.sock",
                "broken-scriptfilename" => "enable"
        ))
)
EOF


# Install KNXD
mkdir /usr/local/knxd
cd /usr/local
git clone https://github.com/knxd/knxd.git
cd knxd
./bootstrap.sh
./configure --disable-systemd --disable-usb CPPFLAGS=-I/usr/local/include/ LDFLAGS=-L/usr/local/lib
gmake
gmake install

# Set correct permissions
chmod 555 /etc/rc.d/smarthomeng
chmod 555 /etc/rc.d/knxd

# Remove fortune tips
sed -i '' '/\/usr\/bin\/fortune/d' ~smarthome/.login
sed -i '' '/\/usr\/bin\/fortune/d' ~smarthome/.profile

# Enable services
sysrc sshd_enable=yes
sysrc php_fpm_enable=yes
sysrc lighttpd_enable=yes
sysrc smarthomeng_enable=yes

# Start services
service sshd start 2>/dev/null
service mysql-server restart
service php-fpm start 2>/dev/null
service smarthomeng start 2>/dev/null
service lighttpd start 2>/dev/null
