# Copyright (c) 2010-2011,2016-2019 Guillaume Outters
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

#- Invocation ------------------------------------------------------------------

suer()
{
	argsSu="$1"
	shift
	[ "x$argsSu" = x- ] && argsSu="$argsSu $1" && shift || true
	
	argsColles="`for arg in "$@" ; do printf "%s" "$arg" ; done`"
	for sep in ' ' '|' '\t' ':' ';' '@' '#' '!' '+' '=' '\r' ; do
		commande="`for arg in "$@" ; do printf "%s$sep" "$arg" ; done | xencode`"
		# Si le séparateur est utilisé dans la commande, il va être difficile de s'en servir sans perdre notre shell. En ce cas on passe au séparateur suivant.
		echo "$argsColles" | grep -q "`printf %s "$sep"`" && continue || true
		su $argsSu -c 'commande="`SCRIPTS="'"$SCRIPTS"'" ; . "'"$INSTALL_SCRIPTS"'/util.util.sh" ; echo '"$commande"' | xdecode`" ; IFS="`printf '"'$sep'"'`" ; $commande'
		return $?
	done
	echo "# Impossible de trouver un séparateur shell qui ne soit pas utilisé par la commande: $*" >&2
	return 1
}

# sudoku: Super User DO KUrsaal (sudo destiné aux installs dans des emplacements partagés, donc a priori protégés: quand on est dans un kursaal, on respecte le mobilier, n'est-ce pas?)
sudoku()
{
	# On se met dans un sous-shell pour ne pas polluer l'environnement avec notre bazar.
	
	(
		# Analyse des paramètres.
		
			enTantQue=root
			ou="$INSTALLS"
			sudo_env=
			while [ "$#" -gt 0 ]
			do
				case "$1" in
					*=*)
						eval "$1"
						export "`echo "$1" | cut -d = -f 1`"
						sudo_env="$sudo_env$1$guili_sep"
						;;
					-u) shift ; enTantQue="$1" ;;
					-d) shift ; ou="$1" ;;
					-f) SANSSU=0 ;;
					*) break ;;
				esac
				shift
			done
		
		# Qu'a-t-on à notre disposition?
		
		# sdk_ecris: peut-on écrire dans le dossier cible?
		if [ -z "$sdk_ecris" -o -z "$sdk_ecrisDernierOu" -o "x$sdk_ecrisDernierOu" != "x$ou" ] # Un minimum de cache.
		then
		touch "$ou/.sudoku.temoin" 2> /dev/null && rm -f "$ou/.sudoku.temoin" 2> /dev/null && sdk_ecris=1 || sdk_ecris=0
			sdk_ecrisDernierOu="$ou"
		fi
		# sdk_vraiment: veut-on *vraiment* passer root?
		# Du fait de notre malheureuse surcharge de sudo, parfois notre sudoku est appelé pour faire du vrai sudo où on a vraiment besoin de passer root (même si $INSTALLS est inscriptible; par exemple pour ajouter à /usr/local/etc/rc.d un lien symbolique vers un de nos fichiers "à nous"). Pour cette usage, appeler SANSSU=0 sudoku ….
		[ "x$SANSSU" = x0 ] && sdk_vraiment=1 || sdk_vraiment=0
		# sdk_sudo: avons-nous un sudo à disposition?
		command -v sudo > /dev/null 2>&1 && sdk_sudo=1 || sdk_sudo=0
		# sdk_moi: suis-je root (0) ou autre (1)?
		[ "`id -u`" -eq 0 ] && sdk_moi=0 || sdk_moi=1
		# sdk_lui: même chose pour l'appelé.
		[ "`id -u $enTantQue`" -eq 0 ] && sdk_lui=0 || sdk_lui=1
		# sdk_diff: lui est-il différent de moi?
		[ "$sdk_moi$sdk_lui" = 00 -o "`id -u`" -eq "`id -u $enTantQue`" ] && sdk_diff=0 || sdk_diff=1
		
		# Exécution!
		
		case $sdk_moi$sdk_lui$sdk_diff$sdk_ecris$sdk_vraiment$sdk_sudo in
			??0???|?0?10?) "$@" ;; # excution directe si: 1. on est déjà le compte cible, ou 2. on est dans le cas spécifique de la tentative d'installation qui peut s'effectuer en tant que nous (on vise root et on arrive à écrire dans la destination et on ne nous a pas vraiment imposé de passer root par SANSSU=0).
			01????|?????0) suer - "$enTantQue" "$@" ;; # su si: 1. je suis root et qu'on me demande de passer autre chose (on suppose que l'admin ne s'est pas embêter à configurer le sudo pour root, puisqu'il a déjà tous les droits), ou 2. sudo n'est pas installé.
			?????1) IFS="$guili_sep" ; tifs $sudo -n -u "$enTantQue" $sudo_env "$@" ;; # sudo dans les autres cas (avec sudo de détecté…).
		esac
	)
}

#- Détection -------------------------------------------------------------------

# Remplaçons sudo.
# L'usage principal de notre sudo surchargé est l'installation dans les dossiers privilégiés; 
# En effet nous utilisons le sudo pour installer dans $INSTALLS, mais parfois ce n'est pas nécessaire de passer su pour cela.
detecterSudo()
{
	sudo="vraisudo" # sudoku a besoin que $sudo soit définie.
	# Malheureusement, historiquement, on a un peu abusé du sudo pour nos installs (au lieu d'utiliser le sudoku dédié, qui n'est arrivé qu'après); du coup, pour compatibilité, on doit conserver cette surcharge sudo = sudoku.
	sudo() { sudoku "$@" ; }
}

_commandMoinsVSudo()
{
	unalias sudo > /dev/null 2>&1 || true
	unset -f sudo > /dev/null 2>&1 || true
	# Des fois qu'on ait été compilé avec un $PATH minimal des seuls prérequis du logiciel (exclusivementPrerequis), pour les opérations avérées root (ex.: install) il va bien falloir s'adjoindre un sudo même s'il n'est pas prérequis explicite.
	sudoguili="`versions sudo | tail -1 || true`"
	[ -z "$sudoguili" ] || PATH="$PATH:$sudoguili/bin"
	command -v sudo
}

vraisudo()
{
	if [ -z "$sudo" -o "x$sudo" = xvraisudo ]
	then
		local _sudo="`_commandMoinsVSudo`"
		case "$_sudo" in
			/*) sudo="$_sudo" ;;
			*) echo "# sudo introuvable dans le PATH \"$PATH\" (pour \"sudo $@\")" >&2 && return 1 ;;
		esac
	fi
	[ -z "$SUDO_VERBOSE" ] || gris "sudo $*" >&2
	$sudo "$@"
}

#- Ajout de droits -------------------------------------------------------------

# Ajoute une commande au sudoers.
sudoer()
{
	sudoerSoudoie --sudo "$@" || true
	sudoerSudo "$@"
}

# Récupère le chemin d'un vrai de vrai logiciel "stable" sur le système (en s'efforçant de ne pas récupérer les surcharges temporaires, par exemple un soudoie installé salement par root avec tous les droits à tout le monde, juste le temps de l'install de _nginx par toto, histoire que toto ne soit pas embêté pour s'ajouter (pour plus tard une fois que le soudoie crade aura disparu) un nginx restart).
vraiEnDur()
{
	local l="$1"
	IFS=:
	for x in $PATH
	do
		unset IFS
		case "$x/" in
			*/tmp/*) continue ;;
		esac
		[ -x "$x/$l" ] && echo "$x/$l" && break
	done
	unset IFS
}

# Fait découper au shell son premier paramètre, et colle le résultat du découpage en fin de paramètres.
# Ex.:
#   sudoer_arguer "sh -c 'v=toi ; echo coucou \$v'" sudo -n -l
#   # est l'équivalent de:
#   sudo -n -l sh -c 'v=toi ; echo coucou $v'
sudoer_arguer()
{
	local trucs="$1" ; shift
	(
		set -f 
		eval '"$@" '"$trucs"
	)
}

sudoerSudo()
{
	# A-t-on déjà les droits?
	(
		sudo="`vraiEnDur sudo`"
		[ -n "$sudo" ] || exit 1
		set -f
		case "$2" in
			ALL) commande=true ;;
			*) commande="$2" ;;
		esac
		sudoer_arguer "$commande" sudoku -u "$1" "$sudo" -n -l > /dev/null 2>&1
	) && return || true
	gris "sudoers: $1 ALL=(ALL) NOPASSWD: $2" >&2
	echo "$1 ALL=(ALL) NOPASSWD: $2" | INSTALLS=/etc sudoku sh -c 'cat >> /etc/sudoers'
}

sudoerSoudoie()
{
	local qui= mode=soudoie quoi test pifs="`date`" pif="`date +%s`"
	local soudoie="`vraiEnDur soudoie`"
	local r=0
	
	for quoi in "$@"
	do
		# Les paramètres spéciaux.
		
		case "$quoi" in
			--sudo) mode=sudo ; continue ;;
		esac
		if [ -z "$qui" ]
		then
			qui="$quoi"
			continue
		fi
		
		# Ah, une commande! Est-elle au format sudo?
		
		if [ $mode = sudo ]
		then
			quoi="`echo "$quoi" | sed -e 's/ALL/*/g' -e 's/\*/**/g'`"
		fi
		
		# A-t-on déjà les droits?
		
		if [ -n "$soudoie" ]
		then
			test="`echo "$quoi" | sed -e 's#^\*\*#/bin/false **#' -e "s!\\*\\*!$pifs!g" -e "s!\\*!$pif!g"`"
			if sudoer_arguer "$quoi" sudoku -u "$qui" "$soudoie" -n -l > /dev/null 2>&1
			then
				continue
			fi
		fi
		
		# Bon ben il faut ajouter le droit.
		
		echo "$qui: $quoi" | INSTALLS=/etc sudoku sh -c 'cat >> /etc/surdoues' || r=$?
	done
	
	return $r
}

detecterSudo
