#!/usr/bin/env bash

MINIOSECRETKEY=miniosecretkey
MINOSITE=local

#########################################################
### UID Check ###
if [ ${EUID:-${UID}} != 0 ]; then
    echo "This script must be run as root"
    exit 1
else
    echo "I am root user."
fi

### Distribution Check ###
lsb_release -d | grep Ubuntu | grep 20.04
DISTVER=$?
if [ ${DISTVER} = 1 ]; then
    echo "only supports Ubuntu 20.04 server"
    exit 1
else
    echo "Ubuntu 20.04=OK"
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
  echo "${ARCH} platform is not supported"
  exit 1
fi

#### LOCALIP #########
ip address show ens160 >/dev/null
retval=$?
if [ ${retval} -eq 0 ]; then
        LOCALIPADDR=`ip -f inet -o addr show ens160 |cut -d\  -f 7 | cut -d/ -f 1`
else
        LOCALIPADDR=`ip -f inet -o addr show eth0 |cut -d\  -f 7 | cut -d/ -f 1`
fi
echo ${LOCALIPADDR}

#########################################################

mc admin info ${MINOSITE}
retval2=$?
if [ ${retval2} -ne 0 ]; then
        echo "minio server is not configured"
        exit 1
fi

# Prometheus
 if [ ! -f /usr/local/prometheus/prometheus-server/prometheus-server ]; then
PROMETHEUSVER=2.28.0
mkdir -p /usr/local/prometheus
cd /usr/local/prometheus
curl -OL https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUSVER}/prometheus-${PROMETHEUSVER}.linux-${ARCH}.tar.gz
tar zxf prometheus-${PROMETHEUSVER}.linux-${ARCH}.tar.gz
mv prometheus-${PROMETHEUSVER}.linux-${ARCH} prometheus-server
cd prometheus-server
mv prometheus.yml prometheus.yml.org
cat << EOT > prometheus.yml
scrape_configs:
- job_name: minio-job
  metrics_path: /minio/v2/metrics/cluster
  scheme: https
  static_configs:
  - targets: ['${LOCALIPADDR}:9000']
  tls_config:
   insecure_skip_verify: true
EOT

cat << EOT > /usr/lib/systemd/system/prometheus.service
[Unit]
Description=Prometheus - Monitoring system and time series database
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/prometheus/prometheus-server/prometheus \
  --config.file=/usr/local/prometheus/prometheus-server/prometheus.yml --web.listen-address=:9091 \

[Install]
WantedBy=multi-user.target
EOT
systemctl enable --now prometheus.service
systemctl status prometheus.service --no-pager
fi


if [ ! -f /usr/local/bin/console ]; then
curl -OL https://github.com/minio/console/releases/latest/download/console-linux-${ARCH}
mv console-linux-${ARCH}  /usr/local/bin/console
chmod +x /usr/local/bin/console
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

# For https connection
mkdir -p ~/.console/certs/CAs
cp -f ~/.minio/certs/public.crt ~/.console/certs/CAs

### add minio-console to systemctl
if [ ! -f /etc/systemd/system/minio-console.service ]; then

if [ ! -f /etc/default/minio-console ]; then
cat <<EOT >> /etc/default/minio-console
# Special opts
CONSOLE_OPTS="--port 9090"
# salt to encrypt JWT payload
CONSOLE_PBKDF_PASSPHRASE=GSECRET
# required to encrypt JWT payload
CONSOLE_PBKDF_SALT=SECRET
# MinIO Endpoint
CONSOLE_MINIO_SERVER=https://${LOCALIPADDR}:9000
# Prometheus
CONSOLE_PROMETHEUS_URL=http://${LOCALIPADDR}:9091
# Log Search Setting
#LOGSEARCH_QUERY_AUTH_TOKEN=<<Token>>
#CONSOLE_LOG_QUERY_URL=http://localhost:Port

EOT
fi

( cd /etc/systemd/system/; curl -O https://raw.githubusercontent.com/minio/console/master/systemd/console.service )
sed -i -e 's/console-user/root/g' /etc/systemd/system/console.service
systemctl enable --now console.service
systemctl status console.service --no-pager
fi

echo ""
echo "*************************************************************************************"
echo "minio console is http://${LOCALIPADDR}:9090"
echo "Access Key is console"
echo "Secret Key is ${MINIOSECRETKEY}"
echo "minio console is installed and configured successfully"
echo ""
echo "You can configure grafana dashboard."
echo "Add Prometheus ad datasource, http://localhost:9091"
echo "Add https://grafana.com/grafana/dashboards/13502"
