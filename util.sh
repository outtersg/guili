#!/bin/sh
# Copyright (c) 2003-2005,2008,2011-2012 Guillaume Outters
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

INSTALL_MEM="$HOME/tmp/paquets"
[ -z "$INSTALLS" ] && INSTALLS="/usr/local" || true
[ -z "$TMP" ] && TMP=/tmp || true

mkdir -p "$TMP/$$" "$INSTALL_MEM"
export PATH="`echo $TMP/$$:$INSTALLS/bin:$PATH | sed -e 's/^\.://' -e 's/:\.://g' -e 's/::*/:/g'`"
export LD_LIBRARY_PATH="$INSTALLS/lib64:$INSTALLS/lib:$LD_LIBRARY_PATH"
export DYLD_LIBRARY_PATH="$LD_LIBRARY_PATH"
export CMAKE_LIBRARY_PATH="$INSTALLS"

CPPFLAGS="-I$INSTALLS/include $CPPFLAGS"
#CFLAGS="-I$INSTALLS/include $CFLAGS"
#CXXFLAGS="-I$INSTALLS/include $CXXFLAGS"
LDFLAGS="-L$INSTALLS/lib64 -L$INSTALLS/lib $LDFLAGS"
PKG_CONFIG_PATH="$INSTALLS/lib/pkgconfig"
CFLAGS="-O3 $CFLAGS" # Trop de logiciels (PHP\xe2\x80\xa6) se compilent par d\xc3\xa9faut sans optimisation. C'est ballot.
CXXFLAGS="-O3 $CXXFLAGS"
export CPPFLAGS CFLAGS CXXFLAGS LDFLAGS PKG_CONFIG_PATH
export ACLOCAL="aclocal -I $INSTALLS/share/aclocal"

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
		$commande -L -k -s "$1" > "$dest" || rm -f "$dest"
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
	7za l "$@" | awk '/^---/{if((entre=!entre)){match($0,/-*$/);posNom=RSTART;next}}{if(entre)print substr($0,posNom)}' # On repère la colonne du chemin du fichier à ce qu'elle est la dernière; et pour ce faire on se base sur la ligne de tirets qui introduit la liste (et la clôt).
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
	echo "=== $logiciel $version ===" >&2
	for i in liste dec archive dossier fichier ; do local $i ; done 2> /dev/null
	
	cd "$TMP"
	echo Obtention et décompression… >&2
	# Certains site (SourceForge, GitHub, etc.) donnent des archives au nom peu explicite.
	fichier="$2"
	if [ -z "$fichier" ]
	then
		fichier="`basename "$1"`"
		echo "$1" | egrep '/archive/v[0-9][0-9.]*(\.tar|\.gz|\.tgz|\.xz|\.bz2|\.7z|\.zip|\.Z){1,2}$' && fichier="`echo "$1" | sed -e 's#/archive/v#-#' -e 's#.*/##'`" || true
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
	$liste "$archive" | sed -e 's=^./==' -e 's=^/==' -e 's=/.*$==' | sort -u > "$TMP/$$/listeArchive"
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

# Remplacements de commandes (pour la phase d'amorçage).

if ! command -v curl 2> /dev/null >&2
then
	[ -x "$TMP/minicurl" ] || cc -o "$TMP/minicurl" "$SCRIPTS/minicurl.c"
	curl()
	{
		"$TMP/minicurl" "$@"
	}
fi

suer()
{
	argsSu="$1"
	shift
	[ "x$argsSu" = x- ] && argsSu="$argsSu $1" && shift || true
	
	argsColles="`for arg in "$@" ; do printf "%s" "$arg" ; done`"
	for sep in ' ' '|' '\t' ':' ';' '@' '#' '!' '+' '=' '\r' ; do
		commande="`for arg in "$@" ; do printf "%s$sep" "$arg" ; done | xxd -p | tr -d '\012'`"
		# Si le séparateur est utilisé dans la commande, il va être difficile de s'en servir sans perdre notre shell. En ce cas on passe au séparateur suivant.
		echo "$argsColles" | grep -q "`printf %s "$sep"`" && continue || true
		su $argsSu -c 'commande="`echo '"$commande"' | xxd -r -p`" ; IFS="`printf '"'$sep'"'`" ; $commande'
		return $?
	done
	echo "# Impossible de trouver un séparateur shell qui ne soit pas utilisé par la commande: $*" >&2
	return 1
}

# Si on n'a pas déjà remplacé sudo (multiples inclusions d'util.sh), faisons-le: on gérera des cas tordus.
# L'usage principal de notre sudo surchargé est l'installation dans les dossiers privilégiés; 
# En effet nous utilisons le sudo pour installer dans $INSTALLS, mais parfois ce n'est pas nécessaire de passer su pour cela.

if [ "x`command -v sudoku 2> /dev/null`" != xsudoku ] # On se protège contre une double inclusion…
then
	sudo="`command -v sudo 2> /dev/null`" # … ne serait-ce que pour éviter qu'ici notre mémorisation du vrai sudo soit l'alias sudo qu'on déclare juste ci-dessous.
	# Malheureusement, historiquement, on a un peu abusé du sudo pour nos installs (au lieu d'utiliser le sudoku dédié, qui n'est arrivé qu'après); du coup, pour compatibilité, on doit conserver cette surcharge sudo = sudoku.
	sudo() { sudoku "$@" ; }
fi

# sudoku: Super User DO KUrsaal (sudo destiné aux installs dans des emplacements partagés, donc a priori protégés: quand on est dans un kursaal, on respecte le mobilier, n'est-ce pas?)
sudoku()
{
	# On se met dans un sous-shell pour ne pas polluer l'environnement avec notre bazar.
	
	(
		# Analyse des paramètres.
		
			enTantQue=root
			sudo_env=
			while [ "$#" -gt 0 ]
			do
				case "$1" in
					*=*)
						eval "$1"
						export "`echo "$1" | cut -d = -f 1`"
						# À FAIRE: utiliser garg si présent.
						sudo_env="$sudo_env $1"
						shift
						;;
					-u) shift ; enTantQue="$1" ; shift ;;
					*) break ;;
				esac
			done
		
		# Qu'a-t-on à notre disposition?
		
		# sdk_ecris: peut-on écrire dans le dossier cible?
		touch "$INSTALLS/.sudoku.temoin" 2> /dev/null && rm -f "$INSTALLS/.sudoku.temoin" 2> /dev/null && sdk_ecris=1 || sdk_ecris=0
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

utiliser=utiliser
command -v $utiliser 2> /dev/null >&2 || utiliser="$SCRIPTS/utiliser"

sutiliser()
{
	# On arrive en fin de parcours, c'est donc que la compil s'est terminée sans erreur. On le marque.
	sudo touch "$dest/.complet"
	
	sut_lv="$1"
	[ ! -z "$sut_lv" ] || sut_lv="`basename "$dest"`"
	
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
	sudo $utiliser "$INSTALLS/$sut_lv"
	
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
	cc_varsawk=
	while [ $# -gt 0 ]
	do
		case "$1" in
			-d) shift ; cc_sep="$1" ;;
			*=*) cc_varsawk="$cc_varsawk|$1" ;;
			*) [ -z "$cc_f" ] && cc_f="$1" || break ;; # À FAIRE: pouvoir traiter plusieurs fichiers.
		esac
		shift
	done
	
	filtrer "$cc_f" awk '
BEGIN {
	s = "'"$cc_sep"'";
	c = "#";
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
		if(match($0, "^( *"c" *)?"i""s))
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
		if(match($0, "^"i""s))
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

preCFlag()
{
	CPPFLAGS="$* $CPPFLAGS"
	CFLAGS="$* $CFLAGS"
	CXXFLAGS="$* $CXXFLAGS"
	export CPPFLAGS CFLAGS CXXFLAGS
}

preChemine()
{
	preCFlag "-I$1/include"
	LDFLAGS="-L$1/lib64 -L$1/lib $LDFLAGS"
	export LDFLAGS
}

prerequerir()
{
	INSTALLS_AVEC_INFOS=1 inclure "$1" "$2" 6> "$TMP/$$/temp.inclureAvecInfos"
	
	# L'idéal est que l'inclusion ait reconnu INSTALLS_AVEC_INFOS et nous ait sorti ses propres variables, à la pkg-config, en appelant infosInstall() en fin (réussie) d'installation.
	# Dans le cas contraire (inclusion ancienne mode peu diserte), on recherche parmi les paquets installés celui qui répond le plus probablement à notre demande, via reglagesCompilPrerequis.
	
	IFS=: read pr_logiciel pr_logicielEtOptions pr_version pr_dest < "$TMP/$$/temp.inclureAvecInfos" || true
	case "|$pr_logiciel|$pr_version|$pr_dest|" in
		*"||"*) pr_logiciel="$1" ; _prerequerirRetrouver "$1" "$2" ;;
	esac
	> "$TMP/$$/temp.inclureAvecInfos"
	
	reglagesCompil "$pr_logiciel" "$pr_version" "$pr_dest"
	
	# Pour répondre à ma question "Comment faire pour avoir en plus de stdout et stderr une stdversunsousshellderetraitement" (question qui s'est posée un moment dans l'élaboration d'inclureAvecInfos):
	# ( ( echo Un ; sleep 2 ; echo Trois >&3 ; sleep 2 ; echo Deux >&2 ; sleep 2 ; echo Trois >&3 ) 3>&1 >&4 | sed -e 's/^/== /' ) 4>&1
}

_prerequerirRetrouver()
{
	dossierRequis=
	for peutEtreDossierRequis in `versions "$1"`
	do
		versionRequis="`echo "$peutEtreDossierRequis" | sed -e "s#.*-##"`"
		testerVersion "$versionRequis" $2 && pr_dest="$peutEtreDossierRequis" && pr_version="$versionRequis" || true
	done
}

reglagesCompil()
{
	rc_logiciel="$1"
	versionInclus="$2"
	dossierRequis="$3"
	
	PREINCLUS="$PREINCLUS $1:$versionInclus"
	eval "dest`echo "$1" | tr +- __`=$dossierRequis"
	export "version_`echo "$1" | tr +- __`=$versionInclus"
	preChemine "$dossierRequis"
	PATH="$dossierRequis/bin:$PATH" # Pour les machins qui ont besoin de lancer des exécutables (xml2-config etc.) de leurs prérequis.
	LD_LIBRARY_PATH="$dossierRequis/lib64:$dossierRequis/lib:$LD_LIBRARY_PATH" # Python et compagnie.
	PKG_CONFIG_PATH="$dossierRequis/lib/pkgconfig:$PKG_CONFIG_PATH"
	if [ -e "$dossierRequis/share/aclocal" ] ; then # aclocal est pointilleux: si on lui précise un -I sur quelque chose qui n'existe pas, il sort immédiatement en erreur.
	ACLOCAL="`echo "$ACLOCAL" | sed -e "s#aclocal#aclocal -I $dossierRequis/share/aclocal #"`"
	fi
	export CPPFLAGS CFLAGS CXXFLAGS LDFLAGS PATH LD_LIBRARY_PATH PKG_CONFIG_PATH ACLOCAL
}

# Si l'on ne veut pas inclure d'office tout $INSTALLS (CPPFLAGS, LDFLAGS), on peut appeler cette chose. Devrait en fait être fait par défaut (pour que les logiciels ne se lient qu'aux prérequis explicites), mais trop de logiciels reposent sur ce $INSTALLS; on est donc en mode "liste rouge", les logiciels souhaitant se distancier de ce comportement devant appeler uniquementPrerequis.
# Ex.: openssl, dans sa compil, ajoute -L. à la fin de ses paramètres de lien (après ceux qu'on lui a passés dans $LDFLAGS). Résultat, pour le lien de libssl.so, qui fait un -lcrypto, si LDFLAGS contient -L/usr/local/lib, il trouvera la libcrypto d'une version plus ancienne déjà installée dans /usr/local/lib, plutôt que celle qu'il vient de compiler dans .
# ATTENTION: ne plus utiliser, préférer exclusivementPrerequis (qui gère aussi le PATH et autres joyeusetés).
# NOTE: avantages / inconvénients
# Avantages: lorsque la même version d'un prérequis est recompilée avec des options différentes (ex.: libtiff+jpeg8 / libtiff+jpegturbo, ou postgresql+ossl10 / postgresql+ossl11), les deux vont créer leurs liens symboliques au même endroit dans $INSTALLS, donc notre logiciel risque de pointer sur l'un au lieu de l'autre (par exemple un php sans exclusivementPrerequis va se compiler sur un postgresql+ossl10, donc sera liée indirectement à openssl 1.0.x, mais le jour où on installe postgresql+ossl11, $INSTALLS/lib/libpq.so sera remplacée et notre php pétera, lié à openssl 1.0.x et à libpq lui-même lié à openssl 1.1.x); exclusivementPrerequis permet de faire pointer le logiciel vers les biblios obtenues par prerequis, donc avec leur version codée en dur (dans notre exemple: il utilisera $INSTALLS/postgresql+ossl10/lib/libpq.so).
# Inconvénient: les chemins étant codés en dur, on ne peut monter en version de façon transparente un des prérequis du logiciel sans le recompiler.
uniquementPrerequis()
{
	export CPPFLAGS="`echo " $CPPFLAGS " | sed -e 's/ /  /g' -e "s# -I$INSTALLS/include # #g"`"
	export LDFLAGS="`echo " $LDFLAGS " | sed -E -e 's/ /  /g' -e "s# -L$INSTALLS/lib(64)? # #g"`"
}

exclusivementPrerequis()
{
	uniquementPrerequis
	export PATH="`echo "$PATH" | tr : '\012' | egrep -v "^$INSTALLS/s?bin$" | tr '\012' ':' | sed -e 's/:$//'`"
	export LD_LIBRARY_PATH="`echo "$LD_LIBRARY_PATH" | tr : '\012' | egrep -v "^$INSTALLS/lib(64)?$" | tr '\012' ':' | sed -e 's/:$//'`"
	export PKG_CONFIG_PATH="`echo "$PKG_CONFIG_PATH" | tr : '\012' | egrep -v "^$INSTALLS/lib/pkgconfig$" | tr '\012' ':' | sed -e 's/:$//'`"
	export DYLD_LIBRARY_PATH="$LD_LIBRARY_PATH"
	export CMAKE_LIBRARY_PATH=
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
[ ! -z "$prerequis_libjpeg" ] || prerequis_libjpeg="libjpeg"
export prerequis_libjpeg

prerequis()
{
	echo "$prerequis" | sed -e 's#  *\([<>0-9]\)#@\1#g' | tr ' :' '\012 ' | sed -e 's#@# #g' -e '/^$/d' -e 's/\([<>=]\)/ \1/' > $TMP/$$/temp.prerequis
	while read requis versionRequis
	do
		case "$requis" in
			*\(\))
				"`echo "$requis" | tr -d '()'`" $versionRequis
				;;
			*)
				prerequerir "$requis" "$versionRequis"
				;;
		esac
	done < $TMP/$$/temp.prerequis # Affectation de variables dans la boucle, on doit passer par un fichier intermédiaire plutôt qu'un | (qui affecterait dans un sous-shell, donc sans effet sur nous).
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

if echo "$1" | grep -q '^\(\(\(>=\|<\) \)*[0-9.]* *\)*$' && [ ! -z "$1" ]
then
	argVersion="$1"
	shift
fi

analyserParametresInstall()
{
	argOptions=
	while [ $# -gt 0 ]
	do
		case "$1" in
			--src) shift ; install_obtenu="$1" ;;
			--dest) shift ; install_dest="$1" ;;
			+[a-z]*) argOptions="$argOptions$1" ;;
		esac
		shift
	done
}

analyserParametresInstall "$@"
case "$0" in
	-*) true ;;
	*)
install_moi="$SCRIPTS/`basename "$0"`"
		;;
esac

infosInstall()
{
	[ -z "$INSTALLS_AVEC_INFOS" ] || echo "$logiciel:$logiciel$argOptions:$version:$dest" >&6
}

destiner()
{
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
	[ -e "$dest/.complet" ] && infosInstall && exit 0 || true
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
				if(i >= ntailles)
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

# Renvoie les versions pour un logiciel donnée, triées par version croissante.
versions()
{
	versions_expr_version='[0-9.]+'
	[ "x$1" = x-v ] && versions_expr_version="$2" && shift && shift || true
	versions_logiciel="`echo "$1" | cut -d + -f 1`"
	versions_expr="/$versions_logiciel`options "$1" | sed -e 's#[+]#([+][^+]*)*[+]#g'`([+][^+]*)*-$versions_expr_version$"
	find "$INSTALLS" -maxdepth 1 \( -name "$versions_logiciel-*" -o -name "$versions_logiciel+*-*" \) | egrep "$versions_expr" | triversions
}

# Renvoie les options dans l'ordre de référence (alphabétique).
options()
{
	echo "$*" | sed -e 's/^[^+]*//' | tr + '\012' | grep -v ^$ | sort | sed -e 's/^/+/' | tr '\012' ' ' | sed -e 's/ $//'
}

option()
{
	case "$argOptions+" in
		*+$1+*) return 0
	esac
	return 1
}

### Fonctions utilitaires dans le cadre des modifs. ###

sudoer()
{
	echo "$1 ALL=(ALL) NOPASSWD: $2" | sudo sh -c 'cat >> /etc/sudoers'
}

listeIdComptesBsd()
{
	( cut -d : -f 3 < /etc/group ; cut -d : -f 3 < /etc/passwd ; cut -d : -f 4 < /etc/passwd ) | sort -n
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

_analyserParametresCreeCompte()
{
	cc_vars="cc_qui cc_id"
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
			*)
				[ -z "$cc_vars" ] && auSecours
				for i in $cc_vars
				do
					export $i="$1"
					break
				done
				cc_vars="`echo "$cc_vars" | sed -e 's/[^ ]* //'`"
				;;
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
			sudo pw useradd "$@"
			;;
		Linux)
			sudo useradd "$@"
			;;
	esac
}

creeCompte()
{
	_analyserParametresCreeCompte "$@"
	
	# Si le compte existe déjà, on le suppose correctement créé.
	grep -q "^$cc_qui:" /etc/passwd && return 0 || true
	
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
	
	if ! grep -q "^$cc_groupe:" /etc/group
	then
		case `uname` in
			FreeBSD) sudo pw groupadd "$cc_groupe" -g "$cc_id" ;;
			Linux) sudo groupadd -g "$cc_id" "$cc_groupe" ;;
		esac
	fi
	
	# Options POSIX de groupe.
	
	cc_opts_groupe= ; [ -z "$cc_groupe" ] || cc_opts_groupe="-g $cc_groupe"
	cc_opts_autres_groupes= ; [ -z "$cc_autres_groupes" ] || cc_opts_autres_groupes="-G $cc_autres_groupes"
	cc_opts_groupes="$cc_opts_groupe $cc_opts_autres_groupes"
	
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

meilleurCompilo()
{
	# À FAIRE:
	# - classer les compilos disponibles par date de publication. Pour ce faire, établir une correspondance version -> date (la date donnée par certains compilos est celle de leur compilation, pas de leur publication initiale).
	# - pouvoir privilégier un compilo en lui ajoutant virtuellement un certain nombre d'années d'avance sur les autres.
	# - pouvoir spécifier un --systeme pour se cantonner au compilo livré avec le système (par exemple pour compiler une extension noyau, ou avoir accès aux saloperies de spécificités de Frameworks sous Mac OS X).
	if command -v clang 2> /dev/null >&2 && command -v clang++ 2> /dev/null >&2
	then
	export CC=clang CXX=clang++
	elif command -v gcc 2> /dev/null >&2 && command -v g++ 2> /dev/null >&2
	then
		export CC=gcc CXX=g++
	else
		export CC=cc CXX=c++
	fi
	case `uname` in
		Darwin)
			# Sur Mac, un clang "mimine" doit pour pouvoir appeler le ld système comme le ferait le compilo système, définir MACOSX_DEPLOYMENT_TARGET (sans quoi le ld est perdu, du type il n'arrive pas à se lier à une hypothétique libcrt.o.dylib).
			export MACOSX_DEPLOYMENT_TARGET="`tr -d '\012' < /System/Library/SDKSettingsPlist/SDKSettings.plist | sed -e 's#.*>MACOSX_DEPLOYMENT_TARGET</key>[ 	]*<string>##' -e 's#<.*##'`"
			;;
	esac
}

meilleurCompilo

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

[ ! -e "$SCRIPTS/util.serveur.sh" ] || . "$SCRIPTS/util.serveur.sh"
[ ! -e "$SCRIPTS/util.multiarch.sh" ] || . "$SCRIPTS/util.multiarch.sh"
