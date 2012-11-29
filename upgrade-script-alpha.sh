#!/bin/bash

# make a file listing the packages installed by ubuntu-desktop
apt-cache depends ubuntu-desktop | sed -e 's/ubuntu-desktop//' | sed -e 's/  Depends: //' | sed -e 's/  Recommends: //' > ubuntu-depends.txt

# purge those packages ( maybe just 'remove' is better )
apt-get purge `cat ubuntu-depends.txt`

dhclient eth0
apt-get update # may need to run 'dhclient eth0' first

# ( so that lightdm will start later )
mv /var/lib/lightdm /var/lib/lightdm.bak

apt-get install xubuntu-desktop

## to install freegeek stuff

add-apt-repository "deb http://apt.freegeek.org/ubuntu lucid main"

apt-get install freegeek-archive keyring

apt-get update

apt-get install freegeek-default-settings
