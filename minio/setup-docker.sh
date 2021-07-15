#!/usr/bin/env bash

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

MINIO_ROOT_USER=minioadminuser
MINIO_ROOT_PASSWORD=minioadminuser
LOCALHOSTNAME=`hostname`
#### LOCALIP #########
ip address show ens160 >/dev/null
retval=$?
if [ ${retval} -eq 0 ]; then
        LOCALIPADDR=`ip -f inet -o addr show ens160 |cut -d\  -f 7 | cut -d/ -f 1`
else
  ip address show ens192 >/dev/null
  retval2=$?
  if [ ${retval2} -eq 0 ]; then
        LOCALIPADDR=`ip -f inet -o addr show ens192 |cut -d\  -f 7 | cut -d/ -f 1`
  else
        LOCALIPADDR=`ip -f inet -o addr show eth0 |cut -d\  -f 7 | cut -d/ -f 1`
  fi
fi
echo ${LOCALIPADDR}

if [ ! -f /usr/bin/docker ]; then
apt -y install docker.io
systemctl enable --now docker
fi

if [ ! -f /usr/local/bin/aws ]; then
apt -y install unzip
curl  -OL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
unzip awscli-exe-linux-x86_64.zip >/dev/null
sudo ./aws/install
echo "complete -C '/usr/local/bin/aws_completer' aws" >> /etc/profile.d/aws.sh
rm awscli-exe-linux-x86_64.zip
rm -rf ./aws
fi

if [ ! -f /usr/local/bin/mc ]; then
curl -OL https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
mv mc /usr/local/bin/
echo "complete -C /usr/local/bin/mc mc" > /etc/bash_completion.d/mc.sh
mc >/dev/null
fi

 if [ ! -f /root/.minio/certs/public.crt ]; then
mkdir -p /minio/config/certs
cd /minio/config/certs/
openssl genrsa -out private.key 2048
cat <<EOF> openssl.conf
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = VA
L = Somewhere
O = MyOrg
OU = MyOU
CN = MyServerName

[v3_req]
subjectAltName = @alt_names

[alt_names]
IP.1 = ${LOCALIPADDR}
DNS.1 = ${LOCALHOSTNAME}
EOF
openssl req -new -x509 -nodes -days 730 -key private.key -out public.crt -config openssl.conf
chmod 600 private.key
chmod 600 public.crt
cd
fi

mkdir -p /minio/data{1..4}
chmod -R 775 /minio/data*
docker run -d -p 9000:9000 --name minio --restart=always \
-e "MINIO_ROOT_USER=${MINIO_ROOT_USER}" \
-e "MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}" \
-e "MINIO_PROMETHEUS_AUTH_TYPE=public" \
-v /minio/data1:/data1 \
-v /minio/data2:/data2 \
-v /minio/data3:/data3 \
-v /minio/data4:/data4 \
-v /minio/config:/root/.minio \
minio/minio server /data{1...4}

mkdir ~/.aws
cat << EOF > ~/.aws/config
[profile minio]
region = us-east-1
EOF
cat << EOF > ~/.aws/credentials
[minio]
aws_access_key_id = ${MINIO_ROOT_USER}
aws_secret_access_key = ${MINIO_ROOT_PASSWORD}
EOF
chmod 600 ~/.aws/*
echo "export AWS_PROFILE=minio" >> /etc/profile

MINIO_ENDPOINT="https://${LOCALIPADDR}:9000"
mc alias rm local
mc alias set local ${MINIO_ENDPOINT} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} --api S3v4
cp /minio/config/certs/public.crt ~/.mc/certs/CAs/
sleep 10
mc admin info local/
echo "*************************************************************"
echo "MINIO_ROOT_USER=${MINIO_ROOT_USER}"
echo "MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}"
echo "Minio endpoint: ${MINIO_ENDPOINT}"
echo "*************************************************************"
echo "How to configure client at remote host:"
echo "Copy cert file to ~/.mc/cert/CA/"
echo "mc alias set Alias_Name ${MINIO_ENDPOINT} ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} --api S3v4"
echo "How to create immutable bucket:"
echo "source /etc/bash_completion.d/mc.sh"
echo "mc mb --with-lock local/Bucket_Name"
echo "mc ls local/"
echo "aws --no-verify --endpoint-url ${MINIO_ENDPOINT}  s3 ls"
#mc mb  --with-lock local/test1
#aws --no-verify --endpoint-url ${MINIO_ENDPOINT} s3 ls
#aws --no-verify --endpoint-url ${MINIO_ENDPOINT} s3api put-object-lock-configuration --bucket test1 --object-lock-configuration 'ObjectLockEnabled="Enabled"'
#aws --no-verify --endpoint-url ${MINIO_ENDPOINT} s3api get-object-lock-configuration --bucket test1

