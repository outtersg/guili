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

logiciel=lua

# Historique des versions gérées

v 5.1.5 && modifs="compilo fpic" || true
v 5.2.1 || true
v 5.3.1 && modifs="compilo fpic log2" || true
v 5.3.3 || true

# Modifications

detecteLog2()
{
	# FreeBSD 8 déclare un log2 mais ne l'implémente pas.
	cat > /tmp/log2.c <<TERMINE
#include <math.h>

int main(int argc, char ** argv)
{
	double n;
	n = log2(567.22);
}
TERMINE
	cc -lm -o /tmp/log2 /tmp/log2.c 2> /dev/null
}

definisLog2()
{
	detecteLog2 || for i in "$@"
	do
		filtrer "$i" sed -e '/include.*math.h/a\
#define log2(n) (log(n) / log(2))
'
	done
}

log2()
{
	definisLog2 src/lmathlib.c
}

fpic()
{
	case `uname` in
		FreeBSD) filtrer src/Makefile sed -e 's#^CFLAGS *=#CFLAGS=-fPIC#' ;;
	esac
}

compilo()
{
	filtrer src/Makefile sed -e 's#^CC *= *gcc#CC=cc#'
}

# Variables

archive="http://www.lua.org/ftp/$logiciel-$version.tar.gz"
dest=$INSTALLS/$logiciel-$version

[ -d "$dest" ] && exit 0

obtenirEtAllerDansVersion

echo Correction… >&2
for modif in true $modifs ; do $modif ; done

echo Compilation… >&2
case `uname | tr '[A-Z]' '[a-z]'` in
	darwin) make macosx ;;
	freebsd) make freebsd ;;
esac

echo Installation… >&2
sudo make install INSTALL_TOP="$dest"

rm -Rf "$TMP/$$"
