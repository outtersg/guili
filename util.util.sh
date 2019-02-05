# Copyright (c) 2003-2005,2008,2011-2012,2018-2019 Guillaume Outters
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

#- Affichage -------------------------------------------------------------------

couleur()
{
	local format="$1" ; shift
	if [ $# -gt 0 ]
	then
		echo "[${format}m$@[0m"
	else
		sed -e "s/^/[${format}m/" -e "s/$/[0m/"
	fi
}

rouge() { couleur 31 "$@" ; }
jaune() { couleur 33 "$@" ; }
vert() { couleur 32 "$@" ; }
gris() { couleur 90 "$@" ; }
bleu() { couleur 34 "$@" ; }
cyan() { couleur 36 "$@" ; }
magenta() { couleur 35 "$@" ; }

#- Système ---------------------------------------------------------------------

commande()
{
	command -v "$@" > /dev/null 2>&1
}

#- Réseau ----------------------------------------------------------------------

# Chope l'hôte et le port des URL passées sur l'entrée standard.
hoteEtPort()
{
	sed -e h -e '/^[a-zA-Z0-9]*:\/\//!s/^.*$/80/' -e 's/:.*//' -e 's/^http$/80/' -e 's/^https$/443/' -e x -e 's#^[a-zA-Z0-9]*://##' -e 's#/.*$##' -e G -e 'y/\n/:/' -e 's/:/ /' -e 's/:.*//' -e 's/ /:/'
}

# Paramètre le maximum de logiciels pour passer par un proxy donné.
# Utilisation: proxy [-e|-w|-p] [-s] [<hôte>:<port>|-]
#   -e|-w|-p
#     Écris la config dans les fichiers persistents (.profile, etc.).
#     (-e comme écrire, -w comme write, -p comme persistent)
#   -s
#     Écris les fichiers système (/etc/profile, etc.).
#     Attention! Il est nécessaire de mentionner -w -s (par sécurité), sans quoi
#     l'option est ignorée.
#   <hôte>:<port>
#     Proxy à taper.
#   -
#     Utiliser la valeur de $ALL_PROXY.
proxy()
{
	local ecrire=non
	local systeme=non
	local param
	while [ $# -gt 0 ]
	do
		case "$1" in
			-e|-w|-p) ecrire=oui ;; # écrire, write, persistence: le paramétrage est mis sur disque.
			-s) systeme=oui ;;
			-) param="$ALL_PROXY" ;;
			*) param="$1" ;;
		esac
		shift
	done
	if [ $ecrire = non -a $systeme = oui ]
	then
		echo "# proxy: précisez -w -s pour modifier le système." >&2
		return 1
	fi
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
	
	local phh="`echo "$http_proxy" | hoteEtPort | cut -d : -f 1`"
	local php="`echo "$http_proxy" | hoteEtPort | cut -d : -f 2`"
	local psh="`echo "$https_proxy" | hoteEtPort | cut -d : -f 1`"
	local psp="`echo "$https_proxy" | hoteEtPort | cut -d : -f 2`"
	
	# Logiciels spécifiques.
	
	[ $ecrire = oui ] || return 0 # À partir de maintenant on fait des modifs persistentes.
	
	local f
	for f in "$HOME/.profile" "$HOME/.shrc" "$HOME/.bashrc"
	do
		[ -e "$f" ] || continue
		filtrer "$f" sed -e '/^# Proxy$/,/^# Fin proxy$/d'
		cat >> "$f" <<TERMINE
# Proxy
export \\
	http_proxy="$http_proxy" \\
	https_proxy="$https_proxy" \\
	HTTP_PROXY="$HTTP_PROXY" \\
	HTTPS_PROXY="$HTTPS_PROXY" \\
	ALL_PROXY="$ALL_PROXY"
# Fin proxy
TERMINE
	done
	
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
	
	( ls -d $HOME/.mozilla/firefox/*.default/ 2> /dev/null || true ) | while read dossierFF
	do
		(
			cat >> "$dossierFF/user.js" 2> /dev/null <<TERMINE
user_pref("network.proxy.ftp", "$phh");
user_pref("network.proxy.ftp_port", $php);
user_pref("network.proxy.http", "$phh");
user_pref("network.proxy.http_port", $php);
user_pref("network.proxy.share_proxy_settings", true);
user_pref("network.proxy.socks", "$phh");
user_pref("network.proxy.socks_port", $php);
user_pref("network.proxy.ssl", "$psh");
user_pref("network.proxy.ssl_port", $psp);
user_pref("network.proxy.type", 1);
TERMINE
		) || true
	done
	
	[ $systeme = oui ] || return 0 # À partir de maintenant on fait des modifs système.
	
	# À FAIRE: /etc/profile
	
	if commande snap && [ -f /etc/environment ]
	then
		sudoku -d /etc/ sh -c "
cd /etc/ \\
&& \\
( \\
	egrep -v '^((http|https)_proxy|(HTTP|HTTPS|ALL)_PROXY)=' < environment \\
	&& cat <<TERMINE
http_proxy=\"$http_proxy\"
https_proxy=\"$https_proxy\"
HTTP_PROXY=\"$HTTP_PROXY\"
HTTPS_PROXY=\"$HTTPS_PROXY\"
ALL_PROXY=\"$ALL_PROXY\"
TERMINE
) \\
> environment.temp && cat environment.temp > environment && rm environment.temp
"
		sudoku -d /etc/ systemctl restart snapd
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

# Reconstitue dans une arbo les fichiers de conf en fusionnant les .defaut avec les modifications effectuées sur une arbo plus ancienne.
# Utilisation:
#   perso <cible> <existant>*
#     <cible>
#       Dossier sur lequel reporter les modifications d'un <existant>
#     <existant>
#       Dossier contenant des fichiers (ou dossiers) .original à côté d'un
#       modifié.
#       Si <existant> a la forme +<chemin>, alors on cherchera tout élément
#       suffixé .original dans l'<existant>. Sinon on se contentera de ceux
#       correspondant à un élément de <cible>.
#       Le + a donc un intérêt pour rechercher les fichiers modifiés dans un
#       existant n'ayant plus de correspondant dans la <cible>, signe que la
#       <cible> ne pourra reprendre la personnalisation. D'un autre côté, il ne
#       faut surtout pas utiliser le + sur une arbo complète, par exemple
#       /usr/local, qui agrège les .original de plusieurs logiciels.
# Ex.:
#   # Si l'on s'apprête à déployer notre logiciel-2.0 en /usr/local/, où logiciel-1.0 s'était déjà installé, et avait été ensuite personnalisé.
#   perso /tmp/logiciel-2.0 /usr/local
perso()
{
	local suffixe=".original"
	
	local cible="$1" ; shift
	local source
	local modeListage
	
	# On crée les fichiers à partir de nos défauts.
	
	(
		cd "$cible"
		find . -name "*$suffixe" | while read defaut
		do
			fcible="`dirname "$defaut"`/`basename "$defaut" "$suffixe"`"
			[ -e "$fcible" ] || cp -Rp "$defaut" "$fcible"
		done
	)
	
	# Dans les arbos de départ, on essaie de trouver des fichiers modifiés à côté de leur version d'origine.
	
	> /tmp/temp.perso.$$
	> /tmp/temp.perso.$$.tar
	for source in "$@"
	do
		modeListage=cible
		case "$source" in
			+*)
				source="`echo "$source" | cut -c 2-`"
				modeListage=source
				;;
		esac
		(
			if [ $modeListage = source ]
			then
				cd "$source" && find . -mindepth 1 -name "*$suffixe"
			else
				cd "$cible" && find . -mindepth 1 ! -name "*$suffixe" | sed -e "s/$/$suffixe/"
			fi
		) | grep -v ^$ | tr '\012' '\000' | ( # Suppression des lignes vides: blindage contre les sed qui rajoutent une fin de ligne.
			cd "$source"
			( xargs -r -0 ls -d 2> /dev/null || true ) | grep -v -f /tmp/temp.perso.$$ | sed -e "s/$suffixe$//" | while read f
			do
				echo "$f" >> /tmp/temp.perso.$$
				diff -rq "$f$suffixe" "$f" | grep -F "Only in $f: " | sed -e 's/^Only in //' -e 's#: #/#' || true
				diff -ruw "$f$suffixe" "$f" >&7 || true
			done | tr '\012' '\000' > /tmp/temp.perso.$$.only
			if [ -s /tmp/temp.perso.$$.only ]
			then
				xargs -0 < /tmp/temp.perso.$$.only tar cf /tmp/temp.perso.$$.tar
			fi
		) 7>&1
	done | sed -e "s#^\(--- [^	]*\)$suffixe#\1#" | \
	(
		cd "$cible"
		patch -p0 -l || \
		(
			echo "# Attention, les personnalisations de $* n'ont pu être appliquées. Consultez:"
			find . -name "*.rej" | sed -e 's/^/  /'
		) | rouge >&2
		if [ -s /tmp/temp.perso.$$.tar ]
		then
		tar xf - < /tmp/temp.perso.$$.tar
		fi
	)
	rm -f /tmp/temp.perso.$$ /tmp/temp.perso.$$.only /tmp/temp.perso.$$.tar
}

# Dans une arbo à la $INSTALLS de Guillaume (bin/toto -> ../toto-1.0.0/bin/toto), cherche le "logiciel" le plus référencé depuis des chemins d'un dossier local.
# Utilisation:
#   leplusdelienscommuns <dossier local> <référentiel>
#     <dossier local>
#       "Petit" dossier dont on va rechercher les fichiers dans le référentiel.
#     <référentiel>
#       Gros dossier supposé contenir des liens symboliques de la forme ../logiciel-version/….
# Ex.:
#   Avec un <dossier local> contenant:
#     bin/toto
#     bin/titi
#     lib/libtoto.so
#   Et un <référentiel> contenant:
#     bin/toto -> ../toto-1.0.0/bin/toto
#     bin/titi -> ../titi-0.9/bin/titi
#     lib/libtoto.so -> ../toto-1.0.0/lib/libtoto.so
#   Renverra:
#     toto-1.0.0
leplusdelienscommuns()
{
	local f
	local dlocal="$1"
	local dref="$2"
	
	( cd "$dlocal" && find . -mindepth 1 ) | \
	(
		cd "$dref"
		while read f
		do
			if [ -L "$f" -a -e "$f" ]
			then
				readlink "$f"
			fi
		done | awk '{sub(/^(\.\.\/)*/,"");sub(/\/.*/,"");if(!n[$0])n[$0]=0;++n[$0]}END{nmax=0;for(i in n)if(n[i]>nmax){nmax=n[i];cmax=i}if(nmax)print cmax}'
	)
}

# perso() pour une arbo "mode installs de Guillaume". On va chercher les éventuels originaux des fichiers de notre cible, mais aussi les originaux "orphelins" (n'ayant pas de correspondant de la source déterminée 
iperso()
{
	local dossier
	
	# Recherche de liens symboliques à la sauce "installs de Guillaume".
	# Comme ils sont noyés dans $INSTALLS au milieu des liens symboliques vers plein d'autres logiciels, on ne cherche que ceux correspondant à un fichier de notre cible. Il y aura sans doute quelques petites différences, mais sur le nombre on devrait avoir suffisamment de témoins pour pouvoir faire de la statistique et retrouver notre dossier source le plus probable.
	
	dossier="`leplusdelienscommuns "$1" "$INSTALLS"`"
	if [ -z "$dossier" ]
	then
		perso "$@" "$INSTALLS"
	else
		perso "$@" "$INSTALLS" "+$INSTALLS/$dossier"
	fi
}

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
