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

parted ${1}  --script 'mklabel gpt mkpart primary 0% 100% print quit'
chmod -x ./setup-part.sh
mv ./setup-part.sh ./setup-part.sh.done
