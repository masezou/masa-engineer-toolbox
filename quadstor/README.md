# QuadStor VTL/VAAI in Ubuntu

Setup QuadStor VTL environment

## Pre-req
* Ubuntu 20.04.2 Server (Clean install and apt update; apt upgrade)
* Dedicate disk volume: 100GB above (Ex /dev/sdb)

## How to use
### QuadStore VTL
* ./setup-vtl.sh /dev/sdb
### QuadStore virt (GB)
* ./setup-virt.sh /dev/sdb 100

## Note
setup-part.sh is just sample script for partition creation.

