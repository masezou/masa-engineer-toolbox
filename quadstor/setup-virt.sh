#!/usr/bin/env bash

if [ $# != 1 ]; then
    echo "$0 device_name volume_size(GB)"
    echo "Example: $0 /dev/sdb 100"
    exit 1
else
    echo OK
fi

if [ ${EUID:-${UID}} != 0 ]; then
    echo "This script must be run as root"
    exit 1
else
    echo "I am root user."
fi

lsb_release -d | grep Ubuntu | grep 20.04
DISTVER=$?
if [ ${DISTVER} = 1 ]; then
    echo "Distribution or version is wrong. exit...."
    exit 1
else
    echo "Ubuntu 20.04=OK"
fi

TARGETBLKSIZE=`lsblk -b -no SIZE $1`


apt -y install uuid-runtime build-essential sg3-utils iotop sysstat lsscsi apache2 psmisc linux-headers-`uname -r`snmp
curl -OL http://archive.ubuntu.com/ubuntu/pool/main/o/openssl1.0/libssl1.0.0_1.0.2n-1ubuntu5.6_amd64.deb
dpkg -i libssl1.0.0_1.0.2n-1ubuntu5.6_amd64.deb
a2enmod cgi
systemctl restart apache2
systemctl enable apache2
curl -OL https://quadstor.com/virtdownloads/quadstor-virt-3.2.19-debian-x86_64.deb
curl -OL https://quadstor.com/virtdownloads/QUADSTOR-REG.mib
curl -OL https://quadstor.com/virtdownloads/QUADSTOR.mib
dpkg -i quadstor-virt-3.2.19-debian-x86_64.deb
systemctl start quadstor
systemctl status quadstor

echo "Initialize $1"
dd if=/dev/zero of=$1 bs=1M count=32
/quadstor/bin/bdconfig -l -c
/quadstor/bin/bdconfig -a -d ${1} -p
/quadstor/bin/bdconfig -l -c
/quadstor/bin/vdconfig -l
/quadstor/bin/spconfig -l
/quadstor/bin/vdconfig -a -v vdisk1 -s ${2} -e
#/quadstor/bin/vdconfig -m -v vdisk1 -d -c -y
/quadstor/bin/vdconfig -m -v vdisk1 -d
LOCALIPADDR=`ip -f inet -o addr show ens160 |cut -d\  -f 7 | cut -d/ -f 1`
echo ""
echo "You can access http://${LOCALIPADDR}/"
echo ""
