#!/bin/sh
# Copyright (c) 2003-2005,2008 Guillaume Outters
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

INSTALL_MEM="$HOME/tmp/paquets"
INSTALLS=/usr/local
TMP=$HOME/tmp

mkdir -p "$TMP/$$"
export PATH="`echo $PATH | sed -e 's/^\.://' -e 's/:\.:/:/g'`"

obtenir()
{
	fichier="$2"
	[ "$fichier" = "" ] && fichier=`echo "$1" | sed -e 's:^.*/::'`
	dest="$INSTALL_MEM/$fichier"
	if [ ! -f "$dest" ] ; then
		echo "Téléchargement de ${fichier}…" >&2
		commande=curl
		[ -z "$http_proxy_user" ] || commande="curl -U $http_proxy_user"
		$commande -L -s "$1" > "$dest" || rm -f "$dest"
	fi
	echo "$dest"
}

de7z()
{
	7za x -y "$@" > /dev/null
}

liste7z()
{
	7za l "$@" | awk '/^---/{if((entre=!entre)){match($0,/-*$/);posNom=RSTART;next}}{if(entre)print substr($0,posNom)}' # On repère la colonne du chemin du fichier à ce qu'elle est la dernière; et pour ce faire on se base sur la ligne de tirets qui introduit la liste (et la clôt).
}

dezipe()
{
	command -v unzip && unzip -qq -o "$@" || de7z "$@"
}

listeZip()
{
	command -v unzip && unzip -qq -l "$1" | sed -e 's/  */	/g' | cut -f 4- || liste7z "$@"
}

# Téléchargege $1 et va dans le dossier obtenu en décompressant.
obtenirEtAllerDans()
{
	for i in liste dec archive dossier fichier ; do local $i ; done 2> /dev/null
	
	cd "$TMP"
	echo Obtention et décompression… >&2
	if [ $# -gt 1 ] ; then
		fichier="$2"
		archive=`obtenir "$1" "$2"`
	else
		fichier="$1"
		archive=`obtenir "$1"`
	fi
	case "$fichier" in
		*.tar.gz|*.tgz|*.tar.Z) dec="tar xzf" ; liste="tar tzf" ;;
		*.tar) dec="tar xf" ; liste="tar tf" ;;
		*.tar.bz2) dec="tar xjf" ; liste="tar tjf" ;;
		*.zip) dec="dezipe" ; liste="listeZip" ;;
	esac
	$liste "$archive" | sed -e 's=^./==' -e 's=^/==' -e 's=/.*$==' | sort -u > "$TMP/$$/listeArchive"
	if [ `wc -l < "$TMP/$$/listeArchive"` -gt 1 ] # Si le machin se décompresse en plusieurs répertoires, on va s'en créer un pour contenir le tout.
	then
		dossier=`mktemp -d "$TMP/XXXXXX"`
		cd "$dossier"
		$dec "$archive"
	else # Sinon, il a déjà son propre conteneur.
		$dec "$archive"
		cd "`cat "$TMP/$$/listeArchive"`"
	fi
}

# Version minimaliste de ce qu'on trouve dans util.bash.
obtenirEtAllerDansVersion()
{
	obtenirEtAllerDans "$archive"
}

# Remplacements de commandes (pour la phase d'amorçage).

if ! command -v curl 2> /dev/null >&2
then
	cc -o "$TMP/minicurl" "$SCRIPTS/minicurl.c"
	curl()
	{
		"$TMP/minicurl" "$@"
	}
fi

if ! command -v sudo 2> /dev/null >&2
then
	sudo()
	{
		"$@" # Avec un peu de chance on est en root.
	}
fi

if ! command -v utiliser 2> /dev/null >&2
then
	utiliser()
	{
		"$SCRIPTS/utiliser" "$@"
	}
fi

filtrer()
{
	fichier="$1"
	shift
	"$@" < "$fichier" > "$TMP/$$/temp" && cat "$TMP/$$/temp" > "$fichier"
}

# Ajoute à une variable du contenu
# Paramètres:
# $1: Makefile
# $2: variable
# $3: ajout
etendreVarMake()
{
	filtrer "$1" awk '{print $0}/^'"$2"'=/{if(commencer == 0) commencer = 1}/[^\\]$/{if(commencer == 1) { print "'"$2"'+= '"$3"'" ; commencer = 2 }}/^$/{if(commencer == 1) { print "'"$2"'+= '"$3"'" ; commencer = 2 }}'
}

chut()
{
	"$@" > "$TMP/$$/temp" 2>&1 || cat "$TMP/$$/temp"
}

ajouterAvec()
{
	[ "$AVEC" = "" ] && AVEC=,
	AVEC="${AVEC}$1,"
}

retirerAvec()
{
	AVEC="`echo "$AVEC" | sed -e "s/,$1,/,/g"`"
}

avec()
{
	echo "$AVEC" | grep -q ",$1,"
}

inclure()
{
	truc=`cd "$SCRIPTS" && ls -d "$1-"[0-9]* "$1" 2> /dev/null | tail -1`
	if [ -z "$truc" ] ; then
		echo '# Aucune instruction pour installer '"$1" >&2
		return 1
	fi
	"$SCRIPTS/$truc"
	return $?
}
