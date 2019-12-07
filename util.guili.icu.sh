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

# Un logiciel (ex.: PHP) qui a pour prérequis à la fois ICU et certains de ses utilisateurs (ex.: Harbuzz, ou Freetype qui utilise Harfbuzz dans ses dernières moutures) doit s'assurer de la cohérence de l'ensemble; en effet ICU à partir de la 58 passe en C++11, dont les prérequis de compilation peuvent jouer sur la bonne installation de logiciel.
# Si nous avons mis une contrainte sur la version d'ICU (ex.: < 58, pour éviter les C++11eries), il nous faut un Harbuzz lié à une ICU de la même gamme.
# La présente méthode repose sur la normalisation d'une option +icu5 pour requérir un "vieil" ICU (< 58).
# Notons qu'il s'agit là d'un parfait cas d'école de ce que pourrait apporter l'hypothétique ecosysteme ("sachant que je veux un icu < 58, et freetype (qui requiert harfbuzz), débrouille-toi pour que mes prérequis s'arrangent entre eux et me fournissent un écosystème cohérent").
prerequisIcu()
{
	local vmaxicu=
	local passerOption=
	local p2="`prerequisExecution`"
	p2="`decoupePrerequis "$p2" | sed -e 's/[+ ].*//' | tr '\012' ' '`"
	
	# A-t-on des contraintes passées par options?
	if option icu5 ; then vmaxicu=58 ; fi
	# Trouve-t-on une contrainte sur la version d'ICU dans nos prérequis directs?
	case " $p2 " in
		*" icu "*)
			local vicu="`decoupePrerequis "$prerequis" | egrep '^icu([+ ]|$)'`"
			vicu="`vmax -1 $vicu`"
			[ -z "$vicu" ] || pge "$vicu" 58 || vmaxicu=58 # À FAIRE: inutile de recalculer ici si l'option icu5 plus haut a déjà déterminé un $vmaxicu inférieur ou égal.
			;;
	esac
	
	case "$vmaxicu" in
		"") return 0 ;;
		58) passerOption="+icu5" ;;
	esac
	case " $p2 " in
		*" icu "*) prerequis="$prerequis icu < $vmaxicu" ;;
	esac
	prerequis="$prerequis `quiEstInteresseParIcu "$passerOption" $p2`"
	prerequis="`decoupePrerequis "$prerequis" | tr '\012' ' '`" # On combine les éventuelles mentions pour transformer par exemple un freetype+hb freetype+icu5 en freetype+hb+icu5.
}

quiEstInteresseParIcu()
{
	local option="$1" ; shift
	( cd "$SCRIPTS/" && egrep -l 'icu5|prerequisIcu|optionsEtPrerequisIcu' "$@" ) | sed -e "s/$/$option/"
}

# Choix de l'ICU auquel se lier:
# - si +icu5 est explicitement demandée, on prend une ICU < 58 (ne nécessitant pas C++11).
# - sinon, à moins que --sans-icu ait été explicitement demandé, on transforme en l'option +icux, à savoir, un ICU sans limite de version (le plus récent que l'on trouve ou sache installer).
optionsEtPrerequisIcu()
{
	optionSi icu || true
	option icu || option icu5 || option icux || return 0
	
	option icu5 || argOptions="`options "$argOptions+icux"`"
	
	local vicu
	if option icux
	then
		argOptions="`options "$argOptions-icu5"`"
		vicu=">= 58"
	else
		vicu="< 58"
		case " $prerequis " in
			*" freetype[+ ]"*) prerequis="$prerequis freetype+icu5" ;;
		esac
	fi
	
	argOptions="`options "$argOptions-icu"`" # On fait disparaître l'option icu, trop équivoque, et moche maintenant qu'on a mis soit icu5 soit icux à la place.
	
	# Comment refléter le choix, soit sur nos prérequis si nous appelons directement icu, soit sur les options de nos prérequis si nous ne faisons que transmettre?
	
	case "$prerequis" in
		*" icu[+ ]"*) remplacerPrerequis "icu $vicu"
	esac
	
	prerequisIcu
}
