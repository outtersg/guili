#!/bin/sh
# Copyright (c) 2005 Guillaume Outters
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

modifs="libcStatique"

v 1.4.15 || true
v 1.4.16 || true
v 1.4.17 || true
v 1.4.18 || true
v 1.4.19 || true

libcStatique()
{
	# https://stackoverflow.com/questions/15285776/multiple-definitions-when-linking-collect2-error-ld-returned-1-exit-status
	# https://github.com/jedisct1/libsodium/issues/202
	# Une certaine version de Linux, avec une certaine version de gcc, fait que les fonctions de la libc sont dupliquées
	# dans chaque .o de m4. À l'édition de liens, ça explose, forcément.
	
	case "$CC" in
		gcc|*/gcc|"gcc "*|*"/gcc "*) true ;;
		*) return 0 ;;
	esac
	
	# Forçage pour certaines versions identifiées, où le test "élégant" ne fonctionne pas (apparemment plantage de ld entre un .o et un .a, alors que nous testons sans archive intermédiaire). Marre de trimballer ce test, on force.
	local force=
	case "`uname` `uname -r`" in
		"Linux 2."*) force=1 ;;
	esac
	
	( echo "#include <stdlib.h>" ; echo "int main(int argc, char ** argv) { return 0; }" ) > $TMP/$$/1.c
	echo "#include <stdlib.h>" > $TMP/$$/2.c
	if [ -n "$force" ] || $CC -O2 -D_FORTIFY_SOURCE=2 -std=c99 $TMP/$$/[12].c -o $TMP/$$/1 2>&1 | grep -q 'ultiple definitions'
	then
		export CFLAGS="-fgnu89-inline $CFLAGS"
		export CPPFLAGS="-fgnu89-inline $CPPFLAGS"
	fi
}

archive=https://ftp.igh.cnrs.fr/pub/gnu/$logiciel/$logiciel-$version.tar.bz2
archive=https://ftp.gnu.org/gnu/$logiciel/$logiciel-$version.tar.bz2

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
