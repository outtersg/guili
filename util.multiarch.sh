#!/bin/sh
# Copyright (c) 2017,2019 Guillaume Outters
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

multiarchMemoriserInvocation()
{
	IFS="`printf '\003'`"
	multiarch_invocation="$install_moi$IFS$*"
	unset IFS
	while [ $# -gt 0 ]
	do
		case "$1" in
			--arch) shift ; multiarch_arch="$1" ;;
		esac
		shift
	done
}

multiarchMemoriserInvocation "$@"

# Multi-ARCHitecturER
# À appeler comme première modif pour installer le logiciel en multi-archi (si supporté par le système).
marcher()
{
	# Version par moire(). Avantages par rapport à la version initiale:
	# - passe par moire(), donc mutualisation.
	# - les compil intermédiaires ont pour $dest la vraie destination (plutôt que $dest-$multiarch_arch): s'ils codent en dur leur --prefix dans certains fichiers (ex.: pkgconfig), ce sera le bon préfixe (ne serait-ce qu'en s'installant dans le .guili.dependances d'autres logiciels).
	# - l'architecture principale est compilée par le process invoqué initialement: il sera plus à même de répondre aux varsPrerequis.
	
	mac || return 0 # Pour le moment je ne sais pas faire sur d'autres plates-formes que le Mac.
	
	case "$GUILI_MOIRE:" in
		*:multiarch:*)
			multiarchConfigurer
			;;
		*)
			if [ $# -eq 0 ]
			then
				IFS="`printf '\003'`"
				tifs maLancer $multiarch_invocation
			else
				maLancer "$install_moi" "$@"
			fi
			;;
	esac
	# On affiche ce que l'on va attaquer:
	# - si l'on tourne avant obtenirEtAllerDansVersion, on peut modifier le joli en-tête qui va y être affiché, ça fera propre
	# - sinon, on arrive après la bataille, on se rabat sur une trace mentionnant l'architecture entre parenthèses.
	# Notre présence dans $modifs indiquera par quel moyen nous sommes lancés.
	case " $modifs " in
		*" marcher "*|*" multiarch "*) gris "(multiarch:$multiarch_arch)" ;;
		*) GUILI_MOIRE="$GUILI_MOIRE:$multiarch_arch" ;;
	esac
}

maLancer()
{
	shift # Le premier paramètre est $install_moi, pour compatibilité avec l'ancien multiarch.
	
	# Pour quelles archis va-t-on travailler?
	
	mas
	
	# En avant!
	
	local a da a0 # a0: archi principale (la première, enfin la zéroïème).
	
	for a in $multiarch_archs
	do
		# La première archi va s'exécuter dans le processus père (nous).
		
		if [ -z "$a0" ]
		then
			da="$dest"
			a0="$a"
			# Le reste des opérations va se faire dans la suite de ce script.
		else
			# Lancement d'un fils pour l'archi.
			moire -i multiarch "$@" --arch "$a"
			
			# Déplacement pour que le suivant trouve la place nette.
			
			da="$dest-$a"
			sudoku mv "$dest" "$da"
		fi
		multiarch_paramsCombiner="$multiarch_paramsCombiner $a $da"
	done
	
	# On installe notre combineur pour après la compil.
	
	guili_postcompil="$guili_postcompil multiarchCombiner"
	
	# Et on prépare notre compil.
	
	multiarch_arch="$a0"
	multiarchConfigurer
}

# À FAIRE: simplifier multiarchMemoriserInvocation et maLancer en virant l'$install_moi qui servaient à l'implémentation d'origine.
multiarch() { marcher "$@" ; }

mas()
{
	# Pour quelles archis va-t-on travailler?
	
	multiarch_archs=
	case "`uname`" in
		Darwin)
			# Petit test rapide: il nous faut aller jusqu'à l'édition de liens, avec un appel à libc; en effet avec le mauvais SDKROOT, la compil peut bien se passer (le compilo sait gérer), par contre la lib n'a pas le symbole.
			{ echo '#include <stdio.h>' ; echo 'int main(int argc, char ** argv) { fprintf(stdout, "oui\\n"); return 0; }' ; } > $TMP/$$/1.c
			local archi
			for archi in x86_64 i386
			do
				cc $CPPFLAGS $CFLAGS $LDFLAGS -arch $archi -o $TMP/$$/a.out $TMP/$$/1.c 2> /dev/null && [ oui = "`$TMP/$$/a.out`" ] && multiarch_archs="$multiarch_archs $archi" || true
			done
			[ -n "$multiarch_archs" ] || multiarch_archs="`uname -m`"
			;;
	esac
}

multiarchCombiner()
{
	multiarch_combineur="multiarchCombiner`uname`"
	$multiarch_combineur $multiarch_paramsCombiner
}

multiarchCombinerDarwin()
{
	local op f aref ala
	multiarch_archRef="$1" ; shift
	multiarch_destRef="$1" ; shift
	while [ $# -gt 0 ]
	do
		cd "$multiarch_destRef"
		
		multiarch_archLa="$1"
		multiarch_destLa="$2"
		multiarchPrecombiner "$multiarch_archLa" "$multiarch_destLa"
		diff -rq . "$multiarch_destLa" 2> /dev/null | sed \
			-e "s#^Only in $multiarch_destLa/#+ #" \
			-e '/^+ /s#: #/#' \
			-e "s#^Only in $multiarch_destLa: #+ #" \
			-e '/^Only/d' \
			-e 's/^Files /= /' -e 's/ and .*differ//' \
		| while read op f
		do
			# Traitement des "Only in".
			case "$op" in
				+)
					case "$f" in $COMPLET|.guili*) continue ;; esac
					echo "$f" >&6
					continue
					;;
			esac
			# Traitement des différences.
			if [ ! -L "$f" ]
			then
				nom="`basename "$f"`"
				suffixe="`echo "$nom" | sed -e 's/^.*\././'`"
				case "$nom" in
					*.*) true ;;
					*)
						if file "$f" | grep -q binary
						then
							suffixe=.bin
						fi
						;;
				esac
				case "$suffixe" in
					.h)
						diff -D __${multiarch_archLa}__ "$f" "$multiarch_destLa/$f" > "$TMP/$$/temp.diffD" || true
						sudo sh -c "cat $TMP/$$/temp.diffD > $f"
						;;
					.so|.dylib|.a|.bin)
						# Certains logiciels (clang + libc++) sont sélectifs: les binaires et bibliothèques privées sont mono-archi (celle du système), tandis que les bibliothèques publiques sont sur l'archi cible. On se garde d'un pétage lipo en vérifiant ce qu'il en est.
						aref="`archisBinDarwin "$f"`"
						ala="`archisBinDarwin "$multiarch_destLa/$f"`"
						case "$ala" in
							*" "*) continue ;; # Louche, le truc à rapatrier est déjà multi-archis. Forte probabilité d'explosion, on passe.
						esac
						case " $aref " in
							*" $ala "*) continue ;; # La référence possède déjà l'archi proposée.
						esac
						lipo -create "$f" "$multiarch_destLa/$f" -output "$TMP/$$/temp.lipo$suffixe" && sudo sh -c "chmod u+w $f ; cat $TMP/$$/temp.lipo$suffixe > $f" # Certains fichiers étant installés en non inscriptible (openssl), mieux vaut s'assurer les droits avant.
						;;
				esac
			fi
		done 6> "$TMP/$$/atarer"
		if [ -s "$TMP/$$/atarer" ]
		then
			( cd "$multiarch_destLa" && tr '\012' '\000' < "$TMP/$$/atarer" | xargs -0 tar cf - ) | sudoku tar xf -
		fi
		rm "$TMP/$$/atarer"
		sudo rm -Rf "$multiarch_destLa"
		shift
		shift
	done
}

archisBinDarwin()
{
	lipo -info "$1" | sed -e '1!d' -e 's/^[^:]*:[^:]*: //' -e 's/ $//' # "Non-fat file: x is architecture: " ou "Architectures in the fat file: x are: "
}

# Peut être surchargée pour modifier des fichiers avant combinaison.
# Paramètres: multiarchPrecombiner <arch> <dest pour arch>
multiarchPrecombiner()
{
	true
}

# multiarchConfigurer par défaut: ajout de -arch ou -march à CFLAGS et compagnie.
# Peut être surchargée par les logiciels à configuration d'archi exotique.
multiarchConfigurer()
{
	local attr="-march"
	case "`uname`" in
		Darwin) attr="-arch" ;;
	esac
	export CFLAGS="$attr $multiarch_arch $CFLAGS"
	export CXXFLAGS="$attr $multiarch_arch $CXXFLAGS"
	export LDFLAGS="$attr $multiarch_arch $LDFLAGS"
}
