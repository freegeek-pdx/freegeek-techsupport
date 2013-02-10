#!/bin/bash
# this file has the following standard layout
# CONFIGURATION
# help function
#FUNCTIONS
# process option arguments
# MAIN

# CONFIGURATION

package_loc="http://tsbackup/"
tst_pkg="tstools.tar.gz"
backup_host="tsbackup"
version=$(lsb_release -a 2> /dev/null | grep Release | awk '{print $2}')

help(){
cat <<EOF 

usage: $0 -s|c [OPTION]...
Upgrade from Ubuntu 10.4 to Xubuntu12.04 with Freegeek Tweaks
        
-h                      Prints this message.
-f                      Force overwrite of existing backup 
-n                      No remove. Do not remove any installed package
-t [NUMBER]             Ticket number.   
-l [LOGFILE]            Write to logfile as well as terminal.

Upgrades from Ubuntu 10.4 to Xubuntu12.04 with Freegeek Tweaks. 
Creates a backup first.
Optionally leave all installed packages (e.g. unity, gnome packages) in place.
The script needs to be run twice. You will need to reboot after the first run 
has completed.
EOF

# if $1 exists and is a number 0..255 return that otherwise return 0
if [[ -n $1 && $(echo {0..255}) =~ $1 ]]; then
        exit $1
else
        exit 0
fi
}

#FUNCTIONS

check_file_write(){
        local file=$1
        touch $file &>/dev/null
        return $?
}

# write to error log and/or standard out 
write_msg(){
local msg="$@"  
for line in "$msg"; do 
        echo "$line"
        if [[ $logfile ]]; then
                if ! echo "$line" >>$logfile; then 
                # should not hit here as already checked
                echo "Could not write to Log File: $logfile"
                exit 3
                fi
        fi
done
return 0
}


test_for_root(){
        if [[ $EUID -ne 0 ]]; then
                return 1
        else
                return 0
        fi
}


# remove fregeek refs from etc/apt/sources.list etc
remove_fg(){
    local returnval=0
    if ! sed -i    's/^.*freegeek/# &/g' /etc/apt/sources.list; then
        write_msg 'failed to remove fg line form sources.list'
        returnval=1
    fi
    if ! rm /etc/apt/sources.list.d/freegeek-extras.list  ; then
        write_msg "failed to move /etc/apt/sources.list.d/freegeek-extras.list"
        returnval=1
    fi
    if [[ -e /etc/apt/sources.list.d/freekbox.list ]]; then
        if ! rm /etc/apt/sources.list.d/freekbox.list ; then
            write_msg  "failed to move /etc/apt/sources.list.d/freekbox.list"
            returnval=1
        fi
    fi
    return $returnval
}

# ensure upgrade is set to lts in /etc/update-manager/release-upgrades
check_release-upgrades(){
    # this is where update-manger stores the config option for prompting 
    # for upgrades. It can be set to normal,lts or never
    release_file="/etc/update-manager/release-upgrades"
    # always set to lts  
    if ! sed -i.bak -e 's/prompt=never/prompt=lts/' $release_file;then
        return 1
    elif ! sed -i.bak -e 's/prompt=normal/prompt=lts/' $release_file; then
        return 1
    else
        return 0
    fi
}

# process option arguments
while getopts "hfnt:l:" option; do            # w: place variable following w in $OPTARG
        case "$option" in
                h) help;;
                f) force_overwrite="true";;
                n)no_remove="true";;
                t)ticket=$OPTARG;;
                l)logfile=$OPTARG;;
                [?])  echo "bad option supplied" ; 
                help;;
        esac
done

#MAIN

if [[ $logfile ]]; then
    if ! check_file_write $logfile ; then
        echo "could not write to $logfile"
        exit 3
    fi
fi

if ! test_for_root; then
    write_msg "You must execute this script with root privileges"
    write_msg "i.e. using sudo"
    exit 3
fi


if [[ -e /home/.first_run_success ]]; then
    second_run="true"
else
    first_run="true"
fi


if [[ $first_run ]]; then
    if [[ $version != "10.04" ]] ; then
        write_msg "This computer is not running Ubuntu 10.04"
        write_msg "This script is designed and tested only for 10.04"
        write_msg "It might work for other LTS versions, if you update the script"
        exit 3
    fi
    write_msg "Running the first part of the upgrade process"
    # get tstools
    if ! wget ${package_loc}${tst_pkg} ; then
       write_msg "failed to download tstools"
        exit 3
    fi

    if ! tar -xvzf $tst_pkg; then
        write_msg "could not extract $tst_pkg"
        exit 3
    fi


    # do backup

    if [[ -e $PWD/tstools_package/ ]]; then
        tsnb="$PWD/tstools_package/" 
    else 
        tsnb=$(find -name tstools_package -print)
    fi
    cd $tsnb
    chmod +x ./ts_network_backup
    now=$(date +%Y%m%d)
    if [[ -z $ticket ]]; then
        echo "Enter ticket number for this job"
        read ticket
    fi
    # force overwrite of existing backup
    if [[ $force_overwrite ]]; then
        backup_command="./ts_network_backup -Fc"
    else
        backup_command="./ts_network_backup -c"
    fi
    # backup using ts_network_backup
    if ! $backup_command $ticket; then
        write_msg "failed to backup system!"
        exit 5
    fi
    
    # ensure upgrade is set to lts in /etc/update-manager/release-upgrades
    if ! check_release-upgrades; then
        write_msg "This machine is set never to update to a new version"
        write_msg "Unable to update this"
        exit 6
    fi

    # remove free geek sources
    if ! remove_fg; then
        write_msg "Could not remove Free Geek sources, preceeding anyway..."
    fi


    # do dist-upgrade
    if ! apt-get update; then
        write_msg "could not update package list"
        exit 3
    fi

    if ! apt-get -y dist-upgrade; then
        write_msg "could not perform dist-upgrade"
        exit 4
    fi

    # do release upgrade
    write_msg "If the next part is sucesfull, reboot and run the script a second time"
    write_msg "Important hit the x key to exit when the system prompts you to reboot"
    write_msg "Otherwise you will end up having to run this part all over again"

    write_msg "hit any key to continue..."
    read -n 1 
    do-release-upgrade 
    if [[ $? -ne 0 ]]; then
        write_msg "Sigh. Something went wrong"
        write_msg "You will have to fix this by hand"
        write_msg "You might need to reinstall"
        write_msg "check your backup ${now}-${ticket} on $backup_host is valid"
        exit 7
    else
        touch /home/.first_run_success
        write_msg  "Sucessfully completed first part of backup"
        write_msg  "Reboot and run the script a second time"
        exit 0
    fi
elif [[ $second_run ]]; then
    write_msg "Preparing to finish the upgrade process"
    # install xubuntu
    #apt-get -y  purge lightdm
    #mv /etc/lightdm/ /root/
    # hangs here or just after need check on apt-get -y  purge lightdm
    # may not be woring, might only need to do this if it is a problem so skip this step??

    xub_msg=$(apt-get -y  install xubuntu-desktop)
    if [[ $? -ne 0 ]]; then
        write_msg "could not install xubuntu! aborting..."
        write_msg "apt-get output:"
        write_msg "$xub_msg"
        exit 5
    else
        write_msg "succesfully installed Xubuntu"
    fi 



    # add back freegeek to /etc/apt/sources.list.d

    apt_file="/etc/apt/sources.list.d/freegeek-extras.list"
    echo "# debian sources for freegeek specific packages" >$apt_file
    echo "# install into /etc/apt/sources.list.d" >>$apt_file

    echo "deb http://apt.freegeek.org/ubuntu precise main" >>$apt_file


    if [[ ! -e /etc/apt/sources.list.d/freegeek-extras.list ]]; then
        write_msg "Could not add Free Geek Sources"
        write_mg  "You will need to fix this and install freegeek-extras and freegeek-default-settings manually"
    elif ! apt-get -y  install freegeek-default-settings freegeek-extras; then
        write_msg "Could not install freegeek-extras and freegeek-default-settings"
        write_msg "You will need to do this  manually" 
    else
        write_msg "Added back Free Geek sources"    
    fi

    # ensure upgrade is set to lts in /etc/update-manager/release-upgrades
    if ! check_release-upgrades; then
        write_msg "This machine is set never to update to a new version"
        write_msg "Unable to update this"
        exit 6
    fi

    # remove unity etc
    write_msg "preparing to remove unused packages"

    if [[ ! $no_remove ]];  then
        big_ass_list_of_packages_to_remove="gnome-control-center gnome-font-viewer gnome-media gnome-menus gnome-nettool gnome-power-manager gnome-screenshot gnome-session gnome-session-canberra gnome-system-log gnome-system-monitor gnome-terminal gcalctool eog nautilus nautilus-sendto unity unity-2d unity-greeter gnome-bluetooth gnome-disk-utility gnome-orca gnome-screensaver gnome-sudoku gnomine ubuntuone-client-gnome  geoclue-ubuntu-geoip gir1.2-gnomebluetooth-1.0 gnome-control-center-data gnome-dictionary gnome-online-accounts gnome-search-tool gnome-session-common indicator-printers libbamf3-0 libgmp3c2 libgnome-media-profiles-3.0-0 libqt4-svg libunity-misc4 nux-tools unity-2d-shell unity-2d-spread unity-asset-pool unity-common unity-lens-applications unity-lens-files unity-lens-music unity-lens-video unity-scope-video-remote"

        for package in $big_ass_list_of_packages_to_remove; do
           if  dpkg-query  -l  bash  2>/dev/null  | grep -q ^.i; then
                list_of_packages_to_remove="$list_of_packages_to_remove $package"
           fi
        done
        write_msg "removing: $list_of_packages_to_remove"
        remove_msg=$(apt-get -y remove $list_of_packages_to_remove)
        if [[ $? -ne 0 ]]; then
            write_msg "Could not remove (some of) $list_of_packages_to_remove"
            write_msg "apt-get remove output:"
            write_msg "$remove_msg"
            exit 6
        else
            write_msg "Sucessfully removed $list_of_packages_to_remove"
        fi
    fi
    
    # Do basic cleanup
    write_msg "cleaning up unused packages"
    autoremove_msg=$(apt-get -y autoremove)
    if [[ $? -ne 0 ]]; then
        write_msg "Could not autoremove packages"
        write_msg "apt-get autoremove output:"
        write_msg "$remove_msg"
        exit 6
    else
        write_msg "Cleanup sucessful"
    fi

    # do a happy dance

    do_happy_dance(){
        write_msg "It worked! $HOST does a happy dance! You should too."
    }

    do_happy_dance
    write_msg "Don't forget to set user sessions to Free Geek Deafault Session"
    write_msg "and restore passwords (etc/shadow) if these have been changed."
    exit 0
fi
