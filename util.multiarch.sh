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

# À FAIRE: supprimer cette fonction et multiarchLancer. Simplifier multiarchMemoriserInvocation et maLancer en virant l'$install_moi initial.
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
	local op f
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
					case "$f" in .complet|.guili*) continue ;; esac
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
