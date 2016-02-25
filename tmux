#!/bin/sh
# Copyright (c) 2006 Guillaume Outters
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

set -e

absolutiseScripts() { SCRIPTS="$1" ; echo "$SCRIPTS" | grep -q ^/ || SCRIPTS="`dirname "$2"`/$SCRIPTS" ; } ; absolutiseScripts "`command -v "$0"`" "`pwd`/." ; while [ -h "$SCRIPTS" ] ; do absolutiseScripts "`readlink "$SCRIPTS"`" "$SCRIPTS" ; done ; SCRIPTS="`dirname "$SCRIPTS"`"
. "$SCRIPTS/util.sh"

logiciel=tmux

# Historique des versions gérées

v 1.8 && prerequis="libevent" && modifs="bonneLibevent surMac" || true
v 1.9a

prerequis

# Modifications

# Si on a le malheur de s'installer sur une machine où tourne le Darwin Calendar Server, celui-ci aura installé une libevent 1.4 quand on veut utiliser notre 2.0.
bonneLibevent()
{
	# On repère une libevent explicitement 2.0, et on ajoute son lib en tête de LDFLAGS, pour qu'elle soit prise en priorité sur la pourrie de DCS.
	LDFLAGS="-L$INSTALLS/`ls -l $INSTALLS/lib/libevent-2.0.so | sed -e 's#.*/\(libevent-[0-9.]*/\)#\1#' -e 's#/.*##'`/lib $LDFLAGS"
	export LDFLAGS
}

surMac()
{
	if mac
	then
		filtrer osdep-darwin.c sed -e 's/bsdshortinfo/bsdinfo/g' -e 's/_SHORTBSDINFO/BSDINFO/g' -e 's/pbsi_/pbi_/g'
	fi
}

# Variables

archive="http://heanet.dl.sourceforge.net/project/tmux/tmux/tmux-$version/tmux-$version.tar.gz"
dest=$INSTALLS/$logiciel-$version

[ -d "$dest" ] && exit 0

obtenirEtAllerDansVersion

echo Correction… >&2
for modif in true $modifs ; do $modif ; done

echo Configuration… >&2
./configure --prefix="$dest"

echo Compilation… >&2
make

echo Installation… >&2
sudo make install
sutiliser "$logiciel-$version"

rm -Rf "$TMP/$$"
