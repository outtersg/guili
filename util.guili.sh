# Copyright (c) 2003-2005,2008,2011-2020 Guillaume Outters
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

COMPLET=".complet"
ENCOURS=".encours"

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
	argVersionSauf "$argsAppli" "$@"
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
		fi | tr "$IFS" '\012' | sed -e 's/$/ /' -e 's/\([<=>]\)\([0-9]\)/\1 \2/g' | egrep '^(([>=<]+ *|[0-9]+\.)[0-9]+(\.[0-9]+)* )+$' | tr '\012' ' '
	)
}

#- Prérequis -------------------------------------------------------------------

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

remplacerPrerequis()
{
	local remplAwk="`for r in "$@" ; do echo "$r" ; done | sed -e 's/^[^ <=>]*/r["&"]="&/' -e 's/$/";/'`"
	prerequis="`decoupePrerequis "$prerequis" | awk 'BEGIN{ '"$remplAwk"' }{ if(r[$1]) { print r[$1]; delete r[$1]; } else print; }END{ for(p in r) print r[p]; }' | tr '\012' ' ' | sed -e 's/   */ /g' -e 's/ $//'`"
}

ecosysteme()
{
	local CC="$CC"
	[ -n "$CC" ] || CC=cc
	[ -x "$SCRIPTS/ecosysteme" ] || $CC -o "$SCRIPTS/ecosysteme" "$SCRIPTS/util.guili.ecosysteme"/*.c
	"$SCRIPTS/ecosysteme" "$@"
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
	
	local pr_dest="$1"
	
	# Si le chemin complet n'est pas fourni, on recherche.
	case "$pr_dest" in
		/*) true ;;
		*)
			pr_dest="`versions "$pr_dest" | tail -1`"
			[ -n "$pr_dest" ] || err "# Impossible de trouver ni installer $1"
			;;
	esac
	> "$TMP/$$/temp.inclureAvecInfos"
	
	reglagesCheminsGuiliChemin $paramLocal "$pr_dest"
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
			PKG_CONFIG_PATH "$INSTALLS/lib64/pkgconfig" \
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
r="$TMP/temp.\$\$.pkgconffiltre"
> "\$r"
( $exp_pkgconfig "\$@" || echo \$? > "\$r" ) | stdin_suppr "-L$INSTALLS/lib" "-L$INSTALLS/lib64"
r="\`cat "\$r" ; rm "\$r"\`"
[ -z "\$r" ] || exit "\$r"
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
# Note pour les amorceurs (trucs qui lancent un logiciel sous-jacent (LSJ) en tant que service système, ex.: l'amorceur _nginx lance le binaire nginx):
# Si le LSJ est reconnu dans les paramètres, tout ce qui suit est considéré non comme paramètres de l'amorceur mais agrégé comme paramètres du LSJ. Ainsi, dans ./_phpfpm -u www php +postgresql, le -u www est-il paramètre de _phpfpm et le +postgresql de php.
# Rien n'empêche ceci dit les amorceurs de transmettre leurs paramètres "manuellement" à leur LSJ (ce qui permet l'écriture simplifiée ./_phpfpm -u www +postgresql; charge alors à l'amorceur de faire le tri entre ses paramètres et de transmettre au LSJ ceux qui lui sont destinées).
# Dans les deux cas, si l'amorceur souhaite indiquer pour quel LSJ il est configuré (options, version), il ne doit pas reposer sur ses propres options mais refléter celles du LSJ (qui peut avoir été trouvé avec plus d'options, par exemple).
analyserParametresInstall()
{
	guili_sep="`printf '\003'`"
	
	case "$logiciel" in
		_*) [ -n "$lsj" ] || lsj="`echo "$logiciel" | cut -c 2-`" ;; # Par convention, _nginx a pour logiciel sous-jacent nginx.
	esac
	
	local l
	if [ -n "$lsj" ]
	then
		for l in $lsj
		do
			eval "lsj_dest_$lsj= ; guili_params_$lsj="
		done
	fi
	
	guili_params_=
	argOptions=
	while [ $# -gt 0 ]
	do
		if [ -n "$lsj" ]
		then
			case " $lsj " in
				*" $1 "*)
					analyserParametresInstallLsj "$@"
					break
					;;
			esac
		fi
		case "$1" in
			--force) GUILI_INSTALLER_VIEILLE=oui ;;
			--src) shift ; install_obtenu="$1" ;;
			--alias) shift ; guili_alias="$guili_alias:$1" ;;
			--dest) shift ; install_dest="$1" ;;
			+) export INSTALLS_MAX=1 ;;
			-) INSTALLS_MIN=1 ;; # en ce cas on vérifie juste la présence d'un nous-mêmes répondant aux paramètres, sans chercher à installer la dernière version.
			+-[a-z]*) argOptions="$argOptions`echo "$1" | cut -d + -f 2-`" ;;
			+[a-z]*) argOptions="$argOptions$1" ;;
			--sans-*) argOptions="$argOptions-`echo "$1" | cut -d - -f 4-`" ;;
			# Le reste peut être cumulé dans $guili_params_: par exemple pour vérification ultérieure que n'a pas été mentionné de paramètre non reconnu.
			*)
				# À FAIRE: argVersion devrait aussi être expurgé d'ici.
				# Certains paramètres applicatifs ont un complément susceptible d'être interprété spécialement; on permet à l'appli de nous préciser lesquels doivent "englober" le paramètre suivant (ex.: dans `-u -`, le - ne doit pas être interprété comme $INSTALLS_MIN, mais faire corps avec le -u pour signifier "l'utilisateur courant").
				if [ -n "$argsAppli" -a -n "$1" ] # Le "$1" parce qu'historiquement les méthodes de découpe des prérequis peuvent nous faire appeler avec un premier paramètre vide.
				then
					case " $argsAppli " in
						*" $1 "*) analyserParametresInstallLsj "" "$1" "$2" ; shift ; shift ; continue ;;
					esac
				fi
				analyserParametresInstallLsj "" "$1" ;;
		esac
		shift
	done
	argOptions="`options "$argOptions" | tr -d ' '`"
	argOptionsOriginal="$argOptions"
	argOptionsDemandees="$argOptions+"
}

analyserParametresInstallLsj()
{
	local lsjcourant="$1" ; shift
	while [ $# -gt 0 ]
	do
		# Cas particulier de variable qui bave: le premier alias de notre premier LSJ peut déterminer le suffixe à donner à notre propre alias implicite.
		# De manière générale (valable pour les autres LSJ aussi), nous lancerons un LSJ depuis son alias générique s'il existe.
		
		case "$1" in
			--alias)
				# $dest<lsj> que nous devrons utiliser? On ne s'installe pas tout de suite sur cette variable, car elle sera écrasée par prerequis(); on met donc de côté dans lsj_dest_<lsj>.
				local varDest="lsj_dest_$lsjcourant"
				eval '[ -n "$'$varDest'" ] || '$varDest'="$INSTALLS/$2"'
				# Suffixe reportable sur nous-mêmes?
				if [ -z "$guili_alias" ]
				then
					case "$2" in
						"$lsjcourant"*) guili_alias="$logiciel`echo "$2" | sed -e "s#^$lsjcourant##"`" ;; # On récupère le suffixe de l'alias de notre LSJ, que l'on accole à notre $logiciel pour obtenir l'alias (ex.: `./_nginx nginx --alias nginxSysteme` s'installera sous _nginxSysteme).
					esac
				fi
				;;
		esac
		
		# Cumul des paramètres destiné à notre $lsjcourant.
		
		eval guili_params_$lsjcourant='"$guili_params_'$lsjcourant'$1$guili_sep"'
		
		# Suivant!
		
		shift
	done
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
		local logicielPrerequis logicielsPrerequis="`decoupePrerequis "$prerequisPour" | cut -d ' ' -f 1 | grep -v '[()]' | cut -d + -f 1 | tr -d - | sort`" # Le sort en vue de générer une liste d'argOptions (tenue d'être ordonnée).
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
	local p chemin
	case "$1" in
		# Si c'est chez nous, on en fait un prérequis.
		"$INSTALLS/"*)
			chemin="$p"
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
			chemin="`versions -1 -f "$p"`"
			;;
	esac
	
	prerequisPour="$prerequisPour $p"
	[ -z "$chemin" ] || GUILI_TEMOINS_ENCOURS="$GUILI_TEMOINS_ENCOURS:$chemin"
}

# Peut être appelé dans l'analyserParametresInstall d'un amorceur pour reporter sur son premier LSJ (ex.: nginx pour l'amorceur _nginx) les options et contraintes de version passées à l'amorceur.
apiReporterParamsLsj()
{
	# Si pas de LSJ, pas d'objet.
	[ -n "$lsj" ] || return 0
	
	local o l var
	
	for l in $lsj ; do break ; done
	
	# Si le LSJ dispose explicitement de ses options propres, pas de report (ex./ `./_nginx +optionAmorceur nginx +optionLSJ ">= 1.15"`).
	eval '[ -z "$guili_params_'$l'" ]' || return 0
	
	# On marque les options comme prises en compte pour ne pas péter au moment de la vérification.
	IFS=+ ; for o in $argOptions ; do [ -n "$o" ] || continue ; option $o ; done ; unset IFS
	
	# Dans nos prérequis, des contraintes s'ajoutent.
	prerequis="$prerequis $l$argOptions $argVersion"
	
	# Et on passe nos options à notre LSJ.
	var=guili_params_$l
	[ -z "$argOptions" ] || eval $var'="$'$var'$argOptions$guili_sep"'
	[ -z "$argVersion" ] || eval $var'="$'$var'$argVersion$guili_sep"'
}

# À invoquer juste avant sutiliser, pour installer (si demandé par option) un greffon.
greffon()
{
	preutiliser
	! option "$1" || ( cd "$SCRIPTS" ; "$SCRIPTS/$1" --pour "$dest" ) || ( sudoku rm "$dest/$ENCOURS" ; false )
}

#- Environnement ---------------------------------------------------------------

reglagesCheminsGuili()
{
	reglagesCheminsPrerequis "$@"
}

# Modifie l'environnement si un truc est dans une arbo GuiLI.
# Note: ne le fait que s'il se trouve dans un dossier dédié $INSTALLS/logiciel-version/bin/binaire, pas s'il est à la "racine" $INSTALLS/bin/binaire; on considère en effet que l'environnement a déjà été modifié dans ce cas.
# Utilisation: reglagesCompilSiGuili <binaire>|<chemin>
reglagesCompilSiGuili()
{
	local binaire="$1"
	case "$binaire" in
		/*) true ;;
		*) binaire="`command -v $1 2> /dev/null || echo "$1"`" ;;
	esac
	local rlvo="`rlvo "$binaire"`"
	if [ ! -z "$rlvo" ]
	then
		_reglagesCompil() { reglagesCheminsGuiliChemin "$1" ; }
		_reglagesCompil $rlvo
	fi
}

reglagesCheminsGuiliChemin()
{
	local paramLocal=
	[ "x$1" = x-l ] && paramLocal="$1" && shift || true
	local rd="$1" rl ro rv
	
	love -e "rl ro rv" "$rd"
	reglagesCheminsGuili $paramLocal "$rl" "$rv" "$rd"
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
	guili_temoins="$1/$COMPLET"
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
				guili_temoins="$guili_temoins$bout/$COMPLET.$moi"
			fi
		done
	done
}

guili_temoinsPresents()
{
	local temoin
	for temoin in `guili_temoins`
	do
		# Cas particulier: un témoin trouvé via un lien symbolique occupant notre $dest est invalide. Ce peut être par exemple un libjpeg-x.y -> libjpegturbo-z.t, alors que nous tentons d'installer le libjpeg officiel.
		case "$temoin" in
			"$dest/$COMPLET") [ -L "$dest" ] && return 1 || true ;;
		esac
		[ -e "$temoin" ] || guili_temoinEnCoursTenantLieuDeComplet "$temoin" || return 1
	done
}

guili_temoinEnCoursTenantLieuDeComplet()
{
	# A-t-on des .encours autorisés à tenir lieu de .complet?
	[ -n "$GUILI_TEMOINS_ENCOURS" ] || return 1
	# Notre témoin est-il bien un .complet?
	local tcomplet="$1"
	case "$tcomplet" in
		*/$COMPLET) true ;;
		*) return 1 ;;
	esac
	# Quel serait le .encours correspondant?
	local dcomplet="`dn "$tcomplet"`"
	case ":$GUILI_TEMOINS_ENCOURS:" in
		*":$dcomplet:"*) true ;;
		*) return 1 ;;
	esac
	# Et existe-t-il, cet ersatz?
	[ -e "$dcomplet/$ENCOURS" -a ! -L "$dcomplet/$ENCOURS" ]
}

guili_sortirAvecInfosSiDejaInstalle()
{
	versionExistante="`versions "$logiciel+$argOptions" "$argVersion" | tail -1`"
	if [ -n "$versionExistante" ]
	then
		love -e "_poubelle argOptions argVersion" "$versionExistante"
		"$logiciel:$logiciel`argOptions`:$version:$dest"
	fi
}
