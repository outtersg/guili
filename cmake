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

SCRIPTS="`command -v "$0"`" ; SCRIPTS="`dirname "$SCRIPTS"`" ; echo "$SCRIPTS" | grep -q "^/" || SCRIPTS=`pwd`/"$SCRIPTS"
. "$SCRIPTS/util.sh"

# Historique des versions gérées

v 2.4.5 || true
v 2.4.6 || true
v 2.8.3 && modifs=putainDeLibJPEGDeMacOSX || true
v 2.8.6 && modifs=putainDeLibJPEGDeMacOSX || true
v 2.8.11 && modifs="putainDeLibJPEGDeMacOSX etToiAlors havefchdir" || true
v 2.8.12 && modifs="etToiAlors havefchdir" || true
v 3.5.2 && modifs="etToiAlors speMac macGcc macOpenssl" || true
v 3.13.1 || true

# Modifications

macOpenssl()
{
	# Le DARWIN_SSL est une infamie qui ne compile plus ou moins pas.
	# LANG et LC_ALL pour éviter un Illegal byte sequence.
	( export LC_ALL=C LANG=C ; filtrer Utilities/cmcurl/CMakeLists.txt sed -e '/OSX_VERSION.*10\.6/s/10\.6/99.99/g' )
	filtrer Utilities/cmlibarchive/libarchive/archive_cryptor_private.h grep -v 'define.*ARCHIVE_CRYPTOR_USE_Apple_CommonCrypto'
}

macGcc()
{
	# Pour une raison que j'ignore, sur mon Mac avec un GCC 4.9.4 comme compilo, Utilities/cmjsoncpp/src/lib_json/json_value.cpp inclut cstddef, qui (en C++11 et suivants, or le configure détecte un GCC qui lui fait ajouter un -std=g++14) croit devoir utiliser un std::max_align_, théoriquement défini en interne du compilo, sauf que ce dernier n'en fait rien, donc plantage.
	mac || return 0
	filtrer Utilities/cmjsoncpp/src/lib_json/json_value.cpp sed -e '/#include <cstddef>/{
i\
#undef __cplusplus
}'
}

speMac()
{
	# GCC sur un Mac est une vieille infamie. On bidouille avec les -isysroot, les -F et autres saloperies, mais in fine:
	# - soit on pointe vers un SDK, et alors on plante à l'édition de lien à la fin (ne trouve pas un symbole à la con _TrucRuneMachin)
	# - soit on ne pointe vers rien, et alors le spécifique Mac ne trouve pas ses en-têtes
	# Donc merde au spécifique Mac.
	mac || return 0
	if true
	then
		for f in Source/cmFindProgramCommand.cxx Source/CPack/cmCPackGeneratorFactory.cxx
		do
			filtrer "$f" sed -e 's/__APPLE__/__APPLE_MES_FESSES__/g'
		done
		filtrer Source/CMakeLists.txt awk '/^endif/{non=0}!non{print}/CMAKE_USE_MACH_PARSER/{if(non)print}/^if\(APPLE/{non=1}'
		filtrer Source/cmake.cxx grep -v 'define .*CMAKE_USE_XCODE'
	else
		if true
		then
			CPPFLAGS="$CPPFLAGS -isysroot=/Developer/SDKs/MacOSX10.6.sdk -I/usr/include"
			LDFLAGS="$LDFLAGS -F/Developer/SDKs/MacOSX10.6.sdk/System/Library/Frameworks -F/System/Library/Frameworks -L/usr/lib"
		else
			CPPFLAGS="$CPPFLAGS -isysroot=/ -I/usr/include"
			LDFLAGS="$LDFLAGS -F/System/Library/Frameworks -L/usr/lib"
		fi
		# Le bootstrap oublie d'exploiter CPPFLAGS et LDFLAGS, on les rajoute donc où nécessaire.
		CFLAGS="$CFLAGS $CPPFLAGS $LDFLAGS"
		CXXFLAGS="$CXXFLAGS $CPPFLAGS $LDFLAGS"
		export CPPFLAGS LDFLAGS CFLAGS CXXFLAGS
	fi
}

# Ce crétin de CMake embarque des bibliothèques complètes (cURL) et s'étonne ensuite de péter lorsque le .h de la biblio est inclus avant le sien.
etToiAlors()
{
	# Les includes ne sont nécessaires que pour compiler CMake lui-même; on inclut donc explicitement les répertoires requis pour *cette* compilation, répertoires qui sont temporaires, plutôt qu'un -I.: ainsi on s'assure que si CMake a des velléités de mémorisation, il ne nous ressortira pas un beau jour de nulle part un -I. dans les applis qu'on lui demande de compiler.
	mkdir -p Utilities/cmcurl/etToiAlors
	tiens="-IetToiAlors/.."
	CPPFLAGS="$tiens $CPPFLAGS"
	CXXFLAGS="$tiens $CXXFLAGS"
	CFLAGS="$tiens $CFLAGS"
	export CPPFLAGS CXXFLAGS CFLAGS
}

havefchdir()
{
	filtrer Utilities/cmlibarchive/libarchive/archive_platform.h sed -e '/define ARCHIVE_PLATFORM_H_INCLUDED/a\
#include "config_freebsd.h"
'
}

# Variables

v="`echo "$version" | cut -d . -f 1,2`"
archive="http://www.cmake.org/files/v$v/$logiciel-$version.tar.gz"

destiner

obtenirEtAllerDansVersion

echo Correction… >&2
for modif in true $modifs ; do $modif ; done

echo Compilation… >&2
./configure --prefix="$dest"

echo Compilation… >&2
make -j 4

echo Installation… >&2
sudo make install
sutiliser
