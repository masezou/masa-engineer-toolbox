#!/usr/bin/env bash
#########################################################

MCLOGINUSER=miniologinuser
MCLOGINPASSWORD=miniologinuser
MINIOPATH=/disk/minio

#########################################################
MINIO_ROOT_USER=minioadminuser
MINIO_ROOT_PASSWORD=minioadminuser
LOCALHOSTNAME=`hostname`

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

# Install Docker for client
if [ ! -f /usr/bin/docker ]; then
# Remove docker from snap and stop snapd
systemctl status snapd.service --no-pager
retvalsnap=$?
if [ ${retvalsnap} -eq 0 ]; then
   snap remove docker
   systemctl disable --now snapd
   systemctl disable --now snapd.socket
   systemctl disable --now snapd.seeded
   systemctl stop snapd
   apt -y remove --purge snapd gnome-software-plugin-snap
   apt -y autoremove
fi
# Remove docker from Ubuntu
apt -y purge docker docker.io
apt -y upgrade
apt -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
apt-key fingerprint 0EBFCD88
cat << EOF > /etc/apt/apt.conf.d/90_no_prompt
APT::Get::Assume-Yes "true";
APT::Get::force-yes "true";
EOF
if [ ${ARCH} = amd64 ]; then
  add-apt-repository  "deb [arch=amd64] https://download.docker.com/linux/ubuntu  $(lsb_release -cs)  stable"
 elif [ ${ARCH} = arm64 ]; then
  add-apt-repository  "deb [arch=arm64] https://download.docker.com/linux/ubuntu  $(lsb_release -cs)  stable"
 else
   echo "${ARCH} platform is not supported"
 exit 1
fi
apt -y install docker-ce-cli docker-ce
curl --retry 10 --retry-delay 3 --retry-connrefused -sS https://raw.githubusercontent.com/containerd/containerd/v1.5.10/contrib/autocomplete/ctr -o /etc/bash_completion.d/ctr
if [ ! -f /usr/local/bin/nerdctl ]; then
apt -y install uidmap
NERDCTLVER=0.18.0
curl --retry 10 --retry-delay 3 --retry-connrefused -sSOL https://github.com/containerd/nerdctl/releases/download/v${NERDCTLVER}/nerdctl-full-${NERDCTLVER}-linux-${ARCH}.tar.gz
tar xfz nerdctl-full-${NERDCTLVER}-linux-${ARCH}.tar.gz -C /usr/local
rm -rf nerdctl-full-${NERDCTLVER}-linux-${ARCH}.tar.gz
nerdctl completion bash > /etc/bash_completion.d/nerdctl
sed -i -e 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1"/g' /etc/default/grub
update-grub
mkdir -p /etc/systemd/system/user@.service.d
cat <<EOF | sudo tee /etc/systemd/system/user@.service.d/delegate.conf
[Service]
Delegate=cpu cpuset io memory pids
EOF
systemctl daemon-reload
fi
groupadd docker
if [ -z $SUDO_USER ]; then
  echo "there is no sudo login"
else
usermod -aG docker ${SUDO_USER}
fi
systemctl enable docker
systemctl daemon-reload
systemctl restart docker

# watchtower
docker run --detach \
    --restart=always \
    --name watchtower \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower
    

fi
# Install Docker Compose
if [ ! -f /usr/local/bin/docker-compose ]; then
DOCKERCOMPOSEVER=2.5.0
if [ ${ARCH} = amd64 ]; then
  curl -OL https://github.com/docker/compose/releases/download/v${DOCKERCOMPOSEVER}/docker-compose-linux-x86_64
  mv docker-compose-linux-x86_64 /usr/local/bin/docker-compose
 elif [ ${ARCH} = arm64 ]; then
  curl -OL https://github.com/docker/compose/releases/download/v${DOCKERCOMPOSEVER}/docker-compose-linux-aarch64
  mv docker-compose-linux-aarch64 /usr/local/bin/docker-compose
 else
   echo "${ARCH} platform is not supported"
 exit 1
fi
chmod +x /usr/local/bin/docker-compose
curl -L https://raw.githubusercontent.com/docker/compose/1.29.2/contrib/completion/bash/docker-compose  -o /etc/bash_completion.d/docker-compose
fi

mkdir -p ${MINIOPATH}

# Create SSL Key
MINIOCERTPATH=${MINIOPATH}/config/certs/
if [ ! -f ${MINIOCERTPATH}/public.crt ]; then
mkdir -p ${MINIOCERTPATH}
openssl genrsa -out ${MINIOCERTPATH}/rootCA.key 4096
openssl req -x509 -new -nodes -key ${MINIOCERTPATH}/rootCA.key -sha256 -days 1825 -out ${MINIOCERTPATH}/rootCA.pem -subj "/C=JP/ST=Tokyo/L=Shibuya/O=cloudshift.corp/OU=development/CN=exmaple CA"
openssl genrsa -out ${MINIOCERTPATH}/private.key 2048
openssl req -subj "/CN=${LOCALIPADDR}" -sha256 -new -key ${MINIOCERTPATH}/private.key -out ${MINIOCERTPATH}/cert.csr
cat << EOF > ${MINIOCERTPATH}/extfile.conf
subjectAltName = DNS:${LOCALHOSTNAME}, IP:${LOCALIPADDR}
EOF
openssl x509 -req -days 365 -sha256 -in ${MINIOCERTPATH}/cert.csr -CA ${MINIOCERTPATH}/rootCA.pem -CAkey ${MINIOCERTPATH}/rootCA.key -CAcreateserial -out ${MINIOCERTPATH}/public.crt -extfile ${MINIOCERTPATH}/extfile.conf
chmod 600 ${MINIOCERTPATH}/private.key
chmod 600 ${MINIOCERTPATH}/public.crt
chmod 600 ${MINIOCERTPATH}/rootCA.pem
mkdir -p ${MINIOCERTPATH}/CAs
cp ${MINIOCERTPATH}/rootCA.pem ${MINIOCERTPATH}/CAs
openssl x509 -in ${MINIOCERTPATH}/public.crt -text -noout| grep IP
fi

# Prometheus
cat << EOF > ${MINIOPATH}/prometheus.yml
scrape_configs:
- job_name: minio-job
  metrics_path: /minio/v2/metrics/cluster
  scheme: https
  static_configs:
  - targets: ['minio:9000']
  tls_config:
   insecure_skip_verify: true
EOF

# Docker-compose
cat << EOF > docker-compose.yml
version: "3.7"
services:
    prometheus:
        image: prom/prometheus
        restart: always
        command: --config.file=/etc/prometheus/prometheus.yml
        ports:
            - "9090:9090"
        volumes:
            - ${MINIOPATH}/prometheus.yml:/etc/prometheus/prometheus.yml
    minio:
        image: minio/minio
        environment:
            - MINIO_ROOT_USER=${MINIO_ROOT_USER}
            - MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
            - MINIO_PROMETHEUS_AUTH_TYPE=public
            - MINIO_PROMETHEUS_URL=http://${LOCALIPADDR}:9090
            - MINIO_SERVER_URL=https://${LOCALIPADDR}:9000
        healthcheck:
            test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
            interval: 30s
            timeout: 20s
            retries: 3
        command: server /data{1...4} --console-address ":9001"
        ports:
            - "9000:9000"
            - "9001:9001"
        volumes:
            - ${MINIOPATH}/data1:/data1
            - ${MINIOPATH}/data2:/data2
            - ${MINIOPATH}/data3:/data3
            - ${MINIOPATH}/data4:/data4
            - ${MINIOPATH}/config:/root/.minio
        restart: always
EOF

docker-compose up -d

sleep 3
mkdir -p ~/.mc/certs/CAs/
docker pull minio/mc
shopt -s expand_aliases
alias mc="docker run --rm -v ~/.mc:/root/.mc minio/mc"
echo "alias mc=\"docker run --rm -v ~/.mc:/root/.mc minio/mc\"" >> ~/.bash_aliases
MINIO_ENDPOINT="https://${LOCALIPADDR}:9000"
mc alias rm local
mc alias set local ${MINIO_ENDPOINT} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} --api S3v4
cp ${MINIOCERTPATH}/public.crt ~/.mc/certs/CAs/

cat << EOF > ~/.mc/s3user.json
{
        "Version": "2012-10-17",
        "Statement": [{
                        "Action": [
                                "admin:ServerInfo"
                        ],
                        "Effect": "Allow",
                        "Sid": ""
                },
                {
                        "Action": [
                                "s3:ListenBucketNotification",
                                "s3:PutBucketNotification",
                                "s3:GetBucketNotification",
                                "s3:ListMultipartUploadParts",
                                "s3:ListBucketMultipartUploads",
                                "s3:ListBucket",
                                "s3:HeadBucket",
                                "s3:GetObject",
                                "s3:GetBucketLocation",
                                "s3:AbortMultipartUpload",
                                "s3:CreateBucket",
                                "s3:PutObject",
                                "s3:DeleteObject",
                                "s3:DeleteBucket",
                                "s3:PutBucketPolicy",
                                "s3:DeleteBucketPolicy",
                                "s3:GetBucketPolicy"
                        ],
                        "Effect": "Allow",
                        "Resource": [
                                "arn:aws:s3:::*"
                        ],
                        "Sid": ""
                }
        ]
}
EOF
mc admin policy add local/ s3user ~/.mc/s3user.json
mc admin user add local ${MCLOGINUSER} ${MCLOGINPASSWORD}
mc admin policy set local s3user,consoleAdmin user=${MCLOGINUSER}

mc admin info local/
echo ""
echo "*************************************************************************************"
echo "Minio API endpoint is ${MINIO_ENDPOINT}"
echo "Access Key ${MCLOGINUSER}"
echo "Secret Key ${MCLOGINPASSWORD}"
echo "Minio console is https://${LOCALIPADDR}:9001"
echo "username: ${MCLOGINUSER}"
echo "password: ${MCLOGINPASSWORD}"
echo "minio and mc was installed and configured successfully"
echo ""
echo "*************************************************************************************"
echo "Next Step"
echo "If you want to use mc command, please re-login or type following"
echo "alias mc=\"docker run -v /root/.mc:/root/.mc minio/mc\""
echo "*************************************************************"
echo "How to configure client at remote host:"
echo "Copy cert file to ~/.mc/cert/CA/"
echo "mc alias set Alias_Name ${MINIO_ENDPOINT} ${MCLOGINUSER} ${MCLOGINPASSWORD} --api S3v4"
echo "How to create immutable bucket:"
echo "mc mb --with-lock local/Bucket_Name"
echo "mc ls local/"
