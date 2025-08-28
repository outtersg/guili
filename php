#!/bin/sh
# Copyright (c) 2004-2005 Guillaume Outters
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
. "$SCRIPTS/util.guili.curl.sh"

OPTIONS_CONF=

# Historique des versions gérées

# pkgconfig au moins pour libxml en PHP 8.
# openssl < 1.1: apparemment la 5.2 connaît déjà la 1.1, mais ça doit être dans nos dépendances que ça coince (genre on se lie à un PostgreSQL ne connaissant lui-même qu'OpenSSL 1.0).
prerequis="langc() langcxx() pkgconfig \\ libjpeg libpng freetype gettext ncurses readline curl+osslxx < 8 zlib iconv mysql postgresql+osslxx < 17 libxml openssl < 1.1 libssh+osslxx sqlite"
v 4.4.7 && ajouterModif readlineNcurses lcplusplus pginfossl doubleYytext || true
v 5.0.3
v 5.0.4
# PHP 5.0.3 ne gère pas l'iconv de Panther; il détecte bien l'appel libiconv,
# mais, n'incluant pas iconv.h, il ne voit pas qu'iconv et libiconv sont les
# mêmes. La version 5.1 corrige ça. Pour compiler la 5.0.x, on peut contourner
# en ajoutant un #define HAVE_ICONV 1 dans ext/iconv/php_have_libiconv.h.
v 5.0.9.1.2005-04-16
v 5.0.9.2.2005-08-22
# La 2005-08-22 crashe avec Apache 2.0.54, dèl'appel.
v 5.0.9.3.2005-08-29
# La 2005-08-29 explose sur la recréation du cache de l'album (httpd-2.1.7).
v 5.0.9.4.2005-09-20
v 5.0.9.5.2005-09-23 && ajouterModif php34617
# icu < 56: https://bugs.archlinux.org/task/58061, http://source.icu-project.org/repos/icu/trunk/icu4c/readme.html#RecBuild par rapport aux namespaces de la 61 (et la 55.1 marche bien, donc < 56 est une valeur sûre)
v 5.1.4 && retirerModif php34617 && prerequis="icu < 56 $prerequis" || true # Avant les prérequis, pour que harfbuzz (requis par les versions récentes de freetype) le détecte et tant qu'à faire l'exploite (comme dit dans le configure d'Harfbuzz: the more the merrier). Ce serait le genre de tâche à dévoluer à ecosysteme (signalement à certaines de nos dépendances de la présence d'autres de nos dépendances pour qu'elles s'y lient, avec réordonnement), en attendant c'est à nous de le faire manuellement.
# Apache 2.2.3
v 5.2.0 && ajouterModif pasDUsrLocalEnDur || true
v 5.2.1 || true #&& ajouterModif pourTrouverApache
v 5.2.3
# Crétin de 5.2.3, son test pour gd lance une commande ld -L(rien du tout) et échoue.
v 5.2.3.1.2007-07-29
v 5.2.5
v 5.2.8
# Chier, tombé en plein sur http://bugs.php.net/bug.php?id=48276 (les cookies étaient générés expirant en l'an 0, et Drupal voyait toutes ses dates en 0 lors des filtrages et affichages.
#v 5.2.10
v 5.2.11
v 5.2.13 && ajouterModif libpng14 && ajouterModif detectionIconvOuLibiconv && ajouterModif mesBibliosDAbord
v 5.2.15
v 5.2.17 && remplacerPrerequis "mysql < 5.5.20" "libxml < 2.8" || true
v 5.3.13 && ajouterModif fileinfoSobre zendNsNameEspace && retirerModif libpng14 doubleYytext && modifs="$modifs pgsqlSetNoticeCallback" && remplacerPrerequis mysql "libxml < 2.12" || true
v 5.3.19 || true
v 5.3.28 || true
v 5.3.29 && ajouterModif tcpinfo || true
v 5.4.5 && retirerModif libpng14 zendNsNameEspace || true
v 5.4.10 || true
v 5.4.11 && remplacerPrerequis "icu >= 50 < 56" "libjpegturbo < 2" && virerPrerequis libjpeg || true
v 5.4.33 || true
v 5.4.36 || true # Apache 2.4.10 + mod_php = au bout d'un certain temps, segfault.
v 5.4.39 || true
v 5.4.41 || true
v 5.4.45 || true
v 5.4.45.1 || true # Qq modifs faites sur un BSD avec un clang++ 17 qui gueulait: 1. un fichier pète sur les register: le recomp en -std=c++11; 2. readdir_r pète: définir à 1 le HAVE_ dans le config.h; 3. cooie_seeker pète: transformer ds toutes les déclarations off_t en fpos_t *, puis le passer en *
v 5.5.7 || true
v 5.5.8 || true
v 5.5.14 || true
v 5.6.3 && ajouterModif haveLibReadline || true
v 5.6.4 || true
v 5.6.10 || true
v 5.6.20 && retirerModif pginfossl || true
v 5.6.25 || true
v 5.6.39 || true
v 5.6.40 || true
v 5.6.40.1 || true
# icu < 70 car en 70, l'UBool operator== de brkiter.h devient un bool operator== (le premier étant un unsigned char, et clang refusant de faire la conversion => la version interne à PHP est incompatible).
# On peut voir d'ailleurs dans les codepointiterator_internal.h des versions 8 qu'ils l'ont aiguillé d'un #if U_ICU_VERSION_MAJOR_NUM >= 70
v 7.0.2 && prerequis="langc() langcxx(11) \\ $prerequis" && modifs="$modifs doubleEgalEnShDansLeConfigure isfinite icucxx11 truefalse" || true
v 7.0.8 || true
v 7.0.15 || true
v 7.1.13 && ajouterModif cve201911043 confclosedir && remplacerPrerequis "openssl < 3" || true
v 7.1.14 || true
v 7.2.1 && remplacerPrerequis "icu >= 60 < 70" || true
v 7.2.3 || true
v 7.2.4 || true
v 7.2.10 || true
v 7.2.11 || true
v 7.2.14 || true
v 7.2.17 || true
v 7.2.29 || true
v 7.2.31 || true
v 7.2.34 || true
v 7.3.1 && prerequis="$prerequis libzip+osslxx" || true # "Notre" libzip requise parce que pour --enable-zip maintenant PHP cherche libzip.pc au lieu de se contenter du .so comme au bon vieux temps; or nombre de distribs ne livrent pas par défaut le .pc.
v 7.3.4 || true
v 7.3.9 || true
v 7.3.10 || true
v 7.3.11 && retirerModif cve201911043 || true # Tout ce qui est >= 7.3.11 (7.3.11, 7.3.12, etc., 7.4.0, 7.4.1, etc.) embarque le correctif à CVE-2019-11043.
v 7.3.13 || true
v 7.3.15 || true
v 7.3.18 || true
v 7.3.26 || true
v 7.3.27 || true
v 7.3.28 || true
v 7.3.29 || true
v 7.3.30 || true
v 7.3.31 || true
v 7.3.32 || true
v 7.3.33 || true
v 7.4.16 && prerequis="$prerequis oniguruma" && remplacerPrerequis "icu >= 60 < 76" && retirerModif confclosedir || true # ICU 76 utilise du C++14; on pourrait donc aussi passer en langcxx(14) en faisant sauter la limitation sur ICU.
v 7.4.19 || true
v 7.4.20 || true
v 7.4.21 || true
v 7.4.22 || true
v 7.4.23 || true
v 7.4.24 || true
v 7.4.25 || true
v 7.4.26 || true
v 7.4.27 || true
v 7.4.28 || true
v 7.4.29 || true
v 7.4.30 || true
v 7.4.32 || true
v 7.4.33 || true
# Pour compiler la master:
#v 7.5 && prerequis="re2c \\ $prerequis oniguruma" && OPTIONS_CONF="$OPTIONS_CONF --enable-maintainer-zts --enable-debug" || true
v 8.0.1 && remplacerPrerequis "openssl < 4" "curl+osslxx" "postgresql+osslxx" "icu >= 60" libxml || true
v 8.0.3 || true
v 8.0.6 || true
v 8.0.7 || true
v 8.0.8 || true
v 8.0.9 || true
v 8.0.10 || true
v 8.0.11 || true
v 8.0.12 || true
v 8.0.13 || true
v 8.0.14 || true
v 8.0.15 || true
v 8.0.16 || true
v 8.0.17 || true
v 8.0.18 || true
v 8.0.19 || true
v 8.0.20 || true
v 8.0.23 || true
v 8.0.24 || true
v 8.0.25 || true
v 8.0.27 || true
v 8.0.28 || true
v 8.0.29 || true
v 8.0.30 || true
v 8.1.1 || true
v 8.1.2 || true
v 8.1.3 || true
v 8.1.4 || true
v 8.1.5 || true
v 8.1.6 || true
v 8.1.7 || true
v 8.1.10 || true
v 8.1.11 || true
v 8.1.12 || true
v 8.1.14 || true
v 8.1.16 || true
v 8.1.17 || true
v 8.1.19 || true
v 8.1.20 || true
v 8.1.21 || true
v 8.1.22 || true
v 8.1.24 || true
v 8.1.25 || true
v 8.1.27 || true
v 8.1.28 || true
v 8.1.29 || true
v 8.1.30 || true
v 8.1.31 || true
v 8.1.32 || true
v 8.1.33 || true
v 8.2.1 && virerPrerequis "langcxx()" && prerequis="langcxx(17) \\ $prerequis" && modifs="$modifs atomicconst pglazyfetch" || true
v 8.2.3 || true
v 8.2.4 || true
v 8.2.6 || true
v 8.2.7 || true
v 8.2.8 || true
v 8.2.9 || true
v 8.2.11 || true
v 8.2.12 || true
v 8.2.15 || true
v 8.2.16 || true
v 8.2.17 || true
v 8.2.18 || true
v 8.2.19 || true
v 8.2.21 || true
v 8.2.22 || true
v 8.2.23 || true
v 8.2.24 || true
v 8.2.25 || true
v 8.2.26 || true
v 8.2.27 || true
v 8.2.28 || true
v 8.2.29 || true
v 8.3.2 && modifs="$modifs pdeathsig" || true
v 8.3.3 || true
v 8.3.4 || true
v 8.3.6 || true
v 8.3.7 || true
v 8.3.9 || true
v 8.3.10 || true
v 8.3.11 || true
v 8.3.12 || true
v 8.3.13 || true
v 8.3.14 || true
v 8.3.15 || true
v 8.3.16 || true
v 8.3.17 || true
v 8.3.19 || true
v 8.3.20 || true
v 8.3.21 || true
v 8.3.22 || true
v 8.3.23 || true
v 8.3.24 || true
v 8.4.1 && retirerModif pgsqlSetNoticeCallback fileinfoSobre && modifs="$modifs ki_tracer" || true
v 8.4.2 || true
v 8.4.3 || true
v 8.4.4 || true
v 8.4.5 || true
v 8.4.6 || true
v 8.4.7 || true
v 8.4.8 || true
v 8.4.10 || true
v 8.4.11 || true
v 8.4.12 || true

# Si on nous demande de nous installer sous l'alias phpx, on renseigne le numéro de version à la place du 'x'.
aliasVersion 'x'

prerequis="$prerequis bzip2" # Chez moi car freetype s'est compilé avec.
OPTIONS_CONF="$OPTIONS_CONF --with-bz2"

# Si un PHP fonctionnel est déniché, on s'en servira pour de l'autogénération.
ANCIEN_PHP="`command -v php || true`"
[ -z "$ANCIEN_PHP" ] || $ANCIEN_PHP --version | grep -q Zend || ANCIEN_PHP=

# Si certains logiciels sont déjà installés, on laisse le configure PHP les détecter, mais on s'assure auparavant que ce sera notre version qu'il détectera, en l'ajoutant aux prérequis.
if optionSi postgresql sh -c 'psql --version 2> /dev/null | grep -q PostgreSQL'
then
	case "$prerequis" in *postgresql) prerequis="$prerequis+osslxx" ;; esac
	# Le configure n'exploite pas le $PATH, mais va chercher pg_config dans des chemins codés en dur à moins d'avoir forcé en --with-…=$chemin.
	cheminPostgresql() { OPTIONS_CONF="$OPTIONS_CONF --with-pgsql=$destpostgresql --with-pdo-pgsql=$destpostgresql" ; }
	modifs="$modifs cheminPostgresql"
fi

if ! optionSi mysql commande mysql
then
	OPTIONS_CONF="$OPTIONS_CONF --without-mysql --without-pdo-mysql"
fi

# Sur de très vieilles machines, PHP 7, qui utilise du sed -E, va se vautrer. Dans ce cas, on demande un sed 4.2.2, qui a l'avantage de gérer le -E mais aussi de compiler sur ces vieilles bécanes.
PATH_EP="`echo "$PATH" | tr : '\012' | egrep -v "^$INSTALLS/s?bin$" | tr '\012' ':' | sed -e 's/:$//'`" # Le PATH sous lequel tournera le configure sera celui d'exclusivementPrerequis.
case "`echo gloc | PATH="$PATH_EP" sed -E -e 's/g|c/p/g' 2> /dev/null`" in
	plop) true ;;
	*) prerequis="sed < 4.3 $prerequis" ;;
esac
prerequisIcu # Demandons à nos prérequis leur version qui se lie à l'ICU que l'on impose.

# Modules simples.
for module in bcmath
do
	if option "$module"
	then
		plus OPTIONS_CONF --enable-$module
	fi
done

# Fin octobre 2019, prerequis() accumule les variables $*FLAGS de tous nos prérequis, sans dédoublonnage (de peur que l'ordre joue).
# Cela pose problème au configure de PHP qui fait un sed -e "s#$*FLAGS#…#", ce qui explose certaines implémentations de sed (limités à 2048 octets pour leur expression à remplacer).
# De toute manière les lignes à rallonge ne sont pas les bienvenues.
# On réduit donc tout ce petit monde.
flagsUniques()
{
	local c v
	for c in CFLAGS CXXFLAGS CPPFLAGS LDFLAGS
	do
		eval v="\"\$$c\""
		export "$c=`args_reduc_u $v`"
	done
}
args_reduc_u()
{
	for p in "$@" ; do echo "$p" ; done | awk '{if(!t[$0]){t[$0]=1;print}}' | tr '\012' ' ' | sed -e 's/ $//'
}
flagsUniques

# Modifs

zendNsNameEspace()
{
	# PHP 5.3 vient avec une définition qui donne un "C++11 requires a space between literal and identifier".
	
	filtrer Zend/zend_API.h sed -e '/#define ZEND_NS_NAME/s/"\\\\"/ & /'
}

doubleYytext()
{
	# https://bugs.php.net/bug.php?id=44462
	local f
	for f in Zend/zend_*.c
	do
		filtrer "$f" sed -e '/^char.*yytext/s#^#//#'
	done
}

atomicconst()
{
	# https://github.com/php/php-src/issues/8881
	# Normalement tous les compilos C11 ont été corrigés (https://gitlab.isc.org/isc-projects/bind9/-/issues/3370)
	filtrer Zend/zend_atomic.h awk '
/zend_atomic.*\(const/{tyty=$0;sub(/.*[(]const */,"",tyty);sub(/[^a-z_].*/,"",tyty)}
/__c11_atomic_load\(&obj->value/{sub(/obj->/, "(("tyty" *)obj)->")}
{print}
'
}

pdeathsig()
{
	# C'est bien gentil de mettre un commentaire "on ne s'inquiète pas du retour vu que peu de systèmes implémentent", si l'appel déjà plante.
	filtrer sapi/cli/php_cli_server.c sed -e '/PROC_PDEATHSIG_CTL/{
i\
#ifdef PROC_PDEATHSIG_CTL
a\
#endif
}'
}

ki_tracer()
{
	# PHP 8.4 repose sur des membres de kinfo_proc absents de FreeBSD 10.2.
	
	case `uname` in FreeBSD) true ;; *) return ;; esac
	
	cat > $TMP/$$/1.c <<TERMINE
#include <sys/types.h>
#include <sys/user.h>

int main(int argc, char ** argv)
{
	struct kinfo_proc i;
	return i.ki_tracer;
}
TERMINE
	compilo_test $CC $TMP/$$/1.c -o $TMP/$$/1.bin || filtrer ext/opcache/jit/ir/ir_gdb.c sed -e '/if.*ki_tracer/{
i\
#ifdef HAVE_KI_TRACER
a\
#else
a\
if(0){
a\
#endif
}'
}

pglazyfetch()
{
	# https://github.com/php/php-src/pull/15750
	# On part de a730319fd531eab6d843b08f8d67abfe278e66d4 qui était la dernière version compatible 8.4 avant rebase pour la 8.5.
	local vphp
	for vphp in 8.4 8.2
	do
		pge $version $vphp || continue
		break
	done
	patch -p0 < "$SCRIPTS/php.pglazyfetch.$vphp.patch"
}

fileinfoSobre()
{
	# https://bugs.php.net/bug.php?id=65106
	if [ -n "$ANCIEN_PHP" ]
	then
	(
		cd ext/fileinfo &&
		cp "$SCRIPTS/php.data_file_to_mgc.c" ./ &&
		$CC -o /tmp/data_file_to_mgc php.data_file_to_mgc.c &&
		/tmp/data_file_to_mgc &&
		LD_LIBRARY_PATH=$INSTALLS/lib:$LD_LIBRARY_PATH $ANCIEN_PHP "$SCRIPTS/php.create_data_file.php" magic.mgc > data_file.c
	)
	else
	filtrer ext/fileinfo/data_file.c sed -e 's#^0x#"\\x#' -e 's#, 0x#\\x#g' -e 's#, *$#"#' -e 's#{ *$##' -e 's#}##' -e 's#, *;#";#'
	fi
}

confclosedir()
{
	# Entre les versions 7.1 et 7.3 incluses, le configure croyant bien faire a ajouté à son test de readdir_r un close symétrique à l'opendir.
	# Problème: l'opération symétrique à opendir est closedir, pas close.
	# En conséquence, le programme testé sortait en erreur, laissant le configure croire que readdir_r n'était pas exploitable (alors que l'erreur était sur la suite).
	
	local f
	for f in acinclude.m4 aclocal.m4 configure
	do
		filtrer "$f" sed -e 's#close(dir)#closedir(dir)#'
	done
}

cve201911043()
{
	case "$version" in
		# Les versions 7.4 et suivantes étant sorties après la CVE, n'appellent pas la présente modif.s
		# On gère donc ici uniquement les mineures à cheval entre version pourrie et version corrigée.
		7.3.*) ! pge $version 7.3.11 || return 0 ;;
		7.2.*) ! pge $version 7.2.24 || return 0 ;;
		7.1.*) ! pge $version 7.1.33 || return 0 ;;
	esac
	patch -p0 < "$SCRIPTS/php.cve-2019-11043.patch"
}

icucxx11()
{
	# ICU à partir de la 58 utilise du char16_t, qui n'existe qu'en C++11, pas implicite.
	# Par contre finalement on ne code pas en dur le -std=c++, laissant le langcxx(nn) régler les choses: dans les versions futures le nn sera différent de 11.
	#export CXXFLAGS="$CXXFLAGS -std=c++11"
	true
}

truefalse()
{
	# Sur mon BSD l'inclusion d'on ne sait quelle version de quoi fait des équivalents #undef TRUE et FALSE.
	# Serait-ce icucxx11?
	# Pourtant celle-ci fonctionne, du moment qu'on reste en ossl10 et non ossl11.
	# Si une précédente tentative de compil a laissé des artéfacts, on les ignore, surtout qu'ils ne sont pas du C préprocessable.
	grep -rl intl_convert.h ext/intl | grep -v '\.dep' | while read f
	do
		filtrer "$f" sed -e '/intl_convert.h/{
a\
#define TRUE 1
a\
#define FALSE 0
}'
	done
	for f in \
		ext/intl/breakiterator/codepointiterator_internal.cpp
	do
		filtrer "$f" awk '!fait&&/^[^\/# ]/{ print "#define TRUE 1"; print "#define FALSE 0"; fait = 1; }{ print; }'
	done
}

pgsqlSetNoticeCallback()
{
	local vphp
	for vphp in 8.1.14
	do
		pge $version $vphp || continue
		patch -p0 -l < "$SCRIPTS/php.pgsqlSetNoticeCallback.$vphp.patch"
		return
	done
	
	local suffixe= adaptation=cat
	case $version in
		8.0.*)
			suffixe=8
			pp80()
			{
				cat "$SCRIPTS/php.pgsqlSetNoticeCallback.80.patch.patch"
				sed -e 's#^\([ 	]*\)bool#\1zend_bool#' -e '/pgsql_driver.stub.php/,/diff.*arginfo/d'
			}
			adaptation=pp80
			;;
		[89].*|[1-9][0-9].*) suffixe=8 ;;
		7.[0-2].*) suffixe=7 ; zsre() { sed -e 's/zend_string_release_ex(\(.*\), 0)/zend_string_release(\1)/g' ; } ; adaptation=zsre ;;
		[7].*) suffixe=7 ;;
		5.6.*) suffixe=56 ;;
		5.*) suffixe=5 ;;
	esac
	[ -z "$suffixe" ] || $adaptation < "$SCRIPTS/php.pgsqlSetNoticeCallback.$suffixe.patch" | patch -p0 -l
}

pginfossl()
{
	# https://github.com/php/php-src/commit/2399c64eaffba559332b54b664b670c46ac471c2
	filtrer ext/pgsql/pgsql.c sed -e 's/#ifdef *USE_SSL/#if defined(USE_SSL) || defined(USE_OPENSSL)/g'
}

isfinite()
{
	# gcc (4.9 recompilé sur de vieilles RedHat en tout cas) définit isfinite, mais sous conditions (C++99) que ne respecte pas forcément la compil PHP. Du coup mieux vaut reposer sur l'implémentation PHP passe-partout.
	filtrer configure sed -e '/#define HAVE_DECL_ISFINITE \$/s/\$.*/0/'
}

doubleEgalEnShDansLeConfigure()
{
	# Ces tests ne passent pas (sh sous FreeBSD 8); en particulier, la détection de la demande de compil de phpdbg échoue.
	filtrer configure sed -e '/ test.*==/s/==/=/g'
}

haveLibReadline()
{
	filtrer sapi/phpdbg/phpdbg.h sed -e 's/ifdef LIBREADLINE/ifdef HAVE_LIBREADLINE/g'
}

lcplusplus()
{
	# Petit souci de "DSO missing from command line" sur une Ubuntu 18.04 / GCC 7.3.0
	if [ `uname` = Linux ]
	then
		LDFLAGS="$LDFLAGS -lstdc++"
	else
		# Le configure 5.6 impose du stdc++ même avec du clang++ / libc++.
		case "$CXX" in
			clang++*)
				echo '#include <iostream> @ int main() { std::cout << "Salut" << std::endl; return 0; }' | tr @ '\012' > /tmp/1.cxx
				# Pour tester le mode de fonctionnement exact de PHP, on ne tente pas la compilation en une passe (.cxx -> exécutable),
				# car clang invoqué en tant que clang++ sait qu'il doit ajouter son -lc++ (et -lc++abi s'il est GuiLI).
				# Or la compil PHP utilise clang++ à la compil (d'ext/intl, seule partie en C++), mais clang à l'édition de liens finale.
				local lcxx
				for lcxx in "" "-lc++" "-lc++ -lc++abi" "-lstdc++"
				do
					$CXX -c -o /tmp/1.o /tmp/1.cxx && $CC -o /tmp/1 /tmp/1.o $lcxx && break
				done
				case "$lcxx" in
					""|-lstdc++) true ;;
					*) filtrer configure sed -e "s#-lstdc++#$lcxx#g" ;;
				esac
				echo "Édition de liens C++: [36m$lcxx[0m"
				;;
		esac
	fi
}

readlineNcurses()
{
	# readline repose sur la présence des fonctions de terminfo… mais se garde bien d'aller la chercher (trop d'endroits possibles?).
	# Du coup si l'on veut se lier à readline il nous faut trouver avec quoi d'autre nous lier pour que ça fonctionne.
	# À FAIRE: faire un coup de prérequis ncurses si une première passe ne l'a pas trouvé.
	# À FAIRE: cf. tinfoliee dans readline: pourrait-on faire sauter ce readlineNcurses?
	cc="$CC"
	[ ! -z "$cc" ] || cc=cc
	echo 'extern int tgetent(char *bp, const char *name); int main(int argc, char ** argv) { tgetent("coucou", "coucou"); }' > testTerminfo.c
	for essai in \
		"" \
		"-lncursesw" \
		"-lncurses" \
		"-lterminfo" \
		"-ltinfo" \
		"/lib64/libterminfo.5."* \
		"(impossible de trouver libterminfo)"
	do
		"$cc" -o testTerminfo testTerminfo.c $LDFLAGS $essai 2> /dev/null >&2 && break || continue
	done
	filtrer configure sed -e "s#-lreadline#-lreadline $essai#g"
		
}

php34617()
{
	patch -p0 << TERMINE
diff -ru Zend/zend.c Zend/zend.c
--- Zend/zend.c	2005-09-23 17:50:39.000000000 +0200
+++ Zend/zend.c	2005-09-23 17:50:10.000000000 +0200
@@ -1602,6 +1602,7 @@
 	zend_destroy_rsrc_list(&EG(regular_list) TSRMLS_CC);
 
 	zend_try {
+		zend_objects_store_destroy(&EG(objects_store));
 		zend_ini_deactivate(TSRMLS_C);
 	} zend_end_try();
 }
diff -ru Zend/zend_execute_API.c Zend/zend_execute_API.c
--- Zend/zend_execute_API.c	2005-09-23 17:48:45.000000000 +0200
+++ Zend/zend_execute_API.c	2005-09-23 17:49:57.000000000 +0200
@@ -297,7 +297,7 @@
 		zend_stack_destroy(&EG(user_error_handlers_error_reporting));
 		zend_ptr_stack_destroy(&EG(user_error_handlers));
 		zend_ptr_stack_destroy(&EG(user_exception_handlers));
-		zend_objects_store_destroy(&EG(objects_store));
+		//zend_objects_store_destroy(&EG(objects_store));
 		if (EG(in_autoload)) {
 			zend_hash_destroy(EG(in_autoload));
 			FREE_HASHTABLE(EG(in_autoload));
TERMINE
}

pasDUsrLocalEnDur()
{
	# Gros cons! Pourquoi est-ce que vous allez chercher les trucs en dur dans /usr/local à défaut /usr, alors que vous avez un PATH qui sert à ça?
	mesChemins="`echo "$PATH" | tr : '\012' | sed -e '/\/bin$/!d' -e 's#/bin$##' | tr '\012' ' '`"
	filtrer configure sed -e "s#/usr/local /usr#$mesChemins#g"
}

pourTrouverApache()
{
	# À ne pas utiliser. Le PATH ne doit pas écraser celui donné par prerequis.
	export PATH=$INSTALLS/sbin:$INSTALLS/bin:$PATH
}

libpng14()
{
	# Voir http://bugs.php.net/bug.php?id=50734
	pge "`libpng-config --version`" 1.4 && patch -p0 <<TERMINE
--- ext/gd/libgd/gd_png.c.bad     2010-01-12 16:16:18.000000000 -0600
+++ ext/gd/libgd/gd_png.c 2010-01-12 16:16:55.000000000 -0600
@@ -145,7 +145,7 @@
		return NULL;
	}
 
-	if (!png_check_sig (sig, 8)) { /* bad signature */
+	if (png_sig_cmp (sig, 0, 8)) { /* bad signature */
		return NULL;
	}
	
TERMINE
}

detectionIconvOuLibiconv()
{
	# En outre (PHP 8.0.3) le -liconv est un peu indispensable à la fin (https://bugs.php.net/80585).
	export LDFLAGS="$LDFLAGS -liconv"
	
	# Encore nécessaire en 7.
	for i in libiconv iconv
	do
		echo "char $i();int main(int argc, char ** argv) { $i(); return 0; }" > "$TMP/$$/testiconv.c"
		cc $CFLAGS $LDFLAGS -o "$TMP/$$/testiconv" "$TMP/$$/testiconv.c" 2> /dev/null && filtrer ext/iconv/iconv.c sed -e "s/define iconv .*/define iconv $i/" -e '/#undef iconv/a\
#define iconv '"$i"'
' && break || continue
	done
	# Et on dézingue le test foireux qui se contente de voir si on a une glibc pour en conclure rapidement qu'on utilise celui d'icelle.
	filtrer configure sed -e 's/iconv_impl_name="glibc"/true/g'
}

# apxs d'Apache 2.2.3 tel qu'installé sur une de mes bécanes me fournit un
# chemin incomplet (juste /usr/lib; apparemment ça lui a suffi pour compiler).
# On force donc notre $INSTALLS/lib à passer devant.
mesBibliosDAbord()
{
	filtrer configure sed -e "s#MH_BUNDLE_FLAGS=\"#MH_BUNDLE_FLAGS=\"-L$INSTALLS/lib #"
}

tcpinfo()
{
	filtrer sapi/fpm/fpm/fpm_sockets.c sed -e '/include.*tcp.h/{
i\
#define __tcpi_sacked tcpi_sacked
i\
#define __tcpi_unacked tcpi_unacked
}'
}

# Variables


# Version officielle des paquets "virtuels" créés pour donner aux versions + CVE un numéro à part.
v_archive="$version"
case "$version" in
	5.6.40.1) v_archive="5.6.40" ;;
	5.4.45.1) v_archive="5.4.45" ;;
esac
archive="http://de.php.net/distributions/$logiciel-$v_archive.tar.bz2"
archive="http://de2.php.net/distributions/$logiciel-$v_archive.tar.bz2"
pge $v_archive 8.0.14 || archive="http://museum.php.net/php`echo $v_archive | cut -d . -f 1`/php-$v_archive.tar.bz2"

if false
then
	cd $TMP/$logiciel-$version
	echo "BASH EST À VOUS"
	bash
else

# Les options qui ne sont exploitées que plus tard doivent être au moins consommées, pour les marquer comme vraiment exploitées. Car destiner() va les inclure dans le chemin final: il refusera de mettre des options qui ne servent à rien.
option apc || true
option xdebug || true

if option test
then
	modifs="$modifs modetest"
	modetest()
	{
		CFLAGS="`echo "$CFLAGS" | sed -e 's/-O3//g'` -g"
		CXXFLAGS="`echo "$CXXFLAGS" | sed -e 's/-O3//g'` -g"
	}
fi

pousserPersonnalisations()
{
	local dest0="$1" dest="$2"
	
	# Copie.
	sudoku -d "`dirname "$dest"`" sh -c "mkdir -p \"$dest\" && cp -R \"$dest0/.\" \"$dest/.\""
}

personnaliserInstallPhp()
{
	local dest0=$TMP/$$/dest
	rm -Rf "$dest0" && mkdir -p "$dest0/lib"
	
	# Le fichier modifié par les greffons devient notre nouvelle référence, écrasant l'ancienne.
	cp "$dest/lib/php.ini" "$dest0/lib/php.ini.original"
	iperso "$dest0"
	
	pousserPersonnalisations "$dest0" "$dest"
}

guili_localiser="$guili_localiser personnaliserInstallPhp"

versionDev=
case "$versionComplete" in
	*.git) versionDev=oui ;;
esac
if [ -n "$install_obtenu" -a -d "$install_obtenu/.git" ]
then
	versionDev=oui
fi

[ -z "$versionDev" ] || prerequis="bison \\ $prerequis"

prerequisOpenssl

destiner

prerequis

case "$version" in
	*-*)
	version_cvs="`echo "$version" | sed -e 's/.*[.]//'`"
	obtenirEtAllerDansCvs -d "$version_cvs" cvs://cvsread:phpfi@cvs.php.net:/repository:php-src
	./buildconf
		;;
	*)
		obtenirEtAllerDansVersion
[ ! -d .git ] || ./buildconf
		;;
esac

echo Correction… >&2
for modif in true $modifs ; do $modif ; done

echo Configuration… >&2
versionApache=
commande apxs && "`apxs -q SBINDIR`/`apxs -q TARGET`" -v | grep version | grep -q 'Apache/2' && versionApache=2 || true
[ -z "$versionApache" ] || OPTIONS_CONF="$OPTIONS_CONF --with-apxs$versionApache"
OPTIONS_CONF="$OPTIONS_CONF --enable-fpm"
[ -z "$version_icu" ] || OPTIONS_CONF="$OPTIONS_CONF --enable-intl" || true
pge $version 5.6 && OPTIONS_CONF="$OPTIONS_CONF --enable-phpdbg" || true
commande mysql && OPTIONS_CONF="$OPTIONS_CONF --with-mysql --with-pdo-mysql" || true
plus OPTIONS_CONF `if pge $version 7.4.0 ; then printf "%s" --with-freetype ; else printf "%s" --with-freetype-dir="$destfreetype" ; fi`
plus OPTIONS_CONF --enable-calendar
[ -z "$version_sqlite" ] || plus OPTIONS_CONF --with-sqlite3="$destsqlite" --with-pdo-sqlite="$destsqlite"
# gettext: pour Horde
# ssl: pour Horde IMP
# En manuel:
true || \
{
	#autoreconf -i -W all
	#autoupdate
	autoconf
	export PKG_CONFIG_PATH="$HOME/local/libdata/pkgconfig:$HOME/local/lib/pkgconfig" CPPFLAGS="-I$HOME/local/include" LDFLAGS="-L$HOME/local/lib"
	./configure --with-pdo-pgsql=$HOME/local --with-libxml=$HOME/local --with-iconv=$HOME/local
	# Faire sauter le if unable to infer tagged configuration et son contenu
	# Modifier aussi ext/pdo_pgsql/tests/common.phpt ext/pdo_pgsql/tests/config.inc (user=gui password=)
	make -j4 && TEST_PHP_EXECUTABLE=`pwd`/sapi/cli/php ./sapi/cli/php run-tests.php ext/pdo_pgsql/tests
}
# --with-jpeg-dir est nécessaire, même si les CPPFLAGS et LDFLAGS ont tout ce qu'il faut: libjpeg n'est pas détecté par compil d'un programme de test comme libpng.
# --enable-fileinfo=shared pour éviter de pénaliser de 7 Mo de mémoire chaque lancement de PHP, pour une fonction quasi inutilisée (et cf. https://bugs.php.net/bug.php?id=65106 2023-01-23 05:15 UTC); cf. https://bugs.php.net/bug.php?id=73046
./configure --prefix="$dest" \
	--with-zlib \
	--with-iconv \
	--enable-exif \
	`pge $version 8 && printf %s --enable || printf %s --with`-gd \
	--with-jpeg-dir \
	--with-ncurses \
	--with-readline \
	--with-curl \
	--enable-fileinfo=shared \
	--enable-sqlite-utf8 \
	--enable-shared \
	--enable-mbstring \
	--enable-soap \
	--enable-sysvsem \
	--enable-sysvshm \
	--with-gettext \
	--with-openssl \
	--with-zip \
	--enable-sockets \
	$OPTIONS_CONF

fi

echo Compilation… >&2
make -j 4

if option test ; then echo "[33mCompilation disponible dans `pwd`[0m" >&2 ; TMP=/tmp/toto ; mkdir -p $TMP ; cd $TMP ; exit 0 ; fi

echo Installation… >&2
sudo make install
phpini()
{
	cat <<TERMINE
; Pour charger les JPEG de 50 Mpixels, il faut bien ça (collages de deux photos).
memory_limit = 256M
; Durée de session: 3 jours (pour le Fournil, qui propose de retenir la session).
session.gc_maxlifetime = 259200
upload_max_filesize = 256M;
post_max_size = 256M
TERMINE
	pge $version 8 || echo "mbstring.internal_encoding = UTF-8"
	if pge $version 7 ; then true
	elif pge $version 5.6 ; then echo "always_populate_raw_post_data = -1"
	else echo "always_populate_raw_post_data = 0"
	fi
	
	echo
	
	cat <<TERMINE
error_reporting = -1
log_errors = On
display_errors = Off
date.timezone = Europe/Paris
magic_quotes_gpc = 0
TERMINE
	
	# Du fait de --enable-fileinfo=shared
	echo "extension = fileinfo"
	
if pge $version 5.5 ; then
		echo 'zend_extension = "opcache.so"'
else
	echo "Il est suggéré d'installer APC ($SCRIPTS/apc)." >&2
fi
	local ccb="`curlcabundle`"
	# /!\ Forcer curl.cainfo empêche PHP d'aller lire une variable d'environnement \$CURL_CA_BUNDLE (si l'on souhaite pouvoir changer de liste d'AC comme de chemise).
	# D'un autre côté ça apporte une cohérence au système (tout le monde utilise la même liste, et si vous voulez ajouter une AC vous l'ajoutez à la liste système, ou alors vous redéfinissez votre liste d'AC au moment de l'appel, mais pas par variable d'environnement).
	[ -z "$ccb" ] || { echo "openssl.cafile = $ccb" ; echo "curl.cainfo = $ccb" ; }
}

_patronTemp()
{
	dest0="$1"
	mkdir -p "$dest0/lib" "$dest0/etc"
	
	phpini > "$dest0/lib/php.ini"

if [ -e "sapi/fpm/init.d.php-fpm.in" ] # Toutes les versions n'ont pas un fpm intégré.
	then
		sed \
			-e "s#@sbindir@#$dest/sbin#g" \
			-e "s#@sysconfdir@#$dest/etc#g" \
			-e "s#@localstatedir@#$dest/var#g" \
			-e '1{
a\
# PROVIDE: phpfpm
a\
# REQUIRE: NETWORKING
}' \
			-e '/[^e]start)/s/)/|quietstart)/' \
			< "sapi/fpm/init.d.php-fpm.in" > "$dest0/etc/init.d.php-fpm" 
		chmod u+x "$dest0/etc/init.d.php-fpm"
		sed \
			-e 's/^;pid =/pid =/' \
			-e 's/^user = .*/user = www/' \
			-e 's/^group = .*/group = www/' \
			-e 's/^pm.max_children = .*/pm.max_children = 20/' \
			< "$dest/etc/php-fpm.conf.default" > "$dest0/etc/php-fpm.conf"
fi
	
	# php.ini sera constitué ainsi:
	# 0. ponte ci-dessus
	# 1. les ajouts d'extensions faits par greffons() plus tard.
	# 2. personnalisations manuelles effectuées sur le php.ini d'une précédente version, reportées par iperso
	# On installe le résultat du 0 pour retravail par 1.
	
	pousserPersonnalisations "$dest0" "$dest"
}

_patronTempPostGreffons()
{
	local dest0="$1"
	
	# Le fichier modifié par les greffons devient notre nouvelle référence, écrasant l'ancienne.
	cp "$dest/lib/php.ini" "$dest0/lib/php.ini"
	# On le renomme en .original pour permettre à iperso d'intégrer les modifications locales.
	cp "$dest0/lib/php.ini" "$dest0/lib/php.ini.original"
	
	pousserPersonnalisations "$dest0" "$dest"
}

_patronTemp "$TMP/$$/dest"

# Xdebug doit être chargé *après* OPCache, or dans certaines configurations (PHP 5.4) notre APC est en fait un OPCache + APCu. 
# cf. https://xdebug.org/docs/install
greffon apc
greffon xdebug

_patronTempPostGreffons "$TMP/$$/dest"

sutiliser
