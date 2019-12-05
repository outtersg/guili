#!/bin/sh
# Copyright (c) 2016-2019 Guillaume Outters
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

# Les fonctions serveurXxx() attendent les variables suivantes:
# - $nom: petit nom du serveur
# - $commande: commande, avec ses paramètres
# - $avant: éventuellement, trucs à exécuter avant le lancement
# - $compte: compte sous lequel doit tourner le serveur
# - $groupe: son groupe
# - $remplacer: si non vide, le serveur sera placé parmi les services système pour être démarré avec la machine (et est lancé dès maintenant). Il remplacera tous les services mentionnés dans $remplacer (il est dès lors judicieux de faire figurer $nom dans $remplacer, afin d'éteindre proprement toute vieille version qui tournerait encore).

serveur_sep="`printf '\003'`"

# Lance / relance / arrête un serveur.
# Utilisateur: servir <serveur> (start|restart|stop|remove)
servir()
{
	local serveur="$1"
	local action="$2"
	[ ! -z "$action" ] || action=restart
	local mode
	local initds
	
	if [ "$action" = remove ]
	then
		servir "$serveur" stop 2> /dev/null || true
	fi
	
	case "`uname`" in
		FreeBSD)
			mode=bsd
			initds=/etc/rc.d
			;;
		Linux)
			mode=initd
			initds=/etc/init.d
			commande systemctl && mode=systemd || true
			;;
		*)
			echo "# Je ne sais pas créer d'amorceur sur `uname`." >&2
			exit 1
	esac
	
	case "$mode" in
		bsd|initd)
			local racine
			for racine in $dest /usr/local ""
			do
				[ -f "$racine/$initds/$serveur" -o -L "$racine/$initds/$serveur" ] || continue # On ne teste pas en -x, car on n'est pas forcément root, donc s'il est exécutable simplement par root le -x renverra faux.
				case "$action" in
					remove)
						sudoku -f rm -f "$racine/$initds/$serveur" `find "$racine"/etc/rc[0-9].d/ -type f 2> /dev/null | grep "/[SK][0-9]*$serveur$"`
						;;
					*)
						sudoku -f "$racine/$initds/$serveur" "$action"
						;;
				esac
				break
			done
			;;
		systemd)
			case "$action" in
				remove)
					sudoku -f systemctl disable "$serveur"
					;;
				*)
					local r=0
					sudoku -f systemctl "$action" "$serveur" || r=$?
					if [ $r -ne 0 ]
					then
						sudoku -f journalctl -xeu "$serveur.service"
						return $r
					fi
					;;
			esac
	esac
}

listeServices()
{
	local zeron="i=0;++i<=n;"
	[ "x$1" = x-r ] && zeron="i=n+1;--i>0;" && shift || true
	
	# Concoction d'un filtrage via awk.
	local filtrageEtTriAwk param n=0
	if [ $# -lt 1 ]
	then
		filtrageEtTriAwk='BEGIN{n=1}{t[$0]=1}'
	else
		filtrageEtTriAwk="BEGIN{n=$#}"
		for param in "$@"
		do
			n=`expr $n + 1`
			filtrageEtTriAwk="$filtrageEtTriAwk/^`echo "$param" | sed -e 's/\*/.*/g'`\$/{if(!t[\$0])t[\$0]=$n}"
		done
	fi
	filtrageEtTriAwk="${filtrageEtTriAwk}END{for($zeron)for(s in t)if(t[s]==i)print s}"
	# Liste, et filtrage.
	(
		# BSD
		if [ -d /etc/rc.d -a -f /etc/rc.conf ]
		then
			# Argh, service -e fait un -x sur les fichiers: s'il n'est pas lancé en root, il ne voit pas les services exécutables seulement par root.
			(
				. /etc/defaults/rc.conf
				. /etc/rc.conf
				find /etc/rc.d `[ -d /usr/local/etc/rc.d ] && echo /usr/local/etc/rc.d || true` -mindepth 1 -maxdepth 1 | sed -e 's#.*/##' | awk "$filtrageEtTriAwk" | while read s # On a intérêt à préfiltrer par awk pour n'effectuer le coûteux test suivant que sur les services réellement demandés.
				do
					eval "test \"x\$`echo "$s" | tr -d -`_enable\" = xYES" && echo "$s" || true
				done
			)
		fi
		# System V
		if [ -d /etc/rc4.d -a -d /etc/rc5.d ]
		then
			find /etc/rc4.d/ /etc/rc5.d/ -mindepth 1 -maxdepth 1 -name 'S[0-9]*' | sed -e 's#.*/S[0-9]*##'
		fi
		# systemd
		if command -v systemctl 2> /dev/null >&2
		then
			systemctl -l | awk '{s=$1;sub(/\.service/,"",s);print s}'
		fi
	) | awk "$filtrageEtTriAwk"
}

serveur()
{
	local nom commande fpid avant compte compteFils comptesPilotes groupe remplacer dest desttemp ports= dservices="$INSTALLS/etc/services.d"
	
	analyserParametresServeur "$@"
	
	for remplace in $remplacer
	do
		servir "$remplace" remove 2> /dev/null || true
	done

	case "`uname`" in
		FreeBSD)
			serveurFreebsd "$@"
			;;
		Linux)
			if command -v systemctl > /dev/null 2>&1
			then
			serveurSystemd "$@"
			else
				serveurLinux "$@"
			fi
			;;
		*)
			echo "# Je ne sais pas créer d'amorceur sur `uname`." >&2
			exit 1
	esac
}

auSecoursServeur()
{
	cat >&2 <<TERMINE
# serveur: installe un serveur / service / démon
# Utilisation: serveur [-n] [-r <autre>]* [-d0 <desttemp>] [-d <dest>] [-u <compte>] [-uf <compte fils>] [-uv <compte var>] [-up <compte pilote>] [-p <fichier pid>] [-e <env>]* [-pre <précommande>] <type> <nom> <commande>
  -n
    Ne pas activer au démarrage de la machine.
  -r <autre>
    Désinstalle <autre> (en plus d'une éventuelle vieille version de <nom>) s'il
    existe en tant que serveur système (principalement en cas de conflit de
    port).
    Ex.: serveur -r apache -r httpd demon nginx …
    Ignoré si -n.
  -d0 <desttemp>
    Placer dans <desttemp>. Si non définie, l'amorceur sera placé directement
    dans <dest>.
  -d <dest>
    Racine de l'install. C'est à partir de cette racine que le démarreur sera
    installé (ex.: \$racine/etc/rc.d/\$nom sous FreeBSD).
  -u <compte>
    Compte Unix sous lequel tourner.
  -uf <compte fils>
  -uv <compte var>
    Compte Unix à qui appartiendront les éventuels dossiers var et compagnie (souvent il s'agira du compte sous lequel tourneront les processus fils).
  -up <compte pilote>
    Compte Unix à qui donner les droits de relancer le serveur.
  -p <fichier pid>
    À indiquer si le processus inscrit son PID dans un fichier déterminé. Sinon
    serveur() lui en attribuera un.
  -e <env>
    Configure l'environnement du serveur. Sous la forme VAR (pour prendre la
    valeur actuelle de \$VAR) ou VAR=VAL.
  -pre <précommande>
    Commandes à lancer avant l'invocation du démarreur (ex.: définition
    d'environnement, création dynamique du fichier de config).
  <type>
    simple: processus avant-plan, qui sera démonisé par le standard système.
  <nom>
    Nom sous lequel apparaît le serveur.
  <commande>
    Commande à lancer.
TERMINE
	exit 1
}

serveurParamEnv()
{
	local var
	for var in "$@"
	do
		case "$var" in
			*=*) true ;;
			*) var="$var=`eval 'echo "$'"$var"'"'`" ;;
		esac
		# Simplification des variables connues.
		# Ce crétin de systemd figurez-vous ne lit pas les lignes de plus de 2048 octets (et pète fort heureusement une erreur de syntaxe à la ligne suivante, ou plus exactement le reste de la ligne qu'il croit être la ligne suivante, disant qu'il manque un =, ce qui nous met la puce à l'oreille). On devra donc sans doute introduire des retours à la ligne, mais on peut commencer par simplifier les expressions qu'on lui fournit (et la lisibilité en bénéficiera sur les autres systèmes).
		if echo "$var" | grep -q '^[^=]*PATH=.*:.*:.*:'
		then
			var="`echo "$var" | cut -d = -f 1`=`echo "$var" | cut -d = -f 2- | args_reduc -d :`"
		fi
		[ -z "$serveur_env" ] || serveur_env="$serveur_env$serveur_sep"
		serveur_env="$serveur_env$var"
	done
}

serveurEnvPourExport()
{
	echo "$serveur_env" | sed -e 's/"/\\"/g' -e "s/^/$serveur_sep/" -e "s/$/$serveur_sep/" -e "s#$serveur_sep\([^=]*=\)#\" \\1\"#g" -e "s/$serveur_sep/\"/g" | sed -e 's/^ *" *//' -e '/^"$/d' -e '/=/s/^/export /'
}

premierParamAffectation()
{
	case "$1" in
		*=*) true ;;
		*) false ;;
	esac
}

analyserParametresServeur()
{
	vars="type nom commande rien"
	nom=
	commande=
	fpid=
	avant=
	compte=
	compteFils=
	comptesPilotes=
	groupe=
	remplacer=
	desttemp= # Destination temporaire.
	sigre=HUP
	# Si on est appelés par un installeur qui utilise du destiner(), dest est définie au dossier (potentiellement utilisateur) dans lequel se trouve tout le bazar
	case "$dest" in
		$INSTALLS/$logiciel*) true ;;
		*) dest= ;; # Dans tous les autres cas, on n'acceptera qu'un -d explicite.
	esac
	serveur_env= # À FAIRE: utiliser garg si disponible.
	while [ $# -gt 0 ]
	do
		case "$1" in
			-d0) shift ; desttemp="$1" ;;
			-d) shift ; dest="$1" ;;
			-n) remplacer="$remplacer -" ;;
			-r) shift ; remplacer="$remplacer $1" ;;
			-u) shift ; compte="$1" ;;
			-uf|-uv) shift ; compteFils="$1" ;;
			-up) shift ; comptesPilotes="$1" ;;
			-p) shift ; fpid="$1" ;;
			-e) shift ; serveurParamEnv "$1" ;;
			-pre) shift ; avant="$avant$serveur_sep$1" ;;
			--sigre) shift ; sigre="$1" ;;
			*)
				if premierParamAffectation $1 # $1 sans guillemets, pour que si "$1" vaut "truc --param=A", on ne voie pas ça comme l'affectation de la valeur "A" à la variable "truc --param".
				then
					serveurParamEnv "$1"
				else
					apAffecter "$1" $vars
				fi
				;;
		esac
		shift
	done

	if [ "x$vars" != xrien ]
	then
		auSecoursServeur
	fi
	
	case "$type" in
		simple|demon) true ;;
		*) auSecoursServeur ;;
	esac
	
	[ -z "$compte" ] || groupe="`id -g -n "$compte"`"
	[ -n "$compteFils" ] || compteFils="$compte"
	[ -n "$comptesPilotes" ] || comptesPilotes="`id -nu` $compte $compteFils"
	
	if [ -z "$desttemp" ]
	then
		desttemp=/tmp/temp.$$.serveur.amorce
		rm -Rf "$desttemp"
		mkdir "$desttemp"
		serveur_puisCopier=oui
	else
		serveur_puisCopier=non
	fi
	
	case "$remplacer " in
		*" - "*) remplacer= ;;
		*) remplacer="$remplacer $nom" ;; # Le serveur remplace ses éventuelles anciennes versions tournant sur le serveur.
	esac
}

serveur_lner()
{
	local options=
	[ "x$1" = x-a ] && options="$1" && shift || true
	local ds="$1" ; shift
	local dd="$1" ; shift
	sudoku -d "$dd" sh <<TERMINE
set -e
. "$SCRIPTS/util.util.chemins.sh"
ds="$ds"
dd="$dd"
IFS=@
fichiers="`IFS=@ ; echo "$*"`"
for f in \$fichiers
do
	d="\$dd/\$f"
	s="\$ds/\$f"
	mkdir -p "\`dirname "\$d"\`"
	[ -L "\$d" ] && rm "\$d" || true
	ln_sr $options "\$s" "\$d"
done
TERMINE
}

serveurFreebsd()
{
	local usrLocal=/usr/local
	local machin_user=
	
	[ ! -z "$dest" ] || dest="$usrLocal"
	
	local nomPropre="`echo "$nom" | tr -d -`"
	
	if [ -z "$fpid" ]
	then
		fpid=$dest/var/run/$nom.pid
		# Bizarre, la doc de daemon dit qu'il faut utiliser -P pour tuer le démon plutôt que le fils (sinon le démon redémarre le fils), mais en pratique ce faisant le stop ne trouve pas le pid. Et comme apparemment le démon ne relance pas le fils, partons sur du -p.
		optionfpiddaemon="-p $fpid"
	fi
	case "$type" in
		simple)
			lanceur="/usr/sbin/daemon"
			paramCompte=
			[ -z "$compte" ] || paramCompte="-u $compte"
			parametres="$paramCompte $optionfpiddaemon $commande"
			;;
		demon) 
			lanceur="`echo "$commande" | awk '{print $1}'`"
			[ -z "$compte" ] || machin_user="${nomPropre}_user=$compte"
			parametres="`echo "$commande" | sed -e 's/^[^ 	]*[ 	]*//'`"
			;;
	esac
	
	mkdir -p "$desttemp/etc/rc.d" "$desttemp/var/run"
	cat > "$desttemp/etc/rc.d/$nom" <<TERMINE
#!/bin/sh
# PROVIDE: $nomPropre
# REQUIRE: NETWORKING
. /etc/rc.subr
name=$nomPropre
rcvar=\`set_rcvar\`
command=$lanceur
extra_commands=reload
sig_reload=SIG$sigre
pidfile=$fpid
command_args="$parametres"
$machin_user
load_rc_config "\$name"
: \${${nomPropre}_enable="NO"}

`echo "$avant" | tr "$serveur_sep" '\012'`
`serveurEnvPourExport`

# La fonction du rc.subr est chiante, elle souhaite vérifier que le PID correspond à un process avec un nom retrouvable. Mais moi une fois que je dis à un lanceur de mettre son PID dans tel fichier, je ne vais pas me poser la question de si le processus qui tournera ce sera lui ou un des innombrables sous-shells ou sous-processus qu'il lancera. Donc on est laxistes.
_find_processes()
{
	local _procname=\$1
	local _interpreter=\$2
	local _psargs=\$3
	local _pref=
	\$PS 2>/dev/null -o pid= -o jid= -o command= \$_psargs | while read _npid _jid reste
	do
		if [ "\$JID" -eq "\$_jid" ]
		then
			echo -n "\$_pref\$_npid"
			_pref=' '
		fi
	done
}

run_rc_command "\$1"
TERMINE
	chmod u+x "$desttemp/etc/rc.d/$nom"
	serveur_porter
	
	if [ "x$serveur_puisCopier" = xoui ]
	then
		sudoku -f sh -c "mkdir -p $dest ; cp -R $desttemp/. $dest/."
	fi
	if [ ! -z "$remplacer" ]
	then
		sudoku -f "$SCRIPTS/rcconfer" ${nomPropre}_enable=YES
	fi
	
	# On l'installe dans le système, si possible de façon compatible avec sutiliser (liens relatifs).
	local bdest="`basename "$dest"`"
	local lieur
	case "$dest" in
		"$usrLocal") true ;; # On installe directement dans /usr/local, donc inutile de faire un lien vers lui-même.
		"$usrLocal/$bdest") lieur="serveur_lner" ;; # Vers un dossier au standard sutiliser.
		*) lieur="serveur_lner -a" ;; # Vers un dossier au standard sutiliser.
	esac
	[ -z "$lieur" ] || $lieur "$dest" "$usrLocal" "etc/rc.d/$nom"
	
	# Ajout au sudoers.
		local d ds="$dest"
		case "$dest" in
			$usrLocal) true ;;
		*) ds="$ds $usrLocal" ;;
		esac
		
		for d in $ds
		do
		serveur_sudoer "$d/etc/rc.d/$nom *"
		done
	
	[ "$serveur_puisCopier" = non ] || servir "$nom" start
}

_lignesEnvSystemd()
{
	# Le crétin qui a conçu les fichiers de conf systemd, trouvant trop difficile de traiter des lignes de plus de 2048 caractères, y insère des LF fictifs, faisant passer la fin à la ligne (fictive, donc), et donnant lieu à un "Missing =" sur icelle. Cf. https://github.com/coreos/fleet/issues/992, https://bugs.freedesktop.org/show_bug.cgi?id=85308, https://github.com/systemd/systemd/issues/3302
	# Pour ce qui est de l'Environment, il les passe ensuite à un truc qui gère à merveille les paquets de plus de 2048 caractères, donc un palliatif consiste en scinder les variables, ex.:
	# Environment=PATH=<le début>
	# Environment=PATH=$PATH<la suite>
	# Bon en fait ça ne marche pas, seule la dernière ligne est prise en compte (avec un "$" littéral). Il faudra reposer sur un script encapsulant environnement et lancement. Mais on garde ce code pour la beauté de l'exercice.
	awk -F = '
BEGIN{ M = 1024; }
{
	c = $0;
	t = length(c);
	while(t > M)
	{
		match(substr(c, 1, 1024), /[^_A-Za-z0-9][_A-Za-z0-9]*$/);
		print(substr(c, 1, RSTART));
		t -= RSTART - 1;
		c = $1"=$"$1""substr(c, RSTART, t);
	}
	print c
}'
}

serveurSystemd()
{
    ajoutService=
	
	case "$type" in
		simple)
            ajoutType=
			;;
		demon) 
			ajoutService="$ajoutService|Type=forking|ExecReload=/bin/kill -s $sigre \$MAINPID|ExecStop=/bin/kill -s QUIT \$MAINPID"
			;;
        *)
            echo "# Je ne sais pas gérer le type '$type'." >&2
            return 1
	esac
	
	mkdir -p "$desttemp/etc/systemd/system"
	cat > "$desttemp/etc/systemd/system/${nom}.service" <<TERMINE
[Unit]
Description=$nom
After=network-online.target

[Service]
User=$compte
Group=$groupe
`IFS="$serveur_sep" ; for ligne in $avant ; do [ -z "$ligne" ] || echo "ExecStartPre=$ligne" ; done | sed -e 's/ExecStartPre=umask  */UMask=0/'`
ExecStart=$commande
`echo "$ajoutService" | tr \| '\012'`
`echo "$serveur_env" | tr "$serveur_sep" '\012' | sed -e 's/^/Environment=/'`
Restart=on-failure

[Install]
WantedBy=multi-user.target
TERMINE
	if [ $serveur_puisCopier = oui ]
	then
		sudoku -f cp "$desttemp/etc/systemd/system/${nom}.service" /etc/systemd/system/
	fi
	if [ ! -z "$remplacer" ]
	then
		sudoku -f systemctl daemon-reload
		sudoku -f systemctl unmask ${nom} > /dev/null 2>&1 || true # Des fois qu'un service avec le même nom existe à l'ancienne (init.d).
		servir "$nom" start
		sudoku -f systemctl enable ${nom}
	fi
	serveur_sudoer "/bin/systemctl * $nom"
}

serveurLinux()
{
	local destsys=/
	
	[ -n "$dest" ] || dest="$destsys"
	
	[ ! -z "$desttemp" ] || desttemp="$dest"
	if [ -z "$fpid" ]
	then
		fpid=$dest/var/run/$nom.pid
	fi
	[ -z "$compte" -o "$compte" = root ] || commande="suer $compte $commande"
	case "$type" in
		simple)
			commande="daemon $commande"
			ftrace="$dest/var/log/$nom.demon.log"
			;;
		demon) 
			true
			;;
	esac
	
	mkdir -p "$desttemp/etc/init.d"
	cat > "$desttemp/etc/init.d/$nom" <<TERMINE
#!/bin/sh

`serveurEnvPourExport`

daemon()
{
	"\$@" < /dev/null >> "$ftrace" 2>&1 &
	echo \$! > "\$pidfile"
}

suer()
{
	local compte="\$1" ; shift
	local paramsShell=
	local gusse="\`grep "^\$compte:" < /etc/passwd\`"
	case "\$gusse" in
		*/nologin|*/false) paramsShell="-s /bin/sh" ;;
	esac
	export pidfile
	su \$paramsShell \$compte -c "\`sed -e '/^daemon(/,/^}$/!d' < "\$0"\` ; \$*"
}

lance()
{
	$commande
}

etat()
{
	pid="\`cat "\$pidfile" 2> /dev/null\`"
	if [ -z "\$pid" ]
	then
		echo "$nom éteint (aucun PID dans \$pidfile)"
		return 1
	fi
	
	if ! ps -p "\$pid" > /dev/null 2>&1
	then
		echo "$nom éteint (dernier PID renseigné, \$pid, introuvable)" >&2
		return 1
	fi
	
	echo "$nom tourne avec pour PID \$pid"
}

recharge()
{
	pid="\`cat "\$pidfile" 2> /dev/null\`"
	if [ -z "\$pid" ]
	then
		echo "# Impossible de recharger le serveur. PID introuvable à \$pidfile." >&2
	else
		kill -$sigre "\$pid"
	fi
}

tue()
{
	pid="\`cat "\$pidfile" 2> /dev/null\`"
	if [ -z "\$pid" ]
	then
		echo "# Impossible d'arrêter le serveur. PID introuvable à \$pidfile." >&2
	else
		kill "\$pid"
		while ps -p "\$pid" > /dev/null 2>&1
		do
			sleep 1
		done
	fi
}

name=$nom
pidfile=$fpid

`echo "$avant" | tr "$serveur_sep" '\012'`
case "\$1" in
	start) etat > /dev/null || lance ;;
	stop) tue ;;
	restart) tue ; lance ;;
	status) etat ;;
	reload) recharge ;;
	*) echo "# Commande \\"\$1\\" inconnue." >&2 ; exit 1 ;;
esac
TERMINE
	chmod u+x "$desttemp/etc/init.d/$nom"
	if [ ! -z "$remplacer" ]
	then
		for i in 0 1 6
		do
			mkdir -p "$desttemp/etc/rc$i.d"
			ln -s "../init.d/$nom" "$desttemp/etc/rc$i.d/K05$nom"
		done
		for i in 2 3 4 5
		do
			mkdir -p "$desttemp/etc/rc$i.d"
			ln -s "../init.d/$nom" "$desttemp/etc/rc$i.d/S95$nom"
		done
		sudoku -d "$destsys/etc" sh -c "( cd $desttemp && tar cf - etc/init.d/$nom etc/rc?.d/?[09]5$nom ) | ( cd "$destsys" && tar xf - --no-same-owner )"
	fi
	
	serveur_sudoer "$dest/etc/init.d/$nom *"
	
	servir "$nom" start
}

#- Utilitaires internes --------------------------------------------------------

# Affecte les droits sudo de redémarrage à $comptesPilotes.
serveur_sudoer()
{
	local comp comm
	for comm in "$@"
	do
		# Évitons les /etc/rc.d//serveur ou //etc/rc.d/serveur malencontreux (par exemple installé dans $dest/etc/rc.d lorsque dest=/):
		# sudo sera pointilleux sur la similitude du chemin du binaire, au / près.
		case "$comm" in
			*//*) comm="`echo "$comm" | sed -e 's#///*#/#g'`" ;;
		esac
		# Consignons pour que l'appelant puisse connaître les droits à donner (à d'autres comptes, par exemple) pour effectuer les opérations de lancement du serveur.
		case "$dest" in
			$INSTALLS/$logiciel*) echo "$comm" >> "$dest/.sudo" ;;
		esac
		# Sudoons pour ceux déclarés dès à présent.
		IFS=', '
		for comp in $comptesPilotes
		do
			unset IFS
			case "$comp" in
				-|root|0|"") continue ;;
			esac
			sudoer "$comp" "$comm"
		done
		unset IFS
	done
}

# Signale quels ports le serveur compte ouvrir.
# (renseigne $nom dans un fichier par port de $ports dans $desttemp/etc/services.d, et compte sur l'appelant pour le recopier dans le dossier cible)
serveur_porter()
{
	if [ -n "$ports" ]
	then
		mkdir -p "$desttemp/etc/services.d"
		local port
		for port in $ports
		do
			echo "$nom" > "$desttemp/etc/services.d/$port"
		done
	fi
}

#- Utilitaires publics ---------------------------------------------------------
# À usage de l'appelant.

# Crée les dossiers /var/ (à usage d'écriture par le serveur) dans le patron (précopie en compte local de ce qui deviendra $dest).
# Env:
#   $dest
#     Emplacement où le patron sera copié in fine.
# Utilisation: serveur_patronVars <dossier patron> <sous-dossier var>+
#   <dossier patron>
#     Dossier de travail où constituer l'arborescence destinée à $dest.
#   <sous-dossier var>
#     Sous-dossier à créer. S'il existe déjà un $dest/<sous-dossier var>, il *ne sera pas créé* (on considère qu'une précédente version du serveur installée à cet endroit a déjà commencé à le remplir, et que le précréer dans le patron ne servirait à rien, voire nous causerait des soucis si le patron essaie de remplacer celui "de production" par le sien).
#     N.B.: nominalement, <sous-dossier var> est relatif à <dossier patron>. Cependant, si un chemin absolu est précisé, et commence par $dest, il sera pris sous notre giron comme s'il avait été mentionné relatif.
serveur_patronVars()
{
	local desttemp="$1" ; shift
	serveur_patronVars="$*"
	local aCreer=
	
	local var
	for var in $serveur_patronVars
	do
		# Si nous est passé un chemin absolu, il doit être par rapport à $dest. Sinon c'est que c'est hors de notre arborescence de destination, donc hors de notre responsabilité.
		case "$var" in
			"$dest"/*) var="`echo "$var" | sed -e "s#^$dest/##"`" ;;
			/*) [ -f "$aCree" ] || aCreer="$aCreer $var" ; continue ;;
		esac
		# S'il existe déjà (précédente install) à la cible, inutile de le recréer dans notre patron, surtout qu'à la cible il appartiendra à $compte et nous ne pourrons sans doute pas installer le nôtre.
		[ -d "$dest/$var" ] || mkdir -p "$desttemp/$var"
	done
	[ -z "$aCreer" ] || sudoku -f mkdir -p $aCreer
}

# chown des dossiers /var/ (tels que passés initialement à serveur_patronVars).
# Env:
#   $serveur_patronVars Initialisée par un appel préalable à serveur_patronVars()
#   $dest
#   $compte
# Utilisation: serveur_chownVars
serveur_chownVars()
{
	[ "$compteFils" = "`id -un`" -o -z "$serveur_patronVars" ] || ( cd "$dest" && sudoku -f chown -R "$compteFils:" $serveur_patronVars )
}
