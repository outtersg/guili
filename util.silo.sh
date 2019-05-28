#!/bin/sh
# Copyright (c) 2018-2019 Guillaume Outters
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Définit les variables permettant de centraliser les versions compilées des logiciels.
_varsBinaireSilo()
{
	triplet="`uname -m`-`uname -s`-`uname -r | cut -d - -f 1`-`dirname "$dest" | sed -e 's#//*#_#g' -e 's#[-.]##g' -e 's#^__*##'`"
	archive="`basename "$dest"`.bin.tar.gz"
}

# Va chercher si un silo central a une version binaire de ce qu'on essaie de compiler.
installerBinaireSilo()
{
	[ ! -z "$INSTALL_SILO" ] || return 0

	local triplet archive
	_varsBinaireSilo

	if [ ! -f "$INSTALL_MEM/$archive" ]
	then
		scp $INSTALL_SILO_SSH_OPTS -o ConnectTimeout=2 "$INSTALL_SILO/$triplet/$archive" "$INSTALL_MEM/$archive" < /dev/null > /dev/null 2>&1 || true
	fi

	if [ -f "$INSTALL_MEM/$archive" ]
	then
		local ddest="`dirname "$dest"`" # Normalement égal à $INSTALLS
		local bdest="`basename "$dest"`"
		sudoku sh -c "cd $ddest && mkdir $bdest.temp && ( cd $bdest.temp && tar xzf "$INSTALL_MEM/$archive" ) && mv $bdest.temp $bdest" && sutiliser - && exit 0 || true
	fi
}

pousserBinaireVersSilo()
{
	local destLogiciel="$1"
	if [ ! -z "$INSTALL_SILO" ]
	then
		local triplet archive
		_varsBinaireSilo
		local silo_hote="`echo "$INSTALL_SILO" | cut -d : -f 1`"
		local silo_chemin="`echo "$INSTALL_SILO" | cut -d : -f 2-`"
		local ssh_opts="$INSTALL_SILO_SSH_OPTS -o ConnectTimeout=2"
		
		(
			cd "$INSTALLS/$destLogiciel"
			tar czf "$INSTALL_MEM/$archive.temp" . && mv "$INSTALL_MEM/$archive.temp" "$INSTALL_MEM/$archive"
			ssh $ssh_opts "$silo_hote" "cd $silo_chemin && mkdir -p $triplet" < /dev/null > /dev/null 2>&1 \
			&& scp $ssh_opts "$INSTALL_MEM/$archive" "$INSTALL_SILO/$triplet/$archive.temp" < /dev/null > /dev/null 2>&1 \
			&& ssh $ssh_opts "$silo_hote" "cd $silo_chemin/$triplet && mv $archive.temp $archive" \
			|| true
		)
	fi
}
