#!/bin/bash
# nodeconfig-centos7.sh script
# goto the / directory (to avoid errors like - could not change directory to "/home/vagrant"
cd /

case $(hostname) in

client*)
#######
echo "Running client only commands:"
echo "Installing bareos-filedaemon and bconsole"
yum install -y bareos-filedaemon bareos-console
# installing bareos specific config files
yum install -y bareos-client-conf
echo "Enabling and Starting bareos-fd daemon process"
systemctl enable bareos-fd.service
systemctl start bareos-fd.service
;;
# end of client specific code
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

server*) 
#######
echo "Running server only commands:"
[[ ! -d /export/nfs ]] && mkdir -m 755 -p /export/nfs

cat > /etc/exports <<EOF
/export/nfs 192.168.0.0/16(rw,no_root_squash)
EOF

# start the NFS service
systemctl start  nfs-idmapd rpcbind nfs-server
systemctl enable nfs-idmapd rpcbind nfs-server

echo "NFS exported file system on server:"
showmount -e

# install and configure postgres
echo "Installing and configuring postgresql"
yum install -y  postgresql-server
# initialize the db
/bin/postgresql-setup initdb
# start postgres
systemctl enable postgresql.service
systemctl start postgresql.service

# install bareos RPMs
echo "Installing bareos server components"
yum install -y  bareos bareos-database-postgresql

# installing bareos specific configuration files
yum install -y bareos-server-conf

# before doing the initialization of bareos tables make /etc/bareos readable for postgres user
chmod 755 /etc/bareos
chmod 644 /etc/bareos/*.conf

# configure bareos
echo "Configuring bareos Postgres tables"
su postgres -c /usr/lib/bareos/scripts/create_bareos_database
su postgres -c /usr/lib/bareos/scripts/make_bareos_tables
su postgres -c /usr/lib/bareos/scripts/grant_bareos_privileges

# start the bareos daemons
echo "Enabling and starting the Bareos daemons"
systemctl enable bareos-dir.service
systemctl enable bareos-sd.service
systemctl enable bareos-fd.service
systemctl start bareos-dir.service
systemctl start bareos-sd.service
systemctl start bareos-fd.service

#service bareos-dir start
#service bareos-sd start
#service bareos-fd start

;;
# end of server specfic code

*) echo "Hum, you should not see this message (check script $0 on system $(hostname))"
;;

esac
exit 0
