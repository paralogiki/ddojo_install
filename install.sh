#!/bin/bash
DD_VERSION="0.1"
DD_NEEDS=""
if [ ! -r "/etc/os-release" ]; then
	echo "We cannot read from /etc/os-release, unable to continue"
	exit
fi
source /etc/os-release
echo "Installing required packages:"
echo "-----------------------------"
DD_CHECK="wget xz chromium-browser php xdotool"
DD_CHROMIUM="/usr/bin/chromium-browser"
if [ "$ID" == "arch" ]; then
	DD_CHECK="wget xz chromium php xdotool"
	DD_CHROMIUM="/usr/bin/chromium"
	sudo pacman --needed -S wget xz chromium php xdotool
else
	sudo apt-get install wget xz chromium-browser php xdotool
fi
for need in $DD_CHECK; do
	NEED_TEST=`which $need`
	if [ "$NEED_TEST" != "/usr/bin/$need" ]; then
		echo "$need is not installed, will attempt to install"
		if [ -z "$DD_NEEDS" ]; then
			DD_NEEDS+="$need"
		else
			DD_NEEDS+=" $need"
		fi
	fi
done
if [ -n "$DD_NEEDS" ]; then
	echo "Failed to install the following packages: $DD_NEEDS, unable to continue"
	exit
fi
DD_HOME=~
cd $DD_HOME
DD_DOWNLOAD_URL="https://www.displaydojo.com/downloads/ddojo_local-$DD_VERSION.xz"
/usr/bin/wget -O $DD_HOME/ddojo_local.xz $DD_DOWNLOAD_URL
/usr/bin/tar xJf ddojo_local.xz
if [ ! -x $DD_HOME/ddojo_local/bin/console ]; then
	echo "Unable to find local client files, unable to continue"
	exit
fi
cd $DD_HOME/ddojo_local
bin/console server:start
$DD_CHROMIUM --app="http://localhost:8000"
