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

DelieS() { local s2 ; while [ -h "$s" ] ; do s2="`readlink "$s"`" ; case "$s2" in [^/]*) s2="`dirname "$s"`/$s2" ;; esac ; s="$s2" ; done ; } ; SCRIPTS() { local s="`command -v "$0"`" ; [ -x "$s" -o ! -x "$0" ] || s="$0" ; case "`basename "$s"`" in *.*) true ;; *sh) s="$1" ;; esac ; case "$s" in [^/]*) s="`pwd`/$s" ;; esac ; DelieS ; s="`dirname "$s"`" ; DelieS ; SCRIPTS="$s" ; } ; SCRIPTS
. "$SCRIPTS/util.sh"

# Historique des versions gérées

v 5.16.3 && modifs="modifiable moiJeSais sansGdbm" || true
v 5.18.0 || true # Attention, ne permet pas à OpenSSL 1.0.1e de finir son install (http://osdir.com/ml/blfs-support/2013-06/msg00136.html).
v 5.24.0 && prerequis="db" || true
v 5.26.1 || true
v 5.28.1 || true
v 5.30.0 || true
v 5.30.1 || true
v 5.40.0 || true
v 5.42.0 || true

# Modifications

sansGdbm()
{
	# Sur un FreeBSD mélant pkg et GuiLI, il peut trouver certaines biblios dans /usr/local/lib qu'il ne retrouvera plus au moment de compiler (avec un LD_LIBRARY_PATH cette fois restreint).
	filtrer Configure sed -e '/wanted/s/ gdbm//g'
}

moiJeSais()
{
	filtrer Configure sed \
		-e "s#^ccflags='#&$CFLAGS#" \
		-e "s#^ldflags='#&$LDLAGS#"
}

modifiable()
{
	chmod u+w Configure
}

# Variables

archive="http://www.cpan.org/src/5.0/perl-$version.tar.gz"

destiner

prerequis

obtenirEtAllerDansVersion

echo Correction… >&2
for modif in true $modifs ; do $modif ; done

echo Configuration… >&2
sh Configure -de \
	-A define:paths="/bin /usr/bin $INSTALLS/bin" \
	-A define:locincpth="$INSTALLS/include" \
	-A define:loclibpth="$INSTALLS/lib" \
	-Dprefix="$dest"

echo Compilation… >&2
make

echo Installation… >&2
sudo make install
sutiliser
