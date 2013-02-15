#!/bin/bash

apt-get remove linux 855.gm-fix.dkms
sudo rm /etc/apt/sources.list.d/glasen-*
sudo rm /etc/apt/sources.list.d/brian-*
sudo rm /etc/X11/xorg.conf
apt-get update
apt-get upgrade
