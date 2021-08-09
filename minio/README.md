# Minio setup
Setup Minio with erasure coding with immutable and minio console

## Requirement
* Linux:Ubuntu 20.04.2 Server (Clean install) with 100GB HDD root volume (amd64 and arm64)
* Windows: Windows Server 2019 with .Net Framework 4.6.1 above with 100GB HDD root volume

##Contents

* setup-systemctl.sh: minio for Linux systemctl version

* setup-win.ps1: for Windows version

## How to use
* ./setup-xxxx.sh or setup-win.ps1  

Once the script was done. You can create minio backet.  
* Linux: mc md --with-lock local/lockbucket
* Windows: c:\minio\mc.exe md --with-lock local/lockbucket

If you have setup minio endpoint, you can access via api
* https://your ip:9000/
* Access key: minioadminuser
* Secret key: minioadminuser

If you have setup minio console, you can access web console.
* https://your ip:9001/
* username: minioadminuser
* password: minioadminuser

## Note
If you want to use actual storage, mount actall device in following location with xfs.
* Linux/Docker
/minio/data1
/minio/data2 
/minio/data3 
/minio/data4 

* Windows
C:\minio\data1
C:\minio\data2
C:\minio\data3
C:\minio\data4
