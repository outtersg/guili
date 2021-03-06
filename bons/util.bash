# Copyright (c) 2005 Guillaume Outters
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

. "$SCRIPTS/util.sh"

mkdir -p "$TMP/$$"

[ "`basename "$SHELL"`" != bash ] && return # util.sh est censé contenir des version minimalistes des fonctions ici développées.

obtenirEtAllerDansDarcs()
{
	local patch= archive= archive_locale= petit_nom=
	local -a options
	
	while [ $# -gt 0 ]
	do
		case "$1" in
			-p) shift ; patch="$1" ; options=("${options[@]}" "--to-patch=$patch") ;;
			-n) shift ; petit_nom="$1" ;;
			*) archive="$1" ;;
		esac
		shift
	done
	endroit=${archive##*/}
	if [ -z "$petit_nom" ]
	then
		[ -z "$patch" ] || endroit="$endroit-$patch"
	else
		endroit="$endroit-$petit_nom"
	fi
	
	cd "$TMP"
	echo Obtention et décompression… >&2
	if [ "x$patch" != x ]
	then
		archive_locale="$INSTALL_MEM/${endroit}.tar.bz2"
		[ -f "$archive_locale" ] && tar xjf "$archive_locale" && cd "$endroit" && return 0
	fi
	darcs get "${options[@]}" "$archive" "$endroit"
	[ -z "$patch" ] || tar cjf "$archive_locale" "$endroit"
	cd $endroit
}

obtenirEtAllerDansSvn()
{
	local rev= archive= archive_locale= options=
	
	while [ $# -gt 0 ]
	do
		case "$1" in
			-r) shift ; rev="$1" ; options="$options --revision=$rev" ;;
			*) archive="$1" ;;
		esac
		shift
	done
	endroit=${archive%/trunk}
	endroit=${endroit##*/}
	[ -z "$rev" ] || endroit="$endroit-r$rev"
	
	cd "$TMP"
	echo Obtention et décompression… >&2
	if [ "x$rev" != x ]
	then
		archive_locale="$INSTALL_MEM/${endroit}.tar.bz2"
		[ -f "$archive_locale" ] && tar xjf "$archive_locale" && cd "$endroit" && return 0
	fi
	chut svn co $options "$archive" "$endroit"
	[ -z "$rev" ] || tar cjf "$archive_locale" "$endroit"
	cd $endroit
}

# Récupère une URL de la forme cvs://login:mdp@serveur:racine:module
obtenirEtAllerDansCvs()
{
	for i in moi passe d endroit archive_date option_date ; do local $i ; done 2> /dev/null
	archive_date=
	option_date=
	[ "x$1" = x-d ] && shift && archive_date="$1" && option_date="-D $1" && shift
	d="${1#cvs://}"
	moi="${d%%@*}"
	endroit="${d##*:}"
	d="${d%:*}"
	d=":pserver:${moi%%:*}@${d#*@}"
	passe="${moi#*:}"
	echo Obtention et décompression… >&2
	if [ "x$archive_date" != x ] ; then
		archive_date="$INSTALL_MEM/${endroit//\//_}.$archive_date.tar.bz2"
		[ -f "$archive_date" ] && mkdir -p "$TMP/$endroit" && cd "$TMP/$endroit" && tar xjf "$archive_date" && return 0
	fi
	cd "$TMP"
	# Le "/1 " qui suit date de cvs 1.11.1, je crois.
	grep -q "^$d" ~/.cvspass || echo "/1 $d A`echo "$passe" | tr '0123456789abcdefghijklmnopqrstuvwxyz' 'o.........y.he.E.c?....=0:. Z..<3.................'`" >> ~/.cvspass # Il faudrait compléter les associations.
	chut cvs -z3 -d "$d" co $option_date "$endroit"
	find "$endroit" -name CVS -print0 | xargs -0 rm -R
	cd "$TMP/$endroit"
	[ "x$archive_date" = x ] || tar cjf "$archive_date" .
}

# Utilise les variables globales version, archive, archive_darcs, archive_svn, archive_cvs.
obtenirEtAllerDansVersion()
{
	if [[ $version = *@* ]] ; then
		obtenirEtAllerDansDarcs -n "${version%%@*}" -p "${version#*@}" "$archive_darcs"
		version="${version%%@*}"
	elif [[ $version = r* ]] ; then
		obtenirEtAllerDansSvn -r ${version#r} $archive_svn
	elif [[ $version = *-* ]] ; then
		obtenirEtAllerDansCvs -d $version $archive_cvs
	else
		obtenirEtAllerDans "$archive"
	fi
}

ajouterModif()
{
	modifs="$modifs $1"
}

retirerModif()
{
	modifs=${modifs//$1/}
}

# Renvoie 0 si le premier paramètre (num de version) est plus grand ou égal au
# second.
pge()
{
	a=$1
	b=$2
	while [ ! -z "$a" ]
	do
		[ -z "$b" -o ${a%%.*} -gt ${b%%.*} ] && return 0
		[ ${a%%.*} -lt ${b%%.*} ] && return 1
		[[ "x$a" = *.* ]] || a=""
		[[ "x$b" = *.* ]] || b=""
		a=${a#*.}
		b=${b#*.}
	done
	[ -z "$b" ]
}
