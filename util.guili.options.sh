#!/bin/sh
# Copyright (c) 2018-2019 Guillaume Outters
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

# Renvoie les options dans l'ordre de référence (alphabétique).
argOptions()
{
	options "$argOptions"
}

options()
{
	echo "$*" | sed -e 's/^[^+]*//' | tr + '\012' | grep -v ^$ | sort -u | sed -e 's/^/+/' | tr -d '\012'
}

option()
{
	case "$argOptions+" in
		*+$1+*)
			argOptionsDemandees="`echo "$argOptionsDemandees" | sed -e "s/[+]$1[+]/+/"`"
			return 0
			;;
	esac
	return 1
}

# Ajoute une option avec pour nom celui d'un logiciel, si celui-ci est détecté dans l'environnement.
# Renvoie 0 si in fine l'option est placée, 1 sinon (penser à lui accoler un || true)
# Utilisation: optionSi <logiciel> [<commande> <arg>*]
# Paramètres:
#   <logiciel>
#     Logiciel dont tester la présence (doit avoir été installé par GuiLI).
#   <commande> <arg>*
#     Optionnellement, commande à jouer comme seconde chance d'installer le logiciel (par exemple si, bien que non installé par GuiLI, la présence de certains include système doit déclencher ce prérequis).
optionSi()
{
	local l="$1"
	shift
	if ! option "$l" && ( versions "$l" | grep -q . || ( [ $# -gt 0 ] && "$@" ) )
	then
		argOptions="`options "$argOptions+$l"`"
	fi
	option "$l" && return 0 || virerPrerequis "$l"
	return 1
}

# S'assure que toutes les options mentionnées en arguments ont été utilisées (le logiciel a appelé option() dessus).
verifierConsommationOptions()
{
	if ! [ -z "$argOptionsDemandees" -o "x$argOptionsDemandees" = x+ ]
	then
		local aod="`echo "$argOptionsDemandees" | sed -e 's/[+]$//' -e 's/[+]/, +/g' -e 's/^, //'`"
		local s=
		echo "$aod" | grep -q '^[+][^+]*$' || s=s
		echo "# Option$s $aod non reconnue$s par $logiciel" >&2
		return 1
	fi
}
