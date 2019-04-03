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

# Renvoie les versions pour un logiciel donnée, triées par version croissante.
versions()
{
	local GUILI_PATH="$GUILI_PATH"
	[ ! -z "$GUILI_PATH" ] || GUILI_PATH="$INSTALLS"
	
	versions_expr_version='[0-9.]+'
	[ "x$1" = x-v ] && versions_expr_version="$2" && shift && shift || true
	versions_logiciel="`echo "$1" | cut -d + -f 1`"
	versions_expr="/$versions_logiciel`options "$1" | sed -e 's#[+]#([+][^+]*)*[+]#g'`([+][^+]*)*-$versions_expr_version$"
	(
		IFS=:
		find $GUILI_PATH -maxdepth 1 \( -name "$versions_logiciel-*" -o -name "$versions_logiciel+*-*" \)
	) | egrep "$versions_expr" | filtrerVersions "$2" | triversions
}

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
	local aVirer="`echo "$*" | tr ' ' '|'`"
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

ecosysteme()
{
	[ -x "$SCRIPTS/ecosysteme" ] || cc -o "$SCRIPTS/ecosysteme" "$SCRIPTS/util.guili.ecosysteme"/*.c
	"$SCRIPTS/ecosysteme" "$@"
}

#- Gestion des paramètres ------------------------------------------------------

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
			-d) shift ; export PATH="$1/bin:$PATH" ;;
			--pour) prerequisPour="$2" ; shift ;;
			--pour=*) prerequisPour="$prerequisPour `echo "$1" | cut -d = -f 2-`" ;;
		esac
		shift
	done
	if [ ! -z "$prerequisPour" ]
	then
		prerequis=$prerequisPour prerequis
		local logicielPrerequis logicielsPrerequis="`decoupePrerequis "$prerequisPour" | cut -d ' ' -f 1 | grep -v '[()]' | cut -d + -f 1 | sort`" # Le sort en vue de générer une liste d'argOptions (tenue d'être ordonnée).
		local v_prerequis
		for logicielPrerequis in $logicielsPrerequis
		do
			eval v_prerequis=\$version_$logicielPrerequis
			argOptions="$argOptions+${logicielPrerequis}_`echo "$v_prerequis" | tr . _`"
		done
	fi
}

# Renvoie les options dans l'ordre de référence (alphabétique).
options()
{
	echo "$*" | sed -e 's/^[^+]*//' | tr + '\012' | grep -v ^$ | sort -u | sed -e 's/^/+/' | tr '\012' ' ' | sed -e 's/ $//'
}

# Ajoute une option avec pour nom celui d'un logiciel, si celui-ci est détecté dans l'environnement.
# Renvoie 0 si in fine l'option est placée, 1 sinon (penser à lui accoler un || true)
optionSi()
{
	local l="$1"
	if ! option "$l" && versions "$l" | grep -q .
	then
		argOptions="`options "$argOptions+$l"`"
	fi
	option "$l" && return 0 || virerPrerequis "$l"
	return 1
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
