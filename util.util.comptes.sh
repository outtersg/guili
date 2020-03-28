# Copyright (c) 2013,2017-2019 Guillaume Outters
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

#- Abstraction -----------------------------------------------------------------

if ! commande usermod
then
	usermod()
	{
		case `uname` in
			FreeBSD) pw usermod "$@" ;;
			*)
				echo "# Argh, impossible de faire un usermod $*" >&2
				return 1
				;;
		esac
	}
fi

#- Listes ----------------------------------------------------------------------

listeIdComptesBsd()
{
	(
		cut -d : -f 3 < /etc/group
		cut -d : -f 3 < /etc/passwd
		cut -d : -f 4 < /etc/passwd
		ypcat group 2> /dev/null | cut -d : -f 3
		ypcat user 2> /dev/null | cut -d : -f 3
		ypcat user 2> /dev/null | cut -d : -f 4
	) | sort -n
}

idCompteLibre()
{
	listeIdComptesBsd | sort -u > "$TMP/$$/uids"
	n=1000
	while grep -q "^$n$" < "$TMP/$$/uids"
	do
		n=`expr $n + 1`
	done
	echo "$n"
}

# Renvoie une liste de groupes uniques.
# groupesNormalises <liste> [<à soustraire>]
groupesNormalises()
{
	echo "$1" | tr ', ' '\012\012' | grep -v "^$2$" | grep -v ^$ | sort -u | tr '\012' , | sed -e 's/,$//'
}

#- Création et modification de comptes -----------------------------------------

_analyserParametresSusermod()
{
	local vars="qui"
	qui=
	groupe=
	autresGroupes=
	_apSusermodAuSecours() { echo "# susermod <qui> [-g <groupe>] [-G <autre groupe>]*" >&2 ; return 1 ; }
	_apSusermodAffecter() { [ $# -ge 2 ] || _apSusermodAuSecours || return $? ; export $2="$1" ; shift ; shift ; vars="$*" ; }
	while [ $# -gt 0 ]
	do
		case "$1" in
			-g) groupe="$2" ; shift ;;
			-G) autresGroupes="$autresGroupes,$2" ; shift ;;
			*) _apSusermodAffecter "$1" $vars || return $? ;;
		esac
		shift
	done
}

susermod()
{
	local qui groupe autresGroupes
	_analyserParametresSusermod "$@"

	local groupeActuel="`id -n -g "$qui"`"
	local autresGroupesActuels="`id -n -G "$qui"`"
	local optionsGroupe=

	# On est en mode accu: les -G s'ajoutent (et non remplacent) aux groupes actuels, le -g, s'il remplace le groupe actuel, l'ajoute aux -G.

	if [ ! -z "$groupe" -a "$groupe" != "$groupeActuel" ]
	then
		autresGroupes="$autresGroupes,$groupeActuel"
		optionsGroupe="-g $groupe"
	fi

	autresGroupes="`groupesNormalises "$autresGroupes" "$groupe"`"
	if [ ! -z "$autresGroupes" ]
	then
		autresGroupes="`groupesNormalises "$autresGroupes,$autresGroupesActuels" "$groupe"`"
		optionsGroupe="$optionsGroupe -G $autresGroupes"
	fi

	[ ! -z "$optionsGroupe" ] || return 0

	# À FAIRE: reporter les groupes existants (si le -g fait sauter le groupe actuel, le reporter en -G; si les -G omettent des groupes actuels, les ajouter (-a devrait le permettre sous Linux; à reconstituer sous FreeBSD)).
	case `uname` in
		FreeBSD)
			SANSSU=0 sudoku pw usermod "$qui" $optionsGroupe
			;;
		Linux)
			SANSSU=0 sudoku usermod "$qui" $optionsGroupe
			;;
	esac
}

_analyserParametresCreeCompte()
{
	local vars="cc_qui cc_id"
	cc_ou=
	cc_qui=
	cc_id=
	cc_groupes=
	cc_coquille=
	cc_mdp=
	while [ $# -gt 0 ]
	do
		case "$1" in
			-s) cc_coquille="$2" ; shift ;;
			-d) cc_ou="$2" ; shift ;;
			-g) cc_groupes="`echo "$2" | tr ': ' ',,'`" ; shift ;;
			--mdp) cc_mdp="$2" ; shift ;;
			*) apAffecter "$1" $vars ;;
		esac
		shift
	done
	
	[ -z "$cc_groupes" ] && cc_groupes=$cc_qui || true
	cc_groupe="`echo "$cc_groupes" | cut -d , -f 1`"
	[ ! -z "$cc_groupe" ] || cc_groupe="$cc_qui"
	cc_autres_groupes="`echo "$cc_groupes" | cut -d , -f 2-`"
}

suseradd()
{
	case `uname` in
		FreeBSD)
			SANSSU=0 sudoku pw useradd "$@"
			;;
		Linux)
			SANSSU=0 sudoku useradd "$@"
			;;
	esac
}

compteExiste()
{
	local source=passwd
	[ "x$1" = x-g ] && shift && source=group || true
	
	grep -q "^$1:" < /etc/$source && return 0 || true
	ypcat "$source" 2> /dev/null | grep -q "^$1:" && return 0 || true
	
	return 1
}

creeGroupe()
{
	local groupe="$1"
	local id="$2"
	if ! compteExiste -g "$groupe"
	then
		case `uname` in
			FreeBSD) SANSSU=0 sudoku pw groupadd "$groupe" -g "$id" ;;
			Linux) SANSSU=0 sudoku groupadd -g "$id" "$groupe" ;;
		esac
	fi
}

creeCompte()
{
	local cc_opts_coquille=
	
	_analyserParametresCreeCompte "$@"
	
	# Options POSIX de groupe.
	
	cc_opts_groupe= ; [ -z "$cc_groupe" ] || cc_opts_groupe="-g $cc_groupe"
	cc_opts_autres_groupes= ; [ -z "$cc_autres_groupes" ] || cc_opts_autres_groupes="-G $cc_autres_groupes"
	cc_opts_groupes="$cc_opts_groupe $cc_opts_autres_groupes"
	
	# Si le compte existe déjà, on le suppose correctement créé. Peut-être tout de même un rattachement de groupes à faire.
	if compteExiste "$cc_qui"
	then
		creeGroupe "$cc_groupe" "$cc_id"
		susermod $cc_qui $cc_opts_groupes
		return 0
	fi
	
	# Pas de doublon?
	
				if [ -z "$cc_id" ]
				then
			cc_id=`idCompteLibre`
				else
					if listeIdComptesBsd | grep -q "^$cc_id$"
					then
						echo "# Le numéro $cc_id (choisi pour le compte $cc_qui) est déjà pris." >&2
						exit 1
					fi
				fi
	
	# Création éventuelle du groupe principal.
	# $cc_id a été choisi pour n'être pris ni comme ID de compte, ni comme ID de groupe: on peut donc l'utiliser pour le nouveau groupe.
	
	creeGroupe "$cc_groupe" "$cc_id"
	
	# Options POSIX de dossier.
	
	cc_opts_ou=
	[ -z "$cc_ou" -o "x$cc_ou" = x- ] || cc_opts_ou="-d $cc_ou"
	[ -z "$cc_ou" ] || cc_opts_ou="$cc_opts_ou -m"
	
	# Options POSIX de shell.
	
	# -s -: par défaut; pas de -s: pas de shell (compte non interactif); -s <autre chose>: le shell indiqué.
	if [ "x$cc_coquille" != x- ]
	then
		[ -z "$cc_coquille" ] && cc_coquille="/coquille/vide" || true
		cc_opts_coquille="-s $cc_coquille"
	fi
	
	# Création!
	
	suseradd $cc_qui -u $cc_id $cc_opts_groupes $cc_opts_ou $cc_opts_coquille
	
	# Le mot de passe éventuel.
	
	case `uname` in
		FreeBSD)
			[ -z "$cc_mdp" ] || echo "$cc_mdp" | sudo pw usermod "$cc_qui" -h 0
			;;
		Linux)
			[ -z "$cc_mdp" ] || echo "$cc_mdp" | sudo passwd --stdin "$cc_qui"
			;;
	esac
}

compteInteractif()
{
	creeCompte -d - -s - "$@"
}
