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
				[ -f "$racine/$initds/$serveur" ] || continue # On ne teste pas en -x, car on n'est pas forcément root, donc s'il est exécutable simplement par root le -x renverra faux.
				case "$action" in
					remove)
						sudoku -f rm -f "$dest/$initds/$serveur" `find "$racine"/etc/rc[0-9].d/ -type f 2> /dev/null | grep "/[SK][0-9]*$serveur$"`
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

serveur()
{
	local nom commande fpid avant compte groupe remplacer dest desttemp
	
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
# Utilisation: serveur [-n] [-r <autre>]* [-d0 <desttemp>] [-d <dest>] [-u <compte>] [-p <fichier pid>] [-e <env>]* [-pre <précommande>] <type> <nom> <commande>
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

analyserParametresServeur()
{
	vars="type nom commande rien"
	nom=
	commande=
	fpid=
	avant=
	compte=
	groupe=
	remplacer=
	desttemp= # Destination temporaire.
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
			-p) shift ; fpid="$1" ;;
			*=*) serveurParamEnv "$1" ;;
			-e) shift ; serveurParamEnv "$1" ;;
			-pre) shift ; avant="$avant$serveur_sep$1" ;;
			*) apAffecter "$1" $vars ;;
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
	local ds="$1" ; shift
	local dd="$1" ; shift
	sudoku -d "$dd" sh <<TERMINE
set -e
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
	ln -s "\$s" "\$d"
done
TERMINE
}

serveurFreebsd()
{
	local usrLocal=/usr/local
	
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
pidfile=$fpid
command_args="$parametres"
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
	if [ "x$serveur_puisCopier" = xoui ]
	then
		sudoku -f sh -c "mkdir -p $dest ; cp -R $desttemp/. $dest/."
	fi
	if [ ! -z "$remplacer" ]
	then
		sudoku -f "$SCRIPTS/rcconfer" ${nomPropre}_enable=YES
	fi
	
	# On l'installe dans le système, si possible de façon compatible avec sutiliser (liens relatifs).
	local relatif="$dest"
	case "$relatif" in
		"$usrLocal") relatif= ;; # On installe directement dans /usr/local, donc inutile de faire un lien vers lui-même.
		"$usrLocal/`basename "$dest"`") relatif="../.." ;; # Vers un dossier au standard sutiliser.
	esac
	[ -z "$relatif" ] || serveur_lner "$relatif" "$usrLocal" "etc/rc.d/$nom"
	
	# Ajout au sudoers.
	if [ ! -z "$compte" ]
	then
		local d ds="$dest"
		case "$dest" in
			$usrLocal) true ;;
			*) ds="$ds "$usrLocal"" ;;
		esac
		
		for d in $ds
		do
			sudoer "$compte" "$d/etc/rc.d/$nom *"
		done
	fi
	
	servir "$nom" start
}

serveurSystemd()
{
    ajoutService=
	
	case "$type" in
		simple)
            ajoutType=
			;;
		demon) 
            ajoutService="$ajoutService|Type=forking|ExecReload=/bin/kill -s HUP \$MAINPID|ExecStop=/bin/kill -s QUIT \$MAINPID"
			;;
        *)
            echo "# Je ne sais pas gérer le type '$type'." >&2
            return 1
	esac
	ajoutService="$ajoutService|`echo "$serveur_sep$serveur_env" | sed -e "s/$serveur_sep/|Environment=/g"`"
    ajoutService="`echo "$ajoutService" | tr \| '\012'`"
	
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
$ajoutService
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
	if [ ! -z "$compte" ]
	then
		sudoer "$compte" "/bin/systemctl * $nom"
	fi
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
	export pidfile
	su \$compte -c "\`sed -e '/^daemon(/,/^}$/!d' < "\$0"\` ; \$*"
}

lance()
{
	$commande
}

tue()
{
	pid="\`cat "\$pidfile"\`"
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
	start) lance ;;
	stop) tue ;;
	restart) tue ; lance ;;
	*) echo "# Commande \\"\$1\\" inconnue." >&2 ; exit 1 ;;
esac
TERMINE
	chmod u+x "$desttemp/etc/init.d/$nom"
	if [ ! -z "$remplacer" ]
	then
		serveur_lner "$desttemp" "$destsys" "etc/init.d/$nom"
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
		sudoku -d "$destsys/etc" sh -c "( cd $desttemp && tar cf - etc/rc?.d/?[09]5$nom ) | ( cd "$destsys" && tar xf - --no-same-owner )"
	fi
	if [ ! -z "$compte" ]
	then
		sudoer "$compte" "$dest/etc/init.d/$nom *"
	fi
	
	servir "$nom" start
}

#- Utilitaires -----------------------------------------------------------------

# Crée les dossiers /var/ (à usage d'écriture par le serveur) dans le patron (précopie en compte local de ce qui deviendra $dest).
# Env:
#   $dest
#     Emplacement où le patron sera copié in fine.
# Utilisation: serveur_patronVars <dossier patron> <sous-dossier var>+
#   <dossier patron>
#     Dossier de travail où constituer l'arborescence destinée à $dest.
#   <sous-dossier var>
#     Sous-dossier à créer. S'il existe déjà un $dest/<sous-dossier var>, il *ne sera pas créé* (on considère qu'une précédente version du serveur installée à cet endroit a déjà commencé à le remplir, et que le précréer dans le patron ne servirait à rien, voire nous causerait des soucis si le patron essaie de remplacer celui "de production" par le sien).
serveur_patronVars()
{
	local desttemp="$1" ; shift
	serveur_patronVars="$*"
	
	local var
	for var in $serveur_patronVars
	do
		# S'il existe déjà (précédente install) à la cible, inutile de le recréer dans notre patron, surtout qu'à la cible il appartiendra à $compte et nous ne pourrons sans doute pas installer le nôtre.
		[ -d "$dest/$var" ] || mkdir -p "$desttemp/$var"
	done
}

# chown des dossiers /var/ (tels que passés initialement à serveur_patronVars).
# Env:
#   $serveur_patronVars Initialisée par un appel préalable à serveur_patronVars()
#   $dest
#   $compte
# Utilisation: serveur_chownVars
serveur_chownVars()
{
	[ "$compte" = "`id -un`" ] || ( cd "$dest" && sudoku -f chown -R "$compte:" $serveur_patronVars )
}
