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

MINIOSECRETKEY=miniosecretkey
MINOSITE=local


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

# Prometheus
mkdir -p /minio/config/prometheus
cd /minio/config/prometheus
cat << EOF > prometheus.yml
scrape_configs:
- job_name: minio-job
  metrics_path: /minio/v2/metrics/cluster
  scheme: https
  static_configs:
  - targets: ['${LOCALIPADDR}:9000']
  tls_config:
   insecure_skip_verify: true
EOF
docker run -d -p 9090:9090 --name minio-prometheus \
  --restart=always \
  -v /minio/config/prometheus \
  prom/prometheus


mc admin info ${MINOSITE}
retval2=$?
if [ ${retval2} -ne 0 ]; then
        echo "minio server is not configured"
        exit 1
fi

echo -e "console\n${MINIOSECRETKEY}" | mc admin user add ${MINOSITE}/
cat > admin.json << EOF
{
        "Version": "2012-10-17",
        "Statement": [{
                        "Action": [
                                "admin:*"
                        ],
                        "Effect": "Allow",
                        "Sid": ""
                },
                {
                        "Action": [
                "s3:*"
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
mc admin policy add ${MINOSITE}/ consoleAdmin admin.json
rm admin.json
mc admin policy set ${MINOSITE}/ consoleAdmin user=console

docker run -d -p 9091:9090 --name minio-console --restart=always \
-e "CONSOLE_PBKDF_PASSPHRASE=SECRET" \
-e "CONSOLE_PBKDF_SALT=SECRET" \
-e "CONSOLE_MINIO_SERVER=https://${LOCALIPADDR}:9000" \
-e "CONSOLE_PROMETHEUS_URL=http://${LOCALIPADDR}:9090" \
-v /minio/config/certs/:/root/.console/certs/CAs \
  minio/console server

echo "*************************************************************************************"
echo "minio console is http://${LOCALIPADDR}:9091"
echo "Access Key is console"
echo "Secret Key is ${MINIOSECRETKEY}"
echo "minio console is installed and configured successfully"
echo ""echo "You can configure grafana dashboard."
echo "Add Prometheus ad datasource, http://localhost:9090"
echo "Add https://grafana.com/grafana/dashboards/13502"
