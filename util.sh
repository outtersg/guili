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
if [ -z "$SANSSU" ]
then
	case `id -u` in
		0) SANSSU=1 ;;
		*) SANSSU=0 ;;
	esac
fi

mkdir -p "$TMP/$$"
export PATH="`echo $TMP/$$:$INSTALLS/bin:$PATH | sed -e 's/^\.://' -e 's/:\.://g' -e 's/::*/:/g'`"
export LD_LIBRARY_PATH="$INSTALLS/lib64:$INSTALLS/lib:$LD_LIBRARY_PATH"
export DYLD_LIBRARY_PATH="$LD_LIBRARY_PATH"
export CMAKE_LIBRARY_PATH="$INSTALLS"

CPPFLAGS="-I$INSTALLS/include $CPPFLAGS"
#CFLAGS="-I$INSTALLS/include $CFLAGS"
#CXXFLAGS="-I$INSTALLS/include $CXXFLAGS"
LDFLAGS="-L$INSTALLS/lib $LDFLAGS"
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

if [ "x$SANSSU" = x1 ] || ! command -v sudo 2> /dev/null >&2
then
	sudo()
	{
		(
			enTantQue=
			while [ "$#" -gt 0 ]
			do
				case "$1" in
					*=*)
						eval "$1"
						export "`echo "$1" | cut -d = -f 1`"
						shift
						;;
					-u) shift ; enTantQue="$1" ; shift ;;
					*) break ;;
				esac
			done
			if [ -z "$enTantQue" -o "$enTantQue" = "`id -n -u`" ]
			then
		"$@" # Avec un peu de chance on est en root.
			else
				suer - "$enTantQue" "$@"
			fi
		)
	}
fi

utiliser=utiliser
command -v $utiliser 2> /dev/null >&2 || utiliser="$SCRIPTS/utiliser"

sutiliser()
{
	logicielParam="`echo "$1" | sed -e 's/-[0-9].*//'`"
	derniere="`versions "$logicielParam" | tail -1 | sed -e 's#.*/##' -e "s/^$1-.*/$1/"`" # Les déclinaisons de nous-mêmes sont assimilées à notre version (ex.: logiciel-x.y.z-misedecôtécarpourrie).
	if [ ! -z "$derniere" ]
	then
		if [ "$1" != "$derniere" ]
		then
			echo "# Attention, $1 ne sera pas utilisé par défaut, car il existe une $derniere plus récente. Si vous voulez forcer l'utilisation par défaut, faites un $SCRIPTS/utiliser $1" >&2
			return 0
		fi
	fi
	sudo $utiliser -r "$INSTALLS" "$@"
}

if [ ! -z "$SANSU" ]
then
	utiliser() { true ; }
	sutiliser() { true ; }
fi

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
	truc=`cd "$SCRIPTS" && ls -d "$1-"[0-9]* "$1" 2> /dev/null | tail -1`
	if [ -z "$truc" ] ; then
		echo '# Aucune instruction pour installer '"$1" >&2
		return 1
	fi
	shift
	"$SCRIPTS/$truc" "$@"
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
	LDFLAGS="-L$1/lib $LDFLAGS"
	export LDFLAGS
}

reglagesCompilPrerequis()
{
	dossierRequis=
	for peutEtreDossierRequis in `versions "$1"`
	do
		basename "$peutEtreDossierRequis" | grep -q "^$1-[0-9][0-9.a-z]*$" || continue
		versionRequis="`echo "$peutEtreDossierRequis" | sed -e "s#$INSTALLS/$1-##"`"
		testerVersion "$versionRequis" $2 && dossierRequis="$peutEtreDossierRequis" && versionInclus="$versionRequis" || true
	done
	PREINCLUS="$1:$versionInclus $PREINCLUS"
	eval "dest`echo "$1" | tr - _`=$dossierRequis"
	preChemine "$dossierRequis"
	PATH="$dossierRequis/bin:$PATH" # Pour les machins qui ont besoin de lancer des exécutables (xml2-config etc.) de leurs prérequis.
	LD_LIBRARY_PATH="$dossierRequis/lib:$LD_LIBRARY_PATH" # Python et compagnie.
	PKG_CONFIG_PATH="$dossierRequis/lib/pkgconfig:$PKG_CONFIG_PATH"
	if [ -e "$dossierRequis/share/aclocal" ] ; then # aclocal est pointilleux: si on lui précise un -I sur quelque chose qui n'existe pas, il sort immédiatement en erreur.
	ACLOCAL="`echo "$ACLOCAL" | sed -e "s#aclocal#aclocal -I $dossierRequis/share/aclocal #"`"
	fi
	export CPPFLAGS CFLAGS CXXFLAGS LDFLAGS PATH LD_LIBRARY_PATH PKG_CONFIG_PATH ACLOCAL
}

prerequerir()
{
	inclure "$@"
	reglagesCompilPrerequis "$@"
}

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
	while [ $# -gt 0 ]
	do
		case "$1" in
			--src) shift ; install_obtenu="$1" ;;
			--dest) shift ; install_dest="$1" ;;
		esac
		shift
	done
}

analyserParametresInstall "$@"
install_moi="$SCRIPTS/`basename "$0"`"

destiner()
{
	dest="$INSTALLS/$logiciel-$version"
	[ -z "$install_dest" ] || dest="$install_dest"
	[ -d "$dest" ] && exit 0 || true
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
	awk '
		{
			ls[length(ls)+1] = $0;
			v = $0;
			sub(/^([^0-9][^-]*-)+/, "", v);
			vs[length(vs)+1] = v;
			split(v, decoupe, ".");
			for(i in decoupe)
				if(i >= length(tailles) || length(decoupe[i]) > tailles[i])
					tailles[i] = length(decoupe[i]);
		}
		END {
			for(nl = 0; ++nl <= length(vs);)
			{
				c = "";
				v = vs[nl];
				split(v, decoupe, ".");
				for(nv = 0; ++nv <= length(tailles);)
					c = c sprintf("%0"tailles[nv]"d", nv > length(decoupe) ? 0 : decoupe[nv]);
				print c" "ls[nl]
			}
		}
	' | sort | cut -d ' ' -f 2-
}

# Renvoie les versions pour un logiciel donnée, triées par version croissante.
versions()
{
	find "$INSTALLS" -maxdepth 1 -name "$1-*" | triversions
}

### Fonctions utilitaires dans le cadre des modifs. ###

listeIdComptesBsd()
{
	( cut -d : -f 3 < /etc/group ; cut -d : -f 3 < /etc/passwd ; cut -d : -f 4 < /etc/passwd ) | sort -n
}
creeCompte()
{
	cc_ou=
	cc_qui=$1
	cc_id=$2
	cc_coquille=/coquille/vide
	[ "x$1" = x-s ] && shift && cc_coquille="$1" && shift || true
	[ "x$1" = x-d ] && shift && cc_ou="$1" && shift || true
	case `uname` in
		FreeBSD)
			if ! grep -q "^$cc_qui:" /etc/passwd
			then
				if [ -z "$cc_id" ]
				then
					cc_id=`listeIdComptesBsd | grep -v ..... | tail -1`
					cc_id=`expr $cc_id + 1`
				else
					if listeIdComptesBsd | grep -q "^$cc_id$"
					then
						echo "# Le numéro $cc_id (choisi pour le compte $cc_qui) est déjà pris." >&2
						exit 1
					fi
				fi
				sudo pw groupadd $cc_qui -g $cc_id
				sudo pw useradd $cc_qui -u $cc_id -g $cc_id -s $cc_coquille
				[ -z "$cc_ou" ] || sudo pw usermod $cc_qui -d "$cc_ou"
			fi
			;;
	esac
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
	ldflagsPseudocargo
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

[ ! -e "$SCRIPTS/util.serveur.sh" ] || . "$SCRIPTS/util.serveur.sh"
