#!/bin/bash

echo "Provisioning centos/7"

# set up hostname (client) - is done via the Vagrantfile

# set up the timezone
timedatectl set-timezone Europe/Brussels
# check the timezone:
date


# Add IP address to /etc/hosts
IPclient="192.168.33.10"
grep -q "^$IPclient" /etc/hosts
if [[ $? -eq 1 ]] ;then
   echo "Add IP addresses of client and server to /etc/hosts file"
   echo "192.168.33.10   client.box client vagrant-client" >> /etc/hosts
   echo "192.168.33.15   server.box server vagrant-server" >> /etc/hosts
   echo "192.168.33.1    vagrant-host" >> /etc/hosts
fi


# Prepare /srv/http/packages/workshop (download area for RPMs)
RPMDIR=/srv/http/packages/workshop
if [[ ! -d $RPMDIR ]] ; then
    mkdir -m 755 -p $RPMDIR
    echo "Created RPM directory $RPMDIR"
fi

# Install software that is required to bootstrap the rest of the workshop
# do an update of the base system first
echo "Running yum update..."
yum update -y

# httpd,createrepo,wget
packages=( httpd createrepo wget )
for pkg in ${packages[@]}
do
    rpm -q $pkg >/dev/null
    if [[ $? -eq 1 ]] ; then
        echo "Installing $pkg RPM package via yum"
        yum install -y $pkg
    fi
done

# Define bareos and rear repo defintions
wget -O /etc/yum.repos.d/bareos.repo http://download.bareos.org/bareos/release/latest/CentOS_7/bareos.repo
# it is the purpose to use the stable version during the workshop
#wget -O /etc/yum.repos.d/Archiving:Backup:Rear.repo http://download.opensuse.org/repositories/Archiving:/Backup:/Rear/CentOS_7/Archiving:Backup:Rear.repo
# however, as we are still adding features we prefer to have the snapshot version for now
wget -O /etc/yum.repos.d/Archiving:Backup:Rear:Snapshot.repo http://download.opensuse.org/repositories/Archiving:/Backup:/Rear:/Snapshot/CentOS_7/Archiving:Backup:Rear:Snapshot.repo
wget -O /etc/yum.repos.d/home:gdha.repo http://download.opensuse.org/repositories/home:/gdha/CentOS_7/home:gdha.repo

# Download RPMs for workshop
packages=( syslinux syslinux-extlinux cifs-utils genisoimage epel-release net-tools xinetd tftp-server dhcp samba samba-client
           bind-utils rear postgresql-server bareos bareos-database-postgresql mtools attr libusal bareos-client-conf
	   bareos-server-conf )

for pkg in ${packages[@]}
do
    echo "Download package $pkg into $RPMDIR"
    yum install -y --downloadonly --downloaddir=$RPMDIR $pkg
done


# create the 'workshop repo' files from the downloaded packages
echo "Run the createrepo command"
createrepo $RPMDIR

if [[ ! -f /etc/yum.repos.d/workshop.repo ]] ; then
   echo "Create the yum repo for workshop"
   cat > /etc/yum.repos.d/workshop.repo <<EOF
[workshop]
name=Rear workshop
baseurl=http://localhost/packages/workshop
enabled=1
gpgcheck=0

EOF
fi

# Users, groups, passwords and sudoers.
echo 'vagrant' | passwd --stdin root
grep 'vagrant' /etc/passwd > /dev/null
if [ $? -ne 0 ]; then
	echo '* Creating user vagrant.'
	useradd vagrant
	echo 'vagrant' | passwd --stdin vagrant
fi
grep '^admin:' /etc/group > /dev/null || groupadd admin
usermod -G admin vagrant

echo 'Defaults    env_keep += "SSH_AUTH_SOCK"' >> /etc/sudoers
echo '%admin ALL=NOPASSWD: ALL' >> /etc/sudoers
sed -i 's/Defaults\s*requiretty/Defaults !requiretty/' /etc/sudoers


# SSH setup
# Add Vagrant ssh key for root and vagrant accouts.
sed -i 's/.*UseDNS.*/UseDNS no/' /etc/ssh/sshd_config

# setup SSH keys for user root
[ -d ~root/.ssh ] || mkdir ~root/.ssh
chmod 700 ~root/.ssh
cat >> ~root/.ssh/authorized_keys << EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCqZRGc6zbCXQVL7L3o6ze9ESvBN1Skm7PhNExXKfsxAmCfaBYFCwcLljXk+ITapUpFmRoeaI74d4qpTsl0eX9I+b7UcjJjhuiX3S2HoWxB+/JyiJoO5SnxkxkUQcMqImDdM9NvCH5IcfcT7sZ+8uOATimSigOAWk0cRrgToGFARutN60F+P9CHHMCaFE/9tYrh/CtfvMZaEcDnmGgbbvFOED+wgdyTg/35iSZMM9YkglF07xxOzvUm7awny/UssuZYOPrGnHylqrup4uOx4fz61Y1Kl0/E9MAxYOC/sRqVkob0sGHaJ0KPavVmIvVwEgBOGHBH2F8g8iAL/Ma1+irl insecure public
 key of vagrant
EOF
chmod 600 ~root/.ssh/authorized_keys
# TODO: use ssh-keygen to generate a new pair of SSH keys for root to exchange between client/server systems?


# setup SSH insecure key for user vagrant
[ -d ~vagrant/.ssh ] || mkdir ~vagrant/.ssh
chmod 700 ~vagrant/.ssh
cat >> ~vagrant/.ssh/authorized_keys << EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCqZRGc6zbCXQVL7L3o6ze9ESvBN1Skm7PhNExXKfsxAmCfaBYFCwcLljXk+ITapUpFmRoeaI74d4qpTsl0eX9I+b7UcjJjhuiX3S2HoWxB+/JyiJoO5SnxkxkUQcMqImDdM9NvCH5IcfcT7sZ+8uOATimSigOAWk0cRrgToGFARutN60F+P9CHHMCaFE/9tYrh/CtfvMZaEcDnmGgbbvFOED+wgdyTg/35iSZMM9YkglF07xxOzvUm7awny/UssuZYOPrGnHylqrup4uOx4fz61Y1Kl0/E9MAxYOC/sRqVkob0sGHaJ0KPavVmIvVwEgBOGHBH2F8g8iAL/Ma1+irl insecure public
 key of vagrant
EOF
chmod 600 ~vagrant/.ssh/authorized_keys


# Disable firewall and switch SELinux to permissive mode.
#chkconfig iptables off
#chkconfig ip6tables off
# firewallD is by default not running with this box

# Networking setup..
# Don't fix ethX names to hw address.
rm -f /etc/udev/rules.d/*persistent-net.rules
rm -f /etc/udev/rules.d/*-net.rules
rm -fr /var/lib/dhclient/*

# Configure /etc/httpd/conf.d/packages.conf
if [[ ! -f /etc/httpd/conf.d/packages.conf ]] ; then
    cat >/etc/httpd/conf.d/packages.conf <<EOF
Alias /packages /srv/http/packages

<Directory /srv/http/packages>
  Options Indexes FollowSymlinks
  AllowOverride All
  # See http://stackoverflow.com/questions/18392741/apache2-ah01630-client-denied-by-server-configuration
  #Order allow,deny
  #Allow from all
  Require all granted
</Directory>
EOF
fi

# SElinux settings when Enforce is on (default setting)
echo "Current mode of SELinux is \"$(getenforce)\"" 
echo "Give httpd rights to read from /srv/http/packages"
chcon -R -t httpd_sys_content_t /srv/http/packages/

# Restart httpd so it knows about $RPMDIR location (/etc/httpd/conf.d/packages.conf)
#service httpd restart
/bin/systemctl restart  httpd.service
/bin/systemctl enable   httpd.service

# add the domain name to the /etc/idmapd.conf file (for NFSv4)
sed -i -e 's,^#Domain =.*,Domain = box,' /etc/idmapd.conf

# move most repos to /etc/disto.repos.d (F25 proposed scheme) to avoid internet traffic during workshop
[[ ! -d /etc/disto.repos.d ]] && mkdir -m 755 -p /etc/disto.repos.d
mv /etc/yum.repos.d/*.repo /etc/disto.repos.d/
mv /etc/disto.repos.d/workshop.repo /etc/yum.repos.d/
echo "Moved all repos from /etc/yum.repos.d/ to /etc/disto.repos.d/ except the workshop.repo"

