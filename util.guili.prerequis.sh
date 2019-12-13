# Copyright (c) 2010-2011,2013-2014,2017-2019 Guillaume Outters
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

prerequis()
{
	# Si l'environnement est configuré pour que nous renvoyons simplement nos prérequis, on obtempère ici (on considère qu'un GuiLI qui atteint ce point n'a plus rien à faire qui puisse influer sur le calcul de $prerequis.
	if [ ! -z "$PREREQUIS_THEORIQUES" ]
	then
		echo "#v:$version"
		echo "#p:$prerequis"
		exit 0
	fi
	# exclusivementPrerequis devrait systématiquement être appelé, pour s'assurer que l'environnement ne pointe que vers les prérequis explicites, et n'embarque pas des dépendances implicites. Cependant, le rattrapage pour migrer tout le monde est monumental, donc nous nous contentons d'une alerte.
	commande DelieS && modifs="exclusivementPrerequis $modifs" || true # On considère que les fichiers modernes, utilisant la dernière mouture de SCRIPTS (avec DelieS), sont prêts à faire de l'exclusivementPrerequis, autrement dit savent déclarer tous leurs prérequis plutôt que de reposer sur une détection.
	case "$modifs" in
		*exclusivementPrerequis*) true ;;
		*)
			case "$prerequis" in
				*openssl*)
					rouge "# Vous êtes joueur"\!" En prérequérant OpenSSL sans appeler exclusivementPrerequis, vous vous exposez à ce que $logiciel soit lié à la mauvaise version d'OpenSSL."
					;;
				*)
					jaune "# Attention, en n'appelant pas exclusivementPrerequis vous vous exposez à ce que $logiciel se lie à des dépendances non désirées."
					;;
			esac
			;;
	esac
	# Initialement on pondait dans un fichier, sur lequel on faisait un while read requis versionRequis ; do … ; done < $TMP/$$/temp.prerequis
	# (ce < après le done pour ne pas faire un cat $TMP/$$/temp.prerequis | while, qui aurait exécuté le while dans un sous-shell donc ne modifiant pas nos variables)
	# Problème: sous certains Linux, lorsque prerequerir() donne lieu à la compil d'un logiciel (car non encore présent sur la machine), mystérieusement le prochain tour de boucle renvoie false (comme si le prerequerir avait fait un fseek($TMP/$$/temp.prerequis, 0, SEEK_END).
	# On passe donc maintenant par de la pure variable locale, qui ne sera pas touchée entre deux tours de boucle…
	local prcourant requis versionRequis
	local prdecoupes="`decoupePrerequis "$prerequis" | tr '\012' \; | sed -e 's/;$//'`"
	[ -z "$prerequis" -o -n "$prdecoupes" ] || return 1 # Si $prdecoupes est vide alors que $prerequis non, decoupePrerequis a dû planter (mais son plantage est masqué par le | tr: le code de retour est celui du tr).
	IFS=';'
	for prcourant in $prdecoupes
	do
		unset IFS
		case "$prcourant" in
			\\|\\\\)
				# Coupure entre prérequis de compilation et prérequis à l'exécution.
				guili_ppath="<:$guili_ppath"
				;;
			*\(*\))
				local appel="`echo "$prcourant" | sed -e 's/ *( */,/' -e 's/ *)[^)]*$//' -e 's/ *, */,/'`"
				IFS=,
				tifs $appel
				;;
			*)
				prerequerir -l $prcourant
				;;
		esac
	done
	unset IFS
	# On modifie l'environnement pour lui ajouter tout ce qu'il faut pour la compilation (-L, -I, etc.), en allant chercher récursivement dans les prérequis de nos prérequis.
	if commande DelieS # … Uniquement sur les GuiLI modernes. À terme on forcera tout le monde à passer par là.
	then
	# À FAIRE: l'ordre n'est sans doute pas bon (<prérequis 1>:<pr 1 du pr 1>:<pr 2>); il vaudrait mieux sans doute d'abord lister tous les prérequis directs, puis tous ceux de niveau 1, etc. (<pr 1>:<pr 2>:<pr 1 du pr 1>).
	# Afin de ne pas polluer les guili_*path (devant contenir uniquement les prérequis directs), on les déclare locales pour contenir les prérequis des prérequis.
	local \
		guili_ppath="$guili_ppath" \
		guili_xpath="$guili_xpath" \
		guili_lpath="$guili_lpath" \
		guili_ipath="$guili_ipath" \
		guili_cppflags="$guili_cppflags" \
		guili_lflags="$guili_lflags" \
		guili_cxxflags="$guili_cxxflags" \
		guili_cxxflags="$guili_cxxflags" \
		guili_pcpath="$guili_pcpath" \
		guili_acpath="$guili_acpath" \
		chemins cheminsRecursifs
	chemins="`guili_prerequis_path`" # Où sont nos prérequis?
	cheminsRecursifs="`IFS=: ; tifs prereqs -u -d $chemins`" # Où sont les prérequis de nos prérequis?
	IFS=: ; tifs chemins $cheminsRecursifs # Eh bien on les prend et on les ajoute tous à l'environnement (-L, -I, etc.), histoire que la compile se passe bien.
	else
	_cheminsExportes
	fi
}

# S'assure de la présence d'un prérequis, en mode rapide (si quelque chose existe qui réponde aux critères, on ne s'embête pas à lui demander de vérifier ses propres prérequis récursivement, on le prend illico).
presentOuPrerequis()
{
	local present="`versions "$1" "$2" | tail -1`"
	if [ -z "$present" ]
	then
		prerequis="$prerequis $1 $2"
	else
		local rlvo="`rlvo "$present/"`"
		_reglagesCheminsPrerequis() { reglagesCheminsPrerequis -l "$2" "$3" "$1" ; }
		_reglagesCheminsPrerequis $rlvo
	fi
}

# S'assure des prérequis en la version précise codée dans le .guili.prerequis.
# L'intérêt est, pour un paquet binaire, de garantir à l'environnement d'exécution d'avoir a minima l'environnement de compil.
# Ex.:
# Notre php s'installe depuis les sources sur une machine vierge; mentionnant dans ses prérequis un simple "icu", il va installer la dernière version d'ICU listée dans les GuiLI, soit une ICU 6x (et se lier à libicu.so-6x).
# On l'installe ensuite sur une vieille machine qui avait déjà une icu-5y en place. Après avoir vérifié ses prérequis (l'icu installé suffit à répondre à la contrainte simple "icu"), l'installeur se rend compte qu'une version binaire existe (celle précédemment compilée) et l'installe. Mais là, sans postprerequis, pétage: libicu.so-6x introuvable.
# postprerequis va donc ajouter pour contraintes aux prérequis l'exacte version avec laquelle on a été compilés.
# Notons que si un prérequis du binaire est déjà présente en une version plus récente qu'indiqué dans le binaire, l'ancienne version sera installée, sans surcharger la nouvelle en tant que "par défaut". On aura donc au final côte à côte une libprerequis.so.1.0, une libprerequis.so.1.1, et une libprerequis.so.1 pointant vers la libprerequis.so.1.1: si le logiciel est lié en dur à libprerequis.so.1.0 il la trouvera, s'il utilise libprerequis.so.1 il bénéficiera de la version du prérequis qui a été compilée après lui (mais s'il s'y lie sans regarder la version mineure c'est sans doute qu'elle est compatible).
postprerequis()
{
	if [ "x$1" = x-e ]
	then
		shift
		guili_ppath=
	else
		local prerequis="$prerequis"
	fi
	local dest="$dest"
	[ -z "$1" ] || dest="$1"
	
	# On n'est capables de travailler que sur arbo précisant les prérequis avec lesquels elle a été installée.
	
	if [ ! -f "$dest/.guili.prerequis" ]
	then
		jaune "# Aucun .guili.prerequis dans $dest; il sera impossible de reconstituer à l'identique ses dépendances d'origine. " >&2
		return 0
	fi
	
	# Seuls les prérequis d'exécution nous intéressent. On retire donc ceux de compil.
	
	prerequis="`IFS='\' ; f() { while [ $# -gt 1 ] ; do shift ; done ; echo "$1" ; } ; f $prerequis`"
	
	# On combine les prérequis du scripts d'install avec ceux précisés dans le paquet binaire, avec pour règles:
	# - si on a une version précise d'installée, on fait sauter les autres contraintes sur la version (pour éviter les cas du genre après une génération de binaire avec une dépendance 1.0.3 du temps où la contrainte était >= 1.0, on s'est rendu compte qu'une >= 1.1 serait mieux, et on l'a inscrite dans l'installeur; la combinaison des deux nous donnerait un dépendance 1.0.3 >= 1.1, impossible à résoudre et donnant donc un échec. On privilégie donc la version binaire (après tout si ç'a été poussé ça doit sans doute quand même marcher).
	# - on combine les options
	#   Ainsi si le binaire précise +ossl10 et le prérequis déclaratif +postgresql, on aura du +postgresql+ossl10.
	#   Plus important, si le déclaratif demande du +ossl+-mysql (forcément avec ossl, et forcément sans mysql), les - n'étant pas reflétés dans le chemin, le binaire ne précise que le +ossl: aussi si on se contentait des options du binaire (+ossl), on risquerait de se lier au +mysql+ossl (considéré comme surensemble du +ossl). Il est donc important d'inclure les règles d'exclusion (qui ne figurent donc que dans les prérequis déclarés dans l'installeur, pas dans le binaire).
	
	prerequis="$prerequis `sed < "$dest/.guili.prerequis" -e '/^#/,$d' -e 's#^.*/##' -e 's/-\([^-]*\)/ \1/' | tr '\012' ' '`" # Dans le .guili.prerequis on s'arrête au premier commentaire (prérequis des prérequis).
	# Dans la recombinaison résultante, on va avoir des "logiciel >= 3 < 4 3.1.4" (où une version figée aura été trouvée, qui supplante toutes les contraintes précédentes), et des "logiciel >= 3 < 4" (où étrangement le paquet compilé ne s'est pas lié à une version, mais bon ça n'est pas notre affaire, simplement prerequis() se tapera d'aller choisir la version exacte dans laquelle installer le prérequis).
	# On va en garder respectivement "logiciel 3.1.4" et "logiciel >= 3 < 4", supprimant les contraintes uniquement si elles précèdent une version exacte.
	prerequis="`decoupePrerequis "$prerequis" | sed -e '/ .*[0-9]  *\([0-9][.0-9]*\)$/s## \1#g'`"
	
	gris "postprerequis: `echo "$prerequis" | tr '\012' ' '`"
	prerequis
}

# Plusieurs modes de fonctionnement:
# - par défaut: cherche une version parmi celles installées; si trouvée, elle fait foi; sinon installe.
# - -i: installe la dernière version si pas déjà en place.
# - -n: fait comme si on installait la dernière version.
varsPrerequis()
{
	local vp_vars=
	local paramsInclure=
	while [ $# -gt 0 ]
	do
		vp_vars="$vp_vars $1"
		case "$1" in
			-n|-i) true ;;
			*) break ;;
		esac
		shift
	done
	shift
	
	decoupePrerequis "$*" > $TMP/$$/temp.prerequis
	while read vp_logiciel vp_version
	do
		case "$vp_logiciel" in
			*\(*\)) true ;;
			*)
				paramsInclure="$vp_logiciel"
				[ -z "$vp_version" ] || paramsInclure="$paramsInclure|$vp_version"
				IFS=\|
				INSTALLS_AVEC_INFOS="$vp_vars" tifs inclure $paramsInclure 6>&1 >&2
				;;
		esac
	done < $TMP/$$/temp.prerequis
}

inclure()
{
	inclure_logiciel="`echo "$1" | cut -d + -f 1`"
	inclure_options="`echo "$1" | sed -e 's/^[^+]*//' -e 's/[+]/ +/g'`"
	truc=`cd "$SCRIPTS" && ls -d "$inclure_logiciel-"[0-9]* "$inclure_logiciel" 2> /dev/null | tail -1`
	if [ -z "$truc" ] ; then
		echo '# Aucune instruction pour installer '"$inclure_logiciel" >&2
		return 1
	fi
	shift
	INSTALLS_AVEC_INFOS="$INSTALLS_AVEC_INFOS" "$SCRIPTS/$truc" $inclure_options "$@"
	return $?
}

inclureBiblios()
{
	local v b
	local trou=
	[ "x$1" = x-t ] && trou=oui && shift
	local dou="$1"
	[ -z "$dou" ] || dou="$dou/"
	for biblio in $biblios
	do
		v="`echo "$biblio" | cut -d : -f 2`"
		b="`echo "$biblio" | cut -d : -f 1`"
		[ -z "$v" ] || v="-v $v"
		if [ -z "$trou" ]
		then
			inclure $dou$b $v
		else
			inclure $dou$b $v || true
		fi
	done
}
