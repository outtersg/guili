#!/bin/sh
# Copyright (c) 2011,2016-2019 Guillaume Outters
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
	verifierConsommationOptions
	if [ -z "$install_dest" ]
	then
		dest="`versions -v "$version" "$logiciel+$argOptions" | tail -1`"
		if [ -z "$dest" ]
		then
			dest="$INSTALLS/$logiciel`argOptions`-$version"
		fi
	else
	dest="$install_dest"
	fi
	guili_temoins "$dest" "$1"
	infosInstall -s
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

	# On arrive en fin de parcours, c'est donc que la compil s'est terminée sans erreur. On le marque.
	sudo touch `guili_temoins`
	guili_deps_pondre
	
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
	
	utiliserSiDerniere "$INSTALLS/$sut_lv"
	
	infosInstall
}

utiliserSiDerniere()
{
	local dest="$dest"
	[ -n "$1" ] || dest="$1"
	local lv="`basename "$dest"`"
	
	local logicielParam="`echo "$lv" | sed -e 's/-[0-9].*//' -e 's/+[^-]*$//'`"
	local derniere="`versions "$logicielParam" | tail -1 | sed -e 's#.*/##' -e "s/^$lv-.*/$lv/"`" # Les déclinaisons de nous-mêmes sont assimilées à notre version (ex.: logiciel-x.y.z-misedecôtécarpourrie).
	if [ ! -z "$derniere" ]
	then
		if [ "$lv" != "$derniere" -a -z "$GUILI_INSTALLER_VIEILLE" ]
		then
			echo "# Attention, $lv ne sera pas utilisé par défaut, car il existe une $derniere plus récente. Si vous voulez forcer l'utilisation par défaut, faites un $SCRIPTS/utiliser $lv" >&2
			return 0
		fi
	fi
	[ ! -d "$dest" ] || sudoku "$SCRIPTS/utiliser" "$dest"
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
	) | sed -e 's/^#/##/' -e 's/^@/#/' > "$fprt"
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
		mv "$fpr" "$fpr.orig"
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

# Trouve un logiciel, renvoie le dossier trouvé et le contenu de son .guili.prerequis séparé par des :
# Un test d'existence est fait pour chaque élément avant de le renvoyer (donc les lignes du .guili.prerequis référençant des dossiers inexistants ne seront pas renvoyées).
# Utilisation: prereqs [-u] (-s <suffixe>)* [-d] <logiciel> [<version>]
#   -u
#     Unique. Si une dépendance est listée deux fois, elle n'apparaîtra que sur sa première occurrence.
#     Attention, ceci peut donner lieu à des comportements non maîtrisés, par exemple si un logiciel prérequérait openssl 1.1 puis le 1.0 puis re le 1.1, sans le -u on obtiendra ossl-1.1:ossl-1.0:ossl-1.1, et on est sûrs que la libssl.so trouvée sera la 1.1 (sur les OS qui donnent la priorité à la première mention aussi bien que sur ceux qui privilégient la dernière). En -u, on aura ossl-1.1:ossl-1.0, et libssl.so sera alors peut-être celle d'OpenSSL 1.0.
#   -s 
#     Si précisé, tous les chemins seront suffixés de /<suffixe>. Appeler par exemple -s bin pour générer un $PATH, -s lib64 -s lib pour un LD_LIBRARY_PATH.
#   -d
#     Les <logiciel>s ne sont pas des logiciels dont retrouver le chemin, mais directement les chemins.
#   <logiciel> [<version>]
#     Logiciel (avec options si besoin) et contraintes de version au sens GuiLI.
prereqs()
{
	local dossiers= testDeja= suffixes= d
	while [ $# -gt 0 ]
	do
		case "$1" in
			-u) testDeja='if(deja[$0])next;deja[$0]=1;' ;;
			-s) suffixes="$suffixes$2:" ; shift ;;
			-d) dossiers=deja ;;
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
	[ -n "$dossiers" -o $# -eq 0 ] || err "# Je n'ai pas trouvé $*"
	local initAwk="nSuffixes = 0; `IFS=: ; for s in $suffixes ; do echo 'c = "'"$s"'"; suffixes[++nSuffixes] = c ? "/"c : "";' ; done`"
	
	for d in $dossiers
	do
		echo "$d"
		[ -f "$d/.guili.prerequis" ] && cat "$d/.guili.prerequis" || [ "$d" = "$INSTALLS" ] || rouge "# Je n'ai pas trouvé $d/.guili.prerequis" >&2
	done | awk "BEGIN{$initAwk}/^#/{next}{ $testDeja for(n = 0; ++n <= nSuffixes;) print \$0\"\"suffixes[n]; }" | while read d
	do
		[ ! -d "$d" ] || echo "$d"
	done | tr '\012' : | sed -e 's/:$//'
}
