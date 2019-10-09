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

initSilo()
{
	[ -z "$INSTALL_SILO_RECUPERER" -o -z "$INSTALL_SILO_POUSSER" ] || return 0
	[ -n "$INSTALL_SILO" ] || return 0
	
	local recuperer= pousser=
	if echo "$INSTALL_SILO" | grep -q '^[^/]*://'
	then
		true
	elif echo "$INSTALL_SILO" | grep -q '^[^/]*:/[^/]'
	then
		recuperer=silo_ssh_recuperer
		pousser=silo_ssh_pousser
	fi
	[ -n "$INSTALL_SILO_RECUPERER" ] || INSTALL_SILO_RECUPERER="$recuperer"
	[ -n "$INSTALL_SILO_POUSSER" ] || INSTALL_SILO_POUSSER="$pousser"
	case "$INSTALL_SILO_RECUPERER|$INSTALL_SILO_POUSSER" in
		*"|"|"|"*)
			echo "# initSilo: impossible de déduire les fonctions de récupération et de poussage du / vers le silo \"$INSTALL_SILO\"." >&2
			return 1
			;;
	esac
}

# Définit les variables permettant de centraliser les versions compilées des logiciels.
_varsBinaireSilo()
{
	triplet="`uname -m`-`uname -s`-`uname -r | cut -d - -f 1`-`dirname "$dest" | sed -e 's#//*#_#g' -e 's#[-.]##g' -e 's#^__*##'`"
	archive="`basename "$dest"`.bin.tar.gz"
}

# Va chercher si un silo central a une version binaire de ce qu'on essaie de compiler.
installerBinaireSilo()
{
	[ -n "$INSTALL_SILO_RECUPERER" ] || return 0

	local triplet archive
	_varsBinaireSilo

	if [ ! -f "$INSTALL_MEM/$archive" ]
	then
		$INSTALL_SILO_RECUPERER "$INSTALL_MEM/$archive" "$triplet" || true
	fi

	if [ -f "$INSTALL_MEM/$archive" ]
	then
		local ddest="`dirname "$dest"`" # Normalement égal à $INSTALLS
		local bdest="`basename "$dest"`"
		sudoku sh -c "
			cd \"$ddest\" \\
			&& rm -Rf \"$bdest.temp\" \\
			&& mkdir \"$bdest.temp\" \\
			&& ( cd \"$bdest.temp\" && tar xzf \"$INSTALL_MEM/$archive\" ) \\
			&& if [ -e \"$bdest\" ] ; then rm -Rf \"$bdest.vieux\" && mv \"$bdest\" \"$bdest.vieux\" ; fi \\
			&& mv \"$bdest.temp\" \"$bdest\" \\
			|| ( rm -Rf \"$dest.temp\" && false )
		" && postprerequis -e && sutiliser - && exit 0 || true
	fi
}

pousserBinaireVersSilo()
{
	[ -n "$INSTALL_SILO_POUSSER" ] || return 0
	
	local destLogiciel="$1"
	
	local triplet archive
	_varsBinaireSilo
	
	(
		cd "$INSTALLS/$destLogiciel"
		tar czf "$INSTALL_MEM/$archive.temp" . && mv "$INSTALL_MEM/$archive.temp" "$INSTALL_MEM/$archive"
		$INSTALL_SILO_POUSSER "$INSTALL_MEM/$archive" "$triplet" || true
	)
}

#- Implémentation: SSH ---------------------------------------------------------

silo_ssh_recuperer()
{
	local archive="$1" triplet="$2"
	local archived="`basename "$archive"`"
	scp $INSTALL_SILO_SSH_OPTS -o ConnectTimeout=2 "$INSTALL_SILO/$triplet/$archived" "$archive" < /dev/null > /dev/null 2>&1
}

silo_ssh_pousser()
{
	local archive="$1" triplet="$2"
	local archived="`basename "$archive"`"
	local silo_hote="`echo "$INSTALL_SILO" | cut -d : -f 1`"
	local silo_chemin="`echo "$INSTALL_SILO" | cut -d : -f 2-`"
	local ssh_opts="$INSTALL_SILO_SSH_OPTS -o ConnectTimeout=2"
	
	ssh $ssh_opts "$silo_hote" "cd $silo_chemin && mkdir -p $triplet" < /dev/null > /dev/null 2>&1 \
	&& scp $ssh_opts "$archive" "$INSTALL_SILO/$triplet/$archived.temp" < /dev/null > /dev/null 2>&1 \
	&& ssh $ssh_opts "$silo_hote" "cd $silo_chemin/$triplet && mv $archived.temp $archived"
}
