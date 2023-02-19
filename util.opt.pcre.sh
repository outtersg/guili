# Inclut une version de PCRE.
# Les versions à tester sont listées (prerequisPcre pcre1 pcre2): la première déjà en place est choisie.
# Si aucune version n'est déjà installée:
# - Si le premier paramètre est -, tant pis, pas de PCRE.
# - Sinon, la première version proposée est incluse.
prerequisPcre()
{
	local pr_pcre="pcre" pr_pcre1="pcre < 10" pr_pcre2="pcre >= 10 < 30"
	# À FAIRE: déterminer automatiquement que si pcre1, les conditions sont réunies pour pcre, et donc l'ajouter pour exposition.
	#   Il faut pouvoir lister toutes les variables en pr_*, et pour chacune voir si _avec les prérequis actuels_ elle répond
	#   (donc il faut que la première étape ait remonté la version exacte trouvée soit précisée dans les prérequis;
	#    ex.:
	#      si en cherchant pcre une 8.45 a été trouvée, alors on doit indiquer qu'on a un +pcre+pcre1.
	#      si rien n'a été trouvé, mais que le GuiLI pcre propose de compiler une 10.42, alors on a un +pcre+pcre2.
	#      (PREREQUIS_THEORIQUES? INSTALLS_AVEC_INFOS? varsPrerequis -r)
	local oui non
	local param defaut pr pr_defaut
	for param in "$@" ; do option "$param" || true ; done # On consomme les options.
	# Les forçages demandés par l'utilisateur final passent devant l'ordre de priorité donné par le script nous invoquant.
	for param in `printf '%s\n' "$argOptions" | sed -e 's/-[^-+]*//g' -e 's/\+/ /g' -e 's/^  *//' -e 's/  */ /g'`
	do
		case " $* " in
			*" $param "*) set -- "$param" "$@"
		esac
	done
	for param in "" "$@"
	do
		case "$defaut" in "") defaut="$param" ;; esac
		
		case "$param" in
			-) continue ;;
		esac
		
		eval 'pr="$pr_'$param'"'
		if [ -n "$pr" ]
		then
			if optionSi "$param/$pr"
			then
				oui="$oui$param "
				break
			else
				non="$non$param "
				[ -n "$pr_defaut" ] || pr_defaut="$pr"
			fi
		fi
		
		# À FAIRE: si c'est le dernier param et qu'il n'y a pas de défaut, inutile de chercher une version existante: ajoutons-le aux prérequis d'office.
		
		# À FAIRE: combiner avec les autres prérequis. Si par exemple les prérequis imposent un pcre < 10, pas la peine de renvoyer +pcre2
		
		# Si toutes les options sont écartée, pas la peine de chercher plus loin.
		case "$argOptions-" in
			*-pcre[-+]*) return 0 ;;
		esac
	done
	
	case "$oui/$defaut" in
		""|/-) return 0 ;; # Rien trouvé et pas de défaut.
		/*)
			argOptions="`options $argOptions +$defaut`"
			prerequis="$prerequis $pr_defaut"
			;;
	esac
	
	# Ajout des options compatibles.
	case "$argOptions-" in
		*+pcre[-+]*) true ;;
		*+pcre[12]*) argOptions="`options $argOptions +pcre`" ;;
	esac
}
