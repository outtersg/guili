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

v 0.15.1 || true
v 0.15.1.20250914 && versionComplete="0.16.0-dev.234+32a1aabff" || true

# zig partant de Zéro, À Générer
# (détermination de la nécessité de partir de zéro)
zigzag()
{
	case "$versionComplete" in "") versionComplete="$version" ;; esac
	if commande zig
	then
		prerequis="zig < $version \\ $prerequis"
	else
		prerequis="cmake python >= 3 \\ $prerequis"
		versionComplete="bootstrap-$versionComplete"
		echo "# Non mais même pas en rêve. zig demande trop de mémoire (compil d'un .c de 200 Mo)." >&2 ; exit 1
	fi
}
zigzag

archive=https://ziglang.org/builds/zig-$versionComplete.tar.xz

destiner

prerequis

obtenirEtAllerDansVersion

echo Correction… >&2
for modif in true $modifs ; do $modif ; done

configurer() { true ; }
case "$archive" in
*[/-]bootstrap-*)

maquer()
{
	export CMAKE_BUILD_PARALLEL_LEVEL=4
	./build native-`uname | tr A-Z a-z`-unknown native
	# Bon de toute façon zig fait partie de ces sans-gêne qui estiment pouvoir faire compiler un fichier de 200 Mo de C sur n'importe quelle machine. Donc on n'atteindra jamais la fin.
}

deployer()
{
	false
}

;;
*)

maquer()
{
	false
}

deployer()
{
	sudoku make install
}

;;
esac

set -x
echo Configuration… >&2
configurer

echo Compilation… >&2
maquer

echo Installation… >&2
deployer

sutiliser
