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

help(){
cat <<EOF 

usage: $0 -s|c [OPTION]...
Upgrade from Ubuntu 10.4 to Xubuntu12.04 with Freegeek Tweaks
        
-h                      Prints this message.
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


# process option arguments
while getopts "hnt:l:" option; do            # w: place variable following w in $OPTARG
        case "$option" in
                h) help;;
                n)no_remove=true;;
                t)ticket=$OPTARG;;
                l)logfile=$OPTARG;;
                [?])  echo "bad option supplied" ; 
                help;;
        esac
done

#MAIN




if ! test_for_root; then
    write_msg "You must execute this script with root privileges"
    write_msg "i.e. using sudo"
    exit 3
fi


if [[ $logfile ]]; then
    if ! check_file_write $logfile ; then
        echo "could not write to $logfile"
        exit 3
    fi
fi


if [[ -e /home/.first_run_success ]]; then
    second_run="true"
else
    first_run="true"
fi


if [[ $first_run ]]; then
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

    if ! sudo ./ts_network_backup -c $ticket; then
        write_msg "failed to backup system!"
        exit 5
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

    # remove unity etc

    if [[ ! $no_remove ]];  then
        big_ass_list_of_packages_to_remove="gnome-control-center gnome-font-viewer gnome-media gnome-menus gnome-nettool gnome-power-manager gnome-screenshot gnome-session gnome-session-canberra gnome-system-log gnome-system-monitor gnome-terminal gcalctool eog nautilus nautilus-sendto unity unity-2d unity-greeter gnome-bluetooth gnome-disk-utility gnome-orca gnome-screensaver gnome-sudoku gnomine ubuntuone-client-gnome"

        for package in $big_ass_list_of_packages_to_remove; do
           if  dpkg-query  -l  bash  2>/dev/null  | grep -q ^.i; then
                list_of_packages_to_remove="$list_of_packages_to_remove $package"
           fi
        done

        remove_msg=$(apt-get remove $list_of_packages_to_remove)
        if [[ $? -ne 0 ]]; then
            write_msg "Could not remove (some of) $list_of_packages_to_remove"
            write_msg "apt-get remove output:"
            write_msg "$remove_msg"
            exit 6
        else
            write_msg "Sucessfully removed $list_of_packages_to_remove"
        fi
    fi

    # do a happy dance

    do_happy_dance(){
        write_msg "It worked! $HOST does a happy dance! You should too."
    }

    do_happy_dance
    exit 0
fi