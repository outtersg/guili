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

v 1.12.8 && prerequis="pkgconfig \\ pixman >= 0.22 glib libpng" && modifs="gnu89" || true
v 1.12.14 && prerequis="pkgconfig \\ pixman >= 0.30 glib libpng" || true
v 1.12.16 || true
v 1.12.18 && modifs="gnu89 strndup" || true
v 1.14.6 || true
v 1.14.8 && prerequis="$prerequis harfbuzz freetype fontconfig" || true # freetype pour éviter le "use of undeclared identifier 'cairo_ft_font_face_create_for_pattern'".
#v 1.15.2 || true # Lien cassé?
v 1.16.0 || true
v 1.17.4 || true
v 1.18.2 && prerequis="meson ninja \\ $prerequis" || true

gnu89()
{
	# https://gitlab.com/graphviz/graphviz/issues/1365
	case "$CC" in
		gcc*) export CFLAGS="$CFLAGS -std=gnu89" ;;
	esac
}

strndup()
{
	mac || return 0
	
	# Sur un Mac avec un GCC, il détecte les fonctions implicites de la lib GCC, mais sans leur définition, et donc il plante.
	for i in perf/cairo-perf-report.c perf/cairo-perf-trace.c perf/cairo-analyse-trace.c
	do
		filtrer "$i" $SEDE -e '/#(ifndef|define) _GNU_SOURCE/{
i\
#include <stdio.h>
i\
#include <unistd.h>
i\
char *strndup(const char *s, size_t n);
i\
ssize_t getline(char **lineptr, size_t *n, FILE *stream);
}'
	done
}

optionSi hb/harfbuzz && prerequis="$prerequis harfbuzz+-cairo" || true # On précise bien qu'on veut l'harfbuzz sans cairo, sinon on se mord la queue.

destiner

prerequis

archive=https://www.cairographics.org/releases/cairo-$version.tar.xz
pge $version 1.18 || archive=https://www.cairographics.org/snapshots/cairo-$version.tar.xz

obtenirEtAllerDansVersion

echo Correction… >&2
for modif in true $modifs ; do $modif ; done

echo Configuration… >&2
case "$prerequis" in
	*meson*) meson setup build --prefix="$dest" ; make=ninja ; cd build ;;
	*) ./configure --prefix="$dest" ; make=make ;;
esac

echo Compilation… >&2
$make -j 4

echo Installation… >&2
sudoku $make install
sutiliser
