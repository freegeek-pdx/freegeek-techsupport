#!/bin/bash
# this file has the following standard layout
# CONFIGURATION
# help function
# INCLUDES
#FUNCTIONS
# process option arguments
# MAIN

# CONFIGURATION

package_loc="http://tsbackup/"
tst_pkg="tstools.tar.gz"
backup_host="tsbackup"

help(){
cat <<EOF 

usage: $0 [OPTION]...
Upgrade from Ubuntu 10.4 to Xubuntu12.04 with Freegeek Tweaks
        
-h                      prints this message
-n                      No remove. Do not remove any installed packages 
-t                      ticket number            

Upgrades from Ubuntu 10.4 to Xubuntu12.04 with Freegeek Tweaks. 
Creates a backup first.
Optionally leave all installed packages (e.g. unity, gnome packages) in place.
 
EOF

# if $1 exists and is a number 0..255 return that otherwise return 0
if [[ -n $1 && $(echo {0..255}) =~ $1 ]]; then
        exit $1
else
        exit 0
fi
}
# INCLUDES
#FUNCTIONS

# process option arguments
while getopts "hnt:" option; do            # w: place variable following w in $OPTARG
        case "$option" in
                h) help;;
                n)no_remove=true;;
                t)ticket=$OPTARG;;
                [?])  echo "bad option supplied" ; 
                help;;
        esac
done

#MAIN


# get tstools
if ! wget ${package_loc}${tst_pkg} ; then
    echo "failed to download tstools"
    exit 3
fi

if ! tar -xvzf $tst_pkg; then
    echo "could not extract $tst_pkg"
    exit 3
fi



# do backup

if [[ -e $PWD/tstools_package/ts_network_backup ]]; then
    tsnb="$PWD/tstools_package/ts_network_backup" 
else 
    tsnb=$(find -name ts_network_backup -print)
fi

chmod +x $tsnb

now=$(date +%Y%m%d)
if [[ -z $ticket ]]; then
    echo "Enter ticket number for this job"
    read ticket
fi

if ! sudo $tsnb -c $ticket; then
    echo "failed to backup system!"
    exit 5
fi

# remove fregeek refs from etc/apt/sources.list etc
sed -i    's/^.*freegeek/# &/g' /etc/apt/sources.list

mv /etc/apt/sources.list.d/freegeek-extras.list /etc/apt/sources.list.d/freegeek-extras.list.bak.$now
mv /etc/apt/sources.list.d/freekbox.list /etc/apt/sources.list.d/freekbox.list.bak.$now

# do release upgrade
if ! do-release-upgrade ; then
    echo "Sigh. Something went wrong"
    echo "You will have to fix this by hand"
    echo "You might need to reinstall"
    echo "check your backup ${now}-${ticket} on $backup_host is valid"
    exit 7
fi

# add back freegeek to /etc/apt/sources.list.d

cat << 'EOF'  > /etc/apt/sources.list.d/freegeek-extras.list
# debian sources for freegeek specific packages
# install into /etc/apt/sources.list.d

deb http://apt.freegeek.org/ubuntu precise main
EOF 


# install xubuntu, freegeek-stuff
sudo apt-get purge lightdm
sudo mv /etc/lightdm/ /root/
sudo apt-get install xubuntu-desktop freegeek-default-settings lightdm-gtk-greeter lightdm freegeek-extras


# remove unity etc

if [[ ! $no_remove ]];  then
    big_ass_list_of_packages_to_remove="gnome-control-center gnome-font-viewer gnome-media gnome-menus gnome-nettool gnome-power-manager gnome-screenshot gnome-session gnome-session-canberra gnome-system-log gnome-system-monitor gnome-terminal gcalctool eog nautilus nuatilus-sendto unity unity-2d unity-greeter gnome-bluetooth gnome-disk-utility gnome-orca gnome-screensaver gnome-sudoku gnomine ubuntuone-client-gnome
"
    for package in big_ass_list_of_packages_to_remove; do
       if  dpkg-query  -l  bash  2>/dev/null  | grep -q ^.i; then
            list_of_packages_to_remove="$list_of_packages_to_remove $package"
       fi
    done

    sudo apt-get remove $list_of_packages_to_remove

fi

# do a happy dance

do_happy_dance(){
    echo "It worked! $HOST does a happy dance! You should too."
}

do_happy_dance
