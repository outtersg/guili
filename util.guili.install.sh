#!/bin/sh
# Copyright (c) 2011,2016-2019 Guillaume Outters
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

destiner()
{
	verifierConsommationOptions
	if [ -z "$install_dest" ]
	then
		dest="`versions -v "$version" "$logiciel+$argOptions" | tail -1`"
		if [ -z "$dest" ]
		then
			dest="$INSTALLS/$logiciel`argOptions`-$version"
		fi
	else
	dest="$install_dest"
	fi
	guili_temoins "$dest" "$1"
	infosInstall -s
}

utiliserSiDerniere()
{
	local dest="$dest"
	[ -n "$1" ] || dest="$1"
	local lv="`basename "$dest"`"
	
	local logicielParam="`echo "$lv" | sed -e 's/-[0-9].*//' -e 's/+[^-]*$//'`"
	local derniere="`versions "$logicielParam" | tail -1 | sed -e 's#.*/##' -e "s/^$lv-.*/$lv/"`" # Les déclinaisons de nous-mêmes sont assimilées à notre version (ex.: logiciel-x.y.z-misedecôtécarpourrie).
	if [ ! -z "$derniere" ]
	then
		if [ "$lv" != "$derniere" -a -z "$GUILI_INSTALLER_VIEILLE" ]
		then
			echo "# Attention, $lv ne sera pas utilisé par défaut, car il existe une $derniere plus récente. Si vous voulez forcer l'utilisation par défaut, faites un $SCRIPTS/utiliser $lv" >&2
			return 0
		fi
	fi
	[ ! -d "$dest" ] || sudoku $utiliser "$dest"
}

guili_deps_crc()
{
	if commande sha1
	then
		sha1
	elif commande sha1sum
	then
		sha1sum | awk '{print$1}'
	fi
}

guili_prerequis_path()
{
	local GUILI_PATH="$GUILI_PATH"
	[ -n "$GUILI_PATH" ] || GUILI_PATH="$INSTALLS"
	local r="$guili_ppath"
	args_suppr -d : `IFS=: ; for racine in $GUILI_PATH ; do printf "r %s" "$racine" ; done`
	echo "$r"
}

# Dépose un fichier-témoin des dépendances utilisées.
guili_deps_pondre()
{
	local fpr="$dest/.guili.prerequis"
	
	# On se marque comme dépendances de nos prérequis, qu'ils sachent que s'ils se désinstallent ils nous mettent dans la mouise (histoire de leur donner mauvaise conscience).
	
	local cPrerequis="`guili_prerequis_path`"
	(
		IFS=:
		for cPrerequi in $cPrerequis
		do
			[ -e "$cPrerequi/.guili.dependances" ] && grep -q "^$dest$" < "$cPrerequi/.guili.dependances" || echo "$dest" | sudoku -d "$cPrerequi" sh -c "cat >> $cPrerequi/.guili.dependances" || true
			crc="`( cat "$cPrerequi/.guili.prerequis" 2> /dev/null || true ) | guili_deps_crc`"
			echo "$crc|$cPrerequi"
		done
	) > "$fpr.encours"
	# À FAIRE: générer aussi un .pc pour les logiciels qui ne viennent pas avec le leur.
	
	# Et on historise notre liste de prérequis.
	
	if [ -e "$fpr" ] && ! diff -q "$fpr" "$fpr.encours"
	then
		# Deux cas si l'on arrive ici:
		# - on a récupéré un paquet précompilé, venant avec son .prerequis; il faut alors signaler que nous n'installons pas exactement dans le même environnement que la source.
		# - ou bien on vient de recompiler sur la présente machine, et on écrase une précédente install'. Cependant ceci ne peut arriver que si le .complet a été dégommé (et le .prerequis a de fortes chances de l'avoir été aussi), ou si un passage outre est effectué (mais dans ce cas on suppose la situation maîtrisée).
		jaune "# Attention, ce paquet est installé dans un environnement différent de celui pour lequel il a originellement été compilé:" >&2
		diff "$fpr" "$fpr.encours" | jaune >&2
		mv "$fpr" "$fpr.orig"
	fi
	mv "$fpr.encours" "$fpr"
}
