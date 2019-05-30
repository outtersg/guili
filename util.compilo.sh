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
		# Ce binaire a-t-il été installé par GuiLI? En ce cas il n'est certainement pas dans un dossier système, donc il faudra aussi aller chercher tout son environnement (lib, include, etc.).
		reglagesCompilSiGuili "$binaire"
	fi
	
	varsCc "$bienVoulu"
	
	# En général le compilo vient avec sa libc++.
	
	eval "cheminBienVoulu=\$dest$bienVoulu"
	if [ -d "$cheminBienVoulu" -a -d "$cheminBienVoulu/include/c++/v1" ]
	then
		#export CPPFLAGS="-cxx-isystem $cheminBienVoulu/include/c++/v1 $CPPFLAGS"
		export 	CXXFLAGS="-cxx-isystem $cheminBienVoulu/include/c++/v1 $CXXFLAGS"
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
					export MACOSX_DEPLOYMENT_TARGET="`tr -d '\012' < "$f" | sed -e 's#.*>MACOSX_DEPLOYMENT_TARGET</key>[ 	]*<string>##' -e 's#<.*##'`"
					break
				fi
			done
			;;
	esac
}

# Pour compatibilité.
meilleurCompiloInstalle() { meilleurCompilo "$@" ; }
