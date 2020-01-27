# Copyright (c) 2019 Guillaume Outters
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
		gcc) gcc --version | sed -e '1!d' -e 's/^gcc (GCC) //' -e 's/ .*//' ;;
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
		reglagesCompilSiGuili "$binaire"
		COMPILO_AJOUTS="guili_ppath$compilo_sep<:$guili_ppath$compilo_sep$COMPILO_AJOUTS" # À FAIRE: toutes les autres guili_…path modifiées par reglagesCompilSiGuili; ou alors, comme noté quelque part, faire en sorte que reglagesCompilSiGuili ne les définisse pas toutes mais qu'elles soient toutes déduites de $guili_ppath une fois cette dernière stabilisée.
		guili_ppath="$gpp<:$guili_ppath"
	fi
	
	varsCc "$bienVoulu"
	
	# En général le compilo vient avec sa libc++.
	
	compilo_cheminLibcxx
}

compiloSysDejaConfigure()
{
	if [ -n "$COMPILO_SYS" ]
	then
		[ "$COMPILO_SYS" != "$1" ] || return 0
		
		# Un compilo avait déjà été configuré, mais on change. On fait donc le ménage.
		# Les variables écrasées, on s'en fiche. Par contre là où il y a du boulot, c'est sur les variables cumulatives.
		
		tifs _compilo_purgerEnv --sep "$compilo_sep" "$COMPILO_AJOUTS"
		
		# Et on prépare le terrain pour inscrire les modifications que *ce* compilo va effectuer (des fois qu'on rerechange de compilo une troisième fois).
		
		COMPILO_AJOUTS=
	fi
	
	COMPILO_SYS="$binaire"
	
	return 1
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
	local ajout="-cxx-isystem $cheminBienVoulu/$suffixe"
	# Pour la compilation d'un compilo différent de nous, d'une, la libc++ ne doit pas être passée qu'à la passe 0 (compilation de la première itération du compilo compilé par notre compilo local), le compilo résultant ne devant pas reposer sur la libc++ d'un "adversaire"; de deux pour la passer il ne faut pas reposer sur des variables génériques telles que CXXFLAGS, qui vont être transmises à toutes les étapes, mais une variable dont l'usage sera explicitement limité à la compilation initiale. On prend CXX, en supposant qu'aux étapes suivantes il sera surchargé par le g++ intermédiaire.
	case "$logiciel" in
		gcc)
			export CXX="$CXX $ajout"
			COMPILO_AJOUTS="CXX$compilo_sep $ajout$compilo_sep$COMPILO_AJOUTS"
			return 0
			;;
	esac
	
	export 	CXXFLAGS="$ajout $CXXFLAGS"
	COMPILO_AJOUTS="CXXFLAGS$compilo_sep$ajout $compilo_sep$COMPILO_AJOUTS"
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

meilleurCompilo()
{
	# À FAIRE:
	# - classer les compilos disponibles par date de publication. Pour ce faire, établir une correspondance version -> date (la date donnée par certains compilos est celle de leur compilation, pas de leur publication initiale).
	# - pouvoir privilégier un compilo en lui ajoutant virtuellement un certain nombre d'années d'avance sur les autres.
	# - pouvoir spécifier un --systeme pour se cantonner au compilo livré avec le système (par exemple pour compiler une extension noyau, ou avoir accès aux saloperies de spécificités de Frameworks sous Mac OS X).
	
	compiloSysVersion + clang gcc
	
	case `uname` in
		Darwin)
			# Sur Mac, un clang "mimine" doit pour pouvoir appeler le ld système comme le ferait le compilo système, définir MACOSX_DEPLOYMENT_TARGET (sans quoi le ld est perdu, du type il n'arrive pas à se lier à une hypothétique libcrt.o.dylib).
			for f in /System/Library/SDKSettingsPlist/SDKSettings.plist /Library/Developer//CommandLineTools/SDKs/MacOSX.sdk/SDKSettings.plist
			do
				if [ -e "$f" ]
				then
					cp "$f" "$TMP/$$/1.plist"
					plutil -convert xml1 "$TMP/$$/1.plist"
					plutil -convert xml1 "$TMP/$$/1.plist"
					export MACOSX_DEPLOYMENT_TARGET="`tr -d '\012' < "$TMP/$$/1.plist" | sed -e 's#.*>MACOSX_DEPLOYMENT_TARGET</key>[ 	]*<string>##' -e 's#<.*##'`"
					break
				fi
			done
			;;
	esac
}

# Pour compatibilité.
meilleurCompiloInstalle() { meilleurCompilo "$@" ; }

cxx17()
{
	compiloSysVersion -i "clang >= 5" "gcc >= 7"
	libcxx
}

cpp14()
{
	compiloSysVersion -i "clang >= 3.5" "gcc >= 5" # clang 3.4 supporte, mais en -std=c++1y.
	libcxx
}

cpp11()
{
	compiloSysVersion -i "clang >= 3.3" "gcc >= 4.8.1"
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
			libcxx="`readlinky "$libcxx"`"
			[ -f "$libcxx" ] && break || true
		fi
	done
	unset IFS
	
	# La bibliothèque vient-elle bien d'une install GuiLI?
	
	[ -n "`rlvo "$libcxx"`" ] || return 0
	
	# Recherche de la version GuiLI de libcxx correspondante.
	# Pour libstdcxx, c'est le suffixe.
	
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
	IFS=.
	v="`IFS=. ; _point123 $v || true`"
	[ -n "$v" ] || return 0
	unset IFS
	
	prerequerir libstdcxx $v # Va installer libstdcxx, et modifier l'environnement ($guili_ppath): ainsi lorsque le logiciel sera installé, il aura pour dépendance libstdcxx.
}

compilo_sep="`printf '\003'`"
