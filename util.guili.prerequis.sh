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
	case "$modifs" in
		*exclusivementPrerequis*) true ;;
		*)
			case "$prerequis" in
				*openssl*)
					rouge "# Vous êtes joueur"\!" En prérequérant OpenSSL sans appeler exclusivementPrerequis, vous vous exposez à ce que $logiciel soit lié à la mauvaise version d'OpenSSL."
					;;
				*)
					jaune "# Attention, en n'appelant pas exclusivementPrerequis vous vous exposez à ce que le logiciel compilé se lie à des dépendances non désirées."
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
	IFS=';'
	for prcourant in $prdecoupes
	do
		unset IFS
		case "$prcourant" in
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
	_cheminsExportes
}

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
