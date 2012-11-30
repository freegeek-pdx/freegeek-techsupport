#!/bin/bash

# made this a variable at the top of the script so we can change 
# it easily at a later date without having to search for it.

fg_repository="deb http://apt.freegeek.org/ubuntu lucid main"

# added functions for things we do repeatedly so we have error checking

#FUNCTIONS
run_update{}(
if ! apt-get update; then  # may need to run 'dhclient eth0' first
        echo
        echo "Error running apt-get update! Exiting..."
        exit 3
fi
)

install_pkg{}(
package=$1
if ! apt-get install $package; then
        echo
        echo "Failed to install $package! Exiting..."
        exit 4
fi
)
## make a file listing the packages installed by ubuntu-desktop
#apt-cache depends ubuntu-desktop | sed -e 's/ubuntu-desktop//' | sed -e 's/  Depends: //' | sed -e 's/  Recommends: //' > ubuntu-depends.txt

# purge those packages ( maybe just 'remove' is better )
#apt-get purge `cat ubuntu-depends.txt`

# This manages to qualify both as a useless use of cat and uses the evil backticksa unless we are worrying about overflowing the shell in which case it sohuld be a tmp file (and check to see if it was written) etc  
# See: http://www.commandlinefu.com/commands/view/1387/backticks-are-evil
# http://www.shlomifish.org/open-source/anti/csh/
# http://stackoverflow.com/questions/11710552/useless-use-of-cat
# http://partmaps.org/era/unix/award.html


# rewritten

# (for clarity making this a variable rather than using a subshell with apt-get ) 
depends_list=$(apt-cache depends ubuntu-desktop | sed -e 's/ubuntu-desktop//' | sed -e 's/  Depends: //' | sed -e 's/  Recommends: //')

apt-get purge $depends_list

# We can't assume eth0 is the right interface
#dhclient eth0
interfaces=$(ifconfig -a -s | awk '{if (NR!=1) {print $1}}')
for interface in $interfaces; do
    if dhclient $interface; then
        has_network=true
        break
    fi
done

if [[ -n $has_network ]]; then
    echo 
    echo "Could not get a network connection. Exiting..."
    exit 5
elif ! ping -qc apt.freegeek.org; then
    echo    
    echo "Could not reach an outside host. Exiting..."
    exit 5
fi

#added error check and made function
#apt-get update  # may need to run 'dhclient eth0' first

run_update

# ( so that lightdm will start later )
now=$(date +%Y%m%d%H%M)

mv /var/lib/lightdm /var/lib/lightdm.bak.$now

if ! apt-get install xubuntu-desktop; then
        echo
        echo "Failed to install xubuntu-desktop! Exiting..."
        exit 4
fi
## to install freegeek stuff

# converted the following to their function form

# apt-get install freegeek-archive keyring
#add-apt-repository "deb http://apt.freegeek.org/ubuntu lucid main"
#apt-get install freegeek-archive keyring
#apt-get update
#apt-get install freegeek-default-settings

if ! add-apt-repository $fg_repository; then
        echo 
        echo "Could not add Free Geek repository! Exiting"
fi
install_pkg freegeek-archive keyring

run_update

install_pkg freegeek-default-settings

echo "Everything should be done"

