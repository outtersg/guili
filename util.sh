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
[ -z "$INSTALLS" ] && INSTALLS=/usr/local
[ -z "$TMP" ] && TMP=/tmp

mkdir -p "$TMP/$$"
export PATH="$TMP/$$:`echo $PATH | sed -e 's/^\.://' -e 's/:\.://g'`"
export LD_LIBRARY_PATH="$INSTALLS/lib:$LD_LIBRARY_PATH"
export DYLD_LIBRARY_PATH="$LD_LIBRARY_PATH"
export CMAKE_LIBRARY_PATH="$INSTALLS"
export LDFLAGS="-L$INSTALLS/lib"
export CPPFLAGS="-I$INSTALLS/include"

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

if [ "x$SANSSU" = x1 ] || ! command -v sudo 2> /dev/null >&2
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

sutiliser()
{
	sudo utiliser -r "$INSTALLS" "$@"
}

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
	shift
	"$SCRIPTS/$truc" "$@"
	return $?
}

# Fonctions utilitaires dans le cadre des modifs.

# Modifie libtool pour lui faire générer du 32 et 64 bits via les -arch propres aux gcc d'Apple.
# Ne plus utiliser, ça marche trop peu souvent (certaines parties du compilo plantent sur du multiarchi). Passer par compil3264.
libtool3264()
{
	if command -v arch >&1 2> /dev/null && arch -arch x86_64 true 2> /dev/null
	then
		CFLAGS="$CFLAGS -arch x86_64 -arch i386"
		LDFLAGS="$CFLAGS -arch x86_64 -arch i386"
		export CFLAGS LDFLAGS CXXFLAGS
		modifspostconf="$modifspostconf libtool3264bis"
	fi
}

libtool3264bis()
{
	# Toutes les étapes incluant une génération de fichiers de dépendances (-M) plantent en multi-archis. C'est d'ailleurs ce qui nous pose problème, car certaines compils combinent génération de méta ET compil proprement dite, qui elle a besoin de son -arch multiple.
	filtrer libtool sed -e '/func_show_eval_locale "/i\
command="`echo "$command" | sed -e "/ -M/s/ -arch [^ ]*//g"`"
'
}

# À ajouter en modif; après la compil dans l'archi cible, déterminera si celle-ci est une 64bits, et, si oui, lancera la recompil équivalente totale en 32bits, avant de combiner les produits via lipo.
compil3264()
{
	if command -v arch 2> /dev/null && arch -arch x86_64 true 2> /dev/null
	then
		if [ "x$1" = "x-32" ]
		then
			CFLAGS="$CFLAGS -arch i386"
			CXXFLAGS="$CXXFLAGS -arch i386"
			LDFLAGS="$LDFLAGS -arch i386"
			export CFLAGS LDFLAGS CXXFLAGS
		else
			mkdir -p "/tmp/$$/compil32bits"
			modifspostcompil="$modifspostcompil compil3264bis"
		fi
	fi
}

compil3264bis()
{
	icirel="`pwd | sed -e "s#$TMP/*##"`"
	tmp2="$TMP/$$/compil32bits"
	TMP="$tmp2" "$SCRIPTS/`basename "$0"`" -32
	tmp2="$tmp2/$icirel"
	find . \( -name \*.dylib -o -name \*.a -o -perm -100 \) -a -type f | xargs file | egrep ": *Mach-O|archive random library" | cut -d : -f 1 | while read f
	do
		touch -r "$f" "$TMP/$$/h"
		lipo -create "$f" "$tmp2/$f" -output "$f.univ" && cat "$f.univ" > "$f"
		touch -r "$TMP/$$/h" "$f"
	done
}

dyld105()
{
	# À FAIRE: ne rajouter ça que si on est en > 10.5.
	# http://lists.apple.com/archives/xcode-users/2005/Dec/msg00524.html
	LDFLAGS="$LDFLAGS -mmacosx-version-min=10.5 -isysroot /Developer/SDKs/MacOSX10.5.sdk/"
	CFLAGS="$CFLAGS -mmacosx-version-min=10.5 -isysroot /Developer/SDKs/MacOSX10.5.sdk/"
	CXXFLAGS="$CXXFLAGS -mmacosx-version-min=10.5 -isysroot /Developer/SDKs/MacOSX10.5.sdk/"
	CPPFLAGS="$CPPFLAGS -mmacosx-version-min=10.5 -isysroot /Developer/SDKs/MacOSX10.5.sdk/"
	export LDFLAGS CFLAGS CXXFLAGS CPPFLAGS
}

# Remplacement d'utilitaires.

# http://www.techques.com/question/1-1482450/Broken-Java-Mac-10.6
for i in jar javac java
do
	rm -f "$TMP/$$/$i"
	commande="`command -v $i || true`"
	cat > "$TMP/$$/$i" <<TERMINE
#!/bin/sh
export DYLD_LIBRARY_PATH=
"$commande" "\$@"
TERMINE
	chmod a+x "$TMP/$$/$i"
done
