#!/bin/bash
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
. "$SCRIPTS/util.bash"

logiciel=cmake

# Historique des versions gérées

version=2.4.5

version=2.4.6
OPTIONS_CONF=()

version=2.8.3
modifs=putainDeLibJPEGDeMacOSX

version=2.8.6
modifs=putainDeLibJPEGDeMacOSX

v 2.8.11 && modifs="putainDeLibJPEGDeMacOSX etToiAlors havefchdir" || true

# Modifications

# CMake, pour sa config, teste son petit monde en essayant de se lier à Carbon.
putainDeLibJPEGDeMacOSX()
{
	# Ces trous du cul d'Apple ont cru bon créer une libJPEG.dylib à eux, qui évidemment ne sert à personne d'autre qu'à eux (les symboles à l'intérieur sont tous préfixés _cg_, comme CoreGraphics). Et avec un système de fichier insensible à la casse, cette connasse de libJPEG de merde prend le pas sur la très légitime libjpeg que l'on souhaite utiliser un peu partout.
	case essai in
		tentative)
			LDFLAGS="-L/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/ImageIO.framework/Versions/A/Resources $LDFLAGS"
			export LDFLAGS
			;;
		test)
			# Ou alors je lui pète la tête, à ce gros nase de CMake qui s'obstine à se lier avec Carbon. C'est pas son boulot, je me démerderai au cas par cas avec les conneries que me fait faire Apple. Putain ils font chier quand même avec leurs bourdes.
			grep -rl 'framework Carbon' . | while read f
			do
				filtrer "$f" sed -e 's/-framework Carbon//g'
			done
			# Mais quand même il va en avoir besoin un coup à la fin.
			filtrer bootstrap sed -e '/-o cmake/{
s//-framework Carbon -o cmake/
s#${cmake_ld_flags}#-L/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/ImageIO.framework/Versions/A/Resources -lJPEG &#
}'
			;;
		essai)
			# Mais ce foutu machin s'obstine à se lancer dans je ne sais quelles variables d'environnement. Alors on essaie de lui dire de se compiler en indépendant.
			LDFLAGS="`echo "$LDFLAGS" | sed -e "s#-L$INSTALLS/lib##g"`"
			DYLD_FALLBACK_LIBRARY_PATH="$LD_LIBRARY_PATH:$DYLD_LIBRARY_PATH:$DYLD_FALLBACK_LIBRARY_PATH"
			unset LD_LIBRARY_PATH
			unset DYLD_LIBRARY_PATH
			export DYLD_FALLBACK_LIBRARY_PATH
			;;
	esac
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
dest="$INSTALLS/$logiciel-$version"

[ -d "$dest" ] && exit 0

obtenirEtAllerDansVersion

echo Correction… >&2
for modif in true $modifs ; do $modif ; done

echo Compilation… >&2
./configure --prefix="$dest"

echo Compilation… >&2
make

echo Installation… >&2
sudo make install
sutiliser $logiciel-$version

rm -Rf "$TMP/$$"
