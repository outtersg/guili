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

Delirant() { local s2 ; while [ -h "$s" ] ; do s2="`readlink "$s"`" ; case "$s2" in [^/]*) s2="`dirname "$s"`/$s2" ;; esac ; s="$s2" ; done ; } ; SCRIPTS() { local s="`command -v "$0"`" ; [ -x "$s" -o ! -x "$0" ] || s="$0" ; case "$s" in */bin/*sh) case "`basename "$s"`" in *.*) true ;; *sh) s="$1" ;; esac ;; esac ; case "$s" in [^/]*) local d="`dirname "$s"`" ; s="`cd "$d" ; pwd`/`basename "$s"`" ;; esac ; Delirant ; s="`dirname "$s"`" ; Delirant ; SCRIPTS="$s" ; } ; SCRIPTS
. "$SCRIPTS/util.sh"

# Historique des versions gérées

v 1.8 && prerequis="libevent ncurses" && modifs="bonneLibevent bonneNcurses surMac" || true
v 1.9.1 || true
v 2.2 || true
v 2.6 || true # Sait correctement détecter ncursesw.
v 2.7 || true
v 2.8 || true
v 3.2.1 || true
v 3.3.1 || true
v 3.5.1 || true

prerequis

# Modifications

# Si on a le malheur de s'installer sur une machine où tourne le Darwin Calendar Server, celui-ci aura installé une libevent 1.4 quand on veut utiliser notre 2.0.
bonneLibevent()
{
	# Ouille en 2025 on a toujours ce truc pourri qui au lieu de forcer une 2.0 par rapport à une 1.4, force maintenant une 2.0 par rapport à une 2.1…
	return 0
	# On repère une libevent explicitement 2.0, et on ajoute son lib en tête de LDFLAGS, pour qu'elle soit prise en priorité sur la pourrie de DCS.
	LDFLAGS="-L$INSTALLS/`ls -l $INSTALLS/lib/libevent-2.0.so | sed -e 's#.*/\(libevent-[0-9.]*/\)#\1#' -e 's#/.*##'`/lib $LDFLAGS"
	export LDFLAGS
}

bonneNcurses()
{
	export CPPFLAGS="-I$destncurses/ncursesw $CPPFLAGS"
}

surMac()
{
	if mac
	then
		filtrer osdep-darwin.c sed -e 's/bsdshortinfo/bsdinfo/g' -e 's/_SHORTBSDINFO/BSDINFO/g' -e 's/pbsi_/pbi_/g'
	fi
}

# Variables

v_alpha="`echo "$version" | awk -F . 'BEGIN{t="abcdefghijklmnopqrstuvwxyz"}{c="";n=$3;while(n>25){n-=25;c=c"z"}if(n)c=c""substr(t,n,1);print $1"."$2""c}'`"
archive="https://github.com/tmux/tmux/releases/download/$v_alpha/tmux-$v_alpha.tar.gz" || true

destiner

obtenirEtAllerDansVersion

echo Correction… >&2
for modif in true $modifs ; do $modif ; done

echo Configuration… >&2
./configure --prefix="$dest"

echo Compilation… >&2
make

echo Installation… >&2
sudo make install

sutiliser
