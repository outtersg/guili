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

prerequis="python"
v 1.0.1 && modifs="ssl" || true
v 1.2.4 || true

# Modifications

ssl()
{
	# Pour télécharger les dépendances, on va avoir quelques soucis.
	# http://stackoverflow.com/questions/27835619/ssl-certificate-verify-failed-error
	filtrer setup.py sed -e '/import sys/{
a\
import ssl
a\
ssl._create_default_https_context = ssl._create_unverified_context
}'
}

# Variables

archive="https://pypi.python.org/packages/source/M/Mako/Mako-$version.tar.gz"

destiner

prerequis

obtenirEtAllerDansVersion

echo Correction… >&2
for modif in true $modifs ; do $modif ; done

echo Compilation… >&2
python ./setup.py build

echo Installation… >&2
dest0="`pwd`/dest"
rm -Rf "$dest0"
pyextinit "$dest0"
sudokupy python ./setup.py install --prefix="$dest0"

sudoku mkdir -p "$dest"
sudoku cp -Rp "$dest0/." "$dest/."
sutiliser - "$PYEXT"
