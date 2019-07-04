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

# GUILI: Grosse Usine à Installs Locales Interdépendantes
# GuiLI: Guillaume's Lightweight Installers

#- Versions --------------------------------------------------------------------

# rlvo: Racine - Logiciel - Version - Options
# Découpe un chemin:
#   /usr/local/logiciel+option0+option1-version/bin/logiciel
# en:
#   /usr/local/logiciel+option0+option1-version logiciel version +option0+option1
rlvo()
{
	local truc racine eRacine
	local GUILI_PATH="$GUILI_PATH"
	[ ! -z "$GUILI_PATH" ] || GUILI_PATH="$INSTALLS"
	IFS=:
	for racine in $GUILI_PATH
	do
		unset IFS
		eRacine="/^`echo "$racine/" | sed -e 's#//*#/#g' -e 's#/#\\\\/#g'`"'\([^/+]*\)\(\(+[^/+]*\)*\)-\([0-9][.0-9]*\)\/.*/'
		for truc in "$@"
		do
			echo "$truc/" | sed -e "$eRacine!d" -e "//s##$racine/\\1\\2-\\4 \\1 \\4 \\2#"
		done
	done
	unset IFS
}

# Récupère tout ce qui ressemble à une contrainte de version dans ses paramètres.
argVersion()
{
	argVersionSauf "" "$@"
}

argVersionSauf()
{
	(
		saufApres="$1" ; shift
		IFS="`printf '\003'`"
		if [ -z "$saufApres" ]
		then
			echo "$*"
		else
			i2="`printf '\004'`"
			deseder="`echo "$saufApres" | tr ' ' '\012' | sed -e "s#^#-e${i2}s/$IFS#" -e '2,$s/^/'$i2'/' -e 's#$#'"$IFS[^$IFS]*/$IFS/g#" | tr -d '\012'`"
			echo "$IFS$*" | ( IFS="$i2" ; sed $deseder )
		fi | tr "$IFS" '\012' | sed -e 's/$/ /' | egrep '^(([>=<]+ *|[0-9]+\.)[0-9]+(\.[0-9]+)* )+$' | tr '\012' ' '
	)
}

#- Prérequis -------------------------------------------------------------------

decoupePrerequis()
{
	echo "$*" | sed -e 's#  *\([<>0-9]\)#@\1#g' | tr ' :' '\012 ' | sed -e 's#@# #g' -e '/^$/d' -e 's/\([<>=]\)/ \1/' | fusionnerPrerequis
}

# Vire des logiciels de la liste $prerequis.
# Ex.:
#   v 1.0 && prerequis="autre < 0.6" || true
#   v 2.0 && prerequis="autre < 1" || true
#   option autre || commande autre || virerPrerequis autre
#   prerequis
# Il est suggéré de fonctionner de cette façon (déclarer le maximum de prérequis, et trouilloter ensuite si telle ou telle condition n'est finalement pas remplie sur la plate-forme, ou si le logiciel n'est pas demandé par une option explicite), car ainsi pour chaque version du logiciel (fonctions v()) on peut définir dans quelle version le prérequis devra être inclus au cas où il reste en lice.
virerPrerequis()
{
	local aVirer="`echo "$*" | sed -e 's/[+]/\\\\+/g' -e 's/ /|/g'`"
	prerequis="`echo " $prerequis " | sed -E -e 's/ /  /g' -e "s# ($aVirer)([ <=>0-9.]+)* # #g"`"
}

# Fusionne les prérequis, de manière à ce que plusieurs occurrences du même prérequis n'en fassent plus qu'une.
# Ex.: ( echo "postgresql+ossl10 < 10" ; echo "postgresql >= 8" ; echo riensansrien ) | fusionnerPrerequis | tr '\012' ' ' -> postgresql+ossl10 < 10 >= 8 riensansrien
fusionnerPrerequis()
{
	# On souhaite avoir en sortie l'ordre d'apparition en entrée. Le for(tableau) n'est pas prédictible (certains awk sortent par ordre d'arrivée, d'autre par ordre alphabétique). On utilise donc un tableau d'ordre à indices numériques, prédictibles.
	awk '
BEGIN{ nPrerequis = 0; }
{
	lo=$1;
	l=lo;
	sub(/[+].*/,"",l);
	o=lo;
	sub(/^[^+]*/,"",o);
	v=$0;
	sub(/^[^ ]* */,"",v);
	if(!logiciels[l])
	{
		ordre[nPrerequis++]=l;
		logiciels[l]=1;
	}
	options[l]=options[l]""o;
	versions[l]=versions[l]" "v;
}
END{
	for(i = 0; i < nPrerequis; ++i)
	{
		l = ordre[i];
		print l""options[l]" "versions[l];
	}
}
'
}

remplacerPrerequis()
{
	local remplAwk="`for r in "$@" ; do echo "$r" ; done | sed -e 's/^[^ <=>]*/r["&"]="&/' -e 's/$/";/'`"
	prerequis="`decoupePrerequis "$prerequis" | awk 'BEGIN{ '"$remplAwk"' }{ if(r[$1]) { print r[$1]; delete r[$1]; } else print; }END{ for(p in r) print r[p]; }' | tr '\012' ' ' | sed -e 's/   */ /g' -e 's/ $//'`"
}

ecosysteme()
{
	[ -x "$SCRIPTS/ecosysteme" ] || cc -o "$SCRIPTS/ecosysteme" "$SCRIPTS/util.guili.ecosysteme"/*.c
	"$SCRIPTS/ecosysteme" "$@"
}

prerequerir()
{
	local paramLocal=
	[ "x$1" = x-l ] && paramLocal="$1" && shift || true
	local paraml="$1" ; shift
	local paramv="$*"
	
	( INSTALLS_AVEC_INFOS=1 inclure "$paraml" "$paramv" ) 6> "$TMP/$$/temp.inclureAvecInfos" || return $?
	
	# L'idéal est que l'inclusion ait reconnu INSTALLS_AVEC_INFOS et nous ait sorti ses propres variables, à la pkg-config, en appelant infosInstall() en fin (réussie) d'installation.
	# Dans le cas contraire (inclusion ancienne mode peu diserte), on recherche parmi les paquets installés celui qui répond le plus probablement à notre demande, via reglagesCompilPrerequis.
	
	local pr_logiciel= pr_version= pr_dest=
	IFS=: read pr_logiciel pr_logicielEtOptions pr_version pr_dest < "$TMP/$$/temp.inclureAvecInfos" || true
	unset IFS # Le sh sur certains Linux ne sait pas cantonner le changement de variable à l'appel de la fonction.
	[ ! -z "$pr_logiciel" ] || pr_logiciel="$paraml" # Pour les logiciels qui ne savent pas être inclusAvecInfos (qui ne renseignent pas les variables).
	
	retrouverPrerequisEtReglerChemins $paramLocal "$pr_logiciel" "$pr_version" "$pr_dest"
	
	# Pour répondre à ma question "Comment faire pour avoir en plus de stdout et stderr une stdversunsousshellderetraitement" (question qui s'est posée un moment dans l'élaboration d'inclureAvecInfos):
	# ( ( echo Un ; sleep 2 ; echo Trois >&3 ; sleep 2 ; echo Deux >&2 ; sleep 2 ; echo Trois >&3 ) 3>&1 >&4 | sed -e 's/^/== /' ) 4>&1
}

reglagesCompilPrerequis() { retrouverPrerequisEtReglerChemins "$@" ; } # Pour compatibilité.
# Affecte tous les réglages compilo pour inclure un module s'il existe déjà (on ne tente pas de compiler sa dernière version, comme le fait prerequerir()).
# Utilisation:
#   retrouverPrerequisEtReglerChemins <logiciel> [<version> [<dest>]]
# Si <dest> n'est pas fourni, il est reconstitué en essayant de trouver <logiciel> qui respecte <version> dans $INSTALLS.
retrouverPrerequisEtReglerChemins()
{
	local paramLocal=
	[ "x$1" = x-l ] && paramLocal="$1" && shift || true
	
	local pr_logiciel="$1" pr_version="$2" pr_dest="$3"
	
	# Si l'un des éléments n'est pas fourni, on recherche.
	case "|$pr_logiciel|$pr_version|$pr_dest|" in
		*"||"*) _prerequerirRetrouver "$pr_logiciel" "$pr_version" ;;
	esac
	> "$TMP/$$/temp.inclureAvecInfos"
	
	reglagesCheminsPrerequis $paramLocal "$pr_logiciel" "$pr_version" "$pr_dest"
}

_prerequerirRetrouver()
{
	dossierRequis=
	for peutEtreDossierRequis in `versions "$1"`
	do
		versionRequis="`echo "$peutEtreDossierRequis" | sed -e "s#.*-##"`"
		testerVersion "$versionRequis" $2 && pr_dest="$peutEtreDossierRequis" && pr_version="$versionRequis" || true
	done
}

exclusivementPrerequis()
{
	local GUILI_PATH="$GUILI_PATH"
	[ -n "$GUILI_PATH" ] || GUILI_PATH="$INSTALLS"
	IFS=:
	local INSTALLS=
	for INSTALLS in $GUILI_PATH
	do
		unset IFS
	uniquementPrerequis
		args_suppr -d : -e \
			PATH "$INSTALLS/bin" \
			PATH "$INSTALLS/sbin" \
			LD_LIBRARY_PATH "$INSTALLS/lib" \
			LD_LIBRARY_PATH "$INSTALLS/lib64" \
			PKG_CONFIG_PATH "$INSTALLS/lib/pkgconfig" \
			CMAKE_INCLUDE_PATH "$INSTALLS/include"
	export DYLD_LIBRARY_PATH="$LD_LIBRARY_PATH"
	export CMAKE_LIBRARY_PATH="$LD_LIBRARY_PATH"
	# On se protège aussi contre les inclusions que nos éventuels prérequis voudront nous faire ajouter. Si nous passons par le contraignant exclusivementPrerequis ça n'est pas pour laisser nos sous-paquets décider.
	exp_pkgconfig="`command -v pkg-config 2>&1 || true`"
	if [ ! -z "$exp_pkgconfig" -a "$exp_pkgconfig" != "$TMP/$$/pkg-config" ]
	then
		cat > "$TMP/$$/pkg-config" <<TERMINE
#!/bin/sh
SCRIPTS="$SCRIPTS"
. "\$SCRIPTS/util.args.sh"
$exp_pkgconfig "\$@" | stdin_suppr "-L$INSTALLS/lib" "-L$INSTALLS/lib64"
TERMINE
		chmod a+x "$TMP/$$/pkg-config"
	fi
	done
	unset IFS
}

# Si l'on ne veut pas inclure d'office tout $INSTALLS (CPPFLAGS, LDFLAGS), on peut appeler cette chose. Devrait en fait être fait par défaut (pour que les logiciels ne se lient qu'aux prérequis explicites), mais trop de logiciels reposent sur ce $INSTALLS; on est donc en mode "liste rouge", les logiciels souhaitant se distancier de ce comportement devant appeler uniquementPrerequis.
# Ex.: openssl, dans sa compil, ajoute -L. à la fin de ses paramètres de lien (après ceux qu'on lui a passés dans $LDFLAGS). Résultat, pour le lien de libssl.so, qui fait un -lcrypto, si LDFLAGS contient -L/usr/local/lib, il trouvera la libcrypto d'une version plus ancienne déjà installée dans /usr/local/lib, plutôt que celle qu'il vient de compiler dans .
# ATTENTION: ne plus utiliser, préférer exclusivementPrerequis (qui gère aussi le PATH et autres joyeusetés).
# NOTE: avantages / inconvénients
# Avantages: lorsque la même version d'un prérequis est recompilée avec des options différentes (ex.: libtiff+jpeg8 / libtiff+jpegturbo, ou postgresql+ossl10 / postgresql+ossl11), les deux vont créer leurs liens symboliques au même endroit dans $INSTALLS, donc notre logiciel risque de pointer sur l'un au lieu de l'autre (par exemple un php sans exclusivementPrerequis va se compiler sur un postgresql+ossl10, donc sera liée indirectement à openssl 1.0.x, mais le jour où on installe postgresql+ossl11, $INSTALLS/lib/libpq.so sera remplacée et notre php pétera, lié à openssl 1.0.x et à libpq lui-même lié à openssl 1.1.x); exclusivementPrerequis permet de faire pointer le logiciel vers les biblios obtenues par prerequis, donc avec leur version codée en dur (dans notre exemple: il utilisera $INSTALLS/postgresql+ossl10/lib/libpq.so).
# Inconvénient: les chemins étant codés en dur, on ne peut monter en version de façon transparente un des prérequis du logiciel sans le recompiler.
uniquementPrerequis()
{
	args_suppr -e \
		CFLAGS "-I$INSTALLS/include" \
		CXXFLAGS "-I$INSTALLS/include" \
		CPPFLAGS "-I$INSTALLS/include" \
		LDFLAGS "-L$INSTALLS/lib" \
		LDFLAGS "-L$INSTALLS/lib64"
}

#- Gestion des paramètres ------------------------------------------------------

# Interprète parmi les paramètres ceux standardisés GuiLI.
analyserParametresInstall()
{
	argOptions=
	while [ $# -gt 0 ]
	do
		case "$1" in
			--force) GUILI_INSTALLER_VIEILLE=oui ;;
			--src) shift ; install_obtenu="$1" ;;
			--dest) shift ; install_dest="$1" ;;
			+) export INSTALLS_MAX=1 ;;
			+[a-z]*) argOptions="$argOptions$1" ;;
			--sans-*) argOptions="$argOptions-`echo "$1" | cut -d - -f 4-`" ;;
		esac
		shift
	done
	argOptions="`options "$argOptions" | tr -d ' '`"
	argOptionsDemandees="$argOptions+"
}

# Recherche les paramètres de type -d <dossier GuiLI> ou --pour "<logiciel GuiLI> <options de version GuiLI>" et:
# - les ajoute à $prerequis
# - invoque ces prérequis
# - ajoute à $argOptions de quoi "marquer" que le logiciel courant aura été compilé pour telle version du prérequis
# Ex.:
#   ./xdebug --pour "php < 7"
# cherchera (ou installera à défaut) un PHP < 7, et mettra dans argOptions quelque chose comme:
#   argOptions="+php_5_6_40"
analyserParametresPour()
{
	prerequisPour=
	while [ $# -gt 0 ]
	do
		case "$1" in
			--pour|-d) _nouveauPour "$2" ; shift ;;
			--pour=*) _nouveauPour "`echo "$1" | cut -d = -f 2-`" ;;
		esac
		shift
	done
	
	prerequisPour="`decoupePrerequis "$prerequisPour"`" # decoupePrerequis dédoublonne et combine, par exemple si on a deux directives --pour "php >= 7" --pour "php+postgresql"
	if [ ! -z "$prerequisPour" ]
	then
		prerequis="$prerequisPour" prerequis
		local logicielPrerequis logicielsPrerequis="`decoupePrerequis "$prerequisPour" | cut -d ' ' -f 1 | grep -v '[()]' | cut -d + -f 1 | sort`" # Le sort en vue de générer une liste d'argOptions (tenue d'être ordonnée).
		local v_prerequis
		for logicielPrerequis in $logicielsPrerequis
		do
			eval v_prerequis=\$version_$logicielPrerequis
			argOptions="$argOptions+${logicielPrerequis}_`echo "$v_prerequis" | tr . _`"
		done
	fi
}

_nouveauPour()
{
	local p
	case "$1" in
		# Si c'est chez nous, on en fait un prérequis.
		"$INSTALLS/"*)
			p="`basename "$1" | sed -e 's/-\([0-9]\)/ \1/'`"
			;;
		# Un chemin pas chez nous: on l'ajoute juste au $PATH, histoire que le binaire soit détecté par l'éventuel configure qui suivra, mais c'est moche.
		/*)
			export PATH="$1/bin:$PATH"
			return
			;;
		# Tout le reste est un prérequis déjà sous la bonne forme.
		*)
			p="$1"
			;;
	esac
	
	prerequisPour="$prerequisPour $p"
}

# À invoquer juste avant sutiliser, pour installer (si demandé par option) un greffon.
greffon()
{
	sudoku touch "$dest/.complet" # Le greffon repose sans doute sur la complétude de notre installation; simulons le résultat post-sutiliser.
	! option "$1" || ( cd "$SCRIPTS" ; "$SCRIPTS/$1" --pour "$dest" ) || ( sudoku rm "$dest/.complet" ; false )
}

#- Environnement ---------------------------------------------------------------

# Modifie l'environnement si un truc est dans une arbo GuiLI.
# Note: ne le fait que s'il se trouve dans un dossier dédié $INSTALLS/logiciel-version/bin/binaire, pas s'il est à la "racine" $INSTALLS/bin/binaire; on considère en effet que l'environnement a déjà été modifié dans ce cas.
# Utilisation: reglagesCompilSiGuili <binaire>|<chemin>
reglagesCompilSiGuili()
{
	local binaire="`command -v $1 2> /dev/null || echo "$1"`"
	local rlvo="`rlvo "$binaire"`"
	if [ ! -z "$rlvo" ]
	then
		_reglagesCompil() { reglagesCompil "$2" "$3" "$1" ; }
		_reglagesCompil $rlvo
	fi
}

#- Installation ----------------------------------------------------------------

# Surchargeable par les logiciels pour une petite passe après compil ou installation d'un paquet binaire.
# Appelée après déploiement réussi; permet en particulier de personnaliser pour usage local: recopie d'extensions non embarquées dans la version officielle, etc.
guili_localiser=
guili_localiser()
{
	# Si dans une guili_localiser on appelle sutiliser - (ex.: après avoir installé dans $destextensionpython, on recopie celle-ci dans $INSTALLS/touteslesextensionspython et on sutilise - ce dernier), il ne faut pas que ce sutiliser réappelle récursivement notre guili_localiser.
	[ -z "$guili_localiserEnCours" ] || return 0
	guili_localiserEnCours=1
	local f
	for f in $guili_localiser true
	do
		"$f"
	done
	guili_localiserEnCours=
}

# Définit, ou liste, des fichiers-témoin dans la ou les arbos cible.
# Le principe du fichier-témoin est d'être installé à la racine d'un dossier dans lequel le logiciel installe des bidules: ainsi si le dossier est supprimé (et les installations avec), le fichier-témoin est censé disparaître.
# Utilisations:
#   guili_temoins # Sans paramètre, liste les témoins définis pour l'install en cours.
#   guili_temoins <racine normale> <racine secondaire>:<racine secondaire>
#   guili_temoins <racine normale> :<racine réelle>
# Paramètres:
#   <racine normale>
#     Racine principale du logiciel (sa racine d'installation).
#   <racine secondaire>
#     Racine dans laquelle le logiciel installe aussi des choses. Si le témoin de la racine principale ou d'une des racines secondaires disparaît, il faut tout réinstaller.
#   <racine réelle>
#     Le logiciel ne fait qu'installer des trucs dans <racine réelle>. Le <racine normale> qui lui était réservé ne sera même pas utilisé (donc le seul fichier-témoin qui importera sera celui dans <racine réelle>).
guili_temoins=
guili_temoins()
{
	if [ $# -gt 0 ]
	then
		# Définition.
		IFS=: _def_guili_temoins "$@"
		unset IFS # Le sh sur certains Linux ne sait pas cantonner le changement de variable à l'appel de la fonction.
	else
		# Consultation.
		(
			[ -z "$guili_temoins" ] && _def_guili_temoins "$dest" || true
			echo "$guili_temoins" | tr : ' '
		)
	fi
}

_def_guili_temoins()
{
	local moi="`basename "$1"`"
	guili_temoins="$1/.complet"
	shift
	local param
	for param in "$@"
	do
		for bout in $param # Repose sur l'appel de guili_temoins avec un IFS de défini.
		do
			if [ -z "$bout" ] # Bout vide -> réinitialisation (le prochain remplacera ce qui a été défini jusque-là).
			then
				guili_temoins=
			else
				[ -z "$guili_temoins" ] || guili_temoins="$guili_temoins:"
				guili_temoins="$guili_temoins$bout/.complet.$moi"
			fi
		done
	done
}

guili_temoinsPresents()
{
	local temoin
	for temoin in `guili_temoins`
	do
		[ -e "$temoin" ] || return 1
	done
}
