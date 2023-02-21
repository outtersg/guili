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

DelieS() { local s2 ; while [ -h "$s" ] ; do s2="`readlink "$s"`" ; case "$s2" in [^/]*) s2="`dirname "$s"`/$s2" ;; esac ; s="$s2" ; done ; } ; SCRIPTS() { local s="`command -v "$0"`" ; [ -x "$s" -o ! -x "$0" ] || s="$0" ; case "$s" in */bin/*sh) case "`basename "$s"`" in *.*) true ;; *sh) s="$1" ;; esac ;; esac ; case "$s" in [^/]*) s="`pwd`/$s" ;; esac ; DelieS ; s="`dirname "$s"`" ; DelieS ; SCRIPTS="$s" ; } ; SCRIPTS
. "$SCRIPTS/util.sh"

# Historique des versions gérées

v 2.5.39 && prerequis="make m4 \\" && modifs="" || true
v 2.6.3 || true
v 2.6.4 && modifs="reallocarray" || true

# En autoreconf, flex a besoin d'un flex qui n'a pas besoin d'un flex (bref d'un flex non autoreconf).
[ "$versionComplete" = "$version" ] || prerequis="autoconf automake m4 libtool bison flex < $version \\ $prerequis"
[ "$versionComplete" = "$version" ] || modifs="$modifs sansDoc"

# Modifications

sansDoc()
{
	# On ne va pas installer un makeinfo pour la doc, eh oh.
	rm -Rf doc
	for f in Makefile Makefile.am Makefile.in
	do
		[ -f "$f" ] || continue
		# On n'en veut ni dans les sous-dossiers à explorer, ni dans les données à installer.
		filtrer "$f" sed -e '/doc \\/d' -e '/:/s/ install-dist_docDATA//'
	done
	filtrer configure.ac sed -e '/doc\/Makefile/d'
}

reallocarray()
{
	# https://github.com/westes/flex/issues/219
	# https://github.com/westes/flex/issues/265
	export CPPFLAGS="$CPPFLAGS -D_GNU_SOURCE"
}

# Variables

archive="http://cznic.dl.sourceforge.net/project/flex/flex-$version.tar.bz2"
archive="https://github.com/westes/flex/releases/download/v$version/flex-$version.tar.gz"

destiner

prerequis

obtenirEtAllerDansVersion

echo Correction… >&2
for modif in true $modifs ; do $modif ; done

echo Configuration… >&2
[ -f configure ] || ./autogen.sh
./configure --prefix="$dest"

echo Compilation… >&2
make

echo Installation… >&2
sudo make install

sutiliser
