#!/usr/bin/env bash
#########################################################
# Description:
# This script will create Docker Registry / NFS / SMB / DNS / Mail Server / Gitlab without docker as service.
# Registry / NFS / SMB store data to /disk directory. You can mount volume to /disk before exectuting this script.

# Docker Private Registory (http://<Hostname>:5000 / no authentication for test purpose.)
REGSVR=1
REGDIR=/disk/registry

# NFS Server
NFSSVR=1
NFSPATH=/disk/nfs_csi
NFSSUBPATH=/disk/nfs_sub

# SMB  Server (It is not implemented yet)
SMBSVR=1
SMBPATH=/disk/smb_csi

# DNS Server
DNSSVR=1
DNSDOMAINNAME="k8slab.internal"
# If you have internal DNS, please comment out and set your own DNS server.
#FORWARDDNS=192.168.8.1
# you can set ingress IP address. *.apps.domainname returns this ip.
#INGRESS_IP=192.168.133.16

# Mail Server
MAILSVR=1

# Gitlab CE Server
GITLABSVR=1

# Custom configuration. (Some environment need to be set or you can set maually.)
#ETHDEV=eth0
#LOCALIPADDR=192.168.16.2

#########################################################
BASEPWD=`pwd`
source /etc/profile

# If there is environment.txt, Any environment value is uses this file.
if [ -f ./environment.txt ]; then
echo "environment.txt fond"
source environment.txt
fi

### Root User Check ###
if [ ${EUID:-${UID}} != 0 ]; then
echo -e "\e[31m This script must be run as root. \e[m"
    exit 255
else
    echo "I am root user."
fi

### HOSTNAME check ###
ping -c 3 `hostname`
retvalping=$?
if [ ${retvalping} -ne 0 ]; then
echo -e "\e[31m HOSTNAME was not configured correctly. \e[m"
exit 255
fi

### Distribution Check ###
UBUNTUVER=`grep DISTRIB_RELEASE /etc/lsb-release | cut -d "=" -f2`
case ${UBUNTUVER} in
    "20.04")
       echo -e "\e[32m${UBUNTUVER} is OK. \e[m"
       ;;
    "22.04")
       echo "${UBUNTUVER} is experimental."
      #exit 255
       ;;
    *)
       echo -e "\e[31m${UBUNTUVER} is NG. \e[m"
      exit 255
        ;;
esac

### Ubuntu Server Edition Check ###
if [ ! -f /usr/share/doc/ubuntu-server/copyright ]; then
echo -e "\e[31m It seemed his VM is installed Ubuntu Desktop media. VM which is installed from Ubuntu Desktop media is not supported. Please re-create VM from Ubuntu Server media! \e[m"
exit 255
fi

### ARCH Check ###
PARCH=`arch`
if [ ${PARCH} = aarch64 ]; then
  ARCH=arm64
  echo ${ARCH}
elif [ ${PARCH} = arm64 ]; then
  ARCH=arm64
  echo ${ARCH}
elif [ ${PARCH} = x86_64 ]; then
  ARCH=amd64
  echo ${ARCH}
else
echo -e "\e[31m ${ARCH} platform is not supported \e[m"
  exit 255
fi

### LOCALIP ###
if [ -z ${ETHDEV} ]; then
   grep ens /etc/netplan/00-installer-config.yaml >/dev/null
   retvaldev1=$?
       if [ ${retvaldev1} -eq 0 ]; then
       ETHDEV=`grep ens /etc/netplan/00-installer-config.yaml |tr -d ' ' | cut -d ":" -f1`
       else
       grep eth /etc/netplan/00-installer-config.yaml >/dev/null
       retvaldev2=$?
          if [ ${retvaldev2} -eq 0 ]; then
          ETHDEV=`grep eth /etc/netplan/00-installer-config.yaml |tr -d ' ' | cut -d ":" -f1`
          fi
      fi
echo ${ETHDEV}
fi
if [ -z ${ETHDEV} ]; then
echo -e "\e[31m You need to ETHDEV value in this file.\e[m"
exit 255
fi

if [ -z ${LOCALIPADDR} ]; then
LOCALIPADDR=`ip -f inet -o addr show ${ETHDEV} |cut -d\  -f 7 | cut -d/ -f 1`
echo ${LOCALIPADDR}
fi

DNSHOSTNAME=`hostname`
apt update
apt -y upgrade
#########################################################
# Install registry
if [ ${REGSVR} = 1 ]; then
if [ ! -f /usr/bin/docker-registry ]; then
echo "Install private registry"
mkdir -p ${REGDIR}
ln -s ${REGDIR} /var/lib/docker-registry
ufw allow 5000
apt -y install docker-registry
sed -i -e "s/  htpasswd/#  htpasswd/g" /etc/docker/registry/config.yml
sed -i -e "s/    realm/#    realm/g" /etc/docker/registry/config.yml
sed -i -e "s/    path/#    path/g" /etc/docker/registry/config.yml
systemctl restart docker-registry
systemctl enable docker-registry
fi
fi

# Install local NFS Server
if [ ${NFSSVR} -eq 1 ]; then
if [ ! -f /etc/exports ]; then
echo "Install local NFS Server"
mkdir -p ${NFSPATH}
chmod -R 1777 ${NFSPATH}
mkdir -p ${NFSSUBPATH}
chmod -R 1777 ${NFSSUBPATH}
apt -y install nfs-kernel-server
cat << EOF >> /etc/exports
${NFSPATH} 192.168.0.0/16(rw,async,no_root_squash)
${NFSPATH} 172.16.0.0/12(rw,async,no_root_squash)
${NFSPATH} 10.0.0.0/8(rw,async,no_root_squash)
${NFSPATH} 127.0.0.1/8(rw,async,no_root_squash)
${NFSSUBPATH} 192.168.0.0/16(rw,async,no_root_squash)
${NFSSUBPATH} 172.16.0.0/12(rw,async,no_root_squash)
${NFSSUBPATH} 10.0.0.0/8(rw,async,no_root_squash)
${NFSSUBPATH} 127.0.0.1/8(rw,async,no_root_squash)
EOF
systemctl restart nfs-server
systemctl enable nfs-server
showmount -e
fi
fi

# Install local SMB Server
if [ ${SMBSVR} -eq 1 ]; then
if [ ! -f /etc/samba/smb.conf ]; then
echo "Install local SMB Server"
mkdir -p ${SMBPATH}
chmod 777 ${SMBPATH}
apt -y install samba smbclient cifs-utils
cat << EOF >>/etc/samba/smb.conf
[smb_csi]
   path = ${SMBPATH}
   writable = yes
   guest ok = yes
   guest only = yes
   force create mode = 777
   force directory mode = 777
EOF
systemctl restart smbd
systemctl enable smbd
fi
fi

# Install local DNS Server
if [ ${DNSSVR} -eq 1 ]; then
if [ ! -f /etc/bind/named.conf ]; then
echo "Install local DNS Server"
apt -y install bind9 bind9utils
echo 'include "/etc/bind/named.conf.internal-zones";' >> /etc/bind/named.conf
mv /etc/bind/named.conf.options /etc/bind/named.conf.options.orig
cat << EOF > /etc/bind/named.conf.options
acl internal-network {
        127.0.0.0/8;
        10.0.0.0/8;
        172.16.0.0/12;
        192.168.0.0/16;
};
options {
        directory "/var/cache/bind";

        // If there is a firewall between you and nameservers you want
        // to talk to, you may need to fix the firewall to allow multiple
        // ports to talk.  See http://www.kb.cert.org/vuls/id/800113

        // If your ISP provided one or more IP addresses for stable
        // nameservers, you probably want to use them as forwarders.
        // Uncomment the following block, and insert the addresses replacing
        // the all-0's placeholder.

        // forwarders {
        //      0.0.0.0;
        // };

        //========================================================================
        // If BIND logs error messages about the root key being expired,
        // you will need to update your keys.  See https://www.isc.org/bind-keys
        //========================================================================
        dnssec-validation auto;

        listen-on-v6 { none; };
        allow-query { localhost; internal-network; };
        recursion yes;
};
EOF
if [ ! -z ${FORWARDDNS} ]; then
sed -i -e "s@// forwarders {@forwarders {@g" /etc/bind/named.conf.options
sed -i -e "s@//      0.0.0.0;@     ${FORWARDDNS} ;@g" /etc/bind/named.conf.options
sed -i -e "s@// };@};@g" /etc/bind/named.conf.options
fi
tsig-keygen -a hmac-sha256 externaldns-key > /etc/bind/external.key
cat /etc/bind/external.key>> /etc/bind/named.conf.options
chown root:bind /etc/bind/named.conf.options
cat << EOF > /etc/bind/named.conf.internal-zones
zone "${DNSDOMAINNAME}" IN {
        type master;
        file "/var/cache/bind/${DNSDOMAINNAME}.lan";
        allow-transfer {
          key "externaldns-key";
        };
        update-policy {
          grant externaldns-key zonesub ANY;
        };
};
zone "0.0.10.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.16.172.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.17.172.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.18.172.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.19.172.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.20.172.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.21.172.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.22.172.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.23.172.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.24.172.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.25.172.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.26.172.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.27.172.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.28.172.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.29.172.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.30.172.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.31.172.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
zone "0.168.192.in-addr.arpa" IN {
        type master;
        file "/etc/bind/db.empty";
        allow-update { none; };
};
EOF
sed -i -e 's/bind/bind -4/g' /etc/default/named
cat << 'EOF' >/var/cache/bind/${DNSDOMAINNAME}.lan
$TTL 86400
EOF
cat << EOF >>/var/cache/bind/${DNSDOMAINNAME}.lan
@   IN  SOA     ${DNSHOSTNAME}.${DNSDOMAINNAME}. root.${DNSDOMAINNAME}. (
        2022050401  ;Serial
        3600        ;Refresh
        1800        ;Retry
        604800      ;Expire
        86400       ;Minimum TTL
)
        IN  NS      ${DNSDOMAINNAME}.
        IN  A       ${LOCALIPADDR}
        IN MX 10    ${DNSHOSTNAME}.${DNSDOMAINNAME}.
${DNSHOSTNAME}     IN  A       ${LOCALIPADDR}
xip		IN NS		ns-aws.sslip.io.
xip		IN NS		ns-gce.sslip.io.
xip		IN NS		ns-azure.sslip.io.
EOF
if [ ! -z ${INGRESS_IP} ]; then
cat << EOF >>/var/cache/bind/${DNSDOMAINNAME}.lan
*.apps IN A ${INGRESS_IP}
EOF
fi
chown bind:bind /var/cache/bind/${DNSDOMAINNAME}.lan
chmod g+w /var/cache/bind/${DNSDOMAINNAME}.lan
systemctl restart named
systemctl enable named
systemctl status named -l --no-pager 
echo "Change DNS setting at this host"
netplan set network.ethernets.${ETHDEV}.nameservers.addresses=[${LOCALIPADDR}]
netplan set network.ethernets.${ETHDEV}.nameservers.search=[${DNSDOMAINNAME}]
netplan apply
sleep 5
cat << EOF > /tmp/nsupdate.txt
server ${LOCALIPADDR}


update delete registry.${DNSDOMAINNAME}
update add registry.${DNSDOMAINNAME} 3600 IN A ${LOCALIPADDR}
update delete nfssvr.${DNSDOMAINNAME}
update add nfssvr.${DNSDOMAINNAME} 3600 IN A ${LOCALIPADDR}
update delete smbsvr.${DNSDOMAINNAME}
update add smbsvr.${DNSDOMAINNAME} 3600 IN A ${LOCALIPADDR}
update delete mail.${DNSDOMAINNAME}
update add mail.${DNSDOMAINNAME} 3600 IN A ${LOCALIPADDR}
update delete gitlab.${DNSDOMAINNAME}
update add gitlab.${DNSDOMAINNAME} 3600 IN A ${LOCALIPADDR}

EOF
nsupdate -k /etc/bind/external.key  /tmp/nsupdate.txt
rm -rf  /tmp/nsupdate.txt
rndc freeze ${DNSDOMAINNAME}
rndc thaw ${DNSDOMAINNAME}
rndc sync -clean ${DNSDOMAINNAME}
sleep 5
echo ""
echo "Sanity Test"
echo ""
host ${DNSHOSTNAME}.${DNSDOMAINNAME}. ${LOCALIPADDR}
echo ""
host mail.${DNSDOMAINNAME}. ${LOCALIPADDR}
echo ""
if [ ! -z ${INGRESS_IP} ]; then
host abcd.apps.${DNSDOMAINNAME}. ${LOCALIPADDR}
echo ""
fi
host www.yahoo.co.jp. ${LOCALIPADDR}
echo ""
fi
fi

# Install local Mail Server
if [ ${MAILSVR} -eq 1 ]; then
if [ ! -f /etc/init.d/postfix ]; then
echo "Install local MAIL Server"
debconf-set-selections <<< "postfix postfix/mailname string ${DNSHOSTNAME}.${DNSDOMAINNAME}"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Local only'"
apt -y install postfix mailutils
systemctl enable postfix
fi
fi

# Install Gitlab CE Server
if [ ${GITLABSVR} -eq 1 ]; then
if [ ! -f /opt/gitlab/LICENSE ]; then
echo "Install Gitlab CE Server"
apt -y install curl openssh-server ca-certificates postfix
curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash
apt -y install gitlab-ce
gitlab-ctl reconfigure
echo "mattermost_external_url 'http://${LOCALIPADDR}:5001'" | bash -c 'cat >> /etc/gitlab/gitlab.rb'
echo "registry_external_url 'http://${LOCALIPADDR}:5002'" | bash -c 'cat >> /etc/gitlab/gitlab.rb'
sed -i -e "s@://gitlab.example.com@://${LOCALIPADDR}@g" /etc/gitlab/gitlab.rb
gitlab-ctl reconfigure

cat << EOF > /etc/cron.daily/gitlab-backup
#!/bin/sh -e
gitlab-rake gitlab:backup:create
cp -a /etc/gitlab/gitlab.rb /var/opt/gitlab/backups/gitlab.rb_date "+%Y%m%d_%H%M%S"
cp -a /etc/gitlab/gitlab-secrets.json /var/opt/gitlab/backups/gitlab-secrets.json_date "+%Y%m%d_%H%M%S"
EOF
chmod +x /etc/cron.daily/gitlab-backup
fi
fi

# Clean up
apt -y autoremove; apt clean
#########################################################
echo ""
echo "*************************************************************************************"
echo "If you re-run this script, you can review this information again."
echo ""
if [ ${REGSVR} -eq 1 ]; then
echo "Registory Server without authentication"
echo "http://${LOCALIPADDR}:5000"
echo ""
fi
if [ ${NFSSVR} -eq 1 ]; then
echo "NFS Server"
echo "  ${LOCALIPADDR} / ${DNSHOSTNAME}.${DNSDOMAINNAME}"
echo "  ${NFSPATH}"
echo "  ${NFSSUBPATH}"
echo ""
fi
if [ ${SMBSVR} -eq 1 ]; then
echo "SMB Server"
echo "  ${LOCALIPADDR} / ${DNSHOSTNAME}.${DNSDOMAINNAME}"
echo "  /smb_csi"
echo ""
fi
if [ ${DNSSVR} -eq 1 ]; then
echo "DNS Server"
echo "  ${LOCALIPADDR} / ${DNSHOSTNAME}"
echo "  ${DNSDOMAINNAME}"
echo "  External Key - cat  /etc/bind/external.key"
cat  /etc/bind/external.key
echo ""
echo "Following entry were registerd to ${LOCALIPADDR}"
echo "     registry.${DNSDOMAINNAME}"
echo "     nfssvr.${DNSDOMAINNAME}"
echo "     smbsvr.${DNSDOMAINNAME}"
echo "     mail.${DNSDOMAINNAME}"
echo "     gitlab.${DNSDOMAINNAME}"
echo ""
fi
if [ ${MAILSVR} -eq 1 ]; then
echo "MAIL Server"
echo " Accepts ${DNSHOSTNAME} / ${DNSHOSTNAME}.${DNSDOMAINNAME} / localhost"
echo ""
fi
if [ ${GITLABSVR} -eq 1 ]; then
echo "Gitlab CE Server"
echo "http://${LOCALIPADDR}"
echo "root user password: cat /etc/gitlab/initial_root_password"
cat /etc/gitlab/initial_root_password
echo ""
echo "GitLab Mattermost"
echo "http://${LOCALIPADDR}:5001"
echo "GitLab docker registory"
echo "http://${LOCALIPADDR}:5002"
echo "Daily backup will be stored to /var/opt/gitlab/backups/"
fi
echo ""

cd ${BASEPWD}
chmod -x $0
