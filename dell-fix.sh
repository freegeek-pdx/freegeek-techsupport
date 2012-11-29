#!/bin/bash



intel855(){
apt-add-repository ppa:glasen/intel-driver
apt-get update
apt-get upgrade
add-apt-repository ppa:glasen/855gm-fix
apt-get update
apt-get install linux 855gm-fix-dkms
}

reenable_kms(){
	echo options i915 modeset=1 | tee /etc/modprobe.d/i915-kms.conf
	update-initramfs -u
}

disable_dri(){
cat <<EOF >/etc/X11/xorg.conf
Section "Module"
        Disable "dri"
        Disable "glx"
EndSection
EOF
}


# MAIN
lspci | grep -q "855GM Integrated Graphics"
855_match=$?

if [[ $855_match -eq 0 ]]; then
	intel855
elif $(lspci | grep -e "8..GM Integrated Graphics") ; then 
	reenable_kms
else
	echo "8XX  chipset not found"
fi
