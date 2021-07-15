# Minio setup
Setup Minio with erasure coding with immutable.

## Requirement
* Linux:Ubuntu 20.04.2 Server (Clean install)  with 100GB HDD root volume (amd64 and arm64)
* Windows: Windows Server 2019 with .Net Framework 4.6.1 above

##Contents
* setup-docker.sh : minio for Linux docker version
* console-setup-docker.sh : minio console for Linux docker version

* setup-systemctl.sh: minio for Linux systemctl version
* console-setup-systemctl.sh: minio console for Linux systemctl version

* setup-win.ps1: for Windows version
* console-setup-win.ps1: for Windows version

## How to use
* ./setup-xxxx.sh or setup-win.ps1  

Once the script was done. You can create minio backet.  
* Linux: mc md --with-lock local/lockbucket
* Windows: c:\minio\mc.exe md --with-lock local/lockbucket

If you have setup minio console, you can access web console.
* http://your ip:9090/
* Access key: console
* Secret key: miniosecretkey

## Note
If you want to use actual storage, mount actall device in following location with xfs.
/minio/data1
/minio/data2 
/minio/data3 
/minio/data4 
