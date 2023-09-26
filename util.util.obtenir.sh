# Copyright (c) 2010-2014,2016-2020 Guillaume Outters
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

#- Récupération ----------------------------------------------------------------

obtenir()
{
	fichier="$2"
	[ "$fichier" = "" ] && fichier=`echo "$1" | sed -e 's:^.*/::'`
	dest="$INSTALL_MEM/$fichier"
	if [ ! -f "$dest" ] ; then
		echo "Téléchargement de ${fichier}…" >&2
		telech "$1" "$fichier" > "$dest" || rm -f "$dest"
		[ -e "$dest" ] || return 1
	fi
	echo "$dest"
}

telech()
{
	local u="$1" l="$2" commande
	[ -n "$l" ] || l="$u"
	commande=curl
	[ -z "$http_proxy_user" ] || commande="curl -U $http_proxy_user"
	(
		export PATH="$INSTALLS/bin:$PATH" LD_LIBRARY_PATH="$INSTALLS/lib64:$INSTALLS/lib:$LD_LIBRARY_PATH"
	affSiBinaire $commande -L -k -s "$u"
	)
}

#- Décompression ---------------------------------------------------------------

initDecompresseur()
{
	local decomp format="$1" archive="$2"
	eval mem="\$GUILI_TAR_$format"
	case "$mem" in
		"")
			tar tJf "$archive" > /dev/null 2>&1 && mem=1 || mem=0
			# On en fait bénéficier les prérequis qui se poseraient la même question.
			# Bon en vrai ça ne marche pas vraiment, car nous ne sommes invoqués qu'à la première décompression d'un .xz, qui se passe après appel des prérequis.
			# On pourrait, entre destiner et prerequis, si archive est en *.xz, invoquer initDecompresseursXz.
			export GUILI_TAR_$format=$mem
			;;
	esac
	case "$mem" in
		1) dec="tar xJf" ; liste="tar tJf" ;;
		*)
			case "$format" in
				xz) dec="de7z" ; liste="liste7z" ;;
			esac
			;;
	esac
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

#- Récupération et décompression -----------------------------------------------

nomArchive()
{
	echo "$1" | sed \
		-e 's#\([^/]*\)\(/archive/refs/tags/\)v*\([0-9][^/]*\)$#\1\2\1-\3#'
}

# Téléchargege $1 et va dans le dossier obtenu en décompressant.
obtenirEtAllerDans()
{
	local liste dec archive dossier fichier
	
	cd "$TMP"
	echo Obtention et décompression… >&2
	# Certains site (SourceForge, GitHub, etc.) donnent des archives au nom peu explicite.
	fichier="$2"
	if [ -z "$fichier" ]
	then
		fichier="`nomArchive "$1"`"
		fichier="`basename "$fichier"`"
		# À FAIRE: ce qui suit doit remonter dans nomArchive:
		echo "$1" | egrep '/archive/v*[0-9][0-9.]*(\.tar|\.gz|\.tgz|\.xz|\.bz2|\.7z|\.zip|\.Z){1,2}$' && fichier="`echo "$1" | sed -e 's#/archive/v*#-#' -e 's#.*/##'`" || true
	fi
	archive=`obtenir "$1" "$fichier"`
	[ -f "$archive" ] || exit 1
	case "$fichier" in
		*.tar.gz|*.tgz|*.tar.Z) dec="tar xzf" ; liste="tar tzf" ;;
		*.tar) dec="tar xf" ; liste="tar tf" ;;
		*.tar.bz2) dec="tar xjf" ; liste="tar tjf" ;;
		*.zip) dec="dezipe" ; liste="listeZip" ;;
		*.xz) initDecompresseur xz "$archive" ;;
		*.7z) dec="de7z" ; liste="liste7z" ;;
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
			$dec "$archive" `_obtenirEtAllerDansVersion_sauf`
			cd "`cat "$TMP/$$/listeArchive"`"
			;;
		*) # Si le machin se décompresse en plusieurs répertoires, on va s'en créer un pour contenir le tout.
			dossier="`mktemp -d "$TMP/temp.guili.$logiciel-$version.XXXXXX"`"
		cd "$dossier"
			$dec "$archive" `_obtenirEtAllerDansVersion_sauf`
			;;
	esac
}

_obtenirEtAllerDansVersion_sauf()
{
	local p
	case "$obtenirSauf" in ?*) for p in $obtenirSauf ; do print " --exclude $p" ; done ;; esac
	# À FAIRE: seulement si le décompresseur le supporte, évidemment.
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
	echo "=== $logiciel`argOptions`$GUILI_MOIRE $version ===" >&2
	
	# A-t-on un binaire déjà compilé?
	
	installerBinaireSilo
	guili_sansBinaire # Appel de guili_sansBinaire si l'on arrive ici.
	
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

# Les logiciels dont l'obtenirEtAllerDansVersion ne donne pas lieu à compilation (ex.: sources en un langage de script qui s'installe par simple dépôt) peuvent surcharger cette fonction en guili_sansBinaire() { true ; }
guili_sansBinaire()
{
	if [ -n "$INSTALL_SANS_COMPIL" ]
	then
		rouge "# Aucun paquet binaire n'est disponible." >&2
		jaune "(veuillez le générer sur une machine de compil' similaire (même processeur, même OS, même chemin d'\$INSTALLS) qui ensuite le pousse vers le silo central)" >&2
		jaune "(attention, le binaire devra avoir exactement même version et mêmes options que sus-mentionné. Si le serveur de compil' prend la liberté d'ajouter une option +jantesalu, forcez-le à la désactiver via un +-jantesalu)" >&2
		exit 1
	fi
}
