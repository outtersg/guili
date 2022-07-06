# Copyright (c) 2019,2022 Guillaume Outters
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

versionCompiloChemin()
{
	case "$1" in
		clang) clang --version | sed -e '1!d' -e 's/^\(.* \)*clang version //' -e 's/ .*//' ;;
		gcc) gcc --version | sed -e '1!d' -e 's/^gcc ([^)]*) //' -e 's/ .*//' ;;
	esac
}

# S'assure d'avoir un compilo bien comme il faut d'installé.
# Utilisation: compiloSysVersion [+] (<compilo> [<version>])+
#   +
#     Si précisé, on va chercher non seulement dans $GUILI_PATH/*/bin avant
#     $PATH.
#     Notons que dans la majorité des cas, le compilo le plus récent installé
#     dans un $GUILI_PATH/*/bin, possède un lien symbolique dans le $PATH/bin:
#     en ce cas il est inutile de préciser le +.
#     Cependant il peut arriver que le lien symbolique du $PATH pointe vers une
#     version antérieure (ex.: une qui corresponde à celle du compilo livré
#     initialement avec le système). En ce cas le + ira chercher les déjà
#     installés masqués.
#   <compilo> [<version>]
#     <compilo>: clang, gcc
#     Si plusieurs compilos sont précisés, sera choisi le plus adapté à l'OS
#     (gcc sous Linux, clang sous FreeBSD, Darwin).
#     <version>: peut être précisé pour ajouter une contrainte de version, ex.:
#     clang >= 7.
compiloSysVersion()
{
	local installer=non
	[ "x$1" = x-i ] && installer=oui && shift || true
	local systeme
	local bienVoulu
	local bienTente
	local bienVoulus
	local versionVoulue
	local chercherTousInstalles=non
	
	[ "x$1" = "x+" ] && shift && chercherTousInstalles=oui || true
	
	# Quels compilos nos paramètres connaissent-ils?
	bienVoulus="`
		for bienTente in "$@"
		do
			echo "$bienTente"
		done | sed -e 's/[ >=].*//' -e 's/^/^/' -e 's/$/$/' | tr '\012' '|' | sed -e 's/|$//'
	`"
	
	# Parmi ceux-ci, quel est celui qui arrive en première position des connus de notre OS?
	systeme="`uname`"
	bienVoulu="`
		case "$systeme" in
			Linux) echo gcc ; echo clang ;;
			*) echo clang ; echo gcc ;;
		esac | egrep "$bienVoulus" | head -1
	`"
	
	versionVoulue="`
		for bienTente in "$@"
		do
			case "$bienTente" in
				$bienVoulu" "*|$bienVoulu) echo "$bienTente" | ( read trucVoulu versionVoulue ; echo "$versionVoulue" ) ; break ;;
			esac
		done
	`"
	
	# Concentrons-nous sur celui-ci.
	
	local binaire="`_compiloBinaire "$bienVoulu"`"
	if [ -z "$binaire" ]
	then
		if [ $installer = oui ]
		then
			prerequerir "$bienVoulu" "$versionVoulue"
			compiloSysVersion "$@" # Sans le -i.
		else
		echo "# Attention, vous n'avez aucun compilateur d'installé. La suite des opérations risque d'être compliquée." >&2
		fi
	else
		# Si un compilo avait déjà été configuré:
		# - soit c'était le même, alors on peut sortir de suite.
		# - soit c'en était un autre, alors il faut faire le ménage avant de nous installer (ex.: la première passe, automatique, aurait affecté le compilo système clang, puis le logiciel aurait décidé de basculer vers du gcc).
		if compiloSysDejaConfigure "$binaire"
		then
			return 0
		fi
		
		case "$bienVoulu" in
			gcc) enrobeurCompilos gcc g++ ;;
		esac
		
		# Ce binaire a-t-il été installé par GuiLI? En ce cas il n'est certainement pas dans un dossier système, donc il faudra aussi aller chercher tout son environnement (lib, include, etc.).
		local gpp="$guili_ppath" ; guili_ppath= # Préparatifs à s'inscrire en queue plutôt qu'en tête.
		bibliosCompiloSys "$binaire"
		reglagesCompilSiGuili "$binaire"
		COMPILO_AJOUTS="guili_ppath$compilo_sep<:$guili_ppath$compilo_sep$COMPILO_AJOUTS" # À FAIRE: toutes les autres guili_…path modifiées par reglagesCompilSiGuili; ou alors, comme noté quelque part, faire en sorte que reglagesCompilSiGuili ne les définisse pas toutes mais qu'elles soient toutes déduites de $guili_ppath une fois cette dernière stabilisée.
		guili_ppath="$gpp<:$guili_ppath"
	fi
	
	varsCc "$bienVoulu"
	
	# En général le compilo vient avec sa libc++.
	
	compilo_cheminLibcxx
}
# Sur les systèmes ne souhaitant pas de compilation (binaires uniquement), on s'efforce d'aller chercher le moins de compilateurs possible.
[ -z "$GUILI_SANS_COMPIL" ] || compiloSysVersion() { true ; }

compiloSysDejaConfigure()
{
	if [ -n "$COMPILO_SYS" ]
	then
		[ "$COMPILO_SYS" != "$1" ] || return 0
		
		# Un compilo avait déjà été configuré, mais on change. On fait donc le ménage.
		# Les variables écrasées, on s'en fiche. Par contre là où il y a du boulot, c'est sur les variables cumulatives.
		
		# À FAIRE: ceci ne devrait plus être utile, puisque désormais nous ne modifions l'environnement qu'une seule fois, quand ont été déterminés les réglages définitifs.
		tifs _compilo_purgerEnv --sep "$compilo_sep" "$COMPILO_AJOUTS"
		
		# Et on prépare le terrain pour inscrire les modifications que *ce* compilo va effectuer (des fois qu'on rerechange de compilo une troisième fois).
		
		COMPILO_AJOUTS=
	fi
	
	COMPILO_SYS="$binaire"
	
	return 1
}

bibliosCompiloSys()
{
	case "$binaire" in
		*clang*)
			# Si c'est un clang GuiLI, il est peut-être trop moderne pour le ld système. On se cherche donc un lieur plus récent:
			# 1. binutils plus récent
			# 2. gold
			# 3. lld (https://wiki.freebsd.org/LLD)
			# COPIE: lieur() dans llvm
			if [ -n "`rlvo "$binaire"`" ]
			then
				local lieur="`versions -1 binutils`"
				[ -z "$lieur" ] || reglagesCompilSiGuili "$lieur"
			fi
			;;
	esac
}

_compilo_ajouterEnv()
{
	while [ $# -gt 0 ]
	do
		eval "export $1=\"\$$1 \$2\""
		shift ; shift
	done
}

_compilo_purgerEnv()
{
	local var val extraction
	while [ $# -gt 0 ]
	do
		var="$1" ; shift
		extraction="$1" ; shift
		eval 'val="$'$var'"'
		val="`echo "$val" | sed -e "s!$extraction!!"`" # s sans g, car pour un truc ajouté, on en retire un, pas tous.
		eval $var='"$val"'
	done
}

compilo_cheminLibcxx()
{
	local cheminBienVoulu suffixes suffixe
	
	eval "cheminBienVoulu=\$dest$bienVoulu"
	
	[ -d "$cheminBienVoulu" ] || return 0
	
	case "$bienVoulu" in
		clang) suffixes="include/c++/v1" ;;
		*) return 0 ;;
	esac
	
	for suffixe in $suffixes
	do
		[ -d "$cheminBienVoulu/$suffixe" ] || continue
		
		case "$bienVoulu" in
			clang) compilo_cheminLibcxxClang "$cheminBienVoulu/$suffixe" ;;
		esac
		
		return 0
	done
}

compilo_cheminLibcxxClang()
{
	local ajout="-cxx-isystem $cheminBienVoulu/$suffixe -cxx-isystem /usr/include"
	modifs="$modifs _compilo_cheminLibcxxClang"
	# Pour la compilation d'un compilo différent de nous, d'une, la libc++ ne doit pas être passée qu'à la passe 0 (compilation de la première itération du compilo compilé par notre compilo local), le compilo résultant ne devant pas reposer sur la libc++ d'un "adversaire"; de deux pour la passer il ne faut pas reposer sur des variables génériques telles que CXXFLAGS, qui vont être transmises à toutes les étapes, mais une variable dont l'usage sera explicitement limité à la compilation initiale. On prend CXX, en supposant qu'aux étapes suivantes il sera surchargé par le g++ intermédiaire.
	case "$logiciel" in
		gcc)
			COMPILO_AJOUTS="CXX$compilo_sep $ajout$compilo_sep$COMPILO_AJOUTS"
			return 0
			;;
	esac
	
	COMPILO_AJOUTS="CXXFLAGS$compilo_sep$ajout $compilo_sep$COMPILO_AJOUTS"
}

_compilo_cheminLibcxxClang()
{
	tifs _compilo_ajouterEnv --sep "$compilo_sep" "$COMPILO_AJOUTS"
}

_tmpBinEnTeteDePath()
{
	export PATH="$TMP/$$:$PATH"
}

enrobeurCompilos()
{
	# GCC a besoin de libgmp, libmpfr et libmpc à l'exécution.
	# Certains GuiLI purgent des $PATH et $LD_LIBRARY_PATH tout dossier "générique" (ex.: /usr/local/lib) après avoir extrait le dossier spécifique au compilo (ex.: /usr/local/gcc-x.y.z/lib). Problème: notre nouveau $LD_LIBRARY_PATH, avec chemin spécifique, permettra bien à gcc d'atteindre sa libgcc.so, mais pas la libmpfr.so, installée dans un autre dossier spécifique.
	# Première possibilité: demander au binaire gcc, au moment où on a encore un $LD_LIBRARY_PATH complet, à quelles libmpfr.so etc. il se lie, et les copier à côté du gcc pour constituer un dossier autosuffisant. Mais bon, ça nous demande pas mal d'introspection.
	# Seconde solution: le gcc tournera exceptionnellement avec le chemin "générique".
	# Ajoutons donc au $LD_LIBRARY_PATH sous lequel tournera gcc, le dossier contenant lesdites bibliothèques indispensables, pour être sûrs que notre gcc se lancera. Mais plutôt que de polluer le $LD_LIBRARY_PATH global (lu par les configure par exemple; on irait à l'encontre de la purge effectuée par l'appelant!), on va se créer un enrobeur de gcc qui ne modifiera que celui qui sert à invoquer gcc.
	# Attention cependant: idéalement on ne lui inclura que les chemins vers les biblios dédiées (gmp, mpc, mpfr). On aura toujours la possibilité, en dernier recours, d'ajouter $GUILI_PATH, mais celui-ci est un fourre-tout, et l'on risque des incohérences, à compiler avec un LD_LIBRARY_PATH=$GUILI_PATH/lib gcc -Lxxx. Ainsi le configure de curl, appelant LD_LIBRARY_PATH=~/local/lib gcc -L~/local/openssl-1.0.x/lib, peut-il exploser en trouvant par exemple dans ~/local/lib une libssh liée à OpenSSL 1.1, mais une libssl 1.0 dans le -L.
	
	local GUILI_PATH="$GUILI_PATH"
	[ ! -z "$GUILI_PATH" ] || GUILI_PATH="$INSTALLS"
	
	# Où aller chercher nos bibliothèques?
	
	local llp_compilo='$LD_LIBRARY_PATH'
	local llpt
	local p
	for p in "$@"
	do
		llpt=
		case "$p" in
			gcc|g++) llpt="`_bibliosGcc`" ;;
		esac
		llp_compilo="$llpt$llp_compilo"
	done
	llp_compilo="`args_reduc -d : "$llp_compilo" | sed -e 's/::*/:/g' -e 's/^://' -e 's/:*$/:/'`"
	llp_compilo="`
		IFS=:
		for chemin in $llp_compilo
		do
			case "$chemin" in
				"") true ;;
				'$LD_LIBRARY_PATH') printf '%s:' "$chemin" ;;
				*)
					for l in lib64 lib
					do
						[ -d "$chemin/$l" ] && printf '%s:' "$chemin/$l" || true
					done
					;;
			esac
		done | sed -e 's/::*$//'
	`"
	
	# Création du détournement.
	
	for outil in "$@"
	do
		sed < "$SCRIPTS/util.filtreargs.sh" > "$TMP/$$/$outil" -e '/^faire$/i\
export LD_LIBRARY_PATH='"$llp_compilo"'
'
		chmod a+x "$TMP/$$/$outil"
	done
	
	# On s'assure que notre dossier de surcharges passe avant celui du compilo, mis en tête de liste dans compiloSysVersion (qui normalement nous appelle).
	# Le PATH recevant les prérequis (dont éventuellement le compilo) dans prerequis(), qui sont définis après nous donc dont les dossiers apparaîtront avant le nôtre dans le LD_LIBRARY_PATH, nous nous inscrivons dans la variable réservée au fonctionnement interne des GuiLI, pour précisément passer devant tout le monde.
	
	guili__xpath="$TMP/$$:$guili__xpath"
}

_bibliosGcc()
{
	local biblios="gmp mpc mpfr gettext"
	local biblio
	local eBiblios="`printf "$biblios" | tr ' ' '|'`"
	local chemin=
	
	for biblio in $biblios ; do local bb_$biblio= ; done
	eval "`LC_ALL=C gcc -v 2>&1 | grep '^Configured with:' | tr ' ' '\012' | egrep "^--with-($eBiblios)=/" | sed -e 's/^--with-/bb_/'`"
	eval "chemin=\"`printf '%s' " $biblios:" | sed -e 's/ /:$bb_/g'`\""
	
	local outils="`LC_ALL=C gcc -v 2>&1 | grep ^COLLECT_LTO_WRAPPER= | cut -d = -f 2-`"
	local outil
	if [ -x "$outils" ]
	then
		# Si on déniche les outils internes à GCC, on va pouvoir trouver à quelles bibliothèques ils sont liés.
		
		outils="`dirname "$outils"`"
		mkdir -p "$TMP/$$/libgcc/lib"
		( export LD_LIBRARY_PATH="$chemin$LD_LIBRARY_PATH" ; biblios "$outils"/* 2> /dev/null || true ) | sort -u | egrep -v '^/(lib|lib64|usr/lib|usr/lib64)/' | while read biblio
		do
			cp -H "$biblio" "$TMP/$$/libgcc/lib/"
		done
		echo "$TMP/$$/libgcc:"
	else
		# Sinon on prend ce qui a été trouvé comme adjonctions de configuration de GCC. Ça ne nous donne que les dossiers, c'est déjà ça.
		echo "$chemin"
	fi
}

_compiloBinaire()
{
	if [ $chercherTousInstalles = oui ]
	then
		local r=0 # $? vaudra 0 pour aucun tour de boucle.
		versions "$bienVoulu" "$versionVoulue" | tail -1 | while read chemin
		do
			echo "$chemin/bin/$bienVoulu"
			# Le return suivant nous fait sortir du sous-shell, pas de la fonction. On lui donne donc une valeur repérable par la fonction pour qu'elle la transforme en retour.
			return 42
		done || r=$?
		[ $r -eq 42 -o $r -eq 0 ] || return $r
		[ $r -eq 0 ] || return 0
	fi
	
	if [ $MODERNITE -ge 4 ]
	then
		_affCompiloSiConvientConfine
	else
		_affCompiloSiConvient
	fi
}

_affCompiloSiConvientConfine()
{
	# Les versions modernes ont tendance à épurer au maximum l'environnement;
	# le compilo, lui, a droit au traitement de faveur de pouvoir chercher dans le chemin *d'origine* ($PATH contenant $INSTALLS même lorsqu'exclusivementPrerequis est passé par là),
	# et avant cela dans les chemins définis par de précédentes passes (genre un compiloSysVersion "tous azimuths" qui aurait trouvé un petit compilo de derrière les fagots: la nouvelle passe qu'on effectue doit essayer cette précédente trouvaille, qui s'il passe le test répondra aux contraintes précédentes + celles en cours de test).
	(
		# À FAIRE: si on codait en dur le chemin de cc et cxx directement dans $CC et $CXX, on ne s'enquiquinerait pas avec ces histoires de PATH.
		# À FAIRE: de toute façon notre truc est un gros mic-mac, avec compiloSysVersion appelé une fois avec fouille d'$INSTALLS, une fois sans (mais espérant pouvoir reprendre le compilo calculé avec), etc. Rationnaliser, avec des prérequis normalisés "langc() langcxx(17) langpy() etc.", et qu'on n'invoque le calcul de compilo qu'une fois par langage, avec des variables COMPILO_xx_AJOUTS calculées séparément (mais s'intégrant ensuite dans le PATH, à voir dans quel ordre).
		#          N.B.: si aucun lang*(), langc() implicite pour compatibilité avec l'actuel. Mais avec la possibilité d'un lang() pour signifier aucun langage (ex.: truc à déployer sans compil).
		guili_ppath=
		PATH="$GUILI_PATHEXT"
		tifs _compilo_ajouterEnv --sep "$compilo_sep" "$COMPILO_AJOUTS"
		export PATH="`echo "$guili_ppath:" | sed -e 's/^[^<]*//' -e 's/<:*//' -e 's#:#/bin:#'`$PATH"
		compilo_tester _affCompiloSiConvient | tee /dev/tty || true
	)
}

_affCompiloSiConvient()
{
	# La version actuellement dans notre $PATH répond-elle au besoin?
	if commande "$bienVoulu" && testerVersion "`versionCompiloChemin "$bienVoulu"`" $versionVoulue
	then
		command -v "$bienVoulu"
	fi
}

varsCc()
{
	case "$1" in
		clang) export CC=clang CXX=clang++ ;;
		gcc) export CC=gcc CXX=g++ ;;
		*) export CC=cc CXX=c++ ;;
	esac
}

langc()
{
	# À FAIRE:
	# - classer les compilos disponibles par date de publication. Pour ce faire, établir une correspondance version -> date (la date donnée par certains compilos est celle de leur compilation, pas de leur publication initiale).
	# - pouvoir privilégier un compilo en lui ajoutant virtuellement un certain nombre d'années d'avance sur les autres.
	# - pouvoir spécifier un --systeme pour se cantonner au compilo livré avec le système (par exemple pour compiler une extension noyau, ou avoir accès aux saloperies de spécificités de Frameworks sous Mac OS X).
	
	case "$*" in
		"") compiloSysVersion + clang gcc ;;
		*) compiloSysVersion "$@" ;;
	esac
	
	case `uname` in
		Darwin)
			# Sur Mac, un clang "mimine" doit pour pouvoir appeler le ld système comme le ferait le compilo système, définir MACOSX_DEPLOYMENT_TARGET (sans quoi le ld est perdu, du type il n'arrive pas à se lier à une hypothétique libcrt.o.dylib).
			envCompiloMac
			;;
	esac
}

# Pour compatibilité.
meilleurCompilo() { langc ; }
meilleurCompiloInstalle() { meilleurCompilo "$@" ; }

langcxx()
{
	# À FAIRE: pour le moment on s'ajoute encore à COMPILO_AJOUTS (au lieu d'un COMPILO_cxx_AJOUTS).
	case "$1" in
		""|11|14|17) cxx$1 + ;; # Avec un + car en $MODERNITE 5, nous sommes appelés en direct, et non plus en second choix après une passe en + qui elle aura eu le loisir de fouiller tous les compilos disponibles.
		*) fatal "# Je ne sais pas gérer langcxx($*)" ;;
	esac
}

cxx17()
{
	compiloSysVersion -i "$@" "clang >= 5" "gcc >= 7"
	libcxx
}

cpp14() { cxx14 "$@" ; }
cxx14()
{
	compiloSysVersion -i "$@" "clang >= 3.5" "gcc >= 5" # clang 3.4 supporte, mais en -std=c++1y.
	libcxx
}

cpp11() { cxx11 "$@" ; }
cxx11()
{
	compiloSysVersion -i "$@" "clang >= 3.3" "gcc >= 4.8.1"
	libcxx
}

cxx()
{
	# On repose sur le compiloSysVersion appelé en standard.
	libcxx
}

libcxx()
{
	# Si le compilo choisi est un compilo non système, en matière de biblios lib(std)c++ il se liera à celles livrées avec le compilo en question.
	# Il nous faut donc ajouter comme prérequis d'exécution, peut-être pas tout le compilo, mais au moins la biblio correspondante.
	case "$CXX" in
		g++|*/g++) libcxxgcc ;;
	esac
}

libcxxgcc()
{
	local libcxx d v
	
	# Recherche de la libstdc++ qui va être utilisée.
	# À FAIRE: chercher en sollicitant peut-être plus g++. Là on est sur de la recherche statique, pas forcément fiable (on repose sur le fait que le $LD_LIBRARY_PATH actuellement défini sera celui utilisé en -L lors de la compilation). Par contre on a l'avantage de fonctionner même si g++ n'est pas installé.
	
	IFS=:
	for d in $LD_LIBRARY_PATH /dev/null
	do
		libcxx="$d/libstdc++.so"
		if [ -e "$libcxx" ]
		then
			libcxx="`lilien "$libcxx"`"
			[ -f "$libcxx" ] && break || true
		fi
	done
	unset IFS
	
	# La bibliothèque vient-elle bien d'une install GuiLI?
	
	[ -n "`rlvo "$libcxx"`" ] || return 0
	
	# Recherche de la version GuiLI de libcxx correspondante.
	# Pour libstdcxx, c'est le suffixe quand il a trois parties; mais les versions embarquées par gcc (en tout cas pour GCC 7 ont un simple .6 :-(
	
	v="`bn "$libcxx"`"
	_point123()
	{
		unset IFS
		local param
		[ "$1.$2.$6" = "libstdc++.so." ] || return 1
		for param in "$3" "$4" "$5"
		do
			case "$param" in
				*[^0-9]*|"") return 1 ;;
			esac
		done
		echo "$3.$4.$5"
	}
	v="`IFS=. ; _point123 $v || true`"
	
	if [ -n "$v" ]
	then
	prerequerir libstdcxx $v # Va installer libstdcxx, et modifier l'environnement ($guili_ppath): ainsi lorsque le logiciel sera installé, il aura pour dépendance libstdcxx.
	else
		# À défaut (libstdc++ embarquée dans gcc), on prérequiert ce dernier.
		prerequerir `rlvo "$libcxx" | { read r l v o ; echo $l$o $v ; }`
	fi
}

#- Spécificités ----------------------------------------------------------------

# Un mini-configure qui fait une configuration d'environnement puis lance des tests.
# Utilisation: compilo_tester <environnementeur> <test>...
compilo_tester()
{
	# Un sous-shell pour isoler.
	(
		# On lance la méthode (qui cherche des trucs et modifie l'environnement).
		$1 || exit 1
		shift
		# Quelques modifications d'environnement demandées par la détection de compilo.
		for m in true $modifs
		do
			case "$m" in _compilo_*) $m ;; esac
		done
		# Et on teste!
		for test in "$@"
		do
			$test || exit 1
		done
	)
}

compilo_test_cc()
{
	# Le minimum viable: une biblio classique.
	# COPIE: util.multiarch.sh
	{ echo '#include <stdio.h>' ; echo 'int main(int argc, char ** argv) { fprintf(stdout, "oui\\n"); return 0; }' ; } > $TMP/$$/1.c
	$CC $CPPFLAGS $CFLAGS $LDFLAGS -o $TMP/$$/a.out $TMP/$$/1.c 2> /dev/null && [ oui = "`$TMP/$$/a.out`" ] || return 1
}

compilo_test_cxx()
{
	# Le minimum viable: une biblio classique.
	{ echo '#include <iostream>' ; echo 'int main(int argc, char ** argv) { std::cout << "oui\\n"; return 0; }' ; } > $TMP/$$/1.cxx
	$CXX $CPPFLAGS $CXXFLAGS $LDFLAGS -o $TMP/$$/a.out $TMP/$$/1.cxx 2> /dev/null && [ oui = "`$TMP/$$/a.out`" ] || return 1
}

#--- GCC ---

pasfortiche()
{
	local vsys="`uname -r | cut -d - -f 1`"
	local vcomp
	case `uname` in
		Linux)
			pg 3 "$vsys" || return 0
			case "$CC" in
				gcc*)
					vcomp="`versionCompiloChemin gcc`"
					pge "$vcomp" 6 || return 0
					;;
				*) return 0 ;;
			esac
			;;
		*) return 0 ;;
	esac
	
	local f
	local fichiers="configure"
	
	# FORTIFY_SOURCE=2 nous plante sur certaines plates-formes (ex.: Linux 2.6.18 avec gcc 7.5.0):
	# le read est remplacé par une version qui fait du:
	# __always_inline read() { if(__read_chk()) asm("read"); }
	# Manque de pot l'__always_inline n'est pas forcément bien interprété, et donc les .o se retrouvent truffés de redéfinitions de read(),
	# dont on peut certes éliminer un inconvénient (multiple definition) via un export LDFLAGS="$LDFLAGS -Wl,--allow-multiple-definition"
	# … mais qui sont tout de même vues par l'assembleur comme du read, et donc read s'appelle lui-même en une joyeuse boucle infinie!
	# (vu sur une compil' d'OpenSSH)
	
	for f in $fichiers
	do
		[ -f "$f" ] || continue
		filtrer "$f" sed -e '/=/s/-D_FORTIFY_SOURCE=2//g'
	done
}

#--- Mac ---

envCompiloMac()
{
	# Problème: sur certaines plates-formes, se cantonner à un SDK est une perte,
	# car le SDK limite au système actuel, tandis que les biblios système savent revenir loin en arrière.
	# Ex.: Bonemine est en 10.14.1, alors qu'il supporte jusqu'au 10.6.
	# En particulier il refuse de compiler en i386 alors qu'il peut (si on le laisse se lier à /usr/lib plutôt qu'à $SDKROOT/usr/lib).
	# https://lists.freedesktop.org/archives/gstreamer-commits/2016-October/096588.html
	# https://reviews.llvm.org/D109460
	# https://discourse.cmake.org/t/how-to-determine-which-architectures-are-available-apple-m1/2401/8
	# D'un autre côté, sur certaines machines on peut avoir compilé un clang à part, plus récent que celui système, mais incapable de gérer la partie C++;
	# en ce cas revenir au SDK est plus sûr.
	
	# À FAIRE: exporter, et récupérer de l'env: un openssl peut réutiliser celui calculé par le php qui l'a appelé.
	# /!\ Dépendant des tests lancés.
	
	local methode test
	local tests=compilo_test_cc
	# /!\ Du fait du scrutin sur $prerequis, envCompiloMac doit n'être appelé qu'après définition de celui-ci (MODERNITE >= 3).
	case " $prerequis" in *" "cpp[\(1-9]*|*" "cxx[\(1-9]*|*" langcxx"*) tests="$tests compilo_test_cxx" ;; esac
	
	for methode in compilo_mac_sdk_min compilo_mac_sdk_xcrun
	do
		compilo_tester $methode $tests || continue
		$methode
		break
	done
}

compilo_mac_sdk_min()
{
	compilo_sdk_min=

	# À FAIRE: parcourir plusieurs SDK, jusqu'à trouver le min qui puisse compiler pour le présent système.
	for f in /System/Library/SDKSettingsPlist/SDKSettings.plist /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/SDKSettings.plist
	do
		if [ -e "$f" ]
		then
			# On peut aussi chercher MACOSX_DEPLOYMENT_TARGET, mais ça revient à xcrun --show-sdk-version.
			# On est plus intéressés par la version min, qui nous permet de compiler des trucs pour de vieux systèmes (on n'est pas trop intéressés par la modernité).
			compilo_sdk_min="`moniquesML "$f" | sed -e '/^.*MinimumDeploymentTarget.*"\([^"]*\)"[^"]*$/!d' -e 's//\1/'`"
			break
		fi
	done
	
	[ -n "$compilo_sdk_min" ] || return 1
	
	gris "Compilation Mac avec MACOSX_DEPLOYMENT_TARGET=$compilo_sdk_min" >&2
	modifs="$modifs _compilo_mac_sdk_min"
}

_compilo_mac_sdk_min()
{
	export MACOSX_DEPLOYMENT_TARGET="$compilo_sdk_min"
}

compilo_mac_sdk_xcrun()
{
	compilo_sdk_root="`xcrun --show-sdk-path`"
	gris "Compilation Mac avec SDKROOT=$compilo_sdk_root" >&2
	modifs="$modifs _compilo_mac_sdk_xcrun"
}

_compilo_mac_sdk_xcrun()
{
	# À FAIRE: utiliser SDKROOT pour d'autres variables.
	export SDKROOT="$compilo_sdk_root"
	export CPPFLAGS="$CPPFLAGS -I$SDKROOT/usr/include"
	export MACOSX_DEPLOYMENT_TARGET="`xcrun --show-sdk-version`"
}

# Mon XML, parce que le format .plist XML est pourri de chez pourri.
# Bon ça s'apparente plus à du JSON.
# Mettons que c'est le Monique's Markup Language (ou Monique s'aime, elle).
moniquesML()
{
	cp "$1" "$TMP/$$/1.plist"
	commande plutil && plutil -convert xml1 "$TMP/$$/1.plist" || true
	sed -E < "$TMP/$$/1.plist" \
		-e 's#<key>([^<">]*)</key>#\1:#g' \
		-e 's#<string>([^<">]*)</string>#"\1",#g' \
		-e 's#<dict>#{#g' \
		-e 's#</dict>#},#g' \
		-e 's#<array>#[#g' \
		-e 's#</array>#],#g' \
		-e 's#<array/>#[],#g' \
	| awk \
'
# Pond ce qui avait été mémorisé tel quel (sur constat qu on n arrivera pas à pondre tassé).
function abandon() { if(cle) { print cle; cle = ""; } if(n) for(i = 0; ++i <= n;) print tab[i]; delete tab; n = 0; }
# Pond ce qui a été mémorisé tassé.
function tasse() {
	if(cle)
	{
		c = cle;
		cle = "";
	}
	if(n)
		for(i = 0; ++i <= n;)
		{
			bout = tab[i];
			if(c) # Indentation supprimée, sauf pour le premier bloc.
				sub(/^[ 	]*/, " ", bout);
			sub(/[ 	]*$/, "", bout);
			c = c""bout;
		}
	delete tab;
	n = 0;
	sub(/, \]/, " ]", c);
	print c;
}
BEGIN{ n = 0; }
/:$/{ if(cle) abandon(); cle = $0; next; }
/\[\]/{ if(n) abandon(); tasse(); next; }
/\[$/{ if(n) abandon(); tab[++n] = $0; next; }
/^[ 	]*\]/{ if(n) { tab[++n] = $0; tasse(); } else print; next; }
# Les chaînes trop longues restent sur une ligne à part, si elles font partie d un tableau.
/^[ 	]*".{24,}/{ abandon(); print; next; }
/^[ 	]*"[^"]*",?$/{ if(n || cle) tab[++n] = $0; if(cle && n == 1) tasse(); next; }
{ abandon(); print; }
'
}

#- Initialisation --------------------------------------------------------------

compilo_sep="`printf '\003'`"
