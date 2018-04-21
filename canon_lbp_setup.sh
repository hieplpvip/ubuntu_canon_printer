#!/bin/bash

##################################################
#Version 3.2 of August 11, 2017
#http://help.ubuntu.ru/wiki/canon_capt
#http://forum.ubuntu.ru/index.php?topic=189049.0
#Translated into English by @hieplpvip
##################################################

#Check for root
[ $USER != 'root' ] && exec sudo "$0"

#User under which we logged in
LOGIN_USER=$(logname)
[ -z "$LOGIN_USER" ] && LOGIN_USER=$(who | head -1 | awk '{print $1}')

#Load the file containing the path to the desktop
if [ -f ~/.config/user-dirs.dirs ]; then 
	source ~/.config/user-dirs.dirs
else
	XDG_DESKTOP_DIR="$HOME/Desktop"
fi

#Driver version
DRIVER_VERSION='2.71-1'
DRIVER_VERSION_COMMON='3.21-1'

#Links to driver packages
declare -A URL_DRIVER=([amd64_common]='https://github.com/hieplpvip/canon_printer/raw/master/Packages/cndrvcups-common_3.21-1_amd64.deb' \
[amd64_capt]='https://github.com/hieplpvip/canon_printer/raw/master/Packages/cndrvcups-capt_2.71-1_amd64.deb' \
[i386_common]='https://github.com/hieplpvip/canon_printer/raw/master/Packages/cndrvcups-common_3.21-1_i386.deb' \
[i386_capt]='https://github.com/hieplpvip/canon_printer/raw/master/Packages/cndrvcups-capt_2.71-1_i386.deb')

#Links to the autoshutdowntool utility
declare -A URL_ASDT=([amd64]='https://github.com/hieplpvip/canon_printer/raw/master/Packages/autoshutdowntool_1.00-1_amd64_deb.tar.gz' \
[i386]='https://github.com/hieplpvip/canon_printer/raw/master/Packages/autoshutdowntool_1.00-1_i386_deb.tar.gz')

#The compatibility of ppd files and printer models
declare -A LASERSHOT=([LBP-810]=1120 [LBP-1120]=1120 [LBP-1210]=1210 \
[LBP2900]=2900 [LBP3000]=3000 [LBP3010]=3050 [LBP3018]=3050 [LBP3050]=3050 \
[LBP3100]=3150 [LBP3108]=3150 [LBP3150]=3150 [LBP3200]=3200 [LBP3210]=3210 \
[LBP3250]=3250 [LBP3300]=3300 [LBP3310]=3310 [LBP3500]=3500 [LBP5000]=5000 \
[LBP5050]=5050 [LBP5100]=5100 [LBP5300]=5300 [LBP6000]=6018 [LBP6018]=6018 \
[LBP6020]=6020 [LBP6020B]=6020 [LBP6200]=6200 [LBP6300n]=6300n [LBP6300]=6300 \
[LBP6310]=6310 [LBP7010C]=7018C [LBP7018C]=7018C [LBP7200C]=7200C [LBP7210C]=7210C \
[LBP9100C]=9100C [LBP9200C]=9200C)

#Sorted printer names
NAMESPRINTERS=$(echo "${!LASERSHOT[@]}" | tr ' ' '\n' | sort -n -k1.4)

#List of models that are supported by the autoshutdowntool utility
declare -A ASDT_SUPPORTED_MODELS=([LBP6020]='MTNA002001 MTNA999999' \
[LBP6020B]='MTMA002001 MTMA999999' [LBP6200]='MTPA00001 MTPA99999' \
[LBP6310]='MTLA002001 MTLA999999' [LBP7010C]='MTQA00001 MTQA99999' \
[LBP7018C]='MTRA00001 MTRA99999' [LBP7210C]='MTKA002001 MTKA999999')

#OS architecture
if [ "$(uname -m)" == 'x86_64' ]; then
  ARCH='amd64'
else
  ARCH='i386'
fi

#Determine the initialization system
if [[ $(ps -p1 | grep systemd) ]]; then
	INIT_SYSTEM='systemd'
else
	INIT_SYSTEM='upstart'
fi

#Move to the working directory in which this script is located
cd "$(dirname "$0")"

function valid_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        ip=($(echo "$ip" | tr '.' ' '))
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

function check_error() {
	if [ $2 -ne 0 ]; then
		case $1 in
			'WGET') echo "Error while downloading file $3"				
				[ -n "$3" ] && [ -f "$3" ] && rm "$3";;
			'PACKAGE') echo "Error installing package $3";;
			*) echo 'Error';;
		esac
		echo 'Press any key to exit'
		read -s -n1
		exit 1
	fi
}

function canon_unistall() {
	if [ -f /usr/sbin/ccpdadmin ]; then
		installed_model=$(ccpdadmin | grep LBP | awk '{print $3}')
		if [ -n "$installed_model" ]; then
			echo "Found printer $installed_model"
			echo "Closing captstatusui"
			killall captstatusui 2> /dev/null
			echo 'Stopping ccpd'
			service ccpd stop
			echo 'Removing the printer from the ccpd daemon configuration file'
			ccpdadmin -x $installed_model
			echo 'Removing the printer from CUPS'
			lpadmin -x $installed_model
		fi
	fi
	echo 'Removing driver packages'
	dpkg --purge cndrvcups-capt
	dpkg --purge cndrvcups-common
	echo 'Removing unused Libraries and Packages'
	apt-get -y autoremove
	echo 'Deleting settings'
	[ -f /etc/init/ccpd-start.conf ] && rm /etc/init/ccpd-start.conf
	[ -f /etc/udev/rules.d/85-canon-capt.rules ] && rm /etc/udev/rules.d/85-canon-capt.rules
	[ -f "${XDG_DESKTOP_DIR}/captstatusui.desktop" ] && rm "${XDG_DESKTOP_DIR}/captstatusui.desktop"
	[ -f /usr/bin/autoshutdowntool ] && rm /usr/bin/autoshutdowntool
	[ $INIT_SYSTEM == 'systemd' ] && update-rc.d -f ccpd remove
	echo 'Uninstall completed'
	echo 'Press any key to exit'
	read -s -n1
	return 0
}

function canon_install() {
	echo
	PS3='Select a printer. Enter the desired number and press Enter: '
	select NAMEPRINTER in $NAMESPRINTERS
	do
		[ -n "$NAMEPRINTER" ] && break
	done
	echo "Selected printer: $NAMEPRINTER"
	echo
	PS3='How is the printer connected to the computer? Enter the desired number and press Enter: '
	select CONECTION in 'Via USB' 'Through network (LAN, NET)'
	do
		if  [ "$REPLY" == "1" ]; then
			CONECTION="usb"
			while true
			do	
				#Looking for a device connected to the USB port
				NODE_DEVICE=$(ls -1t /dev/usb/lp* 2> /dev/null | head -1)
				if [ -n "$NODE_DEVICE" ]; then
					#Determine the serial number of the printer
					PRINTER_SERIAL=$(udevadm info --attribute-walk --name=$NODE_DEVICE | sed '/./{H;$!d;};x;/ATTRS{product}=="Canon CAPT USB \(Device\|Printer\)"/!d;' |  awk -F'==' '/ATTRS{serial}/{print $2}')
					# If the serial number is found, then the device is Canon printer
					[ -n "$PRINTER_SERIAL" ] && break
				fi
				echo -ne "Turn on the printer and plug in USB cable\r"
				sleep 2
			done
			PATH_DEVICE="/dev/canon$NAMEPRINTER"
			break
		elif [ "$REPLY" == "2" ]; then
			CONECTION="lan"
			read -p 'Enter the IP address of the printer: ' IP_ADDRES
			until valid_ip "$IP_ADDRES"
			do
				echo 'Invalid IP address format, enter four decimal numbers'
				echo -n 'from 0 to 255, separated by dots: '
				read IP_ADDRES
			done
			PATH_DEVICE="net:$IP_ADDRES"
			echo 'Turn on the printer and press any key'
			read -s -n1
			sleep 5
			break
		fi		
	done
	echo '***Driver Installation***'
	COMMON_FILE=cndrvcups-common_${DRIVER_VERSION_COMMON}_${ARCH}.deb
	CAPT_FILE=cndrvcups-capt_${DRIVER_VERSION}_${ARCH}.deb
	if [ ! -f $COMMON_FILE ]; then		
		sudo -u $LOGIN_USER wget -O $COMMON_FILE ${URL_DRIVER[${ARCH}_common]}
		check_error WGET $? $COMMON_FILE
	fi
	if [ ! -f $CAPT_FILE ]; then
		sudo -u $LOGIN_USER wget -O $CAPT_FILE ${URL_DRIVER[${ARCH}_capt]}
		check_error WGET $? $CAPT_FILE
	fi
	apt-get -y update
	apt-get -y install libglade2-0
	check_error PACKAGE $? libglade2-0
	echo 'Installing common module for the CUPS driver'
	dpkg -i $COMMON_FILE
	check_error PACKAGE $? $COMMON_FILE
	echo 'Installing the CAPT Printer Driver Module'
	dpkg -i $CAPT_FILE
	check_error PACKAGE $? $CAPT_FILE
	#Replacing the contents of the file /etc/init.d/ccpd
	echo '#!/bin/bash
# startup script for Canon Printer Daemon for CUPS (ccpd)
### BEGIN INIT INFO
# Provides:          ccpd
# Required-Start:    $local_fs $remote_fs $syslog $network $named
# Should-Start:      $ALL
# Required-Stop:     $syslog $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       Start Canon Printer Daemon for CUPS
### END INIT INFO

DAEMON=/usr/sbin/ccpd
case $1 in
	start)
		start-stop-daemon --start --quiet --oknodo --exec ${DAEMON}
		;;
	stop)
		start-stop-daemon --stop --quiet --oknodo --retry TERM/30/KILL/5 --exec ${DAEMON}
		;;	
	status)
		echo "${DAEMON}:" $(pidof ${DAEMON})
		;;
	restart)
		while true
		do
			start-stop-daemon --stop --quiet --oknodo --retry TERM/30/KILL/5 --exec ${DAEMON}
			start-stop-daemon --start --quiet --oknodo --exec ${DAEMON}
			for (( i = 1 ; i <= 5 ; i++ )) 
			do
				sleep 1
				set -- $(pidof ${DAEMON})
				[ -n "$1" -a -n "$2" ] && exit 0
			done
		done
		;;
	*)
		echo "Usage: ccpd {start|stop|status|restart}"
		exit 1
		;;
esac
exit 0' > /etc/init.d/ccpd
	#Installation utilities for managing AppArmor
	apt-get -y install apparmor-utils
	#Setting in AppArmor profile in sparing mode for cupsd
	aa-complain /usr/sbin/cupsd
	echo 'Restarting CUPS'
	service cups restart
	echo 'Installing 32-bit libraries required for'
	echo '64-bit printer driver'
	if [ $ARCH == 'amd64' ]; then
		apt-get -y install libatk1.0-0:i386 libcairo2:i386 libgtk2.0-0:i386 libpango1.0-0:i386 libstdc++6:i386 libpopt0:i386 libxml2:i386 libc6:i386
		check_error PACKAGE $?
	fi
	echo 'Installing the printer in CUPS'
	/usr/sbin/lpadmin -p $NAMEPRINTER -P /usr/share/cups/model/CNCUPSLBP${LASERSHOT[$NAMEPRINTER]}CAPTK.ppd -v ccp://localhost:59687 -E
	echo "Installing the $NAMEPRINTER printer as the default printer"
	/usr/sbin/lpadmin -d $NAMEPRINTER
	echo 'Registering the printer in the ccpd daemon configuration file'
	/usr/sbin/ccpdadmin -p $NAMEPRINTER -o $PATH_DEVICE
	#Verify printer installation
	installed_printer=$(ccpdadmin | grep $NAMEPRINTER | awk '{print $3}')
	if [ -n "$installed_printer" ]; then
		if [ "$CONECTION" == "usb" ]; then
			echo 'Creating a rule for the printer'
			#A rule is created that provides an alternative name (a symbolic link) to our printer so as not to depend on the changing values of lp0, lp1,...
			echo 'KERNEL=="lp[0-9]*", SUBSYSTEMS=="usb", ATTRS{serial}=='$PRINTER_SERIAL', SYMLINK+="canon'$NAMEPRINTER'"' > /etc/udev/rules.d/85-canon-capt.rules
			#Update the rules
			udevadm control --reload-rules
			#Check the created rule
			until [ -e $PATH_DEVICE ]
			do
				echo -ne "Turn off the printer, wait 2 seconds, then turn on the printer\r"
				sleep 2
			done
		fi
		echo -e "\e[2KRunning ccpd"
		service ccpd restart
		#Autoload ccpd
		if [ $INIT_SYSTEM == 'systemd' ]; then
			update-rc.d ccpd defaults
		else
			echo 'description "Canon Printer Daemon for CUPS (ccpd)"
author "LinuxMania <customer@linuxmania.jp>"
start on (started cups and runlevel [2345])
stop on runlevel [016]
expect fork
respawn
exec /usr/sbin/ccpd start' > /etc/init/ccpd-start.conf	
		fi
		#Create the start captstatusui button on the desktop
		echo '#!/usr/bin/env xdg-open
[Desktop Entry]
Version=1.0
Name=captstatusui
GenericName=Status monitor for Canon CAPT Printer
Exec=captstatusui -P '$NAMEPRINTER'
Terminal=false
Type=Application
Icon=/usr/share/icons/Humanity/devices/48/printer.svg' > "${XDG_DESKTOP_DIR}/captstatusui.desktop"
		chmod 775 "${XDG_DESKTOP_DIR}/captstatusui.desktop"
		chown $LOGIN_USER:$LOGIN_USER "${XDG_DESKTOP_DIR}/captstatusui.desktop"
		#Install the autoshutdowntool utility for supported printer models
		if [[ "${!ASDT_SUPPORTED_MODELS[@]}" =~ "$NAMEPRINTER" ]]; then
			SERIALRANGE=(${ASDT_SUPPORTED_MODELS[$NAMEPRINTER]})
			SERIALMIN=${SERIALRANGE[0]}
			SERIALMAX=${SERIALRANGE[1]}	
			if [[ ${#PRINTER_SERIAL} -eq ${#SERIALMIN} && $PRINTER_SERIAL > $SERIALMIN && $PRINTER_SERIAL < $SERIALMAX || $PRINTER_SERIAL == $SERIALMIN || $PRINTER_SERIAL == $SERIALMAX ]]; then
				echo "Installing the autoshutdowntool utility"
				ASDT_FILE=autoshutdowntool_1.00-1_${ARCH}_deb.tar.gz
				if [ ! -f $ASDT_FILE ]; then		
					wget -O $ASDT_FILE ${URL_ASDT[$ARCH]}
					check_error WGET $? $ASDT_FILE
				fi
				tar --gzip --extract --file=$ASDT_FILE --totals --directory=/usr/bin
			fi
		fi	
		#Start captstatusui
		if [[ -n "$DISPLAY" ]] ; then
			sudo -u $LOGIN_USER nohup captstatusui -P $NAMEPRINTER > /dev/null 2>&1 &
			sleep 5
		fi
		echo 'Installation completed. Press any key to exit'
		read -s -n1
		exit 0
	else
		echo "Printer $NAMEPRINTER is not installed"
		echo 'Press any key to exit'
	 	read -s -n1
		exit 1
	fi
}

function canon_update() {
	if [ -f /usr/sbin/ccpdadmin ]; then
		NAMEPRINTER=$(ccpdadmin | grep LBP | awk '{print $3}')
		if [ -n "$NAMEPRINTER" ]; then
			echo "Found $NAMEPRINTER printer"
			SETUP_DRIVER_VERSION=$(dpkg -l | grep cndrvcups-capt | awk '{print $3}')
			echo "Installed driver version: $SETUP_DRIVER_VERSION"
			echo "The driver version to be installed: $DRIVER_VERSION"			
			dpkg --compare-versions $DRIVER_VERSION lt $SETUP_DRIVER_VERSION
			if [ $? -eq 0 ]; then
				echo 'The version of the installed driver is smaller than the version of the driver that is already installed.
The update will not continue. Press any key to exit'
				read -s -n1
				exit 1
			fi
			echo "Closing captstatusui"
			killall captstatusui 2> /dev/null
			echo 'Stopping ccpd'
			service ccpd stop
			echo 'Removing the printer from CUPS'
			lpadmin -x $NAMEPRINTER
			#Update driver
			COMMON_FILE=cndrvcups-common_${DRIVER_VERSION_COMMON}_${ARCH}.deb
			CAPT_FILE=cndrvcups-capt_${DRIVER_VERSION}_${ARCH}.deb
			if [ ! -f $COMMON_FILE ]; then		
				sudo -u $LOGIN_USER wget -O $COMMON_FILE ${URL_DRIVER[${ARCH}_common]}
				check_error WGET $? $COMMON_FILE
			fi
			if [ ! -f $CAPT_FILE ]; then
				sudo -u $LOGIN_USER wget -O $CAPT_FILE ${URL_DRIVER[${ARCH}_capt]}
				check_error WGET $? $CAPT_FILE
			fi
			echo 'Updating the Common Module for the CUPS Driver'
			dpkg -i $COMMON_FILE
			check_error PACKAGE $? $COMMON_FILE
			echo 'Updating the CAPT Printer Driver Module'
			dpkg -i $CAPT_FILE
			check_error PACKAGE $? $CAPT_FILE
			echo 'Restarting CUPS'
			service cups restart
			echo 'Installing the printer in CUPS'
			/usr/sbin/lpadmin -p $NAMEPRINTER -P /usr/share/cups/model/CNCUPSLBP${LASERSHOT[$NAMEPRINTER]}CAPTK.ppd -v ccp://localhost:59687 -E
			echo "Installing the $NAMEPRINTER printer as the default printer"
			/usr/sbin/lpadmin -d $NAMEPRINTER
			if [[ -n "$DISPLAY" ]] ; then			
				echo 'Running captstatusui'
				while true
				do
					sleep 1
					set -- $(pidof /usr/sbin/ccpd)
					if [ -n "$1" -a -n "$2" ]; then
						sudo -u $LOGIN_USER nohup captstatusui -P $NAMEPRINTER > /dev/null 2>&1 &
						sleep 5
						break
					fi
				done
			fi
			echo "The driver has been updated. Press any key to exit"
	 		read -s -n1
			exit 0
		fi
	fi
	echo "Printers from the Canon LBP series are not installed"
	echo 'Press any key to exit'
	read -s -n1
	exit 1
}

function canon_help {
	clear
	echo 'Installation Notes
If you have already done anything to install the printer in this series,
in the current system, then before starting the installation, you should cancel these actions.
If there are no driver packages, they are automatically downloaded from the Internet
in the script folder. Printers LBP-810, LBP-1210 connect through the USB port connector
To update the driver, first uninstall the old version via the script, then
install a new one also through the script.
Notes on printing problems
If the printer stops printing, run captstatusui via the start button
on the desktop or in the terminal with the command: captstatusui -P <printer_name>
The captstatusui window displays a message indicating the current status of the printer, if
an error occurs, its description is displayed. Here you can try pressing the button
"Resume Job" to continue printing or "Cancel Job" button to cancel the job.
If this does not help, then run the script canon_restart.sh

Printer configuration command: cngplp
Additional settings, command: captstatusui -P <printer_name>
Auto-off setting (not for all models): autoshutdowntool
Comments and errors write to the mail coden@mail.ru or
on the forum http://forum.ubuntu.ru/index.php?topic=189049.0
To log the installation process, run the script like this:
logsave log.txt ./canon_lbp_setup.sh
'
}

clear
echo 'Installing the Linux CAPT Printer Driver v'${DRIVER_VERSION}' for Canon LBP printers
on Ubuntu 12.04, 12.10, 13.04, 13.10, 14.04, 14.10, 15.04, 15.10, 16.04, 16.10, 17.04, 17.10 of 32-bit and 64-bit architecture
Supported printers:'
echo "$NAMESPRINTERS" | sed ':a; /$/N; s/\n/, /; ta' | fold -s

PS3='Choice of action. Enter the desired number and press Enter: '
select opt in 'Install' 'Uninstall' 'Help' 'Exit'
do
	if [ "$opt" == 'Install' ]; then
		canon_install
		break
	elif [ "$opt" == 'Uninstall' ]; then
		canon_unistall
		break
#	elif [ "$opt" == 'Update' ]; then
#		canon_update
#		break	
	elif [ "$opt" == 'Help' ]; then
		canon_help
	elif [ "$opt" == 'Exit' ]; then
		break
	fi
done
