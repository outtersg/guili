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

SCRIPTS="`command -v "$0"`" ; [ -x "$SCRIPTS" -o ! -x "$0" ] || SCRIPTS="$0" ; case "`basename "$SCRIPTS"`" in *.*) true ;; *sh) SCRIPTS="$1" ;; esac ; case "$SCRIPTS" in /*) ;; *) SCRIPTS="`pwd`/$SCRIPTS" ;; esac ; delie() { while [ -h "$SCRIPTS" ] ; do SCRIPTS2="`readlink "$SCRIPTS"`" ; case "$SCRIPTS2" in /*) SCRIPTS="$SCRIPTS2" ;; *) SCRIPTS="`dirname "$SCRIPTS"`/$SCRIPTS2" ;; esac ; done ; } ; delie ; SCRIPTS="`dirname "$SCRIPTS"`" ; delie
. "$SCRIPTS/util.sh"

# Historique des versions gérées

v 2.12.02 || true
v 2.14.02 || true

prerequis

# Modifications

# Variables

archive="http://www.nasm.us/pub/nasm/releasebuilds/$version/nasm-$version.tar.xz"

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
