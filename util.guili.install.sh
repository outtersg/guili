#!/bin/sh
# Copyright (c) 2011,2016-2020 Guillaume Outters
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

GUILI_F_VERSION=".guili.version"

# NOTE: DPOM
# Destiner, Prérequis, Obtenir, Modifs
# - Destiner: calcule le chemin du dossier d'install: <logiciel><+options>*-<version>
# - Prérequis: s'assure que tous les prérequis sont là, et en profite pour modifier l'environnement en vue de compiler (ajout des prérequis en -I et -L aux CFLAGS et LDFLAGS, etc.).
# - Obtenir(EtAllerDansVersion): va chercher les sources, les décompresse, et fait un cd dedans
# - Modifs: modifie le source avant configuration et compilation
# À cela s'ajoutent quelques subtilités:
# 1. Lorsque D voit que le logiciel est déjà installé, hop, il sort.
# 2. Lorsqu'O trouve une version déjà compilée, il la décompresse, et hop il sort.
# 3. D (ainsi que la sortie de toute fin en cas de compilation complète), si $INSTALL_AVEC_INFOS est définie, sort un certain nombre d'infos sur le logiciel installé.
# L'ordre est parfois malmené, et le parcours suboptimal:
# a. Souvent P précède D, afin que D (avec $INSTALL_AVEC_INFOS) tienne compte dans son affichage de tout ce qui aura été modifié par les prérequis dans l'environnement.
# b. Du fait de a., quand un logiciel est déjà installé, on reparcourt tous ses prérequis, ce qui un peu dommage (coûteux, quoi).
# c. P va chercher tous les prérequis: aussi bien ceux nécessaires à la construction que ceux qui serviront à l'exécution. C'est bête, car si on a récupéré une version compilée on n'a pas besoin des premiers.
# À FAIRE: réorganiser le processus pour répondre aux points ci-dessus.
# - placer dans un .guili.env(.cache pour dire qu'on peut le supprimer sans risque?) les variables affichées habituellement avec $INSTALL_AVEC_INFOS permettrait de ne pas avoir à nous relancer pour les récupérer (coûteux), mais juste lire ce fichier. De plus ça permettrait la reproductibilité (les paramètres seraient vraiment ceux calculés le jour où le paquet a été compilé, figés dans le temps).
#   Bien entendu si le fichier manque, on se rabat sur le circuit long et on invoque le GuiLI 'il en profitera pour générer le .env, tiens).
# - scinder prérequis de compilation et prérequis à l'exécution. On aurait alors trois chemins (sous réserve que le point précédent soit corrigé pour obtenir l'ordre D - P):
#   - si le logiciel est déjà installé:      D [sortie]
#   - si une version binaire est disponible: D Pexéc O [sortie]
#   - sinon, si la compil est nécessaire:    D Pcomp Pexéc O M [etc.]
# - attention cependant aux options implicites, que seul l'appel du logiciel permet de retrouver; ainsi ./curl par défaut va compiler un ./curl +idn, donc si un logiciel a pour prérequis curl il ne faudra pas chercher simplement les curl-* mais les curl*+idn*-*.
#   Pour cela, un mécanisme de liens symboliques (calculés la première fois) permettrait de faire pointer sur le bon logiciel; ainsi .guili/curl<params d'invocation>-<version> pointerait sur ../curl<params calculés>-<version>
DPOM()
{
	echo "# DOP pas implémenté." >&2
	return 1
}

destiner()
{
	local argOptionsResolu
	verifierConsommationOptions
	
	# Un amorceur peut désirer s'installer à un endroit générique (pour rester en place tandis que son logiciel sous-jacent évolue).
	case "$install_dest:$logiciel:$guili_alias" in
		":_"*":") true ;;
		":_"*":"?*)
			local alias
			IFS=:
			for alias in $guili_alias
			do
				case "$alias" in
					"$logiciel"*)
						# Le premier alias trouvé avec pour préfixe $logiciel devient destination d'install (plutôt que simple alias vers la destination d'install).
						gris "Installation générique dans $INSTALLS/$alias" >&2
						install_dest="$INSTALLS/$alias"
						break
						;;
				esac
			done
			;;
	esac
	
	if [ -z "$install_dest" ]
	then
		# Comparaison options demandées / options effectives:
		# Ex.: le +ossl demandé est devenu +ossl11, ou une option implicite a été ajoutée.
		# Si différentes, on créera des raccourcis pour que la prochaine demande des "options demandées" tombe sur là où nous nous installons réellement (avec les options effectives).
		
		argOptionsResolu="`argOptions`"
		if [ "x$argOptionsResolu" != "x$argOptionsOriginal" ]
		then
			argOptionsOriginal="`argOptions="$argOptionsOriginal" argOptions`"
			[ "x$argOptionsResolu" = "x$argOptionsOriginal" ] || guili_alias="$guili_alias:$logiciel$argOptionsOriginal-$version"
		fi
		
		# Détermination de la destination.
		
		dest="`destCible`"
		if [ -z "$dest" ]
		then
			dest="$INSTALLS/$logiciel$argOptionsResolu-$version"
		fi
	else
	dest="$install_dest"
	fi
	guili_temoins "$dest" "$1"
	infosInstall -s
	
	# Notre destination est-elle bien libre?
	# infosInstall -s s'est assuré qu'aucun dossier complet n'y figurait (auquel cas inutile de nous réinstaller).
	# Reste le cas du lien symbolique, par exemple si nous voulons installer libjpeg-x.y alors qu'il existe un alias libjpeg-x.y -> libjpegturbo-z.t: en ce cas nous prenons le pas sur l'alias (c'était un pis-aller, nous sommes l'install officielle). Laisser l'alias serait catastrophique: nous écraserions l'install de libjpegturbo par celle de libjpeg.
	if [ -L "$dest" ]
	then
		sudoku rm "$dest"
	fi
}

destCible()
{
	if [ -z "$INSTALLS_MIN" ]
	then
		versions -1 -f -v "$version" "$logiciel+$argOptions"
	else
		versions -1 -f "$logiciel+$argOptions" "$argVersion"
	fi
}

# Utilisation: sutiliser [-|+]
#   -|+
#	 Si +, et si $INSTALL_SILO est définie, on pousse une archive binaire de notre $dest installé vers ce silo. Cela permettra à de futurs installant de récupérer notre produit de compil plutôt que de tout recompiler.
#	 Si -, notre produit de compil ne sera pas poussé (à mentionner par exemple s'il installe des bouts ailleurs que dans $dest, car alors l'archive de $dest sera incomplète).
#	 Si non mentionné: comportement de - si on est un amorceur (car supposé installer des trucs dans le système, un peu partout ailleurs que dans $dest); sinon comportement de +.
sutiliser()
{
	local biner=
	[ "x$1" = "x-" -o "x$1" = "x+" ] && biner="$1" && shift || true
	if [ -z "$biner" ]
	then
		case "$logiciel" in
			_*) biner=- ;; # Par défaut, un amorceur n'est pas silotable (car il s'installe un peu partout dans le système: rc.d, init.d, systemd, etc.).
			*) biner=+ ;;
		esac
	fi
	
	local dest="$dest" desto="$dest" logiciel="$logiciel" argOptions="`argOptions`" version="$version"
	local lov="$logiciel$argOptions-$version"
	# Nous demande-t-on de sutiliser autre chose que nous (par exemple nous n'avons pas de destination propre, nous nous greffons à autre chose)?
	# En ce cas nous devons en retrouver les options et version, afin de déterminer nos cadets.
	case "$1" in
		"") true ;;
		"$logiciel-$version"|"$logiciel$argOptions-$version") # Ancienne mode: on précisait quoi utiliser.
			jaune "# Attention, sutiliser déduit maintenant ses paramètres de l'environnement ($lov) et non plus de ses paramètres ($*)." >&2
			;;
		*)
			dest="$1"
			lov="`lover "$dest"`"
			[ -n "$lov" ] || err "# \"$1\" doit être un identifiable comme logiciel+options-version."
			love -e "logiciel argOptions version" "$lov"
			;;
	esac
	local ddest="`bn "$dest"`"
	
	[ "x$biner" = x- ] || guili_postcompil
	
	# On arrive en fin de parcours, c'est donc que la compil s'est terminée sans erreur. On le marque.
	sudo touch `guili_temoins`
	guili_deps_pondre
	
	# Si on est censés pousser notre binaire vers un silo central, on le fait.
	if [ "x$biner" = "x+" ]
	then
		pousserBinaireVersSilo "$lov"
	fi
	
	guili_localiser
	
	diag + "$ddest"
	[ "$ddest" = "$lov" ] || diag : "($lov)"
	utiliserSiDerniere
	
	infosInstall
}

utiliserSiDerniere()
{
	local lv="$logiciel`argOptions`-$version"
	local ddest="`bn "$dest"`"
	local aff="$ddest"
	[ "$lv" = "$ddest" ] || aff="$aff ($lv)"
	
	# Si $logiciel et $version ont été bouffés quelque part, c'est une erreur, car on va en avoir besoin dans ce qui suit.
	case "$version" in
		""|*[^.0-9]*|.*|*.) rouge "# Votre logiciel doit posséder une version pour être comparé aux précédentes installation." >&2 ; return 1 ;;
	esac
	
	local cadets="`cadets "$INSTALLS/$lv"`"
	if [ -n "$cadets" ]
	then
		local derniere="`echo "$cadets" | tail -1`"
		derniere="`basename "$derniere"`"
		if [ "$lv" != "$derniere" -a -z "$GUILI_INSTALLER_VIEILLE" ]
		then
			echo "# Attention, $aff ne sera pas utilisé par défaut, car il existe une $derniere plus récente. Si vous voulez forcer l'utilisation par défaut, faites un $SCRIPTS/utiliser $ddest" >&2
		fi
	fi
	if [ -d "$dest" ]
	then
		# Si notre dossier d'installation ne porte pas notre logiciel et notre version, on l'inscrit dans un fichier explicitant ce que nous contenons en terme de $logiciel-$version.
		[ "$lv" = "$ddest" ] || sudoku sh -c "echo $lv > $dest/$GUILI_F_VERSION"
		sudoku "$SCRIPTS/utiliser" -p "$cadets" --videur "$SCRIPTS/util siPlusRecent42 $logiciel $lv" "$dest"
		# Si notre logiciel a des alias (ex.: libjpegturbo en tant que libjpeg, ou curl+ossl11 en tant que curl), allons-y.
		IFS=:
		tifs guili_tirerAlias -p "`unset IFS ; f() { IFS=\| ; echo "$*" ; } ; f $cadets`" "$dest" $guili_alias
	fi
}

# Arbitre destiné à $SCRIPTS/utiliser
# Utilisation: siPlusRecent42 <logiciel> <logiciel0> <logiciel1>
# Sort avec un code 42 si <logiciel0> est plus récent que <logiciel1> (soit que le nommage en <logiciel>(+<option>)*-<version> l'indique, soit qu'un $INSTALLS/<logicielx>/.guili.version permette de retrouver cette version).
siPlusRecent42()
{
	local l="$1" l0="$2" l1="$3"
	[ -s "$INSTALLS/$l0/$GUILI_F_VERSION" ] && l0="`cat "$INSTALLS/$l0/$GUILI_F_VERSION"`" || true
	[ -s "$INSTALLS/$l1/$GUILI_F_VERSION" ] && l1="`cat "$INSTALLS/$l1/$GUILI_F_VERSION"`" || true
	case "$l0" in $l+*|$l-[0-9][0-9.]*) true ;; *) exit 1 ;; esac
	case "$l1" in $l+*|$l-[0-9][0-9.]*) true ;; *) exit 1 ;; esac
	[ "`( echo "$l0" ; echo "$l1" ) | triversions | tail -1`" = "$l0" ] || exit 1
	exit 42
}

guili_tirerAlias()
{
	local preserves= pseudo
	[ "x$1" = x-p ] && preserves="$2" && shift && shift || true
	local dest="$1" ; shift
	local INSTALLS="$INSTALLS"
	case "$dest" in
		/*) INSTALLS="`dirname "$dest"`" ;;
	esac
	dest="`bn "$dest"`"
	
	for pseudo in "$@"
	do
		# Veut-on tirer un lien de nous-mêmes ou rien vers nous-mêmes?
		
		case "$pseudo" in "$dest"|"") continue ;; esac
		
		# Existe-t-il quelque chose auquel nous ne devons pas toucher?
		
		if [ -e "$INSTALLS/$pseudo" -o -L "$INSTALLS/$pseudo" ] # -e renvoie "faux" sur les liens cassés.
		then
			# Soit un vrai dossier ou fichier.
			
			if [ ! -L "$INSTALLS/$pseudo" ]
			then
				jaune "Impossible de créer $INSTALLS/$pseudo -> $dest: emplacement occupé." >&2
				continue
			fi
			
			# Soit un lien que nous ne devons pas écraser.
			
			[ -z "$preserves" ] || eval "case \"\$pseudo\" in $preserves) continue ;; esac"
			
			# Soit déjà nous-mêmes.
			
			case "`readlink "$INSTALLS/$pseudo"`" in "$dest") continue ;; esac
			
			# Bon sinon ça saute.
			
			sudoku rm "$INSTALLS/$pseudo"
		fi
		
		gris "Alias $dest <- $pseudo"
		diag = "$pseudo -> $dest"
		sudoku ln -s "$dest" "$INSTALLS/$pseudo"
	done
}

sortieSansReinstall()
{
	# Oups, avait-on oublié de se référencer la dernière fois? On corrige.
	
	utiliserSiNouvelle "$dest" || true
	
	# Si nous sommes un amorceur, notre LSJ a lui peut-être été réinstallé.
	
	case "$logiciel" in
		_*) sortieAmorceurSansReinstall ;;
	esac
}

sortieAmorceurSansReinstall()
{
	[ -s "$TMP/$$/temp.modifs" ] || return 0
	local nomServeur="$nomServeur" serveur
	[ -n "$nomServeur" ] || nomServeur="`echo "$logiciel" | cut -c 2-`$suffixe"
	for serveur in $nomServeur
	do
		servir "$serveur" restart
	done
}

# Utilise (place ses pions dans $INSTALLS/bin, etc.) le logiciel en cours d'installation s'il s'agit de la version la plus récente sur cette machine et:
# - il est invoqué en direct
# - ou c'est la première fois qu'on l'utilise
# En effet, il serait malencontreux qu'un logiciel réinstallé comme dépendance d'un autre, se réutilise alors que manuellement l'utilisateur a préférer utiliser une version plus ancienne.
# En outre sur les gros logiciels (genre le compilo, testé à chaque fois), utiliser est coûteux.
utiliserSiNouvelle()
{
	local utilises="$INSTALLS/.guili/utilises"
	if [ ! -f "$utilises" ]
	then
		[ -d "$INSTALLS/.guili" ] || sudoku mkdir -p "$INSTALLS/.guili"
		sudoku touch "$utilises"
	fi
	
	local deja=oui
	grep -q -F "$dest" < "$utilises" || deja=non
	
	[ -n "$INSTALLS_AVEC_INFOS" -a $deja = oui ] && return 0 || true
	
	utiliserSiDerniere
	[ $deja = oui ] || echo "$dest" | sudoku sh -c "cat >> $utilises"
}

guili_deps_crc()
{
	if commande sha1
	then
		sha1
	elif commande sha1sum
	then
		sha1sum | awk '{print$1}'
	fi
}

guili_prerequis_path()
{
	local GUILI_PATH="$GUILI_PATH"
	[ -n "$GUILI_PATH" ] || GUILI_PATH="$INSTALLS"
	local r="`echo "$guili_ppath" | cut -d \< -f 1`"
	args_suppr -d : `IFS=: ; for racine in $GUILI_PATH ; do printf "r %s " "$racine" ; done`
	# NOTE: args_reduc
	# args_reduc pour les greffons qui font un double prerequis:
	# - un dans le cadre de l'analyserParametresPour (ne comportant alors comme prérequis que le logiciel auquel se greffer, sans personnalisation)
	# - un à titre personnel (recomportant le logiciel, mais aussi les dépendances perso).
	# On évitera ainsi la disgracieuse présence en double du logiciel dans la variable résultante.
	# Ceci ne marche évidemment que si les deux occurrences du logiciel se suivent; dans le cas contraire, le mécanisme d'args_reduc, dicté par la prudence, conservera les deux: si un autre bidule s'intercale, on ne peut supprimer une occurrence du logiciel sans atteindre au comportement, car si toto:titi:toto nous assure que toto écrasera titi, les simplifications toto:titi ou titi:toto ont des résultats différents selon que le système a une politique "le premier arrivé prime" ou "le dernier écrase tout".
	echo "$r" | args_reduc -d :
}

# Dépose un fichier-témoin des dépendances utilisées.
# À FAIRE: distinguer prérequis de compil des prérequis d'exécution. Cf. commentaire sur "auto-dépendance" dans ecosysteme.c.
guili_deps_pondre()
{
	local fpr="$dest/.guili.prerequis"
	local fprt="$TMP/$$/.guili.prerequis"
	local dests="`guili_temoins | tr ' ' '\012' | while read temoin ; do dirname "$temoin" ; done`"
	
	[ -n "$dests" ] || return 0 # Si nous sommes des nomades ne nous installant nulle part…
	
	# On se marque comme dépendances de nos prérequis, qu'ils sachent que s'ils se désinstallent ils nous mettent dans la mouise (histoire de leur donner mauvaise conscience).
	
	local cPrerequis="`guili_prerequis_path`"
	(
		echo "$cPrerequis" | tr : '\012' | ( grep -v ^$ || true )
		IFS=:
		for cPrerequi in $cPrerequis
		do
			pdeps="$cPrerequi/.guili.dependances"
			preqs="$cPrerequi/.guili.prerequis"
			for destbis in $dests
			do
				[ -e "$pdeps" ] && grep -q "^$destbis$" < "$pdeps" || echo "$destbis" | grep -v "^$cPrerequi$" # Si notre cible est notre prérequis, elle ne s'inscrit pas comme dépendance d'elle-même (ex.: apc s'installe dans php tout en le prérequérant).
			done | ( unset IFS ; sudoku -d "$cPrerequi" sh -c "cat >> $pdeps" ) || true
			if [ -s "$preqs" ]
			then
				echo "@ $preqs"
				cat "$preqs"
			fi
		done
	) | sed -e 's/^#/##/' -e 's/^@/#/' | guili_prerequis_defiltrer $dests > "$fprt"
	# À FAIRE?: générer un fichier alternatif avec une séparation entre la racine et le logiciel, pour qu'on puisse reconstituer par exemple si le $GUILI_PATH a changé mais possède les mêmes logiciels.
	# À FAIRE: générer aussi un .pc pour les logiciels qui ne viennent pas avec le leur.
	
	# Et on historise notre liste de prérequis.
	
	if [ -e "$fpr" ] && ! diff -q "$fpr" "$fprt"
	then
		# Deux cas si l'on arrive ici:
		# - on a récupéré un paquet précompilé, venant avec son .prerequis; il faut alors signaler que nous n'installons pas exactement dans le même environnement que la source.
		# - ou bien on vient de recompiler sur la présente machine, et on écrase une précédente install'. Cependant ceci ne peut arriver que si le .complet a été dégommé (et le .prerequis a de fortes chances de l'avoir été aussi), ou si un passage outre est effectué (mais dans ce cas on suppose la situation maîtrisée).
		jaune "# Attention, ce paquet est installé dans un environnement différent de celui pour lequel il a originellement été compilé:" >&2
		diff "$fpr" "$fprt" | jaune >&2
		sudoku mv "$fpr" "$fpr.orig"
	fi
	
	local temoin destbis
	for destbis in $dests
	do
		case "$destbis" in
			"$dest") sudoku sh -c "cat > $fpr" < "$fprt" ;;
			*)
				if [ "`grep -v "^$destbis$" < "$fprt" | wc -l`" -ge 1 ]
				then
					(
						echo "#+++ `basename "$dest"` +++"
						grep -v "^$destbis$" < "$fprt"
						echo "#--- `basename "$dest"` ---"
					) | sudoku -d "$destbis" sh -c "cat >> \"$destbis/.guili.prerequis\"" || true
				fi
				;;
		esac
	done
}

# Sort d'une liste de prérequis passée en stdin, toute référence à un des paquets mentionnés en paramètres, et à ses propre prérequis.
# Ex.: si stdin a en entrée:
#   [ toto, titi, # toto, autre, titi, # titi, tierce ]
# guili_prerequis_defiltrer toto donnera:
#   [ titi, # titi, tierce ]
guili_prerequis_defiltrer()
{
	IFS=:
	tifs _guili_prerequis_defiltrer $*
}

_guili_prerequis_defiltrer()
{
	local d
	awk "
function ndieses() { match(\$0, /^##*/); return RLENGTH; }
function bloquer() { niveauBouffe = ndieses(); }
/^##* \//{ if(ndieses() <= niveauBouffe) niveauBouffe = 0; }
niveauBouffe { next; }
`_guili_prerequis_defiltrer_virages "$@"`
niveauBouffe { next; }
{ print; }
"
}

_guili_prerequis_defiltrer_virages()
{
	q="`printf '\004'`"
	for d in "$@"
	do
		echo "$q^$d\$$q{ next; }" # Référence directe au truc: on supprime.
		echo "$q^##* $d/\\.guili\\.prerequis\$$q{ bloquer(); }" # Début de bloc référençant le truc: on active le passage sous silence de tout le bloc.
	done | sed -e 's#/#\\/#g' -e 's/[+]/./g' -e "s#$q#/#g"
}

# Trouve un logiciel, renvoie le dossier trouvé et le contenu de son .guili.prerequis séparé par des :
# Un test d'existence est fait pour chaque élément avant de le renvoyer (donc les lignes du .guili.prerequis référençant des dossiers inexistants ne seront pas renvoyées).
# Utilisation: prereqs [-u] (-s <suffixe>)* [-d] [--ou-theo] <logiciel> [<version>]
#   -u
#     Unique. Si une dépendance est listée deux fois, elle n'apparaîtra que sur sa première occurrence.
#     Attention, ceci peut donner lieu à des comportements non maîtrisés, par exemple si un logiciel prérequérait openssl 1.1 puis le 1.0 puis re le 1.1, sans le -u on obtiendra ossl-1.1:ossl-1.0:ossl-1.1, et on est sûrs que la libssl.so trouvée sera la 1.1 (sur les OS qui donnent la priorité à la première mention aussi bien que sur ceux qui privilégient la dernière). En -u, on aura ossl-1.1:ossl-1.0, et libssl.so sera alors peut-être celle d'OpenSSL 1.0.
#   -s 
#     Si précisé, tous les chemins seront suffixés de /<suffixe>. Appeler par exemple -s bin pour générer un $PATH, -s lib64 -s lib pour un LD_LIBRARY_PATH.
#   -d
#     Les <logiciel>s ne sont pas des logiciels dont retrouver le chemin, mais directement les chemins.
#   --ou-theo
#     Si le logiciel n'est pas installé, ou ne présente pas de "cache" prérequis, les recalcule en interrogeant l'installeur (prérequis théoriques).
#   <logiciel> [<version>]
#     Logiciel (avec options si besoin) et contraintes de version au sens GuiLI.
prereqs()
{
	local dossiers= testDeja= suffixes= d theo=n
	while [ $# -gt 0 ]
	do
		case "$1" in
			-u) testDeja='if(deja[$0])next;deja[$0]=1;' ;;
			-s) suffixes="$suffixes$2:" ; shift ;;
			-d) dossiers=deja ;;
			--ou-theo) theo=ou ;;
			*) break ;;
		esac
		shift
	done
	[ -n "$suffixes" ] || suffixes=:
	if [ -z "$dossiers" ]
	then
		dossiers="`versions -1 "$@"`"
	else
		dossiers="$*"
	fi
	if ! [ -n "$dossiers" -o $# -eq 0 ]
	then
		if [ $theo = ou ]
		then
			dossiers="`varsPrerequis -n dest "$@"`"
		else
			err "# Je n'ai pas trouvé $*"
		fi
	fi
	local initAwk="nSuffixes = 0; `IFS=: ; for s in $suffixes ; do echo 'c = "'"$s"'"; suffixes[++nSuffixes] = c ? "/"c : "";' ; done`"
	
	for d in $dossiers
	do
		echo "$d"
		if [ -f "$d/.guili.prerequis" ] && cat "$d/.guili.prerequis" || [ "$d" = "$INSTALLS" ]
		then
			true
		else
			if [ $theo = ou ]
			then
				local love="`love "$d"`"
				local pr="`varsPrerequis -n prerequis-r "$love"`"
				decoupePrerequis "$pr" | while read p
				do
					varsPrerequis -n dest "$p"
				done
			else
				rouge "# Je n'ai pas trouvé $d/.guili.prerequis" >&2
			fi
		fi
	done | awk "BEGIN{$initAwk}/^#/{next}{ $testDeja for(n = 0; ++n <= nSuffixes;) print \$0\"\"suffixes[n]; }" | while read d
	do
		[ ! -d "$d" ] || echo "$d"
	done | tr '\012' : | sed -e 's/:$//'
}

debiner()
{
	local d= s=
	while [ $# -gt 0 ]
	do
		case "$1" in
			-s) shift ; s="$1" ;;
			-d) shift ; d="$1" ;;
			*) break ;;
		esac
		shift
	done
	sudoku sh <<TERMINE
		set -e
		d="$d"
		s="$s"
		if [ ! -z "\$d" ]
		then
			d="\$d/"
			mkdir -p "\$d"
		fi
		[ -n "\$d" -o -n "\$s" ] || s=.bin
		for b in $*
		do
			d2="\$d"
			s2="\$s"
			if [ -L "\$b" ]
			then
				case "\`readlink "\$b"\`" in
					/*) true ;;
					*) d2= ; [ -n "\$s2" ] || s2=.orig ;; # Un lien relatif ne doit pas être bougé.
				esac
			fi
			b2="\$b\$s2"
			[ -z "\$d2" ] || b2="\$d2\`basename "\$b2"\`"
			mv "\$b" "\$b2"
			cat > "\$b" <<FINI
#!/bin/sh
LD_LIBRARY_PATH="\\\$LD_LIBRARY_PATH:$LD_LIBRARY_PATH"
"\$b2" "\\\$@"
FINI
			chmod a+x "\$b"
		done
TERMINE
}

# Surchargeable par les logiciels pour finaliser l'installation *générique* du logiciel (c'est après cette passe que le logiciel sera poussé vers un éventuel silo à binaires).
guili_postcompil=
guili_postcompil()
{
	local f
	for f in $guili_postcompil true
	do
		"$f"
	done
}
