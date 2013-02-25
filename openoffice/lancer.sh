#!/bin/sh

export DISPLAY=:0.0
if [ ! -d $HOME/Library/Application\ Support/OpenOffice\ 1.1.0 ] ; then
	echo Veuillez patienter pendant l\'installation d\'OpenOffice…
	cat > /tmp/openoffice.reponses << TERMINE
[Environment]
InstallationMode = INSTALL_WORKSTATION
DestinationPath = <home>/Library/Application Support/OpenOffice 1.1.0
InstallationType = WORKSTATION

[Java]
JavaSupport = preinstalled_or_none
TERMINE
	/usr/local/openoffice-1.1.0/setup -r /tmp/openoffice.reponses
fi

ps -auxww | grep soffice.bin | grep -v grep | grep -q "^$USER" && exit 0
echo Lancement d\'OpenOffice. Il va falloir attendre un petit moment.
open -a X11
"$HOME/Library/Application Support/OpenOffice 1.1.0/soffice"
