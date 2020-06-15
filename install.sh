#!/bin/bash
DD_HOME=~
DD_VERSION="0.1"
DD_NEEDS="php php-xml scrot unclutter "
DD_CONFIG_DIR="$DD_HOME/.config/ddojo"
DD_CONFIG="$DD_HOME/.config/ddojo/ddojo.conf"
DD_INSTALLED_VERSION=""
DD_FIRST_INSTALL="yes"
if [ -r "$DD_CONFIG" ]; then
	source $DD_CONFIG
	DD_FIRST_INSTALL="no"
	echo "Found an existing config $DD_CONFIG"
else
	if [ ! -d "$DD_CONFIG_DIR" ]; then
		mkdir -p $DD_CONFIG_DIR
		touch $DD_CONFIG
		echo "First time intalling making $DD_CONFIG_DIR and $DD_CONFIG"
	fi
fi
# TODO Need to do real version comparison
# 1.10 > 1.9 or 1.1.3 < 1.0.2
# For now if versions are different we'll overwrite
DD_DOWNLOAD="yes"
DD_INSTALL="yes"
if [ -n "$DD_INSTALLED_VERSION" ] && [ "$DD_VERSION" == "$DD_INSTALLED_VERSION" ];then
	DD_INSTALL="no"
	DD_DOWNLOAD="no"
	echo "Installed version matches live version, not going to download or install new files"
fi
if [ ! -r "/etc/os-release" ]; then
	echo "ERROR: We cannot read from /etc/os-release, unable to continue"
	exit
fi
source /etc/os-release
DD_CHECK="wget chromium-browser php xdotool"
DD_CHROMIUM="/usr/bin/chromium-browser"
DD_KILL_CHROMIUM_GREP="chromium-browser"
DD_PKG_GET="/usr/bin/sudo apt-get install -y"
if [ "$ID" == "arch" ]; then
	DD_CHECK="wget chromium php xdotool"
	DD_CHROMIUM="/usr/bin/chromium"
	DD_KILL_CHROMIUM_GREP="chromium"
	DD_PKG_GET="/usr/bin/sudo pacman --needed -S"
	#$DD_PKG_GET php-xml
elif [ "$ID" == "debian" ]; then
	DD_CHECK="wget chromium php xdotool"
	DD_CHROMIUM="/usr/bin/chromium"
	DD_KILL_CHROMIUM_GREP="chromium"
	#$DD_PKG_GET php-xml
fi
for need in $DD_CHECK; do
	NEED_TEST=`which $need`
	if [ "$NEED_TEST" != "/usr/bin/$need" ]; then
		echo "$need is not installed, will attempt to install"
		if [ -z "$DD_NEEDS" ]; then
			DD_NEEDS="$need"
		else
			DD_NEEDS+=" $need"
		fi
	fi
done
if [ -n "$DD_NEEDS" ]; then
	echo "We need to install the following packages: $DD_NEEDS"
	$DD_PKG_GET $DD_NEEDS
	DD_NEEDS2=""
	for need in $DD_CHECK; do
		NEED_TEST=`which $need`
		if [ "$NEED_TEST" != "/usr/bin/$need" ]; then
			echo "$need failed to install"
			if [ -z "$DD_NEEDS2" ]; then
				DD_NEEDS2="$need"
			else
				DD_NEEDS2+=" $need"
			fi
		fi
	done
	if [ -n "$DD_NEEDS2" ]; then
		echo "ERROR: Failed to install the following packages: $DD_NEEDS2, unable to continue"
		exit
	fi
fi
cd $DD_HOME
DD_GIT_URL="https://github.com/paralogiki/ddojo_client_full.git"
DD_DOWNLOAD_URL="https://www.displaydojo.com/downloads/ddojo_local-$DD_VERSION.xz"
DD_LOCAL_DIR="$DD_HOME/ddojo_local"
if [ "$DD_INSTALL" == "no" ] && [ ! -d "$DD_LOCAL_DIR" ]; then
	echo "DD_INSTALL was no, but $DD_LOCAL_DIR does not exist, setting DD_INSTALL to yes"
	DD_INSTALL="yes"
	DD_DOWNLOAD="yes"
fi
pkill -f "/usr/bin/php.*/ddojo_local/"
/usr/bin/pkill -f $DD_KILL_CHROMIUM_GREP
if [ "$DD_INSTALL" == "yes" ]; then
	if [ -d "$DD_LOCAL_DIR" ]; then
		echo "Moving existing $DD_LOCAL_DIR to ${DD_LOCAL_DIR}_`date +%s`"
		mv $DD_LOCAL_DIR "$DD_LOCAL_DIR.`date +%s`"
	fi
	git clone $DD_GIT_URL $DD_LOCAL_DIR
	if [ "$DD_FIRST_INSTALL" == "yes" ]; then
		echo "DD_INSTALLED_VERSION=\"$DD_VERSION\"" | tee --append $DD_CONFIG
	fi
	sed -i "s/^\(DD_INSTALLED_VERSION\s*=\s*\).*\$/\1$DD_VERSION/" $DD_CONFIG
	echo "Writing DD_INSTALLED_VERSION=$DD_VERSION to $DD_CONFIG"
fi
if [ ! -x $DD_HOME/ddojo_local/bin/console ]; then
	echo "ERROR: Unable to find local client files, unable to continue"
	exit
fi
cd $DD_HOME/ddojo_local
echo "Launching client listening at http://localhost:8000/"
bin/console server:start
if [ -x /usr/bin/unclutter ]; then
	/usr/bin/unclutter -idle 1.0 &
fi
echo "Opening $DD_KILL_CHROMIUM_GREP at http://localhost:8000"
# --disable-web-security requires --user-data-dir
# --test-type removes the disabled web-security warning
# --check-for-update-interval=31536000
$DD_CHROMIUM --disable-web-security --user-data-dir=/home/pi/.config/ddojochromium --test-type --check-for-update-interval=31536000 --noerrdialogs --start-fullscreen --disable-translate --no-first-run --fast --fast-start --disable-infobars --disable-features=TranslateUI --allow-file-access-from-files --kiosk http://localhost:8000 > /dev/null 2>&1 &
