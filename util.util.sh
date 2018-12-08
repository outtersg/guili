# Copyright (c) 2003-2005,2008,2011-2012,2018 Guillaume Outters
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

#-------------------------------------------------------------------------------
# Ensemble de fonctions utilitaires autonomes (ne dépendant pas de variables globales).
#-------------------------------------------------------------------------------

#- Système ---------------------------------------------------------------------

commande()
{
	command -v "$@" > /dev/null 2>&1
}

#- Réseau ----------------------------------------------------------------------

# Paramètre le maximum de logiciels pour passer par un proxy donné.
proxy()
{
	local ecrire=non
	local param
	while [ $# -gt 0 ]
	do
		case "$1" in
			-e|-w|-p) ecrire=oui ;; # écrire, write, persistence: le paramétrage est mis sur disque.
			-) param="$ALL_PROXY" ;;
			*) param="$1" ;;
		esac
		shift
	done
	case "$param" in
		*://*|"") ALL_PROXY="$param" ;;
		*) ALL_PROXY="http://$param" ;;
	esac
	
	# Variables d'environnement.
	
	export \
		http_proxy="$ALL_PROXY" \
		https_proxy="$ALL_PROXY" \
		HTTP_PROXY="$ALL_PROXY" \
		HTTPS_PROXY="$ALL_PROXY" \
		ALL_PROXY
	
	# Logiciels spécifiques.
	
	[ $ecrire = oui ] || return 0 # À partir de maintenant on fait des modifs persistentes.
	
	if commande npm
	then
		if [ ! -z "$http_proxy" ]
		then
		npm config set proxy "$http_proxy"
		else
			npm config rm proxy
		fi
		if [ ! -z "$https_proxy" ]
		then
		npm config set https-proxy "$https_proxy"
		else
			npm config rm https-proxy
		fi
	fi
}

#- Comptes ---------------------------------------------------------------------

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

#- Filtrage de fichiers --------------------------------------------------------

# À FAIRE: rapatrier filtrer, changerConf, etc.

#- Encodage / décodage ---------------------------------------------------------
# Voir aussi garg.sh

if command -v xxd > /dev/null 2>&1
then
	xencode() { xxd -p | tr '\012' ' ' ; }
	xdecode() { xxd -r -p ; }
else
	# https://stackoverflow.com/a/15554717/1346819
	xencode() { hexdump -e '16/1 "%02x " " "' ; }
	# https://www.unix.com/shell-programming-and-scripting/132294-reverse-hexdump-without-xxd.html
	xdecode() { ( echo 'ibase=16' ; cat | tr 'a-f ' 'A-F\012' ) | bc | awk '{printf("%c",$0)}' ; }
fi

# Temp IFS: réinitialise \$IFS après qu'il a été modifié pour un appel.
# Ex.:
#  params="p1|p2|p3"
#  IFS="|"
#  tifs commande $params
tifs()
{
	unset IFS
	"$@"
}
