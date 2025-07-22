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

v 3.29.3 && v_nspr="4.13.1" && modifs="pasGcc unistd alertesZlib dbsys monsqlite" || true
v 3.40.1 && v_nspr="4.20" && modifs="$modifs nonInitialisees putenv le64" || true
v 3.42.1 || true
v 3.52.1 && v_nspr="4.25" || true
v 3.53 && modifs="$modifs Iutil" || true
v 3.70 && prerequis="perl \\ $prerequis" && v_nspr=4.32 || true
v 3.99 && v_nspr=4.35 || true
v 3.107 && v_nspr=4.36 || true
v 3.109 && v_nspr=4.36 || true

prerequis="make \\ $prerequis zlib nspr $v_nspr sqlite"

# Modifications

monsqlite()
{
	# Une très, très, très longue histoire de FreeBSD sur lequel firefox refusait d'afficher les pages HTTPS (c'est-à-dire tout, en 2025), voire les PDF, avec ma NSS d'installée:
	#   "Vérifiez que le gestionnaire PSM (Personal Security Manager) est installé"
	# Une première fausse piste me mena vers ma compile: en lançant la compil manuellement (hors GuiLI), jusqu'à plantage, puis terminant en GuiLI, ça passait!
	# Las, après d'innombrables tentatives, il s'avérait que la différence d'environnement résidait en une compile DBG par défaut, OPT(imisée) sous GuiLI, les deux pondant dans des dossiers différents, mais l'install ne se faisant que depuis l'un d'eux: bref mon install ne copiait que la moitié des biblios, l'autre étant oubliée (donc firefox tapant dans celles d'/usr/local/lib).
	# En cherchant à circonscrire je finis par réaliser qu'en déplaçant simplement libsoftokn3.so, une install complète (foireuse) redevenait viable.
	# Une tentative d'appliquer absolument toutes les _rustines_ d'/usr/ports/security/nss (on parle bien de rustines, pas du Makefile) se solda par le même échec.
	# Plein de fausses pistes plus tard (avec comparaison des ktrace des deux firefox, des strings des biblios, accès à la console navigateur Firefox…), j'en étais à me demander si à cause de FIPS la biblio (qui était adjointe d'un .chk) n'était pas signée faussement.
	# En essayant de la resigner depuis son dossier d'install, déjà mini bonne nouvelle, shlibsign plantait ("loading softokn3 failed"). Ça allait faciliter le diagnostic (shlibsign, c'est nettement plus rapide à lancer que firefox. Et puis ça ne m'oblige plus à fermer mon navigateur pour retester).
	# Mais autre nouvelle particulière: en signant n'importe quelle autre biblio, c'était toujours softokn3 qui revenait!
	# Nous voilà donc avec une chaîne apparemment codée en dur, qui se déniche dans le source de l'utilitaire, juste après un PR_LoadLibrary. PR come NSPR, ça tombe bien, je peux la recompiler.
	# Et en lui collant un petit printf(dlerror()) juste après le dlopen():
	# /home/gui/local/lib/libsqlite3.so: version SQLITE_3 required by /home/gui/local/lib/libsoftokn3.so not defined
	# Misère! J'avais appliqué toutes les rustines des Ports FreeBSD, mais m'étais dit que la SQLite embarquée compilant, il n'était pas dans mes priorités de la remplacer par celle GuiLI (je m'étais simplement consigné une note À FAIRE dans le présent fichier).
	# Mais donc la SQLite embarquée avait beau compiler, elle n'était utilisée qu'au moment de lire le jeton logiciel, c'est-à-dire trop tard pour être vu comme bloquant.
	export CFLAGS="$CFLAGS -I$destsqlite/include"
}

Iutil()
{
	# fatal error: seccomon.h: No such file or directory; pourtant il n'est pas loin.
	export CFLAGS="$CFLAGS -I../util -I../freebl -I../softoken"
}

clmul()
{
	# Sur de vieux procs, NSS compile des instructions non reconnues.
	# Il nous suffira de les désactiver, de toute façon à l'exécution la biblio détecte le processeur sur lequel elle tourne et utilisera la version logicielle, donc n'essaiera pas de passer par ce code optimisé (enfin, désactivé dans notre cas).
	cat > /tmp/1.c <<TERMINE
#include <wmmintrin.h>

__m128i a()
{
    __m128i gros;
    gros = _mm_set_epi32(0, 0, 0, 0);
    return _mm_clmulepi64_si128(gros, gros, 0);
}
TERMINE
	# Nous tournons en phase de détection des prérequis, donc sans encore les modifs dont celle qui aura déterminé le $CC le plus adapté. Pour nous mettre dans les même conditions de compil que post-modifs, nous devons donc manuellement invoquer comme configurateur d'environnement le compiloSysVersion() habituel.
	if compilo_test -i compiloSysVersion _compiler_c -c -mpclmul /tmp/1.c
	then
		return 0
	fi
	
	prerequis="binutils \\ $prerequis"
	
	return 0
	
	# Ci-suivent les premières tentatives de désactivation du code "moderne".
	# Mais en fait reposer sur binutils est bien mieux: mieux vaut que la bibliothèque embarque toutes les optims possibles, car de toute façon elles ne seront utilisées à l'exécution que si le processeur est détecté comme les supportant.
	# Attention: ce qui suit est destiné à être utilisé dans $modifs (après obtenirEtAllerDansVersion), tandis que la version définitive (avant le return) modifie $prerequis (donc à lancer avant prerequis()).
	
	# On recopie le bout de code de gcm.c, qui jette en disant que l'optim matérielle n'est pas disponible.
	filtrer lib/freebl/gcm-x86.c awk 'faire==2&&/^}/{faire=3}faire!=2{print}/^gcm_HashMult_hw/{faire=1}faire==1&&/{/{faire=2;print"PORT_SetError(SEC_ERROR_LIBRARY_FAILURE);return SECFailure;"}'
	# A priori même génération de processeurs que pour l'assistance AES: on désactive.
	> lib/freebl/aes-x86.c 
	filtrer lib/freebl/rijndael.c sed -e 's/#ifndef NSS_X86_OR_X64/#if 1/' # La version qui renvoie "Erreur: non implémenté" est là.
	# Bon et puis ça continue longtemps comme ça: Hacl_Poly1305_128.c est le prochain sur la liste, et on ne sait où ça s'arrête.
}

le64()
{
	# Les NSS récentes tiennent pour acquis la présence de macros de conversion portées de BSD vers Linux; mais sur les vieux Linux ça ne marche pas.
	
	[ "`uname`" = Linux ] || return 0
	
	# https://github.com/evanmiller/mod_zip/issues/33
	for f in lib/freebl/verified/kremlin/include/kremlin/lowstar_endianness.h lib/freebl/verified/kremlib.h
	do
		if [ -f "$f" ]
		then
			filtrer "$f" sed -e '/#include <endian.h>/{
a\
#ifndef htole64
a\
# include <byteswap.h>
a\
# if __BYTE_ORDER == __LITTLE_ENDIAN
a\
#  define htobe16(x) __bswap_16 (x)
a\
#  define htole16(x) (x)
a\
#  define be16toh(x) __bswap_16 (x)
a\
#  define le16toh(x) (x)
a\
#  define htobe32(x) __bswap_32 (x)
a\
#  define htole32(x) (x)
a\
#  define be32toh(x) __bswap_32 (x)
a\
#  define le32toh(x) (x)
a\
#  define htobe64(x) __bswap_64 (x)
a\
#  define htole64(x) (x)
a\
#  define be64toh(x) __bswap_64 (x)
a\
#  define le64toh(x) (x)
a\
# else
a\
#  define htobe16(x) (x)
a\
#  define htole16(x) __bswap_16 (x)
a\
#  define be16toh(x) (x)
a\
#  define le16toh(x) __bswap_16 (x)
a\
#  define htobe32(x) (x)
a\
#  define htole32(x) __bswap_32 (x)
a\
#  define be32toh(x) (x)
a\
#  define le32toh(x) __bswap_32 (x)
a\
#  define htobe64(x) (x)
a\
#  define htole64(x) __bswap_64 (x)
a\
#  define be64toh(x) (x)
a\
#  define le64toh(x) __bswap_64 (x)
a\
# endif
a\
#endif
}'
			break
		fi
	done
}

putenv()
{
	[ "`uname`" = Linux -a "$CC" = gcc ] || return 0
	
	# Un GCC récent sur un vieux Linux surcharge dans son features.h celui du système, qui rend putenv introuvable.
	# On passe donc l'inclusion de stdlib.h en premier, avant que features.h soit appelé (indirectement).
	filtrer lib/util/secport.c sed -e '{
x
s/././
x
t
}' -e '/^#include/{
i\
#define _GNU_SOURCE
i\
#include <stdlib.h>
h
}'
}

nonInitialisees()
{
	# GCC 7 d'une Ubuntu 18.04 ne voit pas que certaines variables sont initialisées par macro, while(1) ou autre
	# structure parfaitement suffisante; il génère une alerte, transmutée en erreur.
	filtrer lib/libpkix/pkix_pl_nss/system/pkix_pl_oid.c sed -e '/^[ 	]*[_A-Za-z0-9]*[ 	]*cmpResult;/s/;/ = -1;/'
	filtrer cmd/certutil/certext.c sed -e '/^[ 	]*[_A-Za-z0-9]*[ 	]*value;/s/;/ = 0;/'
	filtrer lib/nss/nssinit.c sed -e '/^[ 	]*[_A-Za-z0-9]*[ *	]*context;/s/;/ = NULL;/'
	filtrer lib/ssl/ssl3con.c $SEDE -e '/^[ 	]*[_A-Za-z0-9]*[ *	]*(spkiScheme|scheme);/s/;/ = 0;/'
}

dbsys()
{
	# Symptôme rigolo d'une NSS GuiLI sur un FreeBSD 14.1 avec un Firefox installé par pkg:
	# toute tentative d'accéder à une page HTTPS se solde par une page grise:
	#   "Vérifiez que le gestionnaire PSM (Personal Security Manager) est installé"
	# Allons voir ce que font /usr/ports/security/nss.
	# Parmi la petite dizaine de rustine, patch-sysdb est intrigante, puisqu'elle parle de BdD, pile ce dont un gestionnaire de mots de passe ou AC racine pourrait avoir besoin.
	# On applique la rustine, on recompile, bingo ça passe! On désapplique, on recompile, ça replante!
	# On reproduit donc ici l'essence de cette rustine.
	
	# … Bon alors en fait non, ça n'est pas du tout ça. Cf. monsqlite sur la réalité.
	
	case `uname` in FreeBSD) true ;; *) return 0 ;; esac
	[ -e /usr/include/db.h ] || return 0
	
	grep -rl 'DBMLIB = ' . | while read f ; do filtrer "$f" \
		sed -e '/^DBMLIB = .*/c\
DBMLIB = $(NULL)
'
	done
	grep -rl 'DBM_SRCDIR = ' . | while read f ; do filtrer "$f" \
		sed -e '/^DBM_SRCDIR = .*/c\
DBM_SRCDIR = $(NULL)
'
	done
	
	grep -rl '#include "prtypes.h"' lib/certdb | while read f ; do filtrer "$f" \
		sed -e '/#include "prtypes.h"/c\
#include <prtypes.h>
'
	done
	grep -rl '#include "mcom_db.h"' lib | while read f ; do filtrer "$f" \
		sed -e '/#include "mcom_db.h"/{
a\
#include <fcntl.h>
c\
#include <db.h>
}'
	done
	
	filtrer lib/softoken/legacydb/config.mk grep -v dbm\\.
	
	# À FAIRE?: db en prérequis? Et donc une recherche plutôt dans $INSTALLS/include?
}

pasGcc()
{
	meilleurCompilo
	filtrer coreconf/`uname`.mk sed -e "s#gcc#$CC#g" -e "s#g++#$CXX#g"
}

unistd()
{
	filtrer lib/zlib/gzguts.h sed -e '/include <stdio/a\
#include <unistd.h>
'
}

alertesZlib()
{
	# https://github.com/madler/zlib/pull/112
	filtrer lib/zlib/inflate.c sed -e 's/-1L << 16/-(1L << 16)/g'
}

configure()
{
	echo "INCLUDES += -I$destnspr/include/nspr" >> coreconf/`uname`.mk
	echo "INCLUDES += $CFLAGS" >> coreconf/`uname`.mk 
	echo "DSO_LDOPTS += $LDFLAGS" >> coreconf/`uname`.mk
	echo "MK_SHLIB += $LDFLAGS" >> coreconf/`uname`.mk
}

maqueue()
{
	CC="$CC" CCC="$CXX" BUILD_OPT=1 USE_64=1 \
	NSS_DISABLE_GTESTS=1 NSS_USE_SYSTEM_SQLITE=1 \
	make "$@"
}

install()
{
	# La 3.53 (et peut-être d'autres) n'intègre plus l'export des .h dans son make principal.
	[ -d ../dist/public ] || maqueue export
	
	prefixeObj="`uname`"
	rm -Rf dest
	cp -R -L "`ls -d ../dist/$prefixeObj*.OBJ | tail -1`" dest # bin et lib
	cp -R -L "../dist/public" dest/include # include
	mkdir dest/lib/pkgconfig
	sed \
		-e "s#%prefix%#$dest#g" \
		-e "s#%exec_prefix%#$dest/bin#g" \
		-e "s#%libdir%#$dest/lib#g" \
		-e "s#%includedir%#$dest/include#g" \
		-e "s#%NSS_VERSION%#$version#g" \
		-e "s#%NSPR_VERSION%#$v_nspr#g" \
		< pkg/pkg-config/nss.pc.in > dest/lib/pkgconfig/nss.pc
	sudo rm -Rf "$dest"
	sudo cp -R dest "$dest"
}

# Variables

#archive="https://ftp.mozilla.org/pub/security/nss/releases/NSS_`echo "$version" | tr . _`_RTM/src/nss-$version-with-nspr-$v_nspr.tar.gz"
archive="https://ftp.mozilla.org/pub/security/nss/releases/NSS_`echo "$version" | tr . _`_RTM/src/nss-$version.tar.gz"

clmul

destiner

prerequis

obtenirEtAllerDansVersion
cd nss

echo Correction… >&2
for modif in true $modifs ; do $modif ; done

echo Configuration… >&2
configure --prefix="$dest" $OPTIONS_CONF

echo Compilation… >&2
#CC=cc CCC=c++ BUILD_OPT=1 USE_64=1 make nss_build_all # Si l'on embarque nspr avec.
#CC=cc CCC=c++ BUILD_OPT=1 USE_64=1 make
maqueue -j4

echo Installation… >&2
install
# NSS installe plein de biblios statiques inutiles, dont libssl.a en conflit avec OpenSSL (pour les biblios dynamiques, NSS suffixe par un 3 qui distingue).
# A priori toutes les distribs (Linux, Homebrew pour sûr) zappent les statiques. Faisons la même chose.
sudoku sh -c "cd \"$dest/lib\" && mkdir -p nss && mv *.a nss/"

sutiliser
