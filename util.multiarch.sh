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

multiarch()
{
	mac || return 0 # Pour le moment je ne sais pas faire sur d'autres plates-formes que le Mac.
	
	if [ -z "$multiarch_arch" ]
	then
		multiarchLancer
		exit 0
	else
		dest="$dest.$multiarch_arch"
		[ -z "$install_dest" ] || dest="$install_dest"
		multiarchConfigurer
	fi
}

mas()
{
	# Pour quelles archis va-t-on travailler?
	
	multiarch_archs=
	case "`uname`" in
		Darwin)
			multiarch_archs="x86_64 i386"
			;;
	esac
}

multiarchLancer()
{
	# Pour quelles archis va-t-on travailler?
	
	mas
	
	# En avant!
	
	multiarch_premiereArch="`echo "$multiarch_archs" | awk '{print $1}'`"
	for multiarch_arch in $multiarch_archs
	do
		multiarch_dossierTravail="../$logiciel-$version-$multiarch_arch"
		multiarch_dest="$dest"
		[ "$multiarch_arch" = "$multiarch_premiereArch" ] || multiarch_dest="$INSTALLS/$logiciel-$version-$multiarch_arch" # La première architecture va s'installer à l'endroit officiel.
		cp -R . "$multiarch_dossierTravail"
		IFS="`printf '\003'`"
		$multiarch_invocation --src "$multiarch_dossierTravail" --arch "$multiarch_arch" --dest "$multiarch_dest"
		unset IFS
		multiarch_paramsCombiner="$multiarch_paramsCombiner $multiarch_arch $multiarch_dest"
	done
	
	# Et on combine.
	
	multiarchCombiner
}

multiarchCombiner()
{
	multiarch_combineur="multiarchCombiner`uname`"
	$multiarch_combineur $multiarch_paramsCombiner
}

multiarchCombinerDarwin()
{
	multiarch_archRef="$1" ; shift
	multiarch_destRef="$1" ; shift
	while [ $# -gt 0 ]
	do
		cd "$multiarch_destRef"
		
		multiarch_archLa="$1"
		multiarch_destLa="$2"
		multiarchPrecombiner "$multiarch_archLa" "$multiarch_destLa"
		# À FAIRE: gérer les Only in $multiarch_destLa
		diff -rq . "$multiarch_destLa" 2> /dev/null | sed -e '/^Only/d' -e 's/^Files //' -e 's/ and .*differ//' | while read f
		do
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
						lipo -create "$f" "$multiarch_destLa/$f" -output "$TMP/$$/temp.lipo$suffixe" && sudo sh -c "chmod u+w $f ; cat $TMP/$$/temp.lipo$suffixe > $f" # Certains fichiers étant installés en non inscriptible (openssl), mieux vaut s'assurer les droits avant.
						;;
				esac
			fi
		done
		sudo rm -Rf "$multiarch_destLa"
		shift
		shift
	done
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
