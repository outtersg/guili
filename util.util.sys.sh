# Copyright (c) 2012-2013,2015,2017,2020-2021 Guillaume Outters
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

#- Mac -------------------------------------------------------------------------

# Le Mac a la fâcheuse tendance d'embarquer ses propres versions de composants Open Source (iconv, sqlite3…);
# et d'y lier certaines de ses bibliothèques système.
# Donc pour peu qu'un logiciel se lie à ses dernières (ex.: un truc cherchant un pontage vers CoreGraphics, ou un Python et son scproxy),
# on est condamnés à se lier à ces versions système des Open Source, ou au moins à une version très compatible.

# Pour un logiciel amené à se lier à des bibliothèques système, remplace dans $prerequis celles fournies par ledit système par un équivalent proche (voire se débrouille pour utiliser celle système).
similisys()
{
	prerequis="`_similisys`"
}

_similisys()
{
	decoupePrerequis "$prerequis" | sed -e 's/+/ &/' | while read l reste
	do
		commande "similisys_$l" || { echo "$l $reste" ; continue ; }
		similisys_$l "$reste"
	done | sed -e 's/ +/+/g' | tr '\012' ' '
}

# À FAIRE: pour le moment iconv s'autodétecte sur Mac et s'ajoute l'option +duo.
#similisys_iconv()

similisys_sqlite()
{
	local bib o v
	for bib in \
		/usr/lib/libsqlite3.dylib
	do
		if [ -e "$bib" ]
		then
			nm -o "$bib" | grep -q ' T .*intarray' && o="$o+intarray" || true # https://bugzilla.mozilla.org/show_bug.cgi?id=1055441#c28
			nm -o "$bib" | grep -q ' T .*snapshot_free' && o="$o+snapshot" || true
			break
		fi
	done
	
	echo "sqlite$o $1$v"
}

# CMake, ImageMagick, pkg-config, se lient aux Frameworks MacOS X qui cherchant une libJPEG.dylib spécifique Apple tombent sur notre libjpeg.dylib.
# N.B.: depuis que DYLD_LIBRARY_PATH a été viré de _cheminsExportes, il est possible qu'on puisse se passer de ceci.
putainDeLibJPEGDeMacOSX()
{
	[ -z "$dejaAppelePutainDeLibJPEGDeMacOSX" ] || return 0
	dejaAppelePutainDeLibJPEGDeMacOSX=1
	mac || return 0
	# Ces trous du cul d'Apple ont cru bon créer une libJPEG.dylib à eux, qui évidemment ne sert à personne d'autre qu'à eux (les symboles à l'intérieur sont tous préfixés _cg_, comme CoreGraphics). Et avec un système de fichier insensible à la casse, cette connasse de libJPEG de merde prend le pas sur la très légitime libjpeg que l'on souhaite utiliser un peu partout.
	case essai in
		tentative)
			LDFLAGS="-L/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/ImageIO.framework/Versions/A/Resources $LDFLAGS"
			export LDFLAGS
			;;
		test)
			# Ou alors je lui pète la tête, à ce gros nase de CMake qui s'obstine à se lier avec Carbon. C'est pas son boulot, je me démerderai au cas par cas avec les conneries que me fait faire Apple. Putain ils font chier quand même avec leurs bourdes.
			grep -rl 'framework Carbon' . | while read f
			do
				filtrer "$f" sed -e 's/-framework Carbon//g'
			done
			# Mais quand même il va en avoir besoin un coup à la fin.
			filtrer bootstrap sed -e '/-o cmake/{
s//-framework Carbon -o cmake/
s#${cmake_ld_flags}#-L/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/ImageIO.framework/Versions/A/Resources -lJPEG &#
}'
			;;
		essai)
			# Mais ce foutu machin s'obstine à se lancer dans je ne sais quelles variables d'environnement. Alors on essaie de lui dire de se compiler en indépendant.
			[ "x$1" = xprudemment ] || LDFLAGS="`echo "$LDFLAGS" | sed -e "s#-L$INSTALLS/lib##g"`"
			DYLD_FALLBACK_LIBRARY_PATH="$LD_LIBRARY_PATH:$DYLD_LIBRARY_PATH:$DYLD_FALLBACK_LIBRARY_PATH"
			unset LD_LIBRARY_PATH
			unset DYLD_LIBRARY_PATH
			export DYLD_FALLBACK_LIBRARY_PATH
			;;
	esac
}

# Sous Mavericks, cette foutue lib nous pollue systématiquement: gcc, ld, nm, etc., y sont liés, car ceux d'/usr/bin sont de simples lanceurs qui font un xcodebuild -find xxx (allant chercher le vrai exécutable dans le bon SDK pour la plateforme de l'ordi). On appelle donc systématiquement notre putaineDeLigJPEGDeMacOSX.
mac && putainDeLibJPEGDeMacOSX prudemment || true

macLibtool()
{
	# Sous Mac OS X, un éventuel libtool GNU compilé prend le pas sur celui d'Apple, seul à gérer des options à la con telles que -static. On place donc un alias du libtool officiel quelque part dans le PATH avant celui éventuellement compilé par nos soins.
	# Un lien symbolique ferait l'affaire, mais en écrivant un script enrobeur on se réserve la possibilité d'agir sur les paramètres si un jour quelque chose ne nous plaît pas.
	mac || return 0
	[ -e /usr/bin/libtool ] || return 0
	cat > "$TMP/$$/libtool" <<TERMINE
#!/bin/sh
/usr/bin/libtool "\$@"
TERMINE
	chmod a+x "$TMP/$$/libtool"
}

macMath()
{
	# http://clang-developers.42468.n3.nabble.com/problems-building-libcxx-td2353619.html
	mac || return 0
	cat > /tmp/1.cpp <<TERMINE
#include <cmath>
void f() { llroundl(0.0); }
TERMINE
	! c++ -c -o /tmp/1.o -D__STRICT_ANSI__ /tmp/1.cpp > /dev/null 2>&1 || return 0
	
	CPPFLAGS="$CPPFLAGS -U__STRICT_ANSI__"
	export CPPFLAGS
}

llvmStrnlen()
{
	# Les dernières versions LLVM (et donc tous ceux qui l'embarquent, type Rust) utilise strnlen qui n'est pas définie dans un Mac OS X 10.8, par exemple.
	cat > /tmp/1.cpp <<TERMINE
#include <string.h>
void toto() { strnlen("zug", 2); }
TERMINE
	! c++ -c -o /tmp/1.o /tmp/1.cpp > /dev/null 2>&1 || return 0
	
	# On est obligés de ne cibler que le minimum de fichiers, car d'autres .cpp, d'une part servent à définir le strnlen qui finira dans les biblios, d'autre part incluent des enum dont une valeur est strnlen.
	find . \( -name MachOYAML.cpp -o -name HeaderMap.cpp -o -name LLVMOutputStyle.cpp -o -name macho2yaml.cpp \) -print0 | xargs -0 grep -l strnlen | while read f
	do
		# On insère notre remplacement avant la première ligne qui ne soit pas in include, une ligne vide, ou un commentaire.
		filtrer "$f" awk 'fini{print;next}/#include/{print;next}/^ *\/\//{print;next}/^ *$/{print;next}{print "#define strnlen monstrnlen" ; print "static inline int monstrnlen(const char * c, int t) { int n; for(n = -1; ++n < t && c[n];) {} return n; }" ; print ; fini=1}'
	done
}

#- FreeBSD ---------------------------------------------------------------------

linuxInput()
{
	# Sous FreeBSD, input.h et input-event-codes.h sont dans …/include/dev/evdev/ et non …/include/linux/ (ou alors uniquement si on a installé la couche de compat Linux).
	# Le problème est que la coquille n'est pas dans notre source, mais dans le paquet installé par les ports: on ne peut donc pas corriger, juste poser un fichier équivalent.
	# Cf. le GuiLI mtdev pour un remplacement, et mtdev +linuxinput pour une version encore plus universelle (si les logiciels s'obstinent à accéder à <linux/input.h> en direct).
	
	echo "#include <linux/input.h>" > $TMP/$$/1.c
	echo "#include <dev/evdev/input.h>" > $TMP/$$/2.c
	if ! compilo_test $CC -E $TMP/$$/1.c > /dev/null 2>&1 && compilo_test $CC -E $TMP/$$/2.c > /dev/null 2>&1
	then
		mkdir -p $TMP/$$/linux
		echo "#include <dev/evdev/input.h>" > $TMP/$$/linux/input.h
		echo "#include <dev/evdev/input-event-codes.h>" > $TMP/$$/linux/input-event-codes.h
		export CPPFLAGS="-I$TMP/$$ $CPPFLAGS"
	fi
}

ldlOptionnel()
{
	# Les BSD embarquent dlopen en standard; Linux veut du -ldl. Certains Makefiles codent en dur ce -ldl Linux.
	
	cat > /tmp/testDlopen.c <<TERMINE
void * dlopen(const char *path, int mode);
int main(int argc, char ** argv)
{
dlopen("coucou", 0);
return 0;
}
TERMINE
	cc -o /tmp/testDlopen /tmp/testDlopen.c 2> /dev/null || return 0 # Si plantage de compilation, -ldl est nécessaire, alors on le laisse dans les Makefiles.
	
	for i in "$@"
	do
		filtrer "$i" sed -e 's/-ldl//g'
	done
}

fpic()
{
	CFLAGS="$CFLAGS -fPIC"
	export CFLAGS
}

fbsd10()
{
	# Pour les couillons qui confondent freebsd10 et freebsd1.
	find . -name configure | while read i ; do
		[ ! -f "$i" ] || filtrer "$i" sed -e 's#freebsd1\*#freebsd1|freebsd1.*#g'
	done
}
