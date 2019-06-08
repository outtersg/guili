#!/bin/sh
# Copyright (c) 2003-2005,2008,2011-2019 Guillaume Outters
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

set -e

if [ -z "$SCRIPTS" ] || ! grep -q CEstBienCeFichierCiQuiDoitSeTrouverAuBoutDeSCRIPTS < "$SCRIPTS/util.sh"
then
	echo "# Merci de ne pas appeler util.sh directement, mais de définir \$SCRIPTS puis inclure \$SCRIPTS/util.sh." >&2
	return 1
fi

. "$SCRIPTS/util.local.sh"

[ -n "$INSTALL_MEM" ] || INSTALL_MEM="$HOME/tmp/paquets"
[ -n "$INSTALLS" ] || INSTALLS="$HOME/local" || true
[ -n "$TMP" ] || TMP="$HOME/tmp" || true
[ -n "$SANSSU" ] || SANSSU=1 || true

INSTALL_SCRIPTS="$SCRIPTS" # Des fois que d'autres récupèrent ensuite la variable $SCRIPTS.

util_menage()
{
	if [ $? -eq 0 ] # En cas de meurtre, on ne fait pas disparaître les preuves.
	then
	# Un minimum de blindage pour éviter de supprimer / en cas de gros, gros problème (genre le shell ne saurait même plus fournir $$).
	case "$TMP/$$" in
		*/[0-9]*)
			rm -Rf "$TMP/$$"
			;;
	esac
		# De même pour le dossier courant s'il contient un bout de /tmp/ dans son nom (ex.: dossier de compilation).
		local dossierCourant="`pwd`"
		case "$dossierCourant" in
			*/tmp/[_A-Za-z0-9]*) cd /tmp/ && rm -Rf "$dossierCourant" ;;
		esac
	fi
}
util_mechantmenage()
{
	util_menage
	exit 1
}
trap util_menage EXIT
trap util_mechantmenage INT TERM

# Si notre environnement a été pourri par un appelant qui ne tourne pas sous notre compte, il se peut qu'il ait défini un TMP dans lequel nous ne savons pas écrire. En ce cas nous redéfinissons à une valeur "neutre".
if ! mkdir -p "$TMP/$$" 2> /dev/null
then
	TMP=/tmp
	mkdir -p "$TMP/$$"
fi
mkdir -p "$INSTALL_MEM"

ajouterModif()
{
	modifs="$modifs $*"
}

retirerModif()
{
	for modif in "$@"
	do
		modifs="`echo " $modifs " | sed -e "s/ $modif / /g" -e 's/  */ /g' -e 's/^ //' -e 's/ $//'`"
	done
}

obtenir()
{
	fichier="$2"
	[ "$fichier" = "" ] && fichier=`echo "$1" | sed -e 's:^.*/::'`
	dest="$INSTALL_MEM/$fichier"
	if [ ! -f "$dest" ] ; then
		echo "Téléchargement de ${fichier}…" >&2
		commande=curl
		[ -z "$http_proxy_user" ] || commande="curl -U $http_proxy_user"
		affSiBinaire $commande -L -k -s "$1" > "$dest" || rm -f "$dest"
		[ -e "$dest" ] || return 1
	fi
	echo "$dest"
}

de7z()
{
	7za x -bd -y "$@" | sed -e '/^Extracting /!d' -e 's///' > "$TMP/$$/de7z.liste"
	_liste7z "$@" > "$TMP/$$/de7z.liste" # La ligne précédente est peu fiable.
	if [ `wc -l < "$TMP/$$/de7z.liste"` -eq 1 ] && grep -q '\.tar$' < "$TMP/$$/de7z.liste"
	then
		tar xf `cat "$TMP/$$/de7z.liste"`
	fi
}

_liste7z()
{
	7za l "$@" > "$TMP/$$/temp.liste7z" || return $?
	awk < "$TMP/$$/temp.liste7z" '/^---/{if((entre=!entre)){match($0,/-*$/);posNom=RSTART;next}}{if(entre)print substr($0,posNom)}' # On repère la colonne du chemin du fichier à ce qu'elle est la dernière; et pour ce faire on se base sur la ligne de tirets qui introduit la liste (et la clôt).
}

liste7z()
{
	if [ `_liste7z "$@" | wc -l` -eq 1 ] && _liste7z "$@" | grep -q '\.tar$'
	then
		7za x -so "$@" 2> /dev/null | tar tf -
	else
		_liste7z "$@"
	fi
}

dezipe()
{
	command -v unzip > /dev/null 2>&1 && unzip -qq -o "$@" || de7z "$@"
}

listeZip()
{
	command -v unzip > /dev/null 2>&1 && unzip -qq -l "$1" | head -2 | grep -q '^[ -]*$' && filtreListeZip="-e 1,2d" # Certains FreeBSD n'honorent pas le -qq et sortent quand même un en-tête.
	command -v unzip > /dev/null 2>&1 && unzip -qq -l "$1" | sed -e 's/  */	/g' $filtreListeZip | cut -f 5- || liste7z "$@"
}

# Téléchargege $1 et va dans le dossier obtenu en décompressant.
obtenirEtAllerDans()
{
	for i in liste dec archive dossier fichier ; do local $i ; done 2> /dev/null
	
	cd "$TMP"
	echo Obtention et décompression… >&2
	# Certains site (SourceForge, GitHub, etc.) donnent des archives au nom peu explicite.
	fichier="$2"
	if [ -z "$fichier" ]
	then
		fichier="`basename "$1"`"
		echo "$1" | egrep '/archive/v*[0-9][0-9.]*(\.tar|\.gz|\.tgz|\.xz|\.bz2|\.7z|\.zip|\.Z){1,2}$' && fichier="`echo "$1" | sed -e 's#/archive/v*#-#' -e 's#.*/##'`" || true
	fi
	archive=`obtenir "$1" "$fichier"`
	[ -f "$archive" ] || exit 1
	case "$fichier" in
		*.tar.gz|*.tgz|*.tar.Z) dec="tar xzf" ; liste="tar tzf" ;;
		*.tar) dec="tar xf" ; liste="tar tf" ;;
		*.tar.bz2) dec="tar xjf" ; liste="tar tjf" ;;
		*.zip) dec="dezipe" ; liste="listeZip" ;;
		*.7z|*.xz) dec="de7z" ; liste="liste7z" ;;
	esac
	(
		if ! $liste "$archive"
		then
			echo "# Archive pourrie: $archive. On la supprime." >&2
			mv "$archive" "$archive.pourrie"
			return 1
		fi
	) | sed -e 's=^./==' -e 's=^/==' -e 's=/.*$==' | sort -u > "$TMP/$$/listeArchive"
	case `wc -l < "$TMP/$$/listeArchive" | awk '{print $1}'` in
		0)
			return 1
			;;
		1) # Si l'archive se décompresse en un seul répertoire racine, on prend ce dernier comme conteneur.
			$dec "$archive"
			cd "`cat "$TMP/$$/listeArchive"`"
			;;
		*) # Si le machin se décompresse en plusieurs répertoires, on va s'en créer un pour contenir le tout.
		dossier=`mktemp -d "$TMP/XXXXXX"`
		cd "$dossier"
		$dec "$archive"
			;;
	esac
}

obtenirEtAllerDansGit()
{
	l="`basename "$1"`"
	v="$2"
	a="$INSTALL_MEM/$l-$v.tar.gz"
	
	cd "$TMP"
	echo Obtention et décompression… >&2
	if [ -f "$a" ]
	then
		tar xzf "$a"
		cd "$l-$v"
	else
		urlGit="$archive_git"
		brancheGit=
		case "$urlGit" in
			*@*)
				brancheGit="-b `echo "$archive_git" | sed -e 's/.*@//'`"
				urlGit="`echo "$archive_git" | sed -e 's/@[^@]*//'`"
				;;
		esac
		GIT_SSL_NO_VERIFY=true git clone $brancheGit "$urlGit" "$l-$v"
		cd "$l-$v"
		[ -z "$v" ] || ( v2="`echo "$v" | sed -e 's/.*[.-]//g'`" ; git checkout "$v2" )
		[ -z "$v" ] || ( cd .. && tar czf "$a" "$l-$v" )
	fi
}

obtenirEtAllerDansDarcs()
{
	patch_oeadd=
	archive_oeadd=
	archive_locale_oeadd=
	petit_nom_oeadd=
	options_oeadd=
	zero="`echo | tr '\012' '\011'`"
	
	while [ $# -gt 0 ]
	do
		case "$1" in
			-p) shift ; patch_oeadd="$1" ; options_oeadd="$options_oeadd--to-patch=$patch_oeadd$zero" ;;
			-n) shift ; petit_nom_oeadd="$1" ;;
			*) archive_oeadd="$1" ;;
		esac
		shift
	done
	endroit_oeadd="`basename "$archive_oeadd"`"
	if [ -z "$petit_nom_oeadd" ]
	then
		[ -z "$patch_oeadd" ] || endroit="$endroit_oeadd-$patch_oeadd"
	else
		endroit_oeadd="$endroit_oeadd-$petit_nom_oeadd"
	fi
	
	cd "$TMP"
	echo Obtention et décompression… >&2
	if [ "x$patch_oeadd" != x ]
	then
		archive_locale_oeadd="$INSTALL_MEM/${endroit_oeadd}.tar.bz2"
		[ -f "$archive_locale_oeadd" ] && tar xjf "$archive_locale_oeadd" && cd "$endroit_oeadd" && return 0
	fi
	echo "$options_oeadd--lazy$zero$archive_oeadd$zero$endroit_oeadd" | tr -d '\012' | tr "$zero" '\000' | LANG=C LC_ALL=C xargs -0 darcs get
	[ -z "$patch_oeadd" ] || tar cjf "$archive_locale_oeadd" "$endroit_oeadd"
	cd $endroit_oeadd
}

# Utilise les variables globales version, archive, archive_darcs, archive_svn, archive_cvs.
obtenirEtAllerDansVersion()
{
	echo "=== $logiciel$argOptions $version ===" >&2
	
	# A-t-on un binaire déjà compilé?
	installerBinaireSilo
	# A-t-on déjà une copie des sources?
	if [ ! -z "$install_obtenu" ]
	then
		cd "$install_obtenu"
		return
	fi
	[ -z "$versionComplete" ] && versionComplete="$version" || true
	case "$versionComplete" in
		*.git)
			v="`echo "$versionComplete" | sed -e 's/.git//'`"
			obtenirEtAllerDansGit "$archive_git" "$v"
			if [ -z "$v" ]
			then
				v="`date +%Y-%m-%d`"
			fi
			;;
		*@*)
			vn="`echo "$versionComplete" | sed -e 's/@.*//'`"
			vp="`echo "$versionComplete" | sed -e 's/^[^@]*@//'`"
			obtenirEtAllerDansDarcs -n "$vn" -p "$vp" "$archive_darcs"
			version="$vn"
			;;
		#*-*) obtenirEtAllerDansCvs -d "$version" "$archive_cvs" ;; # Trop de numéros de version utilisent le tiret.
		*-*.cvs) obtenirEtAllerDansCvs -d "`echo "$version" | sed -e 's/.cvs//'`" "$archive_cvs" ;; # Trop de numéros de version utilisent le tiret.
		r*) obtenirEtAllerDansSvn "-$version" "$archive_svn" ;;
		t*) obtenirEtAllerDansSvn "-$version" "$archive_svn_tag" ;;
		*) obtenirEtAllerDans "$archive" "$@" ;;
	esac
}

#- Initialisation --------------------------------------------------------------

cheminsGuili()
{
	local GUILI_PATH="$GUILI_PATH"
	[ ! -z "$GUILI_PATH" ] || GUILI_PATH="$INSTALLS"
	IFS=:
# Les -I n'ont rien à faire dans les C(XX)FLAGS. Les logiciels doivent aller piocher dans CPPFLAGS, sinon c'est qu'ils sont foireux et doivent recevoir une rustine spécifique. Ajouter les -I aux CFLAGS empêche par exemple PostgreSQL de se compiler: il fait un cc $CFLAGS -I../src/include $CPPFLAGS, ce qui fait que si /usr/local/include est dans CFLAGS, et possède mettons des .h de la 9.2, ceux-ci sont inclus avant les .h de la 9.5 lors de la compilation de celui-ci.
	chemins --sans-c-cxx $GUILI_PATH
	unset IFS
	export PATH="`echo $TMP/$$:$PATH | sed -e 's/^\.://' -e 's/:\.:/:/g' -e 's/::*/:/g'`"
	# Trop de logiciels (PHP…) se compilent par défaut sans optimisation. C'est ballot.
	export CFLAGS="-O3 $CFLAGS"
	export CXXFLAGS="-O3 $CXXFLAGS"
}
chemins_init=cheminsGuili

. "$SCRIPTS/util.args.sh"
. "$SCRIPTS/util.util.sh"

# Remplacements de commandes (pour la phase d'amorçage).

if ! command -v curl 2> /dev/null >&2
then
	curlfetch()
	{
		local params=
		local sep="`echo | tr '\012' '\003'`"
		local param
		local sortie=
		local proxy="$ALL_PROXY"
		while [ $# -gt 0 ]
		do
			case "$1" in
				-L|-O) true ;;
				-o) params="$params$sep$1" ; sortie=oui ;;
				-k) params="$params$sep--no-verify-peer" ;;
				-s) params="$params$sep-q" ;;
				-m) params="$params$sep-T" ;;
				-x) shift ; proxy="$1" ;;
				*) params="$params$sep$1" ;;
			esac
			shift
		done
		if [ -z "$sortie" ]
		then
			params="$params$sep-o$sep-"
		fi
		params="`echo "$params" | cut -c 2-`"
		(
			IFS="$sep"
			http_proxy=$proxy affSiBinaire fetch $params
		)
	}
	curlwget()
	{
		local params=wget
		local sep="`echo | tr '\012' '\003'`"
		local param
		local sortie=
		local proxy="$ALL_PROXY"
		while [ $# -gt 0 ]
		do
			case "$1" in
				-L|-O) true ;;
				-o) params="$params$sep-O" ; sortie=oui ;;
				-k) params="$params$sep--no-check-certificate" ;;
				-s) params="$params$sep-q" ;;
				-m) params="$params$sep--timeout" ;;
				-x) shift ; proxy="$1" ;;
				*) params="$params$sep$1" ;;
			esac
			shift
		done
		if [ -z "$sortie" ]
		then
			params="$params$sep-O$sep-"
		fi
		(
			IFS="$sep"
			http_proxy=$proxy https_proxy=$proxy affSiBinaire $params
		)
	}
	curl()
	{
		local curl="`unset -f curl ; command -v curl 2> /dev/null || true`"
		if [ ! -z "$curl" ]
		then
			affSiBinaire "$curl" "$@"
		elif commande fetch
		then
			curlfetch "$@"
		elif commande wget
		then
			curlwget "$@"
		else
	[ -x "/tmp/minicurl" ] || cc -o "/tmp/minicurl" "$SCRIPTS/minicurl.c"
		"/tmp/minicurl" "$@"
		fi
	}
fi

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
		su $argsSu -c 'commande="`. "'"$INSTALL_SCRIPTS"'/util.util.sh" ; echo '"$commande"' | xdecode`" ; IFS="`printf '"'$sep'"'`" ; $commande'
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
						# À FAIRE: utiliser garg si présent.
						sudo_env="$sudo_env $1"
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
		touch "$ou/.sudoku.temoin" 2> /dev/null && rm -f "$ou/.sudoku.temoin" 2> /dev/null && sdk_ecris=1 || sdk_ecris=0
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
			?????1) $sudo -u "$enTantQue" $sudo_env "$@" ;; # sudo dans les autres cas (avec sudo de détecté…).
		esac
	)
}

# Mode de test: une fois en tant qu'utilisateur normal, une fois en root:
# ( . util.sh ; testsudoku )
testsudoku()
{
	set -x
	for INSTALLS in /tmp /usr/local
	do
		for SANSSU in 0 1
		do
			for compte in root bas # Là il faudrait un autre aussi.
			do
				echo "=== `id -u -n` en tant que $compte vers $INSTALLS (SANSSU=$SANSSU) ==="
				sudoku -u "$compte" id
			done
		done
	done
}

# Pour pouvoir lancer un sh -c ou su -c dans lequel lancer des commandes d'util.sh, faire un su toto -c "$INSTALL_UTIL ; versions etc."
INSTALL_ENV_UTIL="SCRIPTS=$SCRIPTS ; . \"\$SCRIPTS/util.sh\" "

# Lance un script de fonctions util.sh en tant qu'un autre compte.
utiler()
{
	local qui="$1" ; shift
	# Redirection du stdout pour éviter la pollution des scripts type fortune si sudoku doit recourir à un su -.
	sudoku -u "$qui" sh -c "exec >&7 ; $INSTALL_ENV_UTIL ; $*" 7>&1 > /dev/null
}

utiliser="$SCRIPTS/utiliser"
command -v $utiliser 2> /dev/null >&2 || utiliser=utiliser # Si SCRIPTS n'est pas définie, on espère trouver un utiliser dans le PATH.

# Utilisation: sutiliser [-|+]
#   -|+
#	 Si +, et si $INSTALL_SILO est définie, on pousse une archive binaire de notre $dest installé vers ce silo. Cela permettra à de futurs installant de récupérer notre produit de compil plutôt que de tout recompiler.
#	 Si -, notre produit de compil ne sera pas poussé (à mentionner par exemple s'il installe des bouts ailleurs que dans $dest, car alors l'archive de $dest sera incomplète).
#	 Si non mentionné: comportement de - si on est un amorceur (car supposé installer des trucs dans le système, un peu partout ailleurs que dans $dest); sinon comportement de +.
sutiliser()
{
	local biner=
	[ "x$1" = "x-" -o "x$1" = "x+" ] && biner="$1" && shift || true

	# On arrive en fin de parcours, c'est donc que la compil s'est terminée sans erreur. On le marque.
	sudo touch `guili_temoins`
	
	sut_lv="$1"
	[ ! -z "$sut_lv" ] || sut_lv="`basename "$dest"`"
	
	# Si on est censés pousser notre binaire vers un silo central, on le fait.
	if [ -z "$biner" ]
	then
		case "$sut_lv" in
			_*) biner=- ;; # Par défaut, un amorceur n'est pas silotable (car il s'installe un peu partout dans le système: rc.d, init.d, systemd, etc.).
			*) biner=+ ;;
		esac
	fi
	if [ "x$biner" = "x+" ]
	then
		pousserBinaireVersSilo "$sut_lv"
	fi
	
	guili_localiser
	
	logicielParam="`echo "$sut_lv" | sed -e 's/-[0-9].*//'`"
	derniere="`versions "$logicielParam" | tail -1 | sed -e 's#.*/##' -e "s/^$sut_lv-.*/$sut_lv/"`" # Les déclinaisons de nous-mêmes sont assimilées à notre version (ex.: logiciel-x.y.z-misedecôtécarpourrie).
	if [ ! -z "$derniere" ]
	then
		if [ "$sut_lv" != "$derniere" ]
		then
			echo "# Attention, $sut_lv ne sera pas utilisé par défaut, car il existe une $derniere plus récente. Si vous voulez forcer l'utilisation par défaut, faites un $SCRIPTS/utiliser $sut_lv" >&2
			return 0
		fi
	fi
	[ ! -d "$INSTALLS/$sut_lv" ] || sudo $utiliser "$INSTALLS/$sut_lv"
	
	infosInstall
}

if [ ! -z "$SANSU" ]
then
	utiliser() { true ; }
	sutiliser() { true ; }
fi

# sinstaller [-u <compte>] <dossier> <dest>
sinstaller()
{
	sinst_compte=
	[ "x$1" = x-u ] && shift && sinst_compte="$1" && shift || true
	sinst_source="$1"
	sinst_dest="$2"
	# Si aucun utilisateur n'est mentionné, on prend le compte courant par défaut, ou root si le courant n'a pas les droits d'écriture.
	if [ -z "$sinst_compte" ]
	then
		sinst_grandpere="`dirname "$sinst_dest"`"
		sinst_sonde="$sinst_grandpere/.sinstaller.sonde"
		if mkdir -p "$sinst_grandpere" 2> /dev/null && touch "$sinst_sonde" 2> /dev/null
		then
			sinst_compte="`id -u -n`"
		else
			sinst_compte=root
		fi
	fi
	
	if ! sudoku -u "$sinst_compte" mkdir -p "$sinst_dest" 2> /dev/null
	then
		SANSSU=0 sudo mkdir -p "$sinst_dest"
		SANSSU=0 sudo chown -R "$sinst_compte:" "$sinst_dest"
	fi
	( cd "$sinst_source" && tar cf - . ) | ( cd "$sinst_dest" && sudoku -u "$sinst_compte" tar xf - )
}

filtrer()
{
	fichier="$1"
	shift
	"$@" < "$fichier" > "$TMP/$$/temp" && cat "$TMP/$$/temp" > "$fichier"
}

sufiltrer()
{
    fichier="$1"
    shift
    "$@" < "$fichier" > "$TMP/$$/temp" && sudo sh -c "cat $TMP/$$/temp > $fichier"
}

# Prend un fichier de conf à plat et insère ou remplace les variables données.
changerconf()
{
	cc_f=
	cc_sep="="
	cc_comm='#'
	cc_varsawk=
	while [ $# -gt 0 ]
	do
		case "$1" in
			-d) shift ; cc_sep="$1" ;;
			-c) shift ; cc_comm="$1" ;;
			*=*) cc_varsawk="$cc_varsawk|$1" ;;
			*) [ -z "$cc_f" ] && cc_f="$1" || break ;; # À FAIRE: pouvoir traiter plusieurs fichiers.
		esac
		shift
	done
	
	filtrer "$cc_f" awk '
BEGIN {
	s = "'"$cc_sep"'";
	c = "'"$cc_comm"'";
	split(substr("'"$cc_varsawk"'", 2), t0, "|");
	for(i in t0) { split(t0[i], telem, "="); t[telem[1]] = t[telem[1]]"|"telem[2]; }
	for(i in t) t[i] = substr(t[i], 2);
}
function pondre() {
	for(i in ici)
	{
		split(ici[i], vals, "|");
		for(j in vals)
			print i""s""vals[j];
	}
	delete ici;
}
{
	# Si on trouve un de nos termes dans la ligne courante, on se prépare à insérer nos valeurs pour cette variable.
	for(i in t)
		if(match($0, "^( *"c" *)?"i"[	 ]*"s))
		{
			ici[i] = t[i];
			delete t[i];
		}
}
/^ *#/{
	# Si la ligne est un commentaire, on la laisse en paix.
	print;
	next;
}
{
	# Autre ligne (donc non commentée).
	# Mais va-t-on la commenter? Si elle définit un des paramètres que l on remplace, oui.
	for(i in ici)
		if(match($0, "^"i"[ 	]*"s))
		{
			split(ici[i], vals, "|");
			for(j in vals)
				if($0 == i""s""vals[j]) # Si la ligne contient une des valeurs que l on va insérer, pas la peine de la commenter (puisqu on en insère une version décommentée, vraisemblablement la même ligne en fait).
					next;
			print c""$0;
			next;
		}
	# Première ligne pas commentaire après (ou au moment) le repérage d un de nos mots-clés! On va donc dire tout ce qu on retenait depuis pas mal de temps.
	pondre();
	# Et tout de même on écrit la ligne en question.
	print;
}
END {
	for(i in t)
		ici[i] = t[i];
	pondre();
}
'
}

# Ajoute à une variable du contenu
# Paramètres:
# $1: Makefile
# $2: variable
# $3: ajout
etendreVarMake()
{
	filtrer "$1" awk '{print $0}/^'"$2"'=/{if(commencer == 0) commencer = 1}/[^\\]$/{if(commencer == 1) { print "'"$2"'+= '"$3"'" ; commencer = 2 }}/^$/{if(commencer == 1) { print "'"$2"'+= '"$3"'" ; commencer = 2 }}'
}

chut()
{
	"$@" > "$TMP/$$/temp" 2>&1 || cat "$TMP/$$/temp"
}

ajouterAvec()
{
	[ "$AVEC" = "" ] && AVEC=,
	AVEC="${AVEC}$1,"
}

retirerAvec()
{
	AVEC="`echo "$AVEC" | sed -e "s/,$1,/,/g"`"
}

avec()
{
	echo "$AVEC" | grep -q ",$1,"
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

exclusivementPrerequis()
{
	uniquementPrerequis
	export PATH="`echo "$PATH" | tr : '\012' | egrep -v "^$INSTALLS/s?bin$" | tr '\012' ':' | sed -e 's/:$//'`"
	export LD_LIBRARY_PATH="`echo "$LD_LIBRARY_PATH" | tr : '\012' | egrep -v "^$INSTALLS/lib(64)?$" | tr '\012' ':' | sed -e 's/:$//'`"
	export PKG_CONFIG_PATH="`echo "$PKG_CONFIG_PATH" | tr : '\012' | egrep -v "^$INSTALLS/lib/pkgconfig$" | tr '\012' ':' | sed -e 's/:$//'`"
	export DYLD_LIBRARY_PATH="$LD_LIBRARY_PATH"
	export CMAKE_LIBRARY_PATH="$LD_LIBRARY_PATH"
	export CMAKE_INCLUDE_PATH="`echo "$CMAKE_INCLUDE_PATH" | tr : '\012' | egrep -v "^$INSTALLS/include$" | tr '\012' ':' | sed -e 's/:$//'`"
	# On se protège aussi contre les inclusions que nos éventuels prérequis voudront nous faire ajouter. Si nous passons par le contraignant exclusivementPrerequis ça n'est pas pour laisser nos sous-paquets décider.
	exp_pkgconfig="`command -v pkg-config 2>&1 || true`"
	if [ ! -z "$exp_pkgconfig" -a "$exp_pkgconfig" != "$TMP/$$/pkg-config" ]
	then
		cat > "$TMP/$$/pkg-config" <<TERMINE
#!/bin/sh
$exp_pkgconfig "\$@" | sed -E -e 's/ /  /g' -e 's/^/ /' -e 's/$/ /' -e 's# -L$INSTALLS/(bin|sbin|lib|lib64) ##g'
TERMINE
		chmod a+x "$TMP/$$/pkg-config"
	fi
}

# Les programmes qui veulent se lier à libjpeg, libjpeg < 9, ou libjpegturbo, peuvent utiliser cette variable, toujours définie, et surchargeable par l'appelant "du dessus".
_initPrerequisLibJpeg()
{
	case "$argOptions+" in
		*+jpeg9+*) prerequis_libjpeg="libjpeg >= 9" ;;
		*+jpeg8+*) prerequis_libjpeg="libjpeg < 9" ;;
		*+jpegturbo+*) prerequis_libjpeg="libjpegturbo" ;;
	esac
[ ! -z "$prerequis_libjpeg" ] || prerequis_libjpeg="libjpeg"
export prerequis_libjpeg
}

prerequis()
{
	# Si l'environnement est configuré pour que nous renvoyons simplement nos prérequis, on obtempère ici (on considère qu'un GuiLI qui atteint ce point n'a plus rien à faire qui puisse influer sur le calcul de $prerequis.
	if [ ! -z "$PREREQUIS_THEORIQUES" ]
	then
		echo "#v:$version"
		echo "#p:$prerequis"
		exit 0
	fi
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

# Sort le chemin d'installation de chacun des prérequis passés en paramètres.
# Appelle prerequis et ne sort que l'info de chemin. L'idée est de pouvoir l'appeler depuis un sous-shell pour connaître le chemin sans modifier tout l'environnement (LDFLAGS et compagnie), par exemple:
#   echo "Le dernier PHP avant la 7 se trouve dans `cible "php < 7"`"
cible()
{
	PREINCLUS=
	prerequis="$*" prerequis
	for preinclus in $PREINCLUS ; do echo "$preinclus" ; done | cut -d : -f 1 | while read lpreinclus
	do
		suffixe="`echo "$lpreinclus" | tr '+-' __`"
		# Mais on ne veut exporter que les $dest sous le préfixe $cible_.
		eval "echo \"\$dest$suffixe\""
	done
}

# Trouve le nom du prochain fichier disponible, en ajoutant des suffixes numériques jusqu'à en trouver un de libre.
prochain()
{
	chemin="$1"
	[ ! -e "$chemin" ] && echo "$chemin" && return
	racineChemin="`echo "$chemin" | sed -e 's#\(\.[a-z0-9A-Z]\{1,3\}\)*$##'`"
	suffixeChemin="`echo "$racineChemin" | sed -e 's#.#.#g'`"
	suffixeChemin="`echo "$chemin" | sed -e "s#^$racineChemin##"`"
	n=1
	while [ -e "$racineChemin.$n$suffixeChemin" ]
	do
		n="`expr $n + 1`"
	done
	echo "$racineChemin.$n$suffixeChemin"
}

# Obtient la version majeure (x.x) d'une version longue (x.x.x).
vmaj()
{
	echo "$1" | sed -e 's/^\([^.]*.[^.]*\).*$/\1/'
}

analyserParametresInstall()
{
	argOptions=
	while [ $# -gt 0 ]
	do
		case "$1" in
			--src) shift ; install_obtenu="$1" ;;
			--dest) shift ; install_dest="$1" ;;
			+) export INSTALLS_MAX=1 ;;
			+[a-z]*) argOptions="$argOptions$1" ;;
		esac
		shift
	done
	argOptions="`options "$argOptions" | tr -d ' '`"
	argOptionsDemandees="$argOptions+"
}

case "$0" in
	-*) true ;;
	*)
install_moi="$SCRIPTS/`basename "$0"`"
		logiciel="`basename "$0"`" # Par défaut, le nom du logiciel est celui de l'installeur (un peu de logique, zut!).
		;;
esac

infosInstall()
{
	local feu=rouge # Si le feu passe au vert, on peut commencer à afficher nos infos.
	local sortie=non # Si $sortie = oui, alors on finira par un bel exit 0.
	
	# -s comme "Pondre Seulement Si possible de Sortir prématurément".
	# Si non spécifié, on pond de toute manière (mais on ne sort pas).
	# Si spécifié, les conditions de sortie (et donc de ponte des infos), sortie prématurée (c'est-à-dire avant installation effective), sont:
	# - soit le logiciel trouvé est déjà installé (auquel cas continuer l'installation ne ferait rien de plus -> on sort): test de "$dest/.complet".
	# - soit on souhaite juste savoir ce qui *va* être installé (mais sans l'installer), ce qui sera déterminé dans le corps de boucle.
	# - soit on va de toute façon ne lister que ce qui est déjà installé, via versions(), donc on sortira puisqu'on demande à se cantonner à l'installé, donc à ne pas installer.
	if [ "x$1" = x-s ]
	then
		if guili_temoinsPresents
		then
			sortie=oui # Déjà installé dans la version voulue, donc on va pouvoir poursuivre.
			feu=vert
		fi
	else
		feu=vert
	fi
	
	if [ ! -z "$INSTALLS_AVEC_INFOS" ] # Petit test pour éviter d'ouvrir >&6 si on n'a rien à sortir (car si ça se trouve l'appelant, n'ayant pas défini la variable, n'a pas non plus ouvert le descripteur).
	then
		for ii_var in `echo "$INSTALLS_AVEC_INFOS" | tr , ' '`
		do
			case "$ii_var" in
				-i) true ;;
				-n) feu=vert ; sortie=oui ;;
		1) echo "$logiciel:$logiciel$argOptions:$version:$dest" ;;
		vars0) echo "dest=$dest version=$version prerequis=\"$prerequis\"" ;;
		vars) echo "dest$logiciel=$dest version_$logiciel=$version prerequis_$logiciel=\"$prerequis\"" ;;
		"") true ;;
		prerequis-r)
			varsPrerequis prerequis-r "$prerequis" | tr '\012' ' '
			echo "$prerequis"
			;;
		*)
				eval "echo \"\$$ii_var\""
			;;
			esac
		done >&6
	fi
	
	[ $feu = vert -a $sortie = oui ] && exit 0 || true
}

destiner()
{
	verifierConsommationOptions
	if [ -z "$install_dest" ]
	then
		dest="`versions -v "$version" "$logiciel$argOptions" | tail -1`"
		if [ -z "$dest" ]
		then
			dest="$INSTALLS/$logiciel$argOptions-$version"
		fi
	else
	dest="$install_dest"
	fi
	guili_temoins "$dest" "$1"
	infosInstall -s
}

# Inscrit une version comme gérée; la retient comme version à compiler si elle rentre dans les critères spécifiés en paramètres du script; renvoie true si la version a compilée est supérieure ou égale à celle-ci, false sinon.
v()
{
	v="`echo "$1" | sed -e 's/@.*//'`"
	testerVersion "$v" $argVersion && version="$v" && versionComplete="$1"
	testerVersion "$v" ppe $argVersion
}

# Teste si la version mentionnée en premier paramètre rentre (ou est plus petite ou égale, si le second paramètre vaut 'ppe') dans l'intervalle défini par la suite des arguments (ex.: testerVersion 2.3.1 >= 2.3 < 2.4 renverra vrai).
testerVersion()
{
	[ "x$1" = x ] && return 0 # Sans mention de version, on dit que tout passe.
	versionTestee="$1"
	shift
	plusPetitOuEgal=false
	[ "x$1" = xppe ] && plusPetitOuEgal=true && shift
	while [ $# -gt 0 ]
	do
		case "$1" in
			">=")
				$plusPetitOuEgal || pge "$versionTestee" "$2" || return 1 # Si on teste un PPE, le >= n'est pas filtrant (la clause PPE est prioritaire).
				shift
				;;
			"<")
				pg "$2" "$versionTestee" || return 1
				shift
				;;
			*) # Numéro de version précis.
				if $plusPetitOuEgal
				then
					pge "$1" "$versionTestee" || return 1
				else
					[ "$versionTestee" = "$1" ] || return 1
				fi
				;;
		esac
		shift
	done
	true
}

pge() { pg -e "$1" "$2" ; }

# Renvoie 0 si le premier paramètre (num de version) est plus grand que le second. Avec l'option -e, on fait du plus grand ou égal.
pg()
{
	egal=
	[ "x$1" = x-e ] && egal="-e" && shift
	b="`echo "$2" | tr . ' '`"
	pgInterne $egal "$1" $b
}

pgInterne()
{
	ouEgal=false
	[ "x$1" = x-e ] && ouEgal=true && shift
	a="`echo "$1" | tr . ' '`"
	shift
	for i in $a
	do
		[ -z "$1" -o "0$i" -gt "0$1" ] && return 0
		[ "0$i" -lt "0$1" ] && return 1
		shift
	done
	$ouEgal && [ -z "$1" ]
}

triversions()
{
	# De deux logiciels en même version, on prend le chemin le plus long: c'est celui qui embarque le plus de modules optionnels.
	awk '
		BEGIN {
			# Certaines versions d awk veulent que ls soit initialisée en array avant de pouvoir être length()ée.
			nls = 0;
			nvs = 0;
			ntailles = 0;
		}
		{
			ls[++nls] = $0;
			v = $0;
			sub(/^([^0-9][^-]*-)+/, "", v);
			vs[++nvs] = v;
			ndecoupe = split(v, decoupe, ".");
			for(i = 0; ++i <= ndecoupe;)
			{
				if(i > ntailles)
				{
					++ntailles;
					tailles[i] = 0;
				}
				if(length(decoupe[i]) > tailles[i])
					tailles[i] = length(decoupe[i]);
			}
		}
		END {
			for(nl = 0; ++nl <= nvs;)
			{
				c = "";
				v = vs[nl];
				ndecoupe = split(v, decoupe, ".");
				for(nv = 0; ++nv <= ntailles;)
					c = c sprintf("%0"tailles[nv]"d", nv > ndecoupe ? 0 : decoupe[nv]);
				print c" "sprintf("%04d", length(ls[nl]))" "ls[nl]
			}
		}
	' | sort | cut -d ' ' -f 3-
}

filtrerVersions()
{
	sed -e '/^.*-\([0-9.]*\)$/!d' -e 's##\1 &#' | while read v chemin
	do
		if testerVersion "$v" $@
		then
			echo "$chemin"
		fi
	done
}

### Fonctions utilitaires dans le cadre des modifs. ###

sudoer()
{
	# A-t-on déjà les droits?
	(
		sudo="`IFS=: ; for x in $PATH ; do [ -x "$x/sudo" ] && echo "$x/sudo" && break ; done`"
		set -f
		case "$2" in
			ALL) commande=true ;;
			*) commande="$2" ;;
		esac
		sudoku -u "$1" "$sudo" -n -l $commande > /dev/null 2>&1
	) && return || true
	echo "$1 ALL=(ALL) NOPASSWD: $2" | INSTALLS=/etc sudoku sh -c 'cat >> /etc/sudoers'
}

#- Création de comptes et groupes ----------------------------------------------

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

## Pare-feu ##

# Troue l'éventuel pare-feu.
feu()
{
	if [ -f /etc/firewalld/zones/public.xml ]
	then
		feuFirewalld "$@"
	fi
}

feuFirewalld()
{
	for feu_port in "$@"
	do
		# On essaie de trouver un service qui ouvre ce port. Si plusieurs services disponibles, on prend le plus petit (celui qui ouvre juste le port en question plutôt que le fourre-tout).
		feu_service="`grep -rl "port=\"$feu_port\"" /usr/lib/firewalld/services | while read l ; do du -b "$l" ; done | sort -n | head -1 | while read f ; do basename "$f" .xml ; done`"
		feu_err=0
		if [ -z "$feu_service" ]
		then
			firewall-cmd -q --zone=public --permanent --add-port=$feu_port/tcp || feu_err=$?
		else
			firewall-cmd -q --zone=public --permanent --add-service=$feu_service || feu_err=$?
		fi
		case "$feu_err" in
			0) true ;;
			252) return 0 ;; # Pas démarré, donc pas de pare-feu, donc on passe.
			*) return $feu_err ;;
		esac
		# À FAIRE?: si feu_err, modifier manuellement les fichiers de conf pour que les règles soient quand même persistées.
		true || filtrer /etc/firewalld/zones/public.xml sed -e "/<service name=\"$feu_service\"/d" -e "/<\/zone>/i\
  <service name=\"$feu_service\"/>
"
	done
	systemctl restart firewalld
}

# Le localhost n'est pas toujours 127.0.0.1 (ex.: jails BSD). Si des programmes ont besoin de coder une IP en dur, mieux vaut passer par là.
localhost()
{
	ifconfig | awk '/^lo/{split($0,ti,/:/);i=ti[1]}/inet /{if(i){print $2;exit}}'
}

mac() { [ "`uname`" = Darwin ] ; }

# Utilise le compilo Apple sur Mac (ex.: libao, libdiscid, qui doivent accéder à CoreAudio et autres Frameworks auxquels seul le compilo Apple sait accéder).
ccMac()
{
	case `uname` in
		Darwin)
			CC=cc
			export CC
			;;
	esac
}

# Modifie libtool pour lui faire générer du 32 et 64 bits via les -arch propres aux gcc d'Apple.
# Ne plus utiliser, ça marche trop peu souvent (certaines parties du compilo plantent sur du multiarchi). Passer par compil3264.
libtool3264()
{
	mac || return 0
	if command -v arch >&1 2> /dev/null && arch -arch x86_64 true 2> /dev/null
	then
		CFLAGS="$CFLAGS -arch x86_64 -arch i386"
		LDFLAGS="$CFLAGS -arch x86_64 -arch i386"
		export CFLAGS LDFLAGS CXXFLAGS
		modifspostconf="$modifspostconf libtool3264bis"
	fi
}

libtool3264bis()
{
	mac || return 0
	# Toutes les étapes incluant une génération de fichiers de dépendances (-M) plantent en multi-archis. C'est d'ailleurs ce qui nous pose problème, car certaines compils combinent génération de méta ET compil proprement dite, qui elle a besoin de son -arch multiple.
	filtrer libtool sed -e '/func_show_eval_locale "/i\
command="`echo "$command" | sed -e "/ -M/s/ -arch [^ ]*//g"`"
'
}

# À ajouter en modif; après la compil dans l'archi cible, déterminera si celle-ci est une 64bits, et, si oui, lancera la recompil équivalente totale en 32bits, avant de combiner les produits via lipo.
EN_32=non
[ "x$1" = x-32 ] && EN_32=oui
compil3264()
{
	mac || return 0
	if command -v arch 2> /dev/null && arch -arch x86_64 true 2> /dev/null
	then
		if [ "$EN_32" = oui ]
		then
			CFLAGS="$CFLAGS -arch i386"
			CXXFLAGS="$CXXFLAGS -arch i386"
			LDFLAGS="$LDFLAGS -arch i386"
			export CFLAGS LDFLAGS CXXFLAGS
		else
			mkdir -p "/tmp/$$/compil32bits"
			modifspostcompil="$modifspostcompil compil3264bis"
		fi
	fi
}

compil3264bis()
{
	mac || return 0
	icirel="`pwd | sed -e "s#$TMP/*##"`"
	tmp2="$TMP/$$/compil32bits"
	TMP="$tmp2" "$SCRIPTS/`basename "$0"`" -32
	tmp2="$tmp2/$icirel"
	find . \( -name \*.dylib -o -name \*.a -o -perm -100 \) -a -type f | xargs file | egrep ": *Mach-O|archive random library" | cut -d : -f 1 | while read f
	do
		touch -r "$f" "$TMP/$$/h"
		lipo -create "$f" "$tmp2/$f" -output "$f.univ" && cat "$f.univ" > "$f"
		touch -r "$TMP/$$/h" "$f"
	done
}

dyld105()
{
	mac || return 0
	# À FAIRE: ne rajouter ça que si on est en > 10.5.
	# http://lists.apple.com/archives/xcode-users/2005/Dec/msg00524.html
	[ -d /Developer/SDKs/MacOSX10.5.sdk ] || return 0
	MACOSXVERSIONFLAGS="-mmacosx-version-min=10.5 -isysroot /Developer/SDKs/MacOSX10.5.sdk/"
	LDFLAGS="$LDFLAGS $MACOSXVERSIONFLAGS"
	CFLAGS="$CFLAGS $MACOSXVERSIONFLAGS"
	CXXFLAGS="$CXXFLAGS $MACOSXVERSIONFLAGS"
	CPPFLAGS="$CPPFLAGS $MACOSXVERSIONFLAGS"
	export LDFLAGS CFLAGS CXXFLAGS CPPFLAGS
}

# CMake, ImageMagick, pour leur config, teste leur petit monde en essayant de se lier à Carbon.
putainDeLibJPEGDeMacOSX()
{
	[ -z "$dejaAppelePutainDeLibJPEGDeMacOSX" ] || return 0
	dejaAppelePutainDeLibJPEGDeMacOSX=1
	mac || return 0
	# Ces trous du cul d'Apple ont cru bon créer une libJPEG.dylib à eux, qui évidemment ne sert à personne d'autre qu'à eux (les symboles à l'intérieur sont tous préfixés _cg_, comme CoreGraphics). Et avec un système de fichier insensible à la casse, cette connasse de libJPEG de merde prend le pas sur la très légitime libjpeg que l'on souhaite utiliser un peu partout.
	case essai in
		tentative)
			LDFLAGS="-L/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/ImageIO.framework/Versions/A/Resources $LDFLAGS"
			export LDFLAGS
			;;
		test)
			# Ou alors je lui pète la tête, à ce gros nase de CMake qui s'obstine à se lier avec Carbon. C'est pas son boulot, je me démerderai au cas par cas avec les conneries que me fait faire Apple. Putain ils font chier quand même avec leurs bourdes.
			grep -rl 'framework Carbon' . | while read f
			do
				filtrer "$f" sed -e 's/-framework Carbon//g'
			done
			# Mais quand même il va en avoir besoin un coup à la fin.
			filtrer bootstrap sed -e '/-o cmake/{
s//-framework Carbon -o cmake/
s#${cmake_ld_flags}#-L/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/ImageIO.framework/Versions/A/Resources -lJPEG &#
}'
			;;
		essai)
			# Mais ce foutu machin s'obstine à se lancer dans je ne sais quelles variables d'environnement. Alors on essaie de lui dire de se compiler en indépendant.
			[ "x$1" = xprudemment ] || LDFLAGS="`echo "$LDFLAGS" | sed -e "s#-L$INSTALLS/lib##g"`"
			DYLD_FALLBACK_LIBRARY_PATH="$LD_LIBRARY_PATH:$DYLD_LIBRARY_PATH:$DYLD_FALLBACK_LIBRARY_PATH"
			unset LD_LIBRARY_PATH
			unset DYLD_LIBRARY_PATH
			export DYLD_FALLBACK_LIBRARY_PATH
			;;
	esac
}

# Sous Mavericks, cette foutue lib nous pollue systématiquement: gcc, ld, nm, etc., y sont liés, car ceux d'/usr/bin sont de simples lanceurs qui font un xcodebuild -find xxx (allant chercher le vrai exécutable dans le bon SDK pour la plateforme de l'ordi). On appelle donc systématiquement notre putaineDeLigJPEGDeMacOSX.
mac && putainDeLibJPEGDeMacOSX prudemment || true

ldlOptionnel()
{
	# Les BSD embarquent dlopen en standard; Linux veut du -ldl. Certains Makefiles codent en dur ce -ldl Linux.
	
	cat > /tmp/testDlopen.c <<TERMINE
void * dlopen(const char *path, int mode);
int main(int argc, char ** argv)
{
dlopen("coucou", 0);
return 0;
}
TERMINE
	cc -o /tmp/testDlopen /tmp/testDlopen.c 2> /dev/null || return 0 # Si plantage de compilation, -ldl est nécessaire, alors on le laisse dans les Makefiles.
	
	for i in "$@"
	do
		filtrer "$i" sed -e 's/-ldl//g'
	done
}

fpic()
{
	CFLAGS="$CFLAGS -fPIC"
	export CFLAGS
}

fbsd10()
{
	# Pour les couillons qui confondent freebsd10 et freebsd1.
	find . -name configure | while read i ; do
		[ ! -f "$i" ] || filtrer "$i" sed -e 's#freebsd1\*#freebsd1|freebsd1.*#g'
	done
}

macLibtool()
{
	# Sous Mac OS X, un éventuel libtool GNU compilé prend le pas sur celui d'Apple, seul à gérer des options à la con telles que -static. On place donc un alias du libtool officiel quelque part dans le PATH avant celui éventuellement compilé par nos soins.
	# Un lien symbolique ferait l'affaire, mais en écrivant un script enrobeur on se réserve la possibilité d'agir sur les paramètres si un jour quelque chose ne nous plaît pas.
	mac || return 0
	[ -e /usr/bin/libtool ] || return 0
	cat > "$TMP/$$/libtool" <<TERMINE
#!/bin/sh
/usr/bin/libtool "\$@"
TERMINE
	chmod a+x "$TMP/$$/libtool"
}

macMath()
{
	# http://clang-developers.42468.n3.nabble.com/problems-building-libcxx-td2353619.html
	mac || return 0
	cat > /tmp/1.cpp <<TERMINE
#include <cmath>
void f() { llroundl(0.0); }
TERMINE
	! c++ -c -o /tmp/1.o -D__STRICT_ANSI__ /tmp/1.cpp > /dev/null 2>&1 || return 0
	
	CPPFLAGS="$CPPFLAGS -U__STRICT_ANSI__"
	export CPPFLAGS
}

llvmStrnlen()
{
	# Les dernières versions LLVM (et donc tous ceux qui l'embarquent, type Rust) utilise strnlen qui n'est pas définie dans un Mac OS X 10.8, par exemple.
	cat > /tmp/1.cpp <<TERMINE
#include <string.h>
void toto() { strnlen("zug", 2); }
TERMINE
	! c++ -c -o /tmp/1.o /tmp/1.cpp > /dev/null 2>&1 || return 0
	
	# On est obligés de ne cibler que le minimum de fichiers, car d'autres .cpp, d'une part servent à définir le strnlen qui finira dans les biblios, d'autre part incluent des enum dont une valeur est strnlen.
	find . \( -name MachOYAML.cpp -o -name HeaderMap.cpp -o -name LLVMOutputStyle.cpp -o -name macho2yaml.cpp \) -print0 | xargs -0 grep -l strnlen | while read f
	do
		# On insère notre remplacement avant la première ligne qui ne soit pas in include, une ligne vide, ou un commentaire.
		filtrer "$f" awk 'fini{print;next}/#include/{print;next}/^ *\/\//{print;next}/^ *$/{print;next}{print "#define strnlen monstrnlen" ; print "static inline int monstrnlen(const char * c, int t) { int n; for(n = -1; ++n < t && c[n];) {} return n; }" ; print ; fini=1}'
	done
}


# Remplacement d'utilitaires.

filtreargs()
{
	(
		sed -e '/ICI/,$d' < "$SCRIPTS/util.filtreargs.sh"
		cat
		sed -e '1,/ICI/d' < "$SCRIPTS/util.filtreargs.sh"
	) > "$TMP/$$/$1"
	chmod a+x "$TMP/$$/$1"
}

# http://www.techques.com/question/1-1482450/Broken-Java-Mac-10.6
case `uname` in
	Darwin)
for i in jar javac java
do
	rm -f "$TMP/$$/$i"
	commande="`command -v $i || true`"
	cat > "$TMP/$$/$i" <<TERMINE
#!/bin/sh
export DYLD_LIBRARY_PATH=
"$commande" "\$@"
TERMINE
	chmod a+x "$TMP/$$/$i"
done
		;;
esac

runghc()
{
	# GHC est vraiment une putain d'usine à gaz plantogène. Je crois que je vais finir par abandonner Darcs à cause de GHC (impossibilité de compiler avec un simple compilo C, bibliothèques qui se mettent en vrac si on a le malheur de tenter d'installer une extension 7.6.2 sur la 7.6.3 qui l'embarquait déjà, plantages inopinés de la distrib binaire, etc.).
	# Redéfinir cette fonction dans le shell ne mettra pas à l'abri les sudo runghc Setup install, mais au moins les configure et build, non sudo, en bénéficieront.
	until /usr/local/bin/runghc "$@" || [ $? -ne 11 ]
	do
		true
	done
}

pseudocargo()
{
	ou="$TMP"
	
	if [ ! -e "$ou/get-pip.py" ]
	then
		( cd "$ou" && curl -O https://bootstrap.pypa.io/get-pip.py )
		sudo LD_LIBRARY_PATH=$LD_LIBRARY_PATH PATH=$PATH python "$ou/get-pip.py"
		sudo LD_LIBRARY_PATH=$LD_LIBRARY_PATH PATH=$PATH pip install pytoml dulwich requests # requests pour la version de krig.
	fi
	
	[ -d "$ou/index" ] || git clone https://github.com/rust-lang/crates.io-index "$ou/index"
	mkdir -p "$ou/bazar"
	
	mkdir -p "$ou/localbin"
	[ -e "$ou/localbin/gmake" ] || ln -s "`command -v make`" "$ou/localbin/gmake"
	PATH="`pwd`/localbin:$PATH"
	export PATH
	triplet=
	machine="`uname -m | sed -e 's/amd64/x86_64/g'`"
	systeme="`uname -s | tr '[A-Z]' '[a-z]'`"
	case $machine-$systeme in
		*-darwin) triplet="$machine-apple-$systeme" ;;
		*) triplet="$machine-unknown-$systeme" ;;
	esac
	#ldflagsPseudocargo
	# Mac OS X 10.9, rustc 1.16.0: si -L <lechemindesbibliosinternesrustc>, pouf, plantage instantané!
	LD_LIBRARY_PATH="`echo ":$LD_LIBRARY_PATH:" | sed -e "s#:$destrust/lib:#:#g"`" \
	"$HOME/src/projets/pseudocargo/bootstrap.py" --crate-index "$ou/index" --target-dir "$ou/bazar" --no-clone --no-clean --target "$triplet" --patchdir "$SCRIPTS/cargo.patches/" "$@"
	
	CARGODEST="$ou/bazar"
}

ldflagsPseudocargo()
{
	# À FAIRE: se greffer au build s'il y en a déjà un dans le Cargo.toml, plutôt que de l'écraser.
	
	filtrer Cargo.toml sed -e '/\[package\]/{
a\
build = "ldflags.rs"
}'
	(
		echo "fn main(){"
		for i in `printf %s "$LDFLAGS" | sed -e 's/-L  */-L/g'`
		do
			case "$i" in
				-L*)
					echo "$i" | sed -e 's/^../println!("cargo:rustc-link-search=native=/' -e 's/$/");/'
					;;
			esac
		done
		echo "}"
	) > ldflags.rs
}

# http://stackoverflow.com/a/1116890
readlinkf()
{
	(
		TARGET_FILE="$1"

		cd "`dirname $TARGET_FILE`"
		TARGET_FILE="`basename $TARGET_FILE`"

		# Iterate down a (possible) chain of symlinks
		while [ -L "$TARGET_FILE" ]
		do
			TARGET_FILE="`readlink $TARGET_FILE`"
			cd "`dirname $TARGET_FILE`"
			TARGET_FILE="`basename $TARGET_FILE`"
		done

		# Compute the canonicalized name by finding the physical path 
		# for the directory we're in and appending the target file.
		PHYS_DIR="`pwd -P`"
		RESULT="$PHYS_DIR/$TARGET_FILE"
		echo "$RESULT"
	)
}

statf()
{
	case `uname` in
		*BSD) stat -f "$@" ;;
		*) stat --format "$@" ;;
	esac
}

[ ! -e "$SCRIPTS/util.guili.sh" ] || . "$SCRIPTS/util.guili.sh"

argVersion="`argVersion "$@"`"
analyserParametresInstall "$@"

for util_module in silo
do
	[ ! -e "$SCRIPTS/util.$util_module.sh" ] || . "$SCRIPTS/util.$util_module.sh"
done
[ ! -e "$SCRIPTS/util.compilo.sh" ] || . "$SCRIPTS/util.compilo.sh"
[ ! -e "$SCRIPTS/util.sudo.sh" ] || . "$SCRIPTS/util.sudo.sh"
[ ! -e "$SCRIPTS/util.serveur.sh" ] || . "$SCRIPTS/util.serveur.sh"
for f in "$SCRIPTS/util.guili."*".sh"
do
	[ ! -e "$f" ] || . "$f"
done
[ ! -e "$SCRIPTS/util.multiarch.sh" ] || . "$SCRIPTS/util.multiarch.sh"
[ ! -e "$SCRIPTS/util.python.sh" ] || . "$SCRIPTS/util.python.sh"

prerequis= # Certains installeurs appellent prerequis(), mais sans avoir initialisé $prerequis. Résultat, ils héritent de l'environnement; pour peu que quelqu'un prérequière un de ces logiciels, ses prerequis seront donc lui-même, et nous voilà partis pour une boucle infinie…
guili__xpath=
meilleurCompilo
_initPrerequisLibJpeg
proxy -

initSilo

! commande pypadest || export PYTHONPATH="`pypadest`"

# Initialisation standard.

if [ -z "$INSTALLS_MAX" ]
then
case " $INSTALLS_AVEC_INFOS " in
	*" -n "*|*" -i "*|"  ") true ;; # En mode INSTALLS_AVEC_INFOS -n ou -i, ou sans INSTALLS_AVEC_INFOS, on laisse dérouler, car on souhaite atteindre la plus haute version qui réponde aux critères définis dans la suite des opérations.
	*)
		# En mode INSTALLS_AVEC_INFOS par défaut, changement de stratégie: on ne veut pas installer selon des critères, juste savoir ce qu'il y a déjà d'installé qui réponde aux critères…
		argVersionExistante="`versions "$logiciel$argOptions" "$argVersion" | tail -1 | sed -e 's/^.*-//'`"
		# … sauf si on ne trouve décidément rien d'installé.
		[ -z "$argVersionExistante" ] || argVersion="$argVersionExistante"
		;;
esac
fi
