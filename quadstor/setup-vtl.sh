#!/usr/bin/env bash

if [ $# != 1 ]; then
    echo "$0 device_name"
    echo "Example: $0 /dev/sdb"
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

apt -y install uuid-runtime build-essential sg3-utils apache2 psmisc linux-headers-generic
a2enmod cgi
systemctl restart apache2
systemctl enable apache2
curl -OL http://archive.ubuntu.com/ubuntu/pool/main/o/openssl1.0/libssl1.0.0_1.0.2n-1ubuntu5.6_amd64.deb
dpkg -i libssl1.0.0_1.0.2n-1ubuntu5.6_amd64.deb
curl -OL https://quadstor.com/vtldownloads/quadstor-vtl-ext-3.0.56-debian-x86_64.deb
dpkg -i quadstor-vtl-ext-3.0.56-debian-x86_64.deb
systemctl enable  quadstorvtl.service
systemctl start  quadstorvtl.service

echo "Initialize $1"
dd if=/dev/zero of=$1 bs=1M count=32
/quadstorvtl/bin/bdconfig -l -c
/quadstorvtl/bin/bdconfig -a -d $1
/quadstorvtl/bin/bdconfig -l -c
/quadstorvtl/bin/vtconfig -l
/quadstorvtl/bin/vtconfig -a -v ADIC1 -t 01 -s 20 -i 4 -d 07 -c 2 -e 768
/quadstorvtl/bin/vtconfig -l -v ADIC1
sleep 5
/quadstorvtl/bin/vcconfig -a -v ADIC1 -g Default  -p DLT000 -t 06 -c 20
/quadstorvtl/bin/vtconfig -l -v ADIC1

LOCALIPADDR=`ip -f inet -o addr show ens160 |cut -d\  -f 7 | cut -d/ -f 1`
echo ""
echo "You can access http://${LOCALIPADDR}/"
echo ""
