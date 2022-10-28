#!/bin/sh
# Copyright (c) 2005,2007 Guillaume Outters
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

set -e

DelieS() { local s2 ; while [ -h "$s" ] ; do s2="`readlink "$s"`" ; case "$s2" in [^/]*) s2="`dirname "$s"`/$s2" ;; esac ; s="$s2" ; done ; } ; SCRIPTS() { local s="`command -v "$0"`" ; [ -x "$s" -o ! -x "$0" ] || s="$0" ; case "$s" in */bin/*sh) case "`basename "$s"`" in *.*) true ;; *sh) s="$1" ;; esac ;; esac ; case "$s" in [^/]*) local d="`dirname "$s"`" ; s="`cd "$d" ; pwd`/`basename "$s"`" ;; esac ; DelieS ; s="`dirname "$s"`" ; DelieS ; SCRIPTS="$s" ; } ; SCRIPTS
. "$SCRIPTS/util.sh"

# Désormais les 8.0.tar.bz2 ne sont plus des 8.0.0, mais des 8.0.x embarquant les x premiers patches.
demarrage=

v 6.3 && prerequis="ncurses" && modifs="ncursesw" || true
v 6.4 || true
v 7.0.205 && modifs="ncursesw corr syntaxephp pyth" || true
v 7.2.160 || true
v 7.3.353 || true
v 7.3.1242 || true
v 7.4.52 && modifs="ncursesw corr syntaxephp pyth mavericks" || true
v 7.4.702 || true
v 7.4.1847 || true
v 7.4.2296 || true
v 8.0.311 && demarrage=".069" || true
v 8.0.1240 && demarrage=".586" || true
v 8.1.608 && demarrage="" || true
v 8.1.804 || true
#v 8.1.805 || true # digraph.c:16:2: error: unterminated conditional directive: #if defined(FEAT_DIGRAPHS) || defined(PROTO)
#v 8.1.1176 || true # Toujours pas corrigé
v 8.2.3455 && modifs="$modifs char_from_string" && modifs_corr="corr82" || true
v 8.2.5111 || true
v 8.2.5172 || true
v 9.0.790 && modifs="$modifs write_info_struct" && modifs_corr="corr90" || true
v 9.0.818 || true

option python3 && prerequis="$prerequis python >= 3" || true

v_maj="`echo "$version" | sed -e 's/\.[^.]*$//'`"
v_min="`echo "$version" | sed -e 's/.*\.//'`"
pge "$version" 8.0 && formateur=4.4d || formateur=3.3d
v_min0="`printf %0$formateur $v_min`"
archive=http://ftp.vim.org/pub/vim/unix/$logiciel-$v_maj$demarrage.tar.bz2
if true
then
# La constitution par rustinage officiel montre ses limites, cf. 4206 un peu plus loin.
# https://www.mail-archive.com/vim_use@googlegroups.com/msg58822.html
archive=https://github.com/vim/vim/archive/refs/tags/v$v_maj.$v_min0.tar.gz
retirerModif corr
retirerModif char_from_string
fi

# Modifications.

write_info_struct()
{
	# https://github.com/vim/vim/commit/72c8e3c070b30f82bc0d203a62c168e43a13e99b
	# https://github.com/vim/vim/commit/fb0cf2357e0c85bbfd9f9178705ad8d77b6b3b4e J'arrive 16 h après que Bram a reçu des cours de git pour comprendre pourquoi son correctif n'est pas passé.
	filtrer src/bufwrite.c sed -e 's/write_info->/write_info./g'
}

corr90()
{
	# 9.0.0206 en doublons de fichiers.
	virerDuDiff 9.0.0206 src/drawscreen.c
	virerDuDiff 9.0.0206 src/mouse.c
	virerDuDiff 9.0.0206 src/terminal.c
	# 9.0.0363 retombe sur une problématique de caractères zarb autour de la rustine (tests d'édition en jeux de caractères orientaux), bloquant mon patch BSD ou GNU.
	# J'abandonne. Basculons sur l'archive git comme proposé au-dessus de archive=…
}

corr82()
{
	# Les rustines fournies par Bram ont quelques curiosités gênantes. Que ni BSD patch ni GNU patch ne semblent parvenir à surmonter.
	filtrer 8.2.0010 sed -e 's/Ã¡/á/g'
	filtrer 8.2.0122 sed -e 's#READMEdir/##g'
	for f in 8.2.0617 8.2.0620 8.2.0627
	do
		filtrer "$f" iconv -f utf-8 -t cp1252
	done
	printf '%s\n%s\n%s\n' '--- vide' '+++ vide' '@@ -0,0 +0,0 @@' > 8.2.0628
	# Le 8.2.0661 essaie de vider un fichier contenant des Ctrl-@ (caractère nul), et BSD patch n'aime pas, mais alors pas du tout…
	for f in 8.2.0661
	do
		#filtrer "$f" awk 'bientot&&/^\*\*\* /{sub(/\*+ /,"@@ -");sub(/ \*+/," +0,0 @@");bientot=0}/^--- src\/testdir\/test_eval.ok/{bientot=1}{print}'
		filtrer "$f" sed -e '/^--- src\/testdir\/test_eval.ok/,/^--- 0 ----/d'
	done
	# Le 8.2.0798 contient deux fois le même fichier :-(
	virerDuDiff 8.2.0798 src/libvterm/t/harness.c
	# Les rsrc BeOS, ouh là.
	virerDuDiff 8.2.0849 src/os_beos.rsrc
	# Bon là j'abandonne au 931.
	# On doit aller jusqu'au 4206 où e_expression_too_recursive_str est définie (et la compil plante s'il ne passe pas, car elle est utilisée ailleurs, grrr…).
}

virerDuDiff()
{
	local rustine="$1" f="$2"
	f="`echo "$f" | tr / .`" # Les / ne sont guère appréciés si le chemin sert dans une /regex/
	filtrer $rustine awk 'etape&&/^\*\*\* [^0-9]/{++etape}!etape&&/^\*\*\* .*'"$f"'/{etape=1}etape!=1{print}'
}

char_from_string()
{
	# Fonction définie deux fois (vim9execute.c et eval.c).
	#filtrer src/eval.c sed -e s/char_from_string/char_from_string_orig/g
	# On transforme une des deux en simple déclaration.
	filtrer src/eval.c sed -e '/^char_from_string/{
s/$/;/
h
a\
#if 0
}' -e '/^}/{
x
s/././
t-)
x
b
:-)
s/.*//
x
a\
#endif
}'
}

ncursesw()
{
	filtrer src/auto/configure sed -e '/tlibs/s/ncurses /ncursesw ncurses /g'
}

pyth()
{
	command -v python3 > /dev/null 2>&1 && OPTIONS="$OPTIONS --enable-python3interp=dynamic" || true
	command -v python > /dev/null 2>&1 && OPTIONS="$OPTIONS --enable-pythoninterp=dynamic" || true
}

corr()
{
	n="`echo "$version" | sed -e 's/.*\.//'`"
	ou="`echo "$archive" | sed -e 's#/unix/[^/]*$#/patches#'`"
	mem="$INSTALL_MEM/$logiciel-$version$demarrage.corr.tar.gz"
	if [ -z "$demarrage" ]
	then
		demarrage=0
	else
		demarrage="`echo "$demarrage" | sed -e 's/^[.0]*//'`"
	fi
	
	if [ -f "$mem" ] && tar xzf "$mem"
	then
		i=$demarrage
	else
		i=$n
		while [ $i -gt $demarrage ]
		do
			iFormate="`printf "%$formateur" "$i"`"
			mv "`obtenir "$ou/$v_maj/$v_maj.$iFormate"`" ./
			i=`expr $i - 1 || true` # Ce crétin d'expr sort en erreur 1 lorsque le résultat vaut 0…
		done
		tar czf "$mem" "$v_maj".*
	fi
	
	for modif in $modifs_corr true
	do
		$modif
	done
	
	while [ $i -lt $n ]
	do
		i=`expr $i + 1`
		patch -f -p0 < "$v_maj.`printf "%$formateur" $i`" || true # Un peu de rustines indigestes Windows, on contourne en ignorant les erreurs. Problème: à partir de la 8.2.4206, la définition d'e_expression_too_recursive_str, indispensable à la compil', ne passe pas. Il faudrait donc imposer que patch tourne sans erreur, pour n'oublier aucune morceau, notre true est un pis-aller qui a servi mais nous met maintenant dans le mur.
	done
}

syntaxephp()
{
	filtrer runtime/syntax/php.vim sed -e 's/\\h\\w/[A-Za-z0-9_âàæÆçéêèëîïôöœŒûùüÿ]/g' # A priori les majuscules sont couvertes aussi, puisque le caractère UTF-8 en minuscule est composé de deux octets, ex. à = a`, donc le [Aaà] est en fait équivalent à [Aaa`] et inclut donc aussi le À qui est la combinaison A`.
}

mavericks()
{
	mac || return 0
	pge `uname -r` 13 || return 0
	# http://codepad.org/Mzsik2R8
	patch -p0 <<TERMINE
diff src/os_unix.c src/os_unix.c
--- src/os_unix.c
+++ src/os_unix.c
@@ -18,6 +18,10 @@
  * changed beyond recognition.
  */
 
+#if defined(__APPLE__)
+#include <AvailabilityMacros.h>
+#endif
+
 /*
  * Some systems have a prototype for select() that has (int *) instead of
  * (fd_set *), which is wrong. This define removes that prototype. We define
TERMINE
}

destiner

prerequis

obtenirEtAllerDansVersion

echo Correction… >&2
for modif in true $modifs ; do $modif ; done

echo Configuration… >&2
./configure --prefix="$dest" --enable-multibyte --disable-gui $OPTIONS

echo Compilation… >&2
make -j4

echo Installation… >&2
sudo make install
sutiliser
