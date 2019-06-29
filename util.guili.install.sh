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

# Utilisation: sutiliser [-|+]
#   -|+
#	 Si +, et si $INSTALL_SILO est définie, on pousse une archive binaire de notre $dest installé vers ce silo. Cela permettra à de futurs installant de récupérer notre produit de compil plutôt que de tout recompiler.
#	 Si -, notre produit de compil ne sera pas poussé (à mentionner par exemple s'il installe des bouts ailleurs que dans $dest, car alors l'archive de $dest sera incomplète).
#	 Si non mentionné: comportement de - si on est un amorceur (car supposé installer des trucs dans le système, un peu partout ailleurs que dans $dest); sinon comportement de +.
sutiliser()
{
	local biner=
	[ "x$1" = "x-" -o "x$1" = "x+" ] && biner="$1" && shift || true

	# On arrive en fin de parcours, c'est donc que la compil s'est terminée sans erreur. On le marque.
	sudo touch `guili_temoins`
	guili_deps_pondre
	
	sut_lv="$1"
	[ ! -z "$sut_lv" ] || sut_lv="`basename "$dest"`"
	
	# Si on est censés pousser notre binaire vers un silo central, on le fait.
	if [ -z "$biner" ]
	then
		case "$sut_lv" in
			_*) biner=- ;; # Par défaut, un amorceur n'est pas silotable (car il s'installe un peu partout dans le système: rc.d, init.d, systemd, etc.).
			*) biner=+ ;;
		esac
	fi
	if [ "x$biner" = "x+" ]
	then
		pousserBinaireVersSilo "$sut_lv"
	fi
	
	guili_localiser
	
	utiliserSiDerniere "$INSTALLS/$sut_lv"
	
	infosInstall
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
	[ ! -d "$dest" ] || sudoku "$SCRIPTS/utiliser" "$dest"
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
		echo "$cPrerequis" | tr : '\012' | ( grep -v ^$ || true )
		IFS=:
		for cPrerequi in $cPrerequis
		do
			pdeps="$cPrerequi/.guili.dependances"
			preqs="$cPrerequi/.guili.prerequis"
			[ -e "$pdeps" ] && grep -q "^$dest$" < "$pdeps" || echo "$dest" | sudoku -d "$cPrerequi" sh -c "cat >> $pdeps" || true
			if [ -s "$preqs" ]
			then
				echo "@ $preqs"
				cat "$preqs"
			fi
		done
	) | sed -e 's/^#/##/' -e 's/^@/#/' > "$fpr.encours"
	# À FAIRE?: générer un fichier alternatif avec une séparation entre la racine et le logiciel, pour qu'on puisse reconstituer par exemple si le $GUILI_PATH a changé mais possède les mêmes logiciels.
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
