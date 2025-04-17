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

. "$SCRIPTS/libuv.util.sh"

# Historique des versions gérées

v 2.4.5 || true
v 2.4.6 || true
v 2.8.3 && modifs=putainDeLibJPEGDeMacOSX || true
v 2.8.6 && modifs=putainDeLibJPEGDeMacOSX || true
v 2.8.11 && modifs="putainDeLibJPEGDeMacOSX etToiAlors havefchdir" || true
v 2.8.12 && modifs="etToiAlors havefchdir" || true
v 3.5.2 && modifs="etToiAlors speMac macGcc macOpenssl" || true
v 3.13.1 && prerequis="langcxx(11) \\" || true
v 3.13.5 || true
if eventfd # À partir de là cmake repose sur une libuv qui ne compile pas sur les "vieux" systèmes.
then
v 3.14.7 || true
v 3.15.7 || true
v 3.16.8 || true
v 3.17.3 || true
v 3.20.3 || true
v 3.21.1 || true
v 3.21.3 || true
v 3.22.1 || true
v 3.27.6 || true
v 3.31.2 && v_openssl=">= 3.2" || true
v 3.31.3 || true
v 3.31.7 || true
fi

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
	# Notons aussi que selon les étapes, la compil se fait dans le dossier du source, ou dans un Bootstrap.cmk. On doit donc tout inclure.
	rm -f toi && ln -s . toi
	mkdir -p Utilities/cmcurl/etToiAlors
	tiens="-IetToiAlors/.. -I../toi/Utilities/cmlibuv/include"
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

# Prérequis
# On prérequiert ici tous les logiciels dont on détecte un exécutable.
# CMake a une fâcheuse tendance à détecter les logiciels présents ainsi, et à en conclure qu'il doit se compiler avec; malheureusement, sur certaines distributions Linux, le binaire peut être présent sans les inclusions (livrées dans un paquet optionnel en "-dev"): dans cette situation, le configure de CMake va vouloir lier au logiciel tierce, et va échouer ne trouvant pas les inclusions.
# Pour ces détections de logiciels tierces, on préfère alors prendre les devants en imposant (via prerequis) que ce soit la version GuiLI qui soit utilisée: GuiLI installe toujours conjointement binaires et inclusions.

! commande openssl || prerequis="$prerequis openssl $v_openssl"
prerequisOpenssl
# La ligne suivante ne servirait que si, parmi les versions de cmake dont le libuv embarqué ne tourne pas sur certaines plates-formes (obsolètes), certaines pouvaient tourner avec un libuv externe (plus ancien que l'embarquée, mais tournant sur la plate-forme). Or il n'en existe pas: cmake repose étroitement sur des fonctionnalités de sa libuv embarquée, il est donc impossible de le compiler avec une libuv plus ancienne.
#pge 3.13.5 $version || prerequisLibuv # Pour la 3.13.5 et en-dessous, la libuv intégrée est bonne, on s'en satisfait. Au dessus, il va falloir basculer vers une libuv externe.

# Tous ces prérequis sont des prérequis de construction. À l'exécution, nos utilisateurs veulent simplement utiliser un cmake, et ne pas devoir dépendre de toutes les bibliothèques auxquelles lui est lié (exemple criant: un bidule nécessitant un OpenSSL < 1.1, se construisant avec cmake, n'a surtout pas envie que ce dernier lui impose son OpenSSL 1.1 "de compilation").
prerequis="$prerequis \\"

destiner

prerequis

obtenirEtAllerDansVersion

echo Correction… >&2
# Petite entourloupe: finalement on ne veut pas qu'exclusivementPrerequis limite $PATH et compagnie aux seuls prérequis déclarés.
# Le configure de cmake va tester plein de logiciels pour savoir quels modules précompiler, aussi on lui laisse accès au plus grand nombre de paquets; on compte sur sa maturité pour ne pas s'y lier.
exclusivementPrerequis() { true ; }
for modif in true $modifs ; do $modif ; done

echo Compilation… >&2
./configure --prefix="$dest" $OPTIONS_CONF

echo Compilation… >&2
make -j 4

echo Installation… >&2
sudo make install
# Nos dépendances d'exécutable ne doivent pas forcer nos appelants à charger nos biblios partagées. Les avoir passées en dépendances de compilation évite de telles bavures, par contre il faut quand même que nous les ayons à portée de main quand nous sommes lancés.
# N.B.: on débine par suffixe et non par placement dans libexec, car je ne sais comment les binaires pètent s'ils ne se trouvent pas à l'endroit où ils ont été installés.
debiner -s .bin "$dest/bin"/*

sutiliser
