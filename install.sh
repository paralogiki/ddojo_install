#!/bin/bash
DD_HOME=~
DD_LOCAL_DIR="$DD_HOME/ddojo_local"
DD_VERSION="0.6"
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
function check_needs() {
	DD_INSTALL_PKGS=""
	for need in $1; do
		NEED_TEST=`/usr/bin/dpkg -l $need 2>/dev/null | /bin/grep ^ii | /usr/bin/wc -l`
		if [ "$NEED_TEST" != "1" ]; then
			#echo "$need is not installed, will attempt to install"
			if [ -z "$DD_INSTALL_PKGS" ]; then
				DD_INSTALL_PKGS="$need"
			else
				DD_INSTALL_PKGS+=" $need"
			fi
		fi
	done
	echo $DD_INSTALL_PKGS
}
function set_gpu_mem() {
	DD_CHK_MEM=`/bin/grep ^gpu_mem /boot/config.txt 2>/dev/null | /usr/bin/wc -l`
	if [ "$DD_CHK_MEM" != "1" ]; then
		echo "Setting gpu_mem=128 in /boot/config.txt"
		echo "gpu_mem=128" | sudo /usr/bin/tee -a /boot/config.txt > /dev/null
	fi
}
function set_current_migration() {
	# We are on a fresh install so we set the current migration
	# to the current date timestamp
	DD_CURRENT_TIME="`date +%s`"
	if [ ! -d "$DD_LOCAL_DIR/migrations" ]; then
		mkdir -p $DD_LOCAL_DIR/migrations
	fi
	echo $DD_CURRENT_TIME >> $DD_LOCAL_DIR/migrations/current.migration
}
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
DD_NEEDS="php-cli php-xml php-json php-tokenizer scrot unclutter wget xdotool chromium-browser"
DD_CHROMIUM="/usr/bin/chromium-browser"
DD_KILL_CHROMIUM_GREP="chromium-browser"
DD_PKG_GET="/usr/bin/sudo apt-get install -y"
if [ "$ID" == "raspbian" ]; then
	# Nothing to switch
	DD_NEEDS="php-cli php-xml php-json php-tokenizer scrot unclutter wget xdotool chromium-browser"
elif [ "$ID" == "debian" ]; then
	DD_NEEDS="php-cli php-xml php-json php-tokenizer scrot unclutter wget xdotool chromium-browser"
	if [ "$VERSION_ID" == "10" ]; then
		# Debian buster
		DD_NEEDS="php-cli php-xml php-json php-tokenizer scrot unclutter wget xdotool chromium"
		DD_CHROMIUM="/usr/bin/chromium"
		DD_KILL_CHROMIUM_GREP="chromium"
	fi
else
	echo "Unsupported operating system"
	exit
fi
DD_INSTALL_PKGS=$( check_needs "$DD_NEEDS" )
if [ -n "$DD_INSTALL_PKGS" ]; then
	echo "We need to install the following packages: $DD_INSTALL_PKGS"
	$DD_PKG_GET $DD_INSTALL_PKGS
	DD_NEEDS2=$( check_needs "$DD_NEEDS2" )
	if [ -n "$DD_NEEDS2" ]; then
		echo "ERROR: Failed to install the following packages: $DD_NEEDS2, unable to continue"
		exit
	fi
fi
cd $DD_HOME
DD_GIT_URL="https://github.com/paralogiki/ddojo_client_full.git"
DD_DOWNLOAD_URL="https://www.displaydojo.com/downloads/ddojo_local-$DD_VERSION.xz"
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
		echo "DD_INSTALLED_VERSION=\"$DD_VERSION\"" >> $DD_CONFIG
	fi
	sed -i "s/^\(DD_INSTALLED_VERSION\s*=\s*\).*\$/\1$DD_VERSION/" $DD_CONFIG
	echo "Writing DD_INSTALLED_VERSION=$DD_VERSION to $DD_CONFIG"
	set_gpu_mem
	set_current_migration
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
