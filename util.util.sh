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

#- Calcul ----------------------------------------------------------------------

# Comparaison de version.
# Renvoie 0 si le premier paramètre (num de version) est plus grand que le second. Avec l'option -e, on fait du plus grand ou égal.
pg()
{
	local r=0
	egal=
	if [ "x$1" = x-e ] ; then egal="-e" ; shift ; fi
	# On pourrait simplifier toute la fin en IFS=. pgInterne $egal "$1" $2, si seulement les vieux sh ne faisaient pas baver la déclaration d'IFS hors de l'appel à pgInterne.
	IFS=.
	pgInterne $egal "$1" $2 || r=1
	unset IFS
	return $r
}

pgInterne()
{
	ouEgal=false
	[ "x$1" = x-e ] && ouEgal=true && shift
	a="$1"
	shift
	for i in $a
	do
		[ -z "$1" -o "0$i" -gt "0$1" ] && return 0
		[ "0$i" -lt "0$1" ] && return 1
		shift
	done
	$ouEgal && [ -z "$1" ]
}

# Comparaison de version, version awk.
# Là pour le plaisir de l'exercice: permettait un gain à l'époque où pg() instanciait deux sous-processus (avec un seul awk, on divisait donc par deux le temps d'exécution, essentiellement passé à forker). Maintenant que pg() est optimisé, c'est nous qui sommes battus (1,5 s pour 1000 appels sur mon FreeBSD), mais cette implémentation pourra servir si on a un grand nombre d'entrées à traiter quelque part, ou bien de la comparaison à faire dans le cadre d'un awk plus complexe.
pgawk()
{
	local compn=">"
	[ "x$1" = x-e ] && compn=">=" && shift || true
	
	awk -F . "BEGIN{
		ng = split(\"$1\", g);
		nd = split(\"$2\", d);
		nmin = ng > nd ? nd : ng;
		for(pos = 0; ++pos <= nmin;)
			if((diff = g[pos] - d[pos]))
				exit diff < 0 ? 1 : 0;
		exit ng $compn nd ? 0 : 1;
	}"
}

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
vertc() { couleur 92 "$@" ; }
gris() { couleur 90 "$@" ; }
bleu() { couleur 34 "$@" ; }
bleuc() { couleur 94 "$@" ; }
ciel() { couleur 96 "$@" ; }
cyan() { couleur 36 "$@" ; }
magenta() { couleur 35 "$@" ; }
orange() { couleur 91 "$@" ; }
rose() { couleur 95 "$@" ; }

# Exécute une commande, après l'avoir affichée façon set -x (ce dernier point seulement s'il s'agit d'un vrai binaire, et non pas une fonction shell encapsulante).
affSiBinaire()
{
	case "`command -v "$1" 2> /dev/null || true`" in
		/*) gris "$@" >&2
	esac
	
	"$@"
}

# Notifie d'une erreur, et sort en erreur shell (ce qui, combiné à un set -e, est fatal à moins d'être récupéré par un || true).
err()
{
	rouge "$@" >&2
	return 1
}

fatal()
{
	rouge "$@" >&2
	exit 1
}

#- Système ---------------------------------------------------------------------

commande()
{
	command -v "$@" > /dev/null 2>&1
}

biblios()
{
	case `uname` in
		Darwin) otool -L "$@" ;;
		*) ldd "$@" ;;
	esac | grep '^	.*(.*)$' | sed -e 's/^	//' -e 's/ *([^)]*)$//' -e 's/^[^/]* => //' | grep -v '[(>]' | grep '^/'
}

readlinky()
{
	case `uname` in
		Linux) readlink -e "$@" ;;
		*)
			local c="$1"
			case "$c" in [^/]*) c="`pwd`/$c" ;; esac
			IFS=/
			c="`_readlinky $c`"
			unset IFS
			[ -e "$c" ] || return 1
			echo "$c"
			;;
	esac
}

_readlinky()
{
	# À FAIRE: en marche arrière, d'une on repérerait plus rapidement les .., de deux si un lien en fin était un absolu on le trouverait rapidement et on remplacerait tout par ce chemin absolu sans calculer les liens relatifs intermédiaires.
	local r= l
	while [ $# -gt 0 ]
	do
		case "$1" in
			""|.) true ;;
			..)
				_readlinky_remonte $r
				;;
			*)
				if [ -L "$r/$1" ]
				then
					l="`readlink "$r/$1"`"
					case "$l" in
						/*) r= ;;
					esac
					shift
					set -- $l "$@"
					continue
				fi
				r="$r/$1"
				;;
		esac
		shift
	done
	echo "$r"
}

_readlinky_remonte()
{
	r=
	shift # Le premier est un /
	while [ $# -gt 1 ] ; do r="$r/$1" ; shift ; done
}

# readlink -e, mais qui ne cherche pas à résoudre $INSTALLS.
# Ce de façon à pouvoir comparer son résultat à $INSTALLS de façon normalisée:
# Avec $INSTALLS valant /home/gui/local
# si readlinky $INSTALLS/lib/libation.so vaut /usr/home/gui/local/ation-1.0/lib/libation.so.1.0
#       lilien $INSTALLS/lib/libation.so vaut     /home/gui/local/ation-1.0/lib/libation.so.1.0
# ce qui permet de préserver l'$INSTALLS au départ.
lilien()
{
	if [ -z "$lilien_installs" -o -z "$_lilien_iorig" -o "$_lilien_iorig" != "$lilien_installs" -o -z "$_lilien_ibis" ]
	then
		[ -n "$lilien_installs" ] || lilien_installs="$INSTALLS"
		_lilien_iorig="$lilien_installs"
		_lilien_ibis="`readlinky "$_lilien_iorig"`"
	fi
	local r="`readlinky "$1"`"
	[ -n "$r" ] || return 1
	case "$r" in
		"$_lilien_ibis"*) echo "$r" | sed -e "s#^$_lilien_ibis#$_lilien_iorig#" ; return ;;
	esac
	echo "$r"
}

#- Système: environnement chemins ----------------------------------------------

reglagesCheminsPrerequis()
{
	# L'option -l permet de travailler avec des variables locales, afin d'accumuler sans incidence sur l'environnement (on exportera en une fois, à la fin).
	# Ceci sert par exemple lorsque l'on boucle sur les prérequis d'un gros logiciel, dont libjpeg puis openssl: si l'on exporte dès après avoir compilé libjpeg, openssl se retrouve à compiler avec tous les -Llibjpeg dont il n'a que faire. Ça ne devrait pas poser problème mais c'est malpropre.
	
	local rc_local=
	[ "x$1" = x-l ] && rc_local=oui && shift || true
	
	local rc_logiciel="$1"
	local versionInclus="$2"
	local dossierRequis="$3"
	
	PREINCLUS="$PREINCLUS $rc_logiciel:$versionInclus"
	eval "dest`echo "$1" | tr +- __`=$dossierRequis"
	eval "version_`echo "$1" | tr +- __`=$versionInclus"
	chemins "$dossierRequis"
}

# Règle tous les chemins pour aller taper dans une arbo conventionnelle (bin, lib, include, etc.).
chemins()
{
	unset IFS # Des fois que notre appelant l'ait réglé à :
	
	itinerairesSauvegardeEnv
	
	local optionsPreChemin=
	[ "x$1" = x--sans-c-cxx ] && optionsPreChemin="$1" && shift || true
	local i=$#
	local racine
	# Si on appelle chemins /usr/local /usr sur un $PATH qui contient déjà /bin, on voudra finir avec /usr/local/bin:/usr/bin:/bin.
	# Une petite gymnastique est donc requise pour les introduire dans le bon ordre.
	while [ $i -gt 0 ]
	do
		eval "racine=\${$i}"
		i=`expr $i - 1` || true # Crétin d'expr qui sort si son résultat est 0. Ce sera aussi notre condition de sortie, mais laissez-moi faire mon dernier tour de boucle, voulez-vous bien?
		
		case "$guili_ppath:" in
			"$racine":*) continue ;; # Déjà en tête de chemin.
		esac
		
		guili_ppath="$racine:$guili_ppath" # p comme prérequis, ou préfixes.
		
		# À FAIRE: ce truc-là ne pourrait-il pas aller dans itineraireBis?
		# Pour le moment il ne fonctionne qu'en préfixage, donc non, mais à voir.
		# D'autant que son bout de code pour éviter les duplications devrait être inutile du fait du "Déjà en tête de chemin" plus haut.
		# /!\ Peut-être à glisser *avant* la vérification d'unicité qui ne conserve que le premier: sur du -L / -I etc., n'est-ce pas le *dernier* qu'il faut conserver? Que prend en compte le compilo?
		preParamsCompil "$racine"
	done
	[ oui = "$rc_local" ] || _cheminsExportes
}

_pverso()
{
	local option="$1" ; shift
	echo "$*" | sed -e 's/^:*/:/' -e 's/:*$//' -e 's/::*/:/g' -e "s#:# $option #g"
}

_cheminsExportes()
{
	itineraireBis # Mise à jour des $guili_*path.
	
	local guili_acflags="`_pverso -I "$guili_acpath"`"
	ACLOCAL="`echo "$guili_env_ACLOCAL" | sed -e 's/^ *$/aclocal/' -e "s#aclocal#aclocal$guili_acflags#"`"
	export \
		PATH="$guili__xpath$guili_xpath$guili_env_PATH" \
		LD_LIBRARY_PATH="$guili_lpath$guili_env_LD_LIBRARY_PATH" \
		CMAKE_LIBRARY_PATH="$guili_lpath$guili_env_CMAKE_LIBRARY_PATH" \
		LDFLAGS="$guili_lflags $guili_env_LDFLAGS" \
		CPPFLAGS="$guili_cppflags $guili_env_CPPFLAGS" \
		CFLAGS="$guili_cflags $guili_env_CFLAGS" \
		CXXFLAGS="$guili_cxxflags $guili_env_CXXFLAGS" \
		CMAKE_INCLUDE_PATH="$guili_ipath$guili_env_CMAKE_INCLUDE_PATH" \
		PKG_CONFIG_PATH="$guili_pcpath$guili_env_PKG_CONFIG_PATH" \
		ACLOCAL \
		ACLOCAL_PATH="$guili_acpath$guili_env_ACLOCAL_PATH"
}

_rc_export()
{
	[ -z "$rc_local" ] || return 0
	
	local sep=" "
	[ "x$1" = x-d ] && sep="$2" && shift && shift || true
	local existant nouveau
	
	while [ $# -gt 0 ]
	do
		eval "existant=\"\$$1\""
		# Quelle portion de la fin de notre ajout correspond au début de l'existant? En effet il ne servira à rien de mettre d'affilée deux fois la même séquence (ex.: -L/usr/local/lib -L/usr/lib -L/usr/local/lib -L/usr/lib).
		# Ceci ne vaut que pour la fin de l'ajout préfixé et le début de l'existant, pas les milieux: l'ordre de prise en compte pouvant varier selon les compilos, pour s'assurer qu'un élément sera toujours pris en priorité on peut souhaiter l'accoler au début ET à la fin, en ce cas il ne faut pas qu'on supprime la fin parce qu'elle ressemble au début.
		nouveau="`args_reduc -d "$sep" "$2" "$existant"`"
		eval 'export '"$1"'="$nouveau"'
		shift
		shift
	done
}

preCFlag()
{
	if [ "x$1" = x--sans-c-cxx ]
	then
		shift
	else
		guili_cxxflags="$* $guili_cflags"
		guili_cxxflags="$* $guili_cxxflags"
		_rc_export CFLAGS "$*" CXXFLAGS "$*"
	fi
	guili_cppflags="$* $guili_cppflags"
	_rc_export CPPFLAGS "$*"
}

preParamsCompil()
{
	local d
	local paramsPreCFlag=
	if [ "x$1" = x--sans-c-cxx ]
	then
		paramsPreCFlag="$1"
		shift
	fi
	preCFlag $paramsPreCFlag "-I$1/include"
	for d in $1/lib64 $1/lib
	do
		if [ -d "$d" ]
		then
			guili_lflags="-L$d $guili_lflags"
			_rc_export LDFLAGS "-L$d"
		fi
	done
}

# Petite exception à notre règle "pas de variable globale dans ce fichier": dès qu'on a défini chemin(), on charge un éventuel environnement, afin de pouvoir dans ce qui suit détecter de nouveaux logiciels (et donc mettre en place ou non des palliatifs).

. "$SCRIPTS/util.itineraires.sh" # Devrait s'appeler util.util.itineraires.sh, mais doit être manuellement inclus en premier pour avoir dans notre $PATH les utilitaires qu'on est amenés à pallier dans la suite.
if [ ! -z "$chemins_init" ]
then
	$chemins_init
fi

#- Réseau ----------------------------------------------------------------------

# Chope l'hôte et le port des URL passées sur l'entrée standard.
hoteEtPort()
{
	sed -e h -e '/^[a-zA-Z0-9]*:\/\//!s/^.*$/80/' -e 's/:.*//' -e 's/^http$/80/' -e 's/^https$/443/' -e x -e 's#^[a-zA-Z0-9]*://##' -e 's#/.*$##' -e G -e 'y/\n/:/' -e 's/:/ /' -e 's/:.*//' -e 's/ /:/'
}

# Pond une liste d'affectation de variables proxy.
varsProxy()
{
	cat <<TERMINE
http_proxy="$http_proxy"
https_proxy="$https_proxy"
HTTP_PROXY="$HTTP_PROXY"
HTTPS_PROXY="$HTTPS_PROXY"
ALL_PROXY="$ALL_PROXY"
TERMINE
}

# Pond sur son stdout le contenu de son stdin additionné d'affectation de variables proxy.
# Appelée avec un -e, y ajoute un export de ces dernières.
ajouterVarsProxy()
{
	egrep -v '^((http|https)_proxy|(HTTP|HTTPS|ALL)_PROXY)=' || true
	varsProxy
	[ "x$1" = x-e ] && echo "export http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY" || true
}

# Ajoute à un fichier (supposé shell) les déclarations de variables de proxy.
retaperVarsProxy()
{
	local e= f d
	
	for f in "$@"
	do
		[ "x$f" = x-e ] && e="-e" && continue || true
		d="`dirname "$f"`"
		if [ -e "$f" ] ; then cat "$f" ; else true ; fi \
		| ajouterVarsProxy $e \
		| sudoku -d "$d" sh -c "cat > \"$f.temp\" && cat \"$f.temp\" > \"$f\" && rm \"$f.temp\""
	done
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
		filtrer "$f" ajouterVarsProxy
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
	
	if [ -f /etc/environment ]
	then
		retaperVarsProxy /etc/environment
	fi
	if [ -d /etc/profile.d ]
	then
		retaperVarsProxy -e /etc/profile.d/proxy.sh
	else
		retaperVarsProxy -e /etc/profile
	fi
	
	if commande snap
	then
		sudoku -d /etc/ systemctl restart snapd
	fi
}

#- Filtrage de fichiers --------------------------------------------------------

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
	local suffixe="$PERSO_ORIGINAL"
	
	local cible="$1" ; shift
	local source
	local modeListage
	
	case "$cible" in
		/*) true ;;
		*) cible="`pwd`/$cible" ;;
	esac
	
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
			/*) true ;;
			*) source="`pwd`/$source" ;;
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
				[ -e "$f$suffixe" ] || continue
				diff -rq "$f$suffixe" "$f" | grep -F "Only in $f: " | sed -e 's/^Only in //' -e 's#: #/#' || true
				diff -ruw "$f$suffixe" "$f" >&7 || true
			done | tr '\012' '\000' > /tmp/temp.perso.$$.only
			if [ -s /tmp/temp.perso.$$.only ]
			then
				xargs -0 < /tmp/temp.perso.$$.only tar cf /tmp/temp.perso.$$.tar
			fi
		) 7>&1
	done | sed -e "s#^\(--- [^	]*\)$suffixe#\1#" > /tmp/temp.perso.$$.patch
	(
		cd "$cible"
		if [ -s /tmp/temp.perso.$$.tar ] || grep -q . < /tmp/temp.perso.$$.patch
		then
			diag _ "report des personnalisations de $*"
		fi
		if grep -q . < /tmp/temp.perso.$$.patch
		then
			patch -f -p0 -l < /tmp/temp.perso.$$.patch || \
		(
			echo "# Attention, les personnalisations de $* n'ont pu être appliquées. Consultez:"
			find . -name "*.rej" | sed -e 's/^/  /'
		) | rouge >&2
		fi
		if [ -s /tmp/temp.perso.$$.tar ]
		then
		tar xf - < /tmp/temp.perso.$$.tar
		fi
	)
	rm -f /tmp/temp.perso.$$ /tmp/temp.perso.$$.only /tmp/temp.perso.$$.tar /tmp/temp.perso.$$.patch
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
		done | egrep "^(\\.\\./)*$logiciel[-+]" | awk '{sub(/^(\.\.\/)*/,"");sub(/\/.*/,"");if(!n[$0])n[$0]=0;++n[$0]}END{nmax=0;for(i in n)if(n[i]>nmax){nmax=n[i];cmax=i}if(nmax)print cmax}'
	)
}

# perso() pour une arbo "mode installs de Guillaume". On va chercher les éventuels originaux des fichiers de notre cible, mais aussi les originaux "orphelins" (n'ayant pas de correspondant de la source déterminée 
iperso()
{
	local dossier
	
	# Recherche de liens symboliques à la sauce "installs de Guillaume".
	# Comme ils sont noyés dans $INSTALLS au milieu des liens symboliques vers plein d'autres logiciels, on ne cherche que ceux correspondant à un fichier de notre cible. Il y aura sans doute quelques petites différences, mais sur le nombre on devrait avoir suffisamment de témoins pour pouvoir faire de la statistique et retrouver notre dossier source le plus probable.
	
	perso "$1" # Sans autre paramètre, simple recopie des .original en leur fichier cible: ça aidera leplusdelienscommuns() à trouver des liens (si les liens existent vers la cible mais pas vers le .original).
	dossier="`leplusdelienscommuns "$1" "$INSTALLS"`"
	iperso_cible=
	if [ -z "$dossier" ]
	then
		perso "$@" "$INSTALLS"
	else
		iperso_cible="$INSTALLS/$dossier"
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
# Pourrait s'appeler Fonction Isolée à Locales et Séparateurs
# Ex.:
#  params="p1|p2|p3"
#  IFS="|"
#  tifs commande $params
# Ou:
#  tifs commande --sep "|" "p1|p2|p3"
# Pour ce qui est de l'environnement, s'assure que:
# - s'il est une fonction shell, l'appelé le sera dans le shell courant plutôt qu'un sous-shell (donc il pourra modifier les variables de l'appelant)
# - les éventuelles variables seront bien transmises à l'appelé (fonction shell ou programme externe)
# - mais ne baveront pas sur le shell courant
# Ceci pallie entre autres un problème avec certains sh, qui dans certaines conditions, font baver une variable:
#   f() { echo $VAR ; } ; g() { local VAR ; VAR=0 f ; } ; VAR=1 ; g ; echo $VAR
# devrait afficher 0 1 (le VAR=0 f devant cantonner la valeur de VAR à f), mais affiche 0 0 sous certains sh Linux, lorsque:
# - VAR est déclarée local
# - et est passée en VAR=0 f
# - et f est une fonction shell
tifs()
{
	# unset IFS, pour répondre au cas d'appel habituel.
	unset IFS
	
	# Le cas facile: les paramètres sont déjà séparés, et on n'a pas de variable à définir.
	case "$1" in
		*=*) true ;;
		*)
			case " $* " in
				*" --sep "*) true ;;
				*) "$@" ; return $? ;;
			esac
			;;
	esac
	
	# Choix d'un séparateur.
	local sep=
	for sep in '\034' '\035' '\036' '\037' ""
	do 
		sep="`printf "$sep"`"
		case "$*" in *"$sep"*) continue ;; esac
		break
	done
	[ -n "$sep" ] || err "# tifs: impossible de trouver un séparateur, les paramètres comportent trop de caractères spéciaux: $*" || return 1
	
	# Les affectations de variables à ne pas faire baver sur l'appelant.
	
	local _tifs_vars=
	while true
	do
		case "$1" in
			*=*) _tifs_vars="$_tifs_vars$1$sep" ;;
			*) break ;;
		esac
		shift
	done
	
	# La suite comporte-t-elle des séparateurs? Si non, on a juste à l'exécuter. Si oui, il faudra découper (ce qui sera plus long).
	
	case " $* " in
		*" --sep "*) true ;;
		*) _tifs_lancer "$@" ; return $? ;;
	esac
	
	# Exécution compliquée.
	
	local r=0 _tifs_params=
	
	# Découpe.
	while [ $# -gt 0 ]
	do
		case "$1" in
			--sep)
				IFS="$2"
				_tifs_plus $3
				unset IFS
				shift ; shift
				;;
			*) _tifs_params="$_tifs_params$1$sep" ;;
		esac
		shift
	done
	
	# Exécution.
	IFS="$sep"
	set -o noglob
	_tifs_lancer $_tifs_params || r=$?
	set +o noglob
	unset IFS
	return $r
}

_tifs_plus()
{
	local p
	for p in "$@"
	do
		_tifs_params="$_tifs_params$p$sep"
	done
}

_tifs_lancer()
{
	unset IFS
	
	# Comment transmettre les variables? Notre premier paramètre nous le dira:
	# - si c'est un programme externe, il faut les lui passer à l'invocation
	# - si c'est une fonction, on les déclare locales chez nous et elle en héritera
	
	if [ -z "$_tifs_vars" ]
	then
		"$@"
	else
		case "`command -v "$1" || true`" in
			/*) ( IFS="$sep" ; export $_tifs_vars ; unset IFS ; "$@" ) ;;
			*) IFS="$sep" ; local $_tifs_vars ; unset IFS ; "$@" ;;
		esac
	fi
}

# Ajoute des valeurs à une variable.
# Utilisation: plus [-d <délimiteur>] <NOM_VARIABLE> <ajout>*
# Ex.:
#  OPTIONS_CONF="--with-bidule"
#  plus OPTIONS_CONF --with-truc --with-machin
#  echo "$OPTIONS_CONF"
#  # -> --with-bidule --with-truc --with-machin
plus()
{
	local sep=" "
	[ "x$1" = x-d ] && sep="$2" && shift && shift || true
	local var="$1" ; shift
	local val="$*"
	eval "$var=\"\$$var\$sep\$val\""
}

# Retire des valeurs d'une variable.
# Utilisation: moins [-d <délimiteur>] <NOM_VARIABLE> <à supprimer>*
# Ex.:
#  OPTIONS_CONF="--with-bidule --with-truc --with-machin"
#  moins OPTIONS_CONF --with-truc --with-machin
#  echo "$OPTIONS_CONF"
#  # -> --with-bidule
moins()
{
	local sep=" "
	[ "x$1" = x-d ] && sep="$2" && shift && shift || true
	local var="$1" ; shift
	local exprExcl="`echo "$*" | sed -e 's/  */|/g'`"
	local val
	eval "$var=\"\`echo \"\$$var\" | tr \"\$sep\" '\\012' | egrep -v \"^(\$exprExcl)\\\$\" || true\`\""
}

for f in "$SCRIPTS"/util.util.*.sh
do
	. "$f"
done
