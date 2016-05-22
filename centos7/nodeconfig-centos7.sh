#!/bin/bash
# nodeconfig-centos7.sh script
# goto the / directory (to avoid errors like - could not change directory to "/home/vagrant"
cd /

case $(hostname) in

client*)
#######
echo "Running client only commands:"
echo "Installing bareos-filedaemon"
yum install -y bareos-filedaemon bareos-console

;;
# end of client specific code

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

# install bareos
echo "Installing bareos server components"
yum install -y  bareos bareos-database-postgresql

# before doing the initialization of bareos tables make /etc/bareos readable for postgres user
chmod 755 /etc/bareos
chmod 644 /etc/bareos/*.conf

# configure bareos
su postgres -c /usr/lib/bareos/scripts/create_bareos_database
su postgres -c /usr/lib/bareos/scripts/make_bareos_tables
su postgres -c /usr/lib/bareos/scripts/grant_bareos_privileges

# start the bareos daemons
service bareos-dir start
service bareos-sd start
service bareos-fd start

;;
# end of server specfic code

*) echo "Hum, you should not see this message (check script $0 on system $(hostname))"
;;

esac
exit 0
