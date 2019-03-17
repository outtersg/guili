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
