#!/bin/bash

# Vesta Ubuntu installer v.01

#----------------------------------------------------------#
#                  Variables&Functions                     #
#----------------------------------------------------------#
export PATH=$PATH:/sbin
export DEBIAN_FRONTEND=noninteractive
RHOST='apt.vestacp.com'
CHOST='c.vestacp.com'
REPO='raring'
VERSION='0.9.8/ubuntu'
arch=$(arch)
os=$(head -n 1 /etc/issue | cut -f 1 -d ' ')
release=$(head -n 1 /etc/issue | cut -f 2 -d ' ' )
codename=$(lsb_release -cs)
memory=$(grep 'MemTotal' /proc/meminfo |tr ' ' '\n' |grep [0-9])
software="nginx apache2 apache2-utils apache2.2-common apache2-suexec rrdtool
    libapache2-mod-ruid2 libapache2-mod-rpaf libapache2-mod-fcgid bind9 idn
    mysql-server mysql-common mysql-client php5-common php5-cgi php5-mysql
    libapache2-mod-php5 vsftpd mc exim4 exim4-daemon-heavy clamav-daemon flex
    dovecot-imapd dovecot-pop3d phpMyAdmin awstats webalizer jwhois rssh git
    spamassassin roundcube roundcube-mysql roundcube-plugins apparmor-utils
    apache2-suexec vesta vesta-nginx vesta-php"


help() {
    echo "usage: $0 [OPTIONS]
   -e, --email                Define email address
   -h, --help                 Print this help and exit
   -f, --force                Force installation
   -n, --noupdate             Do not run apt-get upgrade command"
    exit 1
}

# Password generator
gen_pass() {
    MATRIX='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    LENGTH=10
    while [ ${n:=1} -le $LENGTH ]; do
        PASS="$PASS${MATRIX:$(($RANDOM%${#MATRIX})):1}"
        let n+=1
    done
    echo "$PASS"
}


#----------------------------------------------------------#
#                    Verifications                         #
#----------------------------------------------------------#

# Translating argument to --gnu-long-options
for arg; do
    delim=""
    case "$arg" in
        --help)         args="${args}-h " ;;
        --force)        args="${args}-f " ;;
        --email)        args="${args}-e " ;;
        --noupdate)     args="${args}-n " ;;
        *)              [[ "${arg:0:1}" == "-" ]] || delim="\""
                        args="${args}${delim}${arg}${delim} ";;
    esac
done
eval set -- "$args"

# Getopt
while getopts "dhfne:" Option; do
    case $Option in
        h) help ;;                        # Help
        e) email=$OPTARG ;;               # Set email
        f) force='yes' ;;                 # Force apt-get install
        n) noupdate='yes' ;;              # Disable apt-get upgrade
        *) help ;;                        # Default
    esac
done

# Am I root?
if [ "x$(id -u)" != 'x0' ]; then
    echo 'Error: this script can only be executed by root'
    exit 1
fi

# Check supported version
if [ -e '/etc/redhat-release' ]; then
    echo 'Error: sorry, this installer can work only on Debian or Ubuntu'
    exit 1
fi

# Check supported OS
if [ $os !=  'Ubuntu' ] && [ $os != 'Debian' ]; then
    echo 'Error: sorry, this installer can work only on Debian or Ubuntu'
fi

# Check wget
if [ ! -e '/usr/bin/wget' ]; then
    apt-get -y install wget
    if [ $? -ne 0 ]; then
        echo "Error: can't install wget"
        exit 1
    fi
fi

# Check repo availability
wget -q "$CHOST/$VERSION/vesta.conf" -O /dev/null
if [ $? -ne 0 ]; then
    echo "Error: no access to $REPO repository"
    exit 1
fi

# Check installed packages
tmpfile=$(mktemp -p /tmp)
dpkg --get-selections > $tmpfile
for pkg in exim4 mysql-server apache2 nginx vesta; do
    if [ ! -z "$(grep $pkg $tmpfile)" ]; then
        conflicts="$pkg $conflicts"
    fi
done
rm -f $tmpfile
if [ ! -z "$conflicts" ] && [ -z "$force" ]; then
    echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
    echo
    echo 'Following rpm packages are already installed:'
    echo "$conflicts"
    echo
    echo 'It is highly recommended to remove them before proceeding.'
    echo 'If you want to force installation run this script with -f option:'
    echo "Example: bash $0 --force"
    echo
    echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
    echo
    exit 1
fi

# Check server type
if [ "$memory" -lt '350000' ] && [ -z "$force" ]; then
    echo "Error: not enough memory to install Vesta Control Panel."
    echo -e "\nMinimum RAM required: 350Mb"
    echo 'If you want to force installation run this script with -f option:'
    echo "Example: bash $0 --force"
    exit 1
fi
srv_type='micro'

if [ "$memory" -gt '1000000' ]; then
    srv_type='small'
fi

if [ "$memory" -gt '3000000' ]; then
    srv_type='medium'
fi

if [ "$memory" -gt '7000000' ]; then
    srv_type='large'
fi

# Are you sure ?
if [ -z $email ]; then
    clear
    echo
    echo ' _|      _|  _|_|_|_|    _|_|_|  _|_|_|_|_|    _|_|     '
    echo ' _|      _|  _|        _|            _|      _|    _|   '
    echo ' _|      _|  _|_|_|      _|_|        _|      _|_|_|_|   '
    echo '   _|  _|    _|              _|      _|      _|    _|   '
    echo '     _|      _|_|_|_|  _|_|_|        _|      _|    _|   '
    echo
    echo '                                  Vesta Control Panel'
    echo
    echo
    echo 'Following software will be installed on your system:'
    echo '   - Nginx frontend web server'
    echo '   - Apache application web server'
    echo '   - Bind DNS server'
    echo '   - Exim mail server'
    echo '   - Dovecot IMAP and POP3 server'
    if [ "$srv_type" = 'medium' ] ||  [ "$srv_type" = 'large' ]; then
        echo '   - Clam mail antivirus'
        echo '   - SpamAssassin antispam'
    fi
    echo '   - MySQL database server'
    echo '   - Vsftpd FTP server'
    echo 
    echo '   * SELinux and Iptables will be disabled'
    echo 

    read -p 'Do you want to proceed? [y/n]): ' answer
    if [ "$answer" != 'y' ] && [ "$answer" != 'Y'  ]; then
        echo 'Goodbye'
        exit 1
    fi

    # Check email
    read -p 'Please enter valid email address: ' email
fi

# Validate email
local_part=$(echo $email | cut  -s -f1 -d\@)
remote_host=$(echo $email | cut -s -f2 -d\@)
mx_failed=1
if [ ! -z "$remote_host" ] && [ ! -z "$local_part" ]; then
    /usr/bin/host -t mx "$remote_host" > /dev/null 2>&1
    mx_failed="$?"
fi

if [ "$mx_failed" -eq 1 ]; then
    echo "Error: email $email is not valid"
    exit 1
fi


#----------------------------------------------------------#
#                   Install repository                     #
#----------------------------------------------------------#
# Let's start
echo -e "\n\n\n\nInstallation will take about 15 minutes ...\n"
sleep 5

# Update system
if [ -z "$noupdate" ]; then
    apt-get -y upgrade
    if [ $? -ne 0 ]; then
        echo 'Error: apt-get upgrade failed'
        exit 1
    fi
fi

# Install nginx repo
apt_list=/etc/apt/sources.list
check_nginx_repo=$(grep nginx.org $apt_list)
if [ -z "$check_nginx_repo" ]; then
    echo "deb http://nginx.org/packages/ubuntu/ $codename nginx" >> $apt_list
    wget http://nginx.org/keys/nginx_signing.key -O /tmp/nginx_signing.key
    apt-key add /tmp/nginx_signing.key
fi

# Install vesta repo
check_vesta_repo=$(grep $RHOST $apt_list)
if [ -z "$check_vesta_repo" ]; then
    echo "deb http://$RHOST/ $codename free" >> $apt_list
fi
wget $CHOST/deb_signing.key -O deb_signing.key 
apt-key add deb_signing.key



#----------------------------------------------------------#
#                         Backups                          #
#----------------------------------------------------------#

# Prepare backup tree
vst_backups="/root/vst_install_backups/$(date +%s)"
mkdir -p $vst_backups/nginx
mkdir -p $vst_backups/apache2
mkdir -p $vst_backups/mysql
mkdir -p $vst_backups/exim4
mkdir -p $vst_backups/dovecot
mkdir -p $vst_backups/clamav
mkdir -p $vst_backups/spamassassin
mkdir -p $vst_backups/vsftpd
mkdir -p $vst_backups/bind
mkdir -p $vst_backups/vesta/admin
mkdir -p $vst_backups/home

# Backup sudoers
if [ -e '/etc/sudoers' ]; then
    cp /etc/sudoers $vst_backups/
fi

# Backup nginx
service nginx stop > /dev/null 2>&1
if [ -e '/etc/nginx/nginx.conf' ]; then
    cp -r /etc/nginx/* $vst_backups/nginx/
fi

# Backup apache2
service apache2 stop > /dev/null 2>&1
if [ -e '/etc/apache2/apache2.conf' ]; then
    cp -r /etc/apache2/* $vst_backups/apache2/
fi

# Backup bind9
service bind9 stop > /dev/null 2>&1
if [ -e '/etc/bind/named.conf' ]; then
    cp -r /etc/bind/* $vst_backups/bind/
fi

# Backup vsftpd
service vsftpd stop > /dev/null 2>&1
if [ -e '/etc/vsftpd.conf' ]; then
    cp /etc/vsftpd.conf $vst_backups/vsftpd/
fi

# Backup exim4
service exim4 stop > /dev/null 2>&1
if [ -e '/etc/exim4/exim4.conf.template' ]; then
    cp -r /etc/exim4/* $vst_backups/exim4/
fi

# Backup clamav
service clamav-daemon stop > /dev/null 2>&1
if [ -e '/etc/clamav/clamd.conf' ]; then
    cp -r /etc/clamav/* $vst_backups/clamav/
fi

# Backup SpamAssassin
service spamassassin stop > /dev/null 2>&1
if [ -e '/etc/spamassassin/local.cf' ]; then
    cp -r /etc/spamassassin/* $vst_backups/spamassassin/
fi

# Backup dovecot
service dovecot stop > /dev/null 2>&1
if [ -e '/etc/dovecot.conf' ]; then
    cp /etc/dovecot.conf $vst_backups/dovecot/
fi
if [ -e '/etc/dovecot' ]; then
    cp -r /etc/dovecot/* $vst_backups/dovecot/
fi

# Backup MySQL stuff
service mysql stop > /dev/null 2>&1
if [ -e '/var/lib/mysql' ]; then
    mv /var/lib/mysql $vst_backups/mysql/mysql_datadir
fi
if [ -e '/etc/mysql/my.cnf' ]; then 
    cp -r /etc/mysql/* $vst_backups/mysql/
fi
if [ -e '/root/.my.cnf' ]; then
    mv /root/.my.cnf  $vst_backups/mysql/
fi

# Backup vesta
service vesta stop > /dev/null 2>&1
if [ -e '/usr/local/vesta' ]; then
    mv /usr/local/vesta/* $vst_backups/vesta/
fi


#----------------------------------------------------------#
#                     Install packages                     #
#----------------------------------------------------------#

# Exclude heavy packages
if [ "$srv_type" = 'micro' ]; then
    software=$(echo "$software" | sed -e 's/libapache2-mod-fcgid//')
    software=$(echo "$software" | sed -e 's/clamav-daemon//')
    software=$(echo "$software" | sed -e 's/spamassassin//')
fi

if [ "$srv_type" = 'small' ]; then
    software=$(echo "$software" | sed -e 's/clamav-daemon//')
    software=$(echo "$software" | sed -e 's/spamassassin//')
fi

# Install Vesta packages
apt-get update
apt-get -y install $software
if [ $? -ne 0 ]; then
    echo 'Error: apt-get install failed'
    exit 1
fi


#----------------------------------------------------------#
#                     Configure system                     #
#----------------------------------------------------------#

# Set writable permission on tmp directory
chmod 777 /tmp

# Enable password auth
sed -i "s/rdAuthentication no/rdAuthentication yes/g" /etc/ssh/sshd_config
service ssh restart

# AppArmor
aa-complain /usr/sbin/named

# Disable awstats cron
rm -f /etc/cron.d/awstats

# Set directory color
echo 'LS_COLORS="$LS_COLORS:di=00;33"' >> /etc/profile

# Sudo configuration
wget $CHOST/$VERSION/sudoers.conf -O /etc/sudoers
chmod 0440 /etc/sudoers

# NTP Synchronization
echo '#!/bin/sh' > /etc/cron.daily/ntpdate
echo "$(which ntpdate) -s pool.ntp.org" >> /etc/cron.daily/ntpdate
chmod 775 /etc/cron.daily/ntpdate
ntpdate -s pool.ntp.org

# Setup rssh
if [ -z "$(grep /usr/bin/rssh /etc/shells)" ]; then
    echo /usr/bin/rssh >> /etc/shells
fi
sed -i 's/#allowscp/allowscp/' /etc/rssh.conf
sed -i 's/#allowsftp/allowsftp/' /etc/rssh.conf
sed -i 's/#allowrsync/allowrsync/' /etc/rssh.conf
chmod 755 /usr/bin/rssh

# Nginx configuration
rm -f /etc/nginx/conf.d/*.conf
wget $CHOST/$VERSION/nginx.conf -O /etc/nginx/nginx.conf
wget $CHOST/$VERSION/nginx-status.conf -O /etc/nginx/conf.d/status.conf
touch /etc/nginx/conf.d/vesta.conf
update-rc.d nginx defaults
service nginx stop > /dev/null 2>&1
service nginx start
if [ "$?" -ne 0 ]; then
    echo "Error: nginx start failed"
    exit 1
fi

# Apache configuration
wget $CHOST/$VERSION/apache2.conf -O /etc/apache2/apache2.conf
wget $CHOST/$VERSION/apache2-status.conf \
    -O /etc/apache2/mods-enabled/status.conf
wget $CHOST/$VERSION/apache2.log -O /etc/logrotate.d/apache2
rm -f /etc/apache2/conf.d/vesta.conf
echo > /etc/apache2/conf.d/vesta.conf
echo "# Powever by vesta" > /etc/apache2/sites-available/default
echo "# Powever by vestas" > /etc/apache2/sites-available/default-ssl
echo "# Powever by vestas" > /etc/apache2/ports.conf
touch /var/log/apache2/access.log
touch /var/log/apache2/error.log
mkdir -p /var/log/apache2/domains
chmod a+x /var/log/apache2
chmod 640 /var/log/apache2/access.log
chmod 640 /var/log/apache2/error.log
chmod 751 /var/log/apache2/domains
a2enmod suexec
echo -e "/home\npublic_html/cgi-bin" > /etc/apache2/suexec/www-data
update-rc.d apache2 defaults
service apache2 stop > /dev/null 2>&1
service apache2 start
if [ "$?" -ne 0 ]; then
    echo "Error: apache2 start failed"
    exit 1
fi

# Vsftpd configuration
wget $CHOST/$VERSION/vsftpd.conf -O /etc/vsftpd.conf
update-rc.d vsftpd defaults
service vsftpd stop > /dev/null 2>&1
service vsftpd start
if [ "$?" -ne 0 ]; then
    echo "Error: vsftpd start failed"
    exit 1
fi

# MySQL configuration
mpass=$(gen_pass)
wget $CHOST/$VERSION/my.cnf -O /etc/mysql/my.cnf
mysql_install_db
update-rc.d mysql defaults
service mysql stop > /dev/null 2>&1
service mysql start
if [ "$?" -ne 0 ]; then
    echo "Error: mysql start failed"
    exit 1
fi
mysqladmin -u root password $mpass
echo -e "[client]\npassword='$mpass'\n" > /root/.my.cnf
chmod 600 /root/.my.cnf
mysql -e "DELETE FROM mysql.user WHERE User=''"
mysql -e "DROP DATABASE test"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
mysql -e "DELETE FROM mysql.user WHERE user='' or password='';"
mysql -e "FLUSH PRIVILEGES"

# Bind configuration
wget $CHOST/$VERSION/named.conf -O /etc/bind/named.conf
chown root:bind /etc/bind/named.conf
chmod 640 /etc/bind/named.conf
update-rc.d bind9 defaults
service bind9 stop > /dev/null 2>&1
service bind9 start
if [ "$?" -ne 0 ]; then
    echo "Error: bind9 start failed"
    exit 1
fi

# Exim
wget $CHOST/$VERSION/exim4.conf.template -O /etc/exim4/exim4.conf.template
if [ "$srv_type" = 'micro' ] ||  [ "$srv_type" = 'small' ]; then
    sed -i "s/^SPAMASSASSIN/#SPAMASSASSIN/g" /etc/exim4/exim4.conf.template
    sed -i "s/^CLAMD/#CLAMD/g" /etc/exim4/exim4.conf.template
fi
wget $CHOST/$VERSION/dnsbl.conf -O /etc/exim4/dnsbl.conf
wget $CHOST/$VERSION/spam-blocks.conf -O /etc/exim4/spam-blocks.conf
touch /etc/exim4/white-blocks.conf
rm -rf /etc/exim4/domains
mkdir -p /etc/exim4/domains
chmod 640 /etc/exim4/exim4.conf.template
gpasswd -a Debian-exim mail
if [ -e /etc/init.d/sendmail ]; then
    update-rc.d -f sendmail remove
    service sendmail stop
fi
if [ -e /etc/init.d/postfix ]; then
    update-rc.d -f postfix remove
    service postfix stop
fi
rm -f /etc/alternatives/mta
ln -s /usr/sbin/exim4 /etc/alternatives/mta
update-rc.d exim4 defaults
service exim4 stop > /dev/null 2>&1
service exim4 start
if [ "$?" -ne 0 ]; then
    echo "Error: exim start failed"
    exit
fi

# Dovecot configuration
wget $CHOST/$VERSION/dovecot.conf -O /etc/dovecot/dovecot.conf
cd /etc/dovecot/
wget $CHOST/$VERSION/dovecot-conf.d.tar.gz
rm -rf conf.d *.ext README
tar -xzf dovecot-conf.d.tar.gz
rm -f dovecot-conf.d.tar.gz
chown -R root:root /etc/dovecot
gpasswd -a dovecot mail
update-rc.d dovecot defaults
service dovecot stop > /dev/null 2>&1
service dovecot start
if [ "$?" -ne 0 ]; then
    echo "Error: dovecot start failed"
    exit 1
fi

# ClamAV configuration
if [ "$srv_type" = 'medium' ] ||  [ "$srv_type" = 'large' ]; then
    wget $CHOST/$VERSION/clamd.conf -O /etc/clamav/clamd.conf
    gpasswd -a clamav mail
    gpasswd -a clamav Debian-exim
    /usr/bin/freshclam
    update-rc.d clamav-daemon defaults
    service clamav-daemon stop > /dev/null 2>&1
    service clamav-daemon start
    if [ "$?" -ne 0 ]; then
        echo "Error: clamav start failed"
        exit 1
    fi
fi

# SpamAssassin configuration
if [ "$srv_type" = 'medium' ] ||  [ "$srv_type" = 'large' ]; then
    update-rc.d spamassassin defaults
    sed -i "s/ENABLED=0/ENABLED=1/" /etc/default/spamassassin
    service spamassassin stop > /dev/null 2>&1
    service spamassassin start
    if [ "$?" -ne 0 ]; then
        echo "Error: spamassassin start failed"
        exit 1
    fi
fi

# php configuration
sed -i "s/;date.timezone =/date.timezone = UTC/g" /etc/php5/apache2/php.ini
sed -i "s/;date.timezone =/date.timezone = UTC/g" /etc/php5/cli/php.ini

# phpMyAdmin configuration
wget $CHOST/$VERSION/apache2-pma.conf -O /etc/phpmyadmin/apache.conf
wget $CHOST/$VERSION/pma.conf -O /etc/phpmyadmin/config.inc.php
ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf.d/phpmyadmin.conf
mv -f /etc/phpmyadmin/config-db.php /etc/phpmyadmin/config-db.php_

# Roundcube configuration
wget $CHOST/$VERSION/apache2-webmail.conf -O /etc/roundcube/apache.conf
wget $CHOST/$VERSION/roundcube-main.conf -O /etc/roundcube/main.inc.php
wget $CHOST/$VERSION/roundcube-db.conf -O /etc/roundcube/db.inc.php
wget $CHOST/$VERSION/roundcube-driver.php -O \
    /usr/share/roundcube/plugins/password/drivers/vesta.php
wget $CHOST/$VERSION/roundcube-pw.conf -O \
    /etc/roundcube/plugins/password/config.inc.php
r="$(gen_pass)"
mysql -e "CREATE DATABASE roundcube"
mysql -e "GRANT ALL ON roundcube.* TO roundcube@localhost IDENTIFIED BY '$r'"
sed -i "s/%password%/$r/g" /etc/roundcube/db.inc.php
mysql roundcube < /usr/share/dbconfig-common/data/roundcube/install/mysql

# Vesta configuration
echo "export VESTA='/usr/local/vesta'" > /etc/profile.d/vesta.sh
chmod 755 /etc/profile.d/vesta.sh
source /etc/profile.d/vesta.sh
echo 'PATH=$PATH:/usr/local/vesta/bin' >> /root/.bash_profile
echo 'export PATH' >> /root/.bash_profile
source /root/.bash_profile
wget $CHOST/$VERSION/vesta.log -O /etc/logrotate.d/vesta

# Directory tree
mkdir -p $VESTA/conf
mkdir -p $VESTA/log
mkdir -p $VESTA/ssl
mkdir -p $VESTA/data
mkdir -p $VESTA/data/ips
mkdir -p $VESTA/data/queue
mkdir -p $VESTA/data/users
touch $VESTA/data/queue/backup.pipe
touch $VESTA/data/queue/disk.pipe
touch $VESTA/data/queue/webstats.pipe
touch $VESTA/data/queue/restart.pipe
touch $VESTA/data/queue/traffic.pipe
chmod 750 $VESTA/conf
chmod 750 $VESTA/data/users
chmod 750 $VESTA/data/ips
chmod -R 750 $VESTA/data/queue
ln -s /usr/local/vesta/log /var/log/vesta
touch /var/log/vesta/system.log
touch /var/log/vesta/nginx-error.log
touch /var/log/vesta/auth.log
chmod 660 /var/log/vesta/*
adduser backup > /dev/null 2>&1
mkdir -p /home/backup
chown backup:backup /home/backup
ln -s /home/backup /backup
chmod a+x /backup

# vesta.conf
wget $CHOST/$VERSION/vesta.conf -O $VESTA/conf/vesta.conf
if [ "$srv_type" = 'micro' ] ||  [ "$srv_type" = 'small' ]; then
    sed -i "s/clamav-daemon//g" $VESTA/conf/vesta.conf
    sed -i "s/spamassassin//g" $VESTA/conf/vesta.conf
fi

# Templates
cd /usr/local/vesta/data
wget $CHOST/$VERSION/packages.tar.gz -O packages.tar.gz
tar -xzf packages.tar.gz
rm -f packages.tar.gz
cd /usr/local/vesta/data
wget $CHOST/$VERSION/templates.tar.gz -O templates.tar.gz
tar -xzf templates.tar.gz
rm -f templates.tar.gz
chmod -R 755 /usr/local/vesta/data/templates
cp templates/web/skel/public_html/index.html /var/www/
sed -i 's/%domain%/It worked!/g' /var/www/index.html
if [ "$srv_type" = 'micro' ]; then
    rm -f /usr/local/vesta/data/templates/web/apache2/phpfcgid.*
fi

# Default SSL keys
cd /usr/local/vesta/ssl
wget $CHOST/$VERSION/certificate.crt -O certificate.crt
wget $CHOST/$VERSION/certificate.key -O certificate.key

# Adding admin user
if [ ! -z "$(grep ^admin: /etc/passwd)" ] && [ "$force" = 'yes' ]; then
    chattr -i /home/admin/conf > /dev/null 2>&1
    userdel -f admin
    chattr -i /home/admin/conf
    mv -f /home/admin  $vst_backups/home/
    rm -f /tmp/sess_*
fi
if [ ! -z "$(grep ^admin: /etc/group)" ] && [ "$force" = 'yes' ]; then
    groupdel admin > /dev/null 2>&1
fi
vpass=$(gen_pass)
$VESTA/bin/v-add-user admin $vpass $email default System Administrator
if [ $? -ne 0 ]; then
    echo "Error: can't create admin user"
    exit 1
fi
$VESTA/bin/v-change-user-shell admin bash
$VESTA/bin/v-change-user-language admin en

# Configure mysql host
$VESTA/bin/v-add-database-host mysql localhost root $mpass
$VESTA/bin/v-add-database admin default default $(gen_pass) mysql

# Configuring system ips
$VESTA/bin/v-update-sys-ip

# Get main ip
main_ip=$(ifconfig |grep 'inet addr:' |grep -v 127.0.0.1 |head -n1 | \
    cut -f2 -d: | cut -f1 -d ' ')

# Get remote ip
vst_ip=$(wget vestacp.com/what-is-my-ip/ -O - 2>/dev/null)
if [ ! -z "$vst_ip" ] && [ "$vst_ip" != "$main_ip" ]; then
    # Set NAT association
    $VESTA/bin/v-change-sys-ip-nat $main_ip $vst_ip
fi
if [ -z "$vst_ip" ]; then
    vst_ip=$main_ip
fi

# Add default web domain
$VESTA/bin/v-add-web-domain admin default.domain $vst_ip

# Add default dns domain
$VESTA/bin/v-add-dns-domain admin default.domain $vst_ip

# Add default mail domain
$VESTA/bin/v-add-mail-domain admin default.domain

# Configuring crond
command='sudo /usr/local/vesta/bin/v-update-sys-queue disk'
$VESTA/bin/v-add-cron-job 'admin' '15' '02' '*' '*' '*' "$command"
command='sudo /usr/local/vesta/bin/v-update-sys-queue traffic'
$VESTA/bin/v-add-cron-job 'admin' '10' '00' '*' '*' '*' "$command"
command='sudo /usr/local/vesta/bin/v-update-sys-queue webstats'
$VESTA/bin/v-add-cron-job 'admin' '30' '03' '*' '*' '*' "$command"
command='sudo /usr/local/vesta/bin/v-update-sys-queue backup'
$VESTA/bin/v-add-cron-job 'admin' '*/5' '*' '*' '*' '*' "$command"
command='sudo /usr/local/vesta/bin/v-backup-users'
$VESTA/bin/v-add-cron-job 'admin' '10' '05' '*' '*' '*' "$command"
command='sudo /usr/local/vesta/bin/v-update-user-stats'
$VESTA/bin/v-add-cron-job 'admin' '20' '00' '*' '*' '*' "$command"
command='sudo /usr/local/vesta/bin/v-update-sys-rrd'
$VESTA/bin/v-add-cron-job 'admin' '*/5' '*' '*' '*' '*' "$command"

# Build inititall rrd images
$VESTA/bin/v-update-sys-rrd

# Start system service
update-rc.d vesta defaults
service vesta stop > /dev/null 2>&1
service vesta start
if [ "$?" -ne 0 ]; then
    echo "Error: vesta start failed"
    exit 1
fi

# Send notification to vestacp.com
wget vestacp.com/notify/?$REPO -O /dev/null

# Send notification to admin email
echo -e "Congratulations, you have just successfully installed \
the Vesta Control Panel

You can login in Vesta with following credentials:
    username: admin
    password: $vpass
    https://$vst_ip:8083

We hope that you enjoy your installation of Vesta. Please \
feel free to contact us anytime if you have any questions.
Thank you.

--
Sincerely yours
vestacp.com team
" > $tmpfile

send_mail="$VESTA/web/inc/mail-wrapper.php"
cat $tmpfile | $send_mail -s "Vesta Control Panel" $email
rm -f $tmpfile

# Congrats
echo '======================================================='
echo
echo
echo ' _|      _|  _|_|_|_|    _|_|_|  _|_|_|_|_|    _|_|   '
echo ' _|      _|  _|        _|            _|      _|    _| '
echo ' _|      _|  _|_|_|      _|_|        _|      _|_|_|_| '
echo '   _|  _|    _|              _|      _|      _|    _| '
echo '     _|      _|_|_|_|  _|_|_|        _|      _|    _| '
echo
echo
echo '-------------------------------'
echo "  https://$vst_ip:8083"
echo '  username: admin'
echo "  password: $vpass"
echo '-------------------------------'
echo
echo
echo 'Congratulations,'
echo 'you have successfully installed Vesta Control Panel.'
echo
echo

# Tricky way to get new PATH variable
cd
bash

# EOF
