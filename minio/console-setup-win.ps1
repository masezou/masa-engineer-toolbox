New-NetFirewallRule -DisplayName "Allow-Inbound-TCP9000" -Direction Inbound -Protocol TCP -LocalPort 9090 -Action Allow
New-NetFirewallRule -DisplayName "Allow-Inbound-TCP9000" -Direction Inbound -Protocol TCP -LocalPort 9091 -Action Allow
cd C:\minio
Invoke-WebRequest -Uri https://github.com/minio/console/releases/latest/download/console-windows-amd64.exe -OutFile console.exe
Invoke-WebRequest -Uri https://github.com/prometheus/prometheus/releases/download/v2.28.0/prometheus-2.28.0.windows-amd64.zip -OutFile prometheus-2.28.0.windows-amd64.zip
Invoke-WebRequest -Uri https://github.com/winsw/winsw/releases/download/v2.11.0/WinSW.NET461.exe -OutFile console-service.exe 

mkdir C:\minio\prometheus
cd C:\minio\prometheus
Expand-Archive -Path C:\minio\prometheus-2.28.0.windows-amd64.zip -DestinationPath C:\minio\prometheus

cp C:\minio\console-service.exe C:\minio\prometheus\prometheus-service.exe 
cp C:\minio\prometheus\prometheus-2.28.0.windows-amd64\prometheus.exe C:\minio\prometheus\

$env:TARGETHOST = $Env:COMPUTERNAME
$env:TARGETHOST = $Env:TARGETHOST+=":9000"
write-host $env:TARGETHOST
echo @"
scrape_configs:
- job_name: minio-job
  metrics_path: /minio/v2/metrics/cluster
  scheme: https
  static_configs:
  - targets: ['$env:TARGETHOST']
  tls_config:
   insecure_skip_verify: true
"@ >prometheus.yml
echo @"
<service>
  <id>Prometheus</id>
  <name>Prometheus</name>
  <description>Prometheus for Minio</description>
  <executable>prometheus.exe</executable>
  <arguments>--config.file=C:\minio\prometheus\prometheus.yml --web.listen-address=:9091</arguments>
  <logmode>rotate</logmode>
  <serviceaccount>
    <domain>$Env:COMPUTERNAME</domain>
    <user>Administrator</user>
    <password>Password00!</password>
    <allowservicelogon>true</allowservicelogon>
  </serviceaccount>
</service>
"@ >prometheus-service.xml
./prometheus-service.exe install
start-service prometheus

cd C:\minio\
C:\minio\mc.exe admin user add local/ console miniosecretkey
echo @"
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
"@ >admin.json
$targetpath = "C:\minio\admin.json"
(Get-Content $targetpath) -Join "`r`n" | Set-Content $targetpath
C:\minio\mc.exe admin policy add local/ consoleAdmin admin.json
del C:\minio\admin.json
C:\minio\mc.exe admin policy set local/ consoleAdmin user=console

$env:CONSOLE_MINIO_SERVER = $Env:COMPUTERNAME
$env:CONSOLE_MINIO_SERVER = $Env:CONSOLE_MINIO_SERVER+=":9000"
$env:CONSOLE_MINIO_SERVER = "https://"+$Env:CONSOLE_MINIO_SERVER
write-host $env:CONSOLE_MINIO_SERVER
$env:CONSOLE_PROMETHEUS_URL = $Env:COMPUTERNAME
$env:CONSOLE_PROMETHEUS_URL = $Env:CONSOLE_PROMETHEUS_URL+=":9091"
$env:CONSOLE_PROMETHEUS_URL = "http://"+$Env:CONSOLE_PROMETHEUS_URL
write-host $env:CONSOLE_PROMETHEUS_URL

echo @"
<service>
  <id>MinIOConsole</id>
  <name>Console</name>
  <description>MinIO Console is a high performance object storage server</description>
  <executable>console.exe</executable>
  <env name="CONSOLE_OPTS" value="--port 9090"/>
  <env name="CONSOLE_PBKDF_PASSPHRASE" value="GSECRET"/>
  <env name="CONSOLE_PBKDF_SALT" value="SECRET" />
  <env name="CONSOLE_MINIO_SERVER" value="$env:CONSOLE_MINIO_SERVER" />
  <env name="CONSOLE_PROMETHEUS_URL" value="$env:CONSOLE_PROMETHEUS_URL" />
  <arguments>server</arguments>
  <logmode>rotate</logmode>
  <serviceaccount>
    <domain>$Env:COMPUTERNAME</domain>
    <user>Administrator</user>
    <password>Password00!</password>
    <allowservicelogon>true</allowservicelogon>
  </serviceaccount>
</service>
"@ >console-service.xml

./console-service.exe install
start-service console

mkdir $env:USERPROFILE\.console\certs\CAs
cp  $env:USERPROFILE\.minio\certs\public.crt $env:USERPROFILE\.console\certs\CAs

$env:URLHOST2 = $Env:COMPUTERNAME
$env:URLHOST2 = $Env:URLHOST2+=":9090"
write-host $env:URLHOST2

start http://$env:URLHOST2
Write-Host Done. credential is console. Hit any key -NoNewLine
[Console]::ReadKey() | Out-Null

