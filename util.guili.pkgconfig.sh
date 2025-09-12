# Copyright (c) 2020 Guillaume Outters
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

pkgconfer()
{
	local paquet= descr= prex=- biblios= cflags= d
	local TMP="$TMP" ; [ -n "$TMP" ] || TMP=/tmp
	local t="$TMP/$$/pkgconfig.temp"
	
	rm -Rf "$t" && mkdir "$t"
	
	while [ $# -gt 0 ]
	do
		case "$1" in
			-l*) biblios="$biblios $1" ;;
			-p) shift ; prex="$1" ;;
			*)
				paquet="$1"
				case "$2" in [A-Za-z]*" "*) descr="$2" ; shift ;; esac
				_pkgconf_pondre > "$t/$paquet.pc"
				;;
		esac
		shift
	done
	
	sudoku "$SCRIPTS/installer" "$t" "$dest/lib/pkgconfig"
}

_pkgconf_pondre()
{
	if [ "$prex" = - ]
	then
		prex="`IFS='\' ; f() { while [ $# -gt 1 ] ; do shift ; done ; echo "$1" ; } ; pr="$prerequis " ; f $pr`" # Un petit espace à la fin pour les cas où le \ en dernière position risquerait d'être ignoré.
	fi
	if [ -n "$biblios" ]
	then
		for d in lib lib64
		do
			[ ! -d "$dest/$d" ] || biblios="-L\${prefix}/$d $biblios"
		done
	fi
	[ ! -d "$dest/include" ] || cflags="$cflags -I\${prefix}/include"
	[ -n "$descr" ] || descr="$paquet"
	
	cat <<TERMINE
prefix=$dest

Name: $paquet
Description: $descr
Version: $version
TERMINE
	pkgconf_lignes Cflags "$cflags" Libs "$biblios" Requires "$prex"
}

pkgconf_lignes()
{
	while [ $# -gt 0 ]
	do
		case "$2" in
			*[^\ ]*) echo "$1: $2" ;;
		esac
		shift
		shift
	done
}

pkgconf_lib()
{
	local f
	[ -n "$1" ] || set -- Makefile
	
	# Certains logiciels poussent les fichiers pkgconfig vers libdata/pkgconfig plutôt que lib/pkgconfig sous FreeBSD.
	# Ce qui est vrai pour le système (/usr/local/libdata/pkgconfig), mais pas pour GuiLI.
	
	# Finalement de plus en plus de logiciels se calant sur libdata (qui est plus propre: les lib, c'est les lib), il est dépréconisé de le faire.
	rouge "# Merci de ne plus utiliser pkgConfLib, mais de laisser utiliser libdata/pkgconfig." >&2
	
	for f in "$@"
	do
		[ -f "$f" ] || continue
		filtrer "$f" sed -e s/libdata/lib/g
	done
}

# Renvoie la totale des chemins de recherche de .pc, dont les dossiers système
# (à la différence de $guili_pcpath qui ne renvoie que la partie sous $INSTALLS)
pkgconf_path()
{
	local prems=1 rech_racine rech_dossier
	for rech_racine in "$INSTALLS" /usr/local /usr
	do
		for rech_dossier in libdata lib
		do
			case "$prems" in 1) prems=2 ;; *) printf : ;; esac
			printf %s "$rech_racine/$rech_dossier/pkgconfig"
		done
	done
	# À FAIRE: en fait le début pourrait être récupéré de $guili_pcpath.
}
