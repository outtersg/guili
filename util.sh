#!/bin/sh
# Copyright (c) 2003-2005,2008,2011-2019 Guillaume Outters
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

if [ -z "$SCRIPTS" ] || ! grep -q CEstBienCeFichierCiQuiDoitSeTrouverAuBoutDeSCRIPTS < "$SCRIPTS/util.sh"
then
	echo "# Merci de ne pas appeler util.sh directement, mais de définir \$SCRIPTS puis inclure \$SCRIPTS/util.sh." >&2
	return 1
fi

. "$SCRIPTS/util.local.sh"

[ -n "$INSTALL_MEM" ] || INSTALL_MEM="$HOME/tmp/paquets"
[ -n "$INSTALLS" ] || INSTALLS="$HOME/local" || true
[ -n "$SANSSU" ] || SANSSU=1 || true

INSTALL_SCRIPTS="$SCRIPTS" # Des fois que d'autres récupèrent ensuite la variable $SCRIPTS.

. "$SCRIPTS/util.init.sh"

util_tmp

mkdir -p "$INSTALL_MEM"

ajouterModif()
{
	modifs="$modifs $*"
}

retirerModif()
{
	for modif in "$@"
	do
		modifs="`echo " $modifs " | sed -e "s/ $modif / /g" -e 's/  */ /g' -e 's/^ //' -e 's/ $//'`"
	done
}

#- Initialisation --------------------------------------------------------------

cheminsGuili()
{
	# Mémorisation, avant de tout casser.
	
	[ -n "$GUILI_PATHEXT" ] || export GUILI_PATHEXT="$PATH"
	
	local GUILI_PATH="$GUILI_PATH"
	[ ! -z "$GUILI_PATH" ] || GUILI_PATH="$INSTALLS"
	IFS=:
# Les -I n'ont rien à faire dans les C(XX)FLAGS. Les logiciels doivent aller piocher dans CPPFLAGS, sinon c'est qu'ils sont foireux et doivent recevoir une rustine spécifique. Ajouter les -I aux CFLAGS empêche par exemple PostgreSQL de se compiler: il fait un cc $CFLAGS -I../src/include $CPPFLAGS, ce qui fait que si /usr/local/include est dans CFLAGS, et possède mettons des .h de la 9.2, ceux-ci sont inclus avant les .h de la 9.5 lors de la compilation de celui-ci.
	chemins --sans-c-cxx $GUILI_PATH
	unset IFS
	
	guili_env_PATH="`echo "$TMP/$$:$guili_env_PATH" | sed -e 's/^\.://' -e 's/:\.:/:/g' -e 's/::*/:/g'`"
	# Trop de logiciels (PHP…) se compilent par défaut sans optimisation. C'est ballot.
	guili_env_CFLAGS="-O3 $guili_env_CFLAGS"
	guili_env_CXXFLAGS="-O3 $guili_env_CXXFLAGS"
}
# Détecte le "degré de modernité" du GuiLI appelant.
# Cette détection se fonde sur la fonction par laquelle est calculé SCRIPTS.
detecterModernite()
{
	MODERNITE=0
	# 3: meilleurCompilo appelé uniquement au moment de prerequis() (l'environnement n'est pas pollué par le "premier choix" automatique de compilo si le logiciel en choisit un autre).
	if command -v Delicat > /dev/null 2>&1 ; then MODERNITE=3
	# 2: exclusivementPrerequis: le logiciel sait déclarer tous ses prérequis plutôt que de reposer sur une détection (contraignant, mais maîtrisé et reproductible).
	elif command -v DelieS > /dev/null 2>&1 ; then MODERNITE=2
	fi
}

chemins_init=cheminsGuili
detecterModernite

. "$SCRIPTS/util.args.sh"
. "$SCRIPTS/util.guili.sed.sh" # Va nous servir pour beaucoup de choses.
. "$SCRIPTS/util.util.sh"
. "$SCRIPTS/util.versions.sh"

# Remplacements de commandes (pour la phase d'amorçage).

if ! command -v curl 2> /dev/null >&2
then
	curlfetch()
	{
		local params=
		local sep="`echo | tr '\012' '\003'`"
		local param
		local sortie=
		local proxy="$ALL_PROXY"
		while [ $# -gt 0 ]
		do
			case "$1" in
				-L|-O) true ;;
				-o) params="$params$sep$1" ; sortie=oui ;;
				-k) params="$params$sep--no-verify-peer" ;;
				-s) params="$params$sep-q" ;;
				-m) params="$params$sep-T" ;;
				-x) shift ; proxy="$1" ;;
				*) params="$params$sep$1" ;;
			esac
			shift
		done
		if [ -z "$sortie" ]
		then
			params="$params$sep-o$sep-"
		fi
		params="`echo "$params" | cut -c 2-`"
		(
			IFS="$sep"
			http_proxy=$proxy affSiBinaire fetch $params
		)
	}
	curlwget()
	{
		local params=wget
		local sep="`echo | tr '\012' '\003'`"
		local param
		local sortie=
		local proxy="$ALL_PROXY"
		while [ $# -gt 0 ]
		do
			case "$1" in
				-L|-O) true ;;
				-o) params="$params$sep-O" ; sortie=oui ;;
				-k) params="$params$sep--no-check-certificate" ;;
				-s) params="$params$sep-q" ;;
				-m) params="$params$sep--timeout" ;;
				-x) shift ; proxy="$1" ;;
				*) params="$params$sep$1" ;;
			esac
			shift
		done
		params="$params$sep-t${sep}2" # Par défaut wget tente 20 fois. On a autre chose à faire que d'attendre. 2 fois parce qu'on est bons.
		if [ -z "$sortie" ]
		then
			params="$params$sep-O$sep-"
		fi
		(
			IFS="$sep"
			http_proxy=$proxy https_proxy=$proxy affSiBinaire $params
		)
	}
	curl()
	{
		local curl="`unset -f curl ; command -v curl 2> /dev/null || true`"
		if [ ! -z "$curl" ]
		then
			affSiBinaire "$curl" "$@"
		elif commande fetch
		then
			curlfetch "$@"
		elif commande wget
		then
			curlwget "$@"
		else
	[ -x "/tmp/minicurl" ] || cc -o "/tmp/minicurl" "$SCRIPTS/minicurl.c"
		"/tmp/minicurl" "$@"
		fi
	}
fi

# Pour pouvoir lancer un sh -c ou su -c dans lequel lancer des commandes d'util.sh, faire un su toto -c "$INSTALL_UTIL ; versions etc."
INSTALL_ENV_UTIL="SCRIPTS=$SCRIPTS ; . \"\$SCRIPTS/util.sh\" "

# Lance un script de fonctions util.sh en tant qu'un autre compte.
utiler()
{
	local qui="$1" ; shift
	# Redirection du stdout pour éviter la pollution des scripts type fortune si sudoku doit recourir à un su -.
	sudoku -u "$qui" sh -c "exec >&7 ; $INSTALL_ENV_UTIL ; $*" 7>&1 > /dev/null
}

if [ ! -z "$SANSU" ]
then
	utiliser() { true ; }
	sutiliser() { true ; }
fi

# sinstaller [-u <compte>] <dossier> <dest>
sinstaller()
{
	sinst_compte=
	[ "x$1" = x-u ] && shift && sinst_compte="$1" && shift || true
	sinst_source="$1"
	sinst_dest="$2"
	# Si aucun utilisateur n'est mentionné, on prend le compte courant par défaut, ou root si le courant n'a pas les droits d'écriture.
	if [ -z "$sinst_compte" ]
	then
		sinst_grandpere="`dirname "$sinst_dest"`"
		sinst_sonde="$sinst_grandpere/.sinstaller.sonde"
		if mkdir -p "$sinst_grandpere" 2> /dev/null && touch "$sinst_sonde" 2> /dev/null
		then
			sinst_compte="`id -u -n`"
		else
			sinst_compte=root
		fi
	fi
	
	if ! sudoku -u "$sinst_compte" mkdir -p "$sinst_dest" 2> /dev/null
	then
		SANSSU=0 sudo mkdir -p "$sinst_dest"
		SANSSU=0 sudo chown -R "$sinst_compte:" "$sinst_dest"
	fi
	( cd "$sinst_source" && tar cf - . ) | ( cd "$sinst_dest" && sudoku -u "$sinst_compte" tar xf - )
}

# Ajoute à une variable du contenu
# Paramètres:
# $1: Makefile
# $2: variable
# $3: ajout
etendreVarMake()
{
	filtrer "$1" awk '{print $0}/^'"$2"'=/{if(commencer == 0) commencer = 1}/[^\\]$/{if(commencer == 1) { print "'"$2"'+= '"$3"'" ; commencer = 2 }}/^$/{if(commencer == 1) { print "'"$2"'+= '"$3"'" ; commencer = 2 }}'
}

chut()
{
	"$@" > "$TMP/$$/temp" 2>&1 || cat "$TMP/$$/temp"
}

ajouterAvec()
{
	[ "$AVEC" = "" ] && AVEC=,
	AVEC="${AVEC}$1,"
}

retirerAvec()
{
	AVEC="`echo "$AVEC" | sed -e "s/,$1,/,/g"`"
}

avec()
{
	echo "$AVEC" | grep -q ",$1,"
}

# Sort le chemin d'installation de chacun des prérequis passés en paramètres.
# Appelle prerequis et ne sort que l'info de chemin. L'idée est de pouvoir l'appeler depuis un sous-shell pour connaître le chemin sans modifier tout l'environnement (LDFLAGS et compagnie), par exemple:
#   echo "Le dernier PHP avant la 7 se trouve dans `cible "php < 7"`"
cible()
{
	PREINCLUS=
	prerequis="$*" prerequis
	for preinclus in $PREINCLUS ; do echo "$preinclus" ; done | cut -d : -f 1 | while read lpreinclus
	do
		suffixe="`echo "$lpreinclus" | tr '+-' __`"
		# Mais on ne veut exporter que les $dest sous le préfixe $cible_.
		eval "echo \"\$dest$suffixe\""
	done
}

# Trouve le nom du prochain fichier disponible, en ajoutant des suffixes numériques jusqu'à en trouver un de libre.
prochain()
{
	chemin="$1"
	[ ! -e "$chemin" ] && echo "$chemin" && return
	racineChemin="`echo "$chemin" | sed -e 's#\(\.[a-z0-9A-Z]\{1,3\}\)*$##'`"
	suffixeChemin="`echo "$racineChemin" | sed -e 's#.#.#g'`"
	suffixeChemin="`echo "$chemin" | sed -e "s#^$racineChemin##"`"
	n=1
	while [ -e "$racineChemin.$n$suffixeChemin" ]
	do
		n="`expr $n + 1`"
	done
	echo "$racineChemin.$n$suffixeChemin"
}

# Obtient la version majeure (x.x) d'une version longue (x.x.x).
vmaj()
{
	echo "$1" | sed -e 's/^\([^.]*.[^.]*\).*$/\1/'
}

case "$0" in
	-*) true ;;
	*)
install_moi="$SCRIPTS/`basename "$0"`"
		logiciel="`basename "$0"`" # Par défaut, le nom du logiciel est celui de l'installeur (un peu de logique, zut!).
		;;
esac

infosInstall()
{
	local feu=rouge # Si le feu passe au vert, on peut commencer à afficher nos infos.
	local sortie=non # Si $sortie = oui, alors on finira par un bel exit 0.
	
	# -s comme "Pondre Seulement Si possible de Sortir prématurément".
	# Si non spécifié, on pond de toute manière (mais on ne sort pas).
	# Si spécifié, les conditions de sortie (et donc de ponte des infos), sortie prématurée (c'est-à-dire avant installation effective), sont:
	# - soit le logiciel trouvé est déjà installé (auquel cas continuer l'installation ne ferait rien de plus -> on sort): test de "$dest/.complet".
	# - soit on souhaite juste savoir ce qui *va* être installé (mais sans l'installer), ce qui sera déterminé dans le corps de boucle.
	# - soit on va de toute façon ne lister que ce qui est déjà installé, via versions(), donc on sortira puisqu'on demande à se cantonner à l'installé, donc à ne pas installer.
	if [ "x$1" = x-s ]
	then
		if guili_temoinsPresents
		then
			sortie=oui # Déjà installé dans la version voulue, donc on va pouvoir poursuivre.
			feu=vert
			sortieSansReinstall
		fi
	else
		feu=vert
	fi
	
	if [ ! -z "$INSTALLS_AVEC_INFOS" ] # Petit test pour éviter d'ouvrir >&6 si on n'a rien à sortir (car si ça se trouve l'appelant, n'ayant pas défini la variable, n'a pas non plus ouvert le descripteur).
	then
		for ii_var in `echo "$INSTALLS_AVEC_INFOS" | tr , ' '`
		do
			case "$ii_var" in
				-i) true ;;
				-n) feu=vert ; sortie=oui ;;
		1) echo "$logiciel:$logiciel`argOptions`:$version:$dest" ;;
		vars0) echo "dest=$dest version=$version prerequis=\"$prerequis\"" ;;
		vars) echo "dest$logiciel=$dest version_$logiciel=$version prerequis_$logiciel=\"$prerequis\"" ;;
		"") true ;;
		prerequis-r)
					varsPrerequis `echo "$INSTALLS_AVEC_INFOS" | tr , ' '` "$prerequis" | tr '\012' ' '
			echo "$prerequis"
			;;
		*)
				eval "echo \"\$$ii_var\""
			;;
			esac
		done >&6
	fi
	
	[ $feu = vert -a $sortie = oui ] && exit 0 || true
}

# Inscrit une version comme gérée; la retient comme version à compiler si elle rentre dans les critères spécifiés en paramètres du script; renvoie true si la version a compilée est supérieure ou égale à celle-ci, false sinon.
v()
{
	v="`echo "$1" | sed -e 's/@.*//'`"
	testerVersion "$v" $argVersion && version="$v" && versionComplete="$1"
	testerVersion "$v" ppe $argVersion
}

# Le localhost n'est pas toujours 127.0.0.1 (ex.: jails BSD). Si des programmes ont besoin de coder une IP en dur, mieux vaut passer par là.
localhost()
{
	ifconfig | awk '/^lo/{split($0,ti,/:/);i=ti[1]}/inet /{if(i){print $2;exit}}'
}

mac() { [ "`uname`" = Darwin ] ; }

# Utilise le compilo Apple sur Mac (ex.: libao, libdiscid, qui doivent accéder à CoreAudio et autres Frameworks auxquels seul le compilo Apple sait accéder).
ccMac()
{
	case `uname` in
		Darwin)
			CC=cc
			export CC
			;;
	esac
}

# Modifie libtool pour lui faire générer du 32 et 64 bits via les -arch propres aux gcc d'Apple.
# Ne plus utiliser, ça marche trop peu souvent (certaines parties du compilo plantent sur du multiarchi). Passer par compil3264.
libtool3264()
{
	mac || return 0
	if command -v arch >&1 2> /dev/null && arch -arch x86_64 true 2> /dev/null
	then
		CFLAGS="$CFLAGS -arch x86_64 -arch i386"
		LDFLAGS="$CFLAGS -arch x86_64 -arch i386"
		export CFLAGS LDFLAGS CXXFLAGS
		modifspostconf="$modifspostconf libtool3264bis"
	fi
}

libtool3264bis()
{
	mac || return 0
	# Toutes les étapes incluant une génération de fichiers de dépendances (-M) plantent en multi-archis. C'est d'ailleurs ce qui nous pose problème, car certaines compils combinent génération de méta ET compil proprement dite, qui elle a besoin de son -arch multiple.
	filtrer libtool sed -e '/func_show_eval_locale "/i\
command="`echo "$command" | sed -e "/ -M/s/ -arch [^ ]*//g"`"
'
}

# À ajouter en modif; après la compil dans l'archi cible, déterminera si celle-ci est une 64bits, et, si oui, lancera la recompil équivalente totale en 32bits, avant de combiner les produits via lipo.
EN_32=non
[ "x$1" = x-32 ] && EN_32=oui
compil3264()
{
	mac || return 0
	if command -v arch 2> /dev/null && arch -arch x86_64 true 2> /dev/null
	then
		if [ "$EN_32" = oui ]
		then
			CFLAGS="$CFLAGS -arch i386"
			CXXFLAGS="$CXXFLAGS -arch i386"
			LDFLAGS="$LDFLAGS -arch i386"
			export CFLAGS LDFLAGS CXXFLAGS
		else
			mkdir -p "/tmp/$$/compil32bits"
			modifspostcompil="$modifspostcompil compil3264bis"
		fi
	fi
}

compil3264bis()
{
	# À FAIRE: utiliser moire().
	mac || return 0
	icirel="`pwd | sed -e "s#$TMP/*##"`"
	tmp2="$TMP/$$/compil32bits"
	TMP="$tmp2" "$SCRIPTS/`basename "$0"`" -32
	tmp2="$tmp2/$icirel"
	find . \( -name \*.dylib -o -name \*.a -o -perm -100 \) -a -type f | xargs file | egrep ": *Mach-O|archive random library" | cut -d : -f 1 | while read f
	do
		touch -r "$f" "$TMP/$$/h"
		lipo -create "$f" "$tmp2/$f" -output "$f.univ" && cat "$f.univ" > "$f"
		touch -r "$TMP/$$/h" "$f"
	done
}

dyld105()
{
	mac || return 0
	# À FAIRE: ne rajouter ça que si on est en > 10.5.
	# http://lists.apple.com/archives/xcode-users/2005/Dec/msg00524.html
	[ -d /Developer/SDKs/MacOSX10.5.sdk ] || return 0
	MACOSXVERSIONFLAGS="-mmacosx-version-min=10.5 -isysroot /Developer/SDKs/MacOSX10.5.sdk/"
	LDFLAGS="$LDFLAGS $MACOSXVERSIONFLAGS"
	CFLAGS="$CFLAGS $MACOSXVERSIONFLAGS"
	CXXFLAGS="$CXXFLAGS $MACOSXVERSIONFLAGS"
	CPPFLAGS="$CPPFLAGS $MACOSXVERSIONFLAGS"
	export LDFLAGS CFLAGS CXXFLAGS CPPFLAGS
}

# CMake, ImageMagick, pkg-config, se lient aux Frameworks MacOS X qui cherchant une libJPEG.dylib spécifique Apple tombent sur notre libjpeg.dylib.
# N.B.: depuis que DYLD_LIBRARY_PATH a été viré de _cheminsExportes, il est possible qu'on puisse se passer de ceci.
putainDeLibJPEGDeMacOSX()
{
	[ -z "$dejaAppelePutainDeLibJPEGDeMacOSX" ] || return 0
	dejaAppelePutainDeLibJPEGDeMacOSX=1
	mac || return 0
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
			[ "x$1" = xprudemment ] || LDFLAGS="`echo "$LDFLAGS" | sed -e "s#-L$INSTALLS/lib##g"`"
			DYLD_FALLBACK_LIBRARY_PATH="$LD_LIBRARY_PATH:$DYLD_LIBRARY_PATH:$DYLD_FALLBACK_LIBRARY_PATH"
			unset LD_LIBRARY_PATH
			unset DYLD_LIBRARY_PATH
			export DYLD_FALLBACK_LIBRARY_PATH
			;;
	esac
}

# Sous Mavericks, cette foutue lib nous pollue systématiquement: gcc, ld, nm, etc., y sont liés, car ceux d'/usr/bin sont de simples lanceurs qui font un xcodebuild -find xxx (allant chercher le vrai exécutable dans le bon SDK pour la plateforme de l'ordi). On appelle donc systématiquement notre putaineDeLigJPEGDeMacOSX.
mac && putainDeLibJPEGDeMacOSX prudemment || true

ldlOptionnel()
{
	# Les BSD embarquent dlopen en standard; Linux veut du -ldl. Certains Makefiles codent en dur ce -ldl Linux.
	
	cat > /tmp/testDlopen.c <<TERMINE
void * dlopen(const char *path, int mode);
int main(int argc, char ** argv)
{
dlopen("coucou", 0);
return 0;
}
TERMINE
	cc -o /tmp/testDlopen /tmp/testDlopen.c 2> /dev/null || return 0 # Si plantage de compilation, -ldl est nécessaire, alors on le laisse dans les Makefiles.
	
	for i in "$@"
	do
		filtrer "$i" sed -e 's/-ldl//g'
	done
}

fpic()
{
	CFLAGS="$CFLAGS -fPIC"
	export CFLAGS
}

fbsd10()
{
	# Pour les couillons qui confondent freebsd10 et freebsd1.
	find . -name configure | while read i ; do
		[ ! -f "$i" ] || filtrer "$i" sed -e 's#freebsd1\*#freebsd1|freebsd1.*#g'
	done
}

macLibtool()
{
	# Sous Mac OS X, un éventuel libtool GNU compilé prend le pas sur celui d'Apple, seul à gérer des options à la con telles que -static. On place donc un alias du libtool officiel quelque part dans le PATH avant celui éventuellement compilé par nos soins.
	# Un lien symbolique ferait l'affaire, mais en écrivant un script enrobeur on se réserve la possibilité d'agir sur les paramètres si un jour quelque chose ne nous plaît pas.
	mac || return 0
	[ -e /usr/bin/libtool ] || return 0
	cat > "$TMP/$$/libtool" <<TERMINE
#!/bin/sh
/usr/bin/libtool "\$@"
TERMINE
	chmod a+x "$TMP/$$/libtool"
}

macMath()
{
	# http://clang-developers.42468.n3.nabble.com/problems-building-libcxx-td2353619.html
	mac || return 0
	cat > /tmp/1.cpp <<TERMINE
#include <cmath>
void f() { llroundl(0.0); }
TERMINE
	! c++ -c -o /tmp/1.o -D__STRICT_ANSI__ /tmp/1.cpp > /dev/null 2>&1 || return 0
	
	CPPFLAGS="$CPPFLAGS -U__STRICT_ANSI__"
	export CPPFLAGS
}

llvmStrnlen()
{
	# Les dernières versions LLVM (et donc tous ceux qui l'embarquent, type Rust) utilise strnlen qui n'est pas définie dans un Mac OS X 10.8, par exemple.
	cat > /tmp/1.cpp <<TERMINE
#include <string.h>
void toto() { strnlen("zug", 2); }
TERMINE
	! c++ -c -o /tmp/1.o /tmp/1.cpp > /dev/null 2>&1 || return 0
	
	# On est obligés de ne cibler que le minimum de fichiers, car d'autres .cpp, d'une part servent à définir le strnlen qui finira dans les biblios, d'autre part incluent des enum dont une valeur est strnlen.
	find . \( -name MachOYAML.cpp -o -name HeaderMap.cpp -o -name LLVMOutputStyle.cpp -o -name macho2yaml.cpp \) -print0 | xargs -0 grep -l strnlen | while read f
	do
		# On insère notre remplacement avant la première ligne qui ne soit pas in include, une ligne vide, ou un commentaire.
		filtrer "$f" awk 'fini{print;next}/#include/{print;next}/^ *\/\//{print;next}/^ *$/{print;next}{print "#define strnlen monstrnlen" ; print "static inline int monstrnlen(const char * c, int t) { int n; for(n = -1; ++n < t && c[n];) {} return n; }" ; print ; fini=1}'
	done
}


# Remplacement d'utilitaires.

filtreargs()
{
	(
		sed -e '/ICI/,$d' < "$SCRIPTS/util.filtreargs.sh"
		cat
		sed -e '1,/ICI/d' < "$SCRIPTS/util.filtreargs.sh"
	) > "$TMP/$$/$1"
	chmod a+x "$TMP/$$/$1"
}

# http://www.techques.com/question/1-1482450/Broken-Java-Mac-10.6
case `uname` in
	Darwin)
for i in jar javac java
do
	rm -f "$TMP/$$/$i"
	commande="`command -v $i || true`"
	cat > "$TMP/$$/$i" <<TERMINE
#!/bin/sh
export DYLD_LIBRARY_PATH=
"$commande" "\$@"
TERMINE
	chmod a+x "$TMP/$$/$i"
done
		;;
esac

runghc()
{
	# GHC est vraiment une putain d'usine à gaz plantogène. Je crois que je vais finir par abandonner Darcs à cause de GHC (impossibilité de compiler avec un simple compilo C, bibliothèques qui se mettent en vrac si on a le malheur de tenter d'installer une extension 7.6.2 sur la 7.6.3 qui l'embarquait déjà, plantages inopinés de la distrib binaire, etc.).
	# Redéfinir cette fonction dans le shell ne mettra pas à l'abri les sudo runghc Setup install, mais au moins les configure et build, non sudo, en bénéficieront.
	until /usr/local/bin/runghc "$@" || [ $? -ne 11 ]
	do
		true
	done
}

pseudocargo()
{
	ou="$TMP"
	
	if [ ! -e "$ou/get-pip.py" ]
	then
		( cd "$ou" && curl -O https://bootstrap.pypa.io/get-pip.py )
		sudo LD_LIBRARY_PATH=$LD_LIBRARY_PATH PATH=$PATH python "$ou/get-pip.py"
		sudo LD_LIBRARY_PATH=$LD_LIBRARY_PATH PATH=$PATH pip install pytoml dulwich requests # requests pour la version de krig.
	fi
	
	[ -d "$ou/index" ] || git clone https://github.com/rust-lang/crates.io-index "$ou/index"
	mkdir -p "$ou/bazar"
	
	mkdir -p "$ou/localbin"
	[ -e "$ou/localbin/gmake" ] || ln -s "`command -v make`" "$ou/localbin/gmake"
	PATH="`pwd`/localbin:$PATH"
	export PATH
	triplet=
	machine="`uname -m | sed -e 's/amd64/x86_64/g'`"
	systeme="`uname -s | tr '[A-Z]' '[a-z]'`"
	case $machine-$systeme in
		*-darwin) triplet="$machine-apple-$systeme" ;;
		*) triplet="$machine-unknown-$systeme" ;;
	esac
	#ldflagsPseudocargo
	# Mac OS X 10.9, rustc 1.16.0: si -L <lechemindesbibliosinternesrustc>, pouf, plantage instantané!
	LD_LIBRARY_PATH="`echo ":$LD_LIBRARY_PATH:" | sed -e "s#:$destrust/lib:#:#g"`" \
	"$HOME/src/projets/pseudocargo/bootstrap.py" --crate-index "$ou/index" --target-dir "$ou/bazar" --no-clone --no-clean --target "$triplet" --patchdir "$SCRIPTS/cargo.patches/" "$@"
	
	CARGODEST="$ou/bazar"
}

ldflagsPseudocargo()
{
	# À FAIRE: se greffer au build s'il y en a déjà un dans le Cargo.toml, plutôt que de l'écraser.
	
	filtrer Cargo.toml sed -e '/\[package\]/{
a\
build = "ldflags.rs"
}'
	(
		echo "fn main(){"
		for i in `printf %s "$LDFLAGS" | sed -e 's/-L  */-L/g'`
		do
			case "$i" in
				-L*)
					echo "$i" | sed -e 's/^../println!("cargo:rustc-link-search=native=/' -e 's/$/");/'
					;;
			esac
		done
		echo "}"
	) > ldflags.rs
}

# http://stackoverflow.com/a/1116890
readlinkf()
{
	(
		TARGET_FILE="$1"

		cd "`dirname $TARGET_FILE`"
		TARGET_FILE="`basename $TARGET_FILE`"

		# Iterate down a (possible) chain of symlinks
		while [ -L "$TARGET_FILE" ]
		do
			TARGET_FILE="`readlink $TARGET_FILE`"
			cd "`dirname $TARGET_FILE`"
			TARGET_FILE="`basename $TARGET_FILE`"
		done

		# Compute the canonicalized name by finding the physical path 
		# for the directory we're in and appending the target file.
		PHYS_DIR="`pwd -P`"
		RESULT="$PHYS_DIR/$TARGET_FILE"
		echo "$RESULT"
	)
}

statf()
{
	case `uname` in
		*BSD) stat -f "$@" ;;
		*) stat --format "$@" ;;
	esac
}

[ ! -e "$SCRIPTS/util.guili.sh" ] || . "$SCRIPTS/util.guili.sh"
for util_module in silo
do
	[ ! -e "$SCRIPTS/util.$util_module.sh" ] || . "$SCRIPTS/util.$util_module.sh"
done
[ ! -e "$SCRIPTS/util.compilo.sh" ] || . "$SCRIPTS/util.compilo.sh"
[ ! -e "$SCRIPTS/util.sudo.sh" ] || . "$SCRIPTS/util.sudo.sh"
[ ! -e "$SCRIPTS/util.serveur.sh" ] || . "$SCRIPTS/util.serveur.sh"
for f in "$SCRIPTS/util.guili."*".sh"
do
	[ ! -e "$f" ] || . "$f"
done
[ ! -e "$SCRIPTS/util.multiarch.sh" ] || . "$SCRIPTS/util.multiarch.sh"
[ ! -e "$SCRIPTS/util.python.sh" ] || . "$SCRIPTS/util.python.sh"

argVersion="`argVersion "$@"`"
analyserParametresInstall "$@"

prerequis= # Certains installeurs appellent prerequis(), mais sans avoir initialisé $prerequis. Résultat, ils héritent de l'environnement; pour peu que quelqu'un prérequière un de ces logiciels, ses prerequis seront donc lui-même, et nous voilà partis pour une boucle infinie…
guili__xpath=
[ $MODERNITE -ge 3 ] || meilleurCompilo
_initPrerequisLibJpeg
proxy -

initSilo

# À FAIRE: voir les effets de la mise en commentaire du truc ci-dessous sur les concernés (ex.: yamllint certbot meson)
# N.B.: de toute manière le code en question était pourri puisque pypadest utilisait $dest et $destpython, non encore définies ici. Autrement dit $dest/lib/python pointait sur le /lib/python système.
#! commande pypadest || export PYTHONPATH="`pypadest`"
