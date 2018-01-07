#!/bin/sh
# Copyright (c) 2005,2007 Guillaume Outters
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

logiciel=vim

# Désormais les 8.0.tar.bz2 ne sont plus des 8.0.0, mais des 8.0.x embarquant les x premiers patches.
demarrage=

v 6.3 || true
v 6.4 || true
v 7.0.205 && modifs="corr syntaxephp pyth" || true
v 7.2.160 || true
v 7.3.353 || true
v 7.3.1242 || true
v 7.4.52 && modifs="corr syntaxephp pyth mavericks" || true
v 7.4.702 || true
v 7.4.1847 || true
v 7.4.2296 || true
v 8.0.311 && demarrage=".069" || true
v 8.0.1240 && demarrage=".586" || true

archive=http://ftp.vim.org/pub/vim/unix/$logiciel-${version%.*}$demarrage.tar.bz2

dest=$INSTALLS/$logiciel-$version

pyth()
{
	command -v python3 > /dev/null 2>&1 && OPTIONS="$OPTIONS --enable-python3interp=dynamic" || true
	command -v python > /dev/null 2>&1 && OPTIONS="$OPTIONS --enable-pythoninterp=dynamic" || true
}

corr()
{
	n="${version##*.}"
	ou="${archive%/*}"
	ou="${ou/unix/patches}"
	mem="$INSTALL_MEM/$logiciel-$version$demarrage.corr.tar.gz"
	if [ -z "$demarrage" ]
	then
		demarrage=0
	else
		demarrage="`echo "$demarrage" | sed -e 's/^[.0]*//'`"
	fi
	
	pge "$version" 8.0 && formateur=4.4d || formateur=3.3d
	
	if [ -f "$mem" ] && tar xzf "$mem"
	then
		i=$demarrage
	else
		i=$n
		while [ $i -gt $demarrage ]
		do
			iFormate="`printf "%$formateur" "$i"`"
			mv "`obtenir "$ou/${version%.*}/${version%.*}.$iFormate"`" ./
			i=`expr $i - 1`
		done
		tar czf "$mem" "${version%.*}".*
	fi
	
	while [ $i -lt $n ]
	do
		i=`expr $i + 1`
		patch -f -p0 < "${version%.*}.`printf "%$formateur" $i`" || true # Un peu de rustines indigestes Windows.
	done
}

syntaxephp()
{
	filtrer runtime/syntax/php.vim sed -e 's/\\h\\w/[A-Za-z0-9_âàçéêèëîïôöûùüÿ]/g' # A priori les majuscules sont couvertes aussi, puisque le caractère UTF-8 en minuscule est composé de deux octets, ex. à = a`, donc le [Aaà] est en fait équivalent à [Aaa`] et inclut donc aussi le À qui est la combinaison A`.
}

mavericks()
{
	mac || return 0
	pge `uname -r` 13 || return 0
	# http://codepad.org/Mzsik2R8
	patch -p0 <<TERMINE
diff src/os_unix.c src/os_unix.c
--- src/os_unix.c
+++ src/os_unix.c
@@ -18,6 +18,10 @@
  * changed beyond recognition.
  */
 
+#if defined(__APPLE__)
+#include <AvailabilityMacros.h>
+#endif
+
 /*
  * Some systems have a prototype for select() that has (int *) instead of
  * (fd_set *), which is wrong. This define removes that prototype. We define
TERMINE
}

[ -d "$dest" ] && exit 0

prerequis

obtenirEtAllerDansVersion

echo Correction… >&2
for modif in true $modifs ; do $modif ; done

echo Configuration… >&2
./configure --prefix="$dest" --enable-multibyte --disable-gui $OPTIONS

echo Compilation… >&2
make

echo Installation… >&2
sudo make install
sutiliser "$logiciel-$version"

rm -Rf $TMP/$$
