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
						SANSSU=0 sudoku rm -f "$dest/$initds/$serveur" `find "$racine"/etc/rc[0-9].d/ -type f 2> /dev/null | grep "/[SK][0-9]*$serveur$"`
						;;
					*)
						SANSSU=0 sudoku "$racine/$initds/$serveur" "$action"
						;;
				esac
				break
			done
			;;
		systemd)
			case "$action" in
				remove)
					SANSSU=0 sudoku systemctl disable "$serveur"
					;;
				*)
					SANSSU=0 sudoku systemctl "$action" "$serveur"
					;;
			esac
	esac
}

serveur()
{
	local nom commande fpid avant compte groupe remplacer dest desttemp
	
	analyserParametresServeur "$@"
	
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
		[ -z "$serveur_env" ] || serveur_env="$serveur_env$serveur_sep"
		serveur_env="$serveur_env$var"
	done
}

serveurEnvPourExport()
{
	echo "$serveur_env" | sed -e "s/^/$serveur_sep/" -e "s/$/$serveur_sep/" -e "s#$serveur_sep\([^=]*=\)#\" \\1\"#g" -e "s/$serveur_sep/\"/g" | sed -e 's/^ *" *//'
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
			*)
				[ -z "$vars" ] && auSecours
				for i in $vars
				do
					eval $i='"$1"'
					break
				done
				vars="`echo "$vars" | sed -e 's/[^ ]* //'`"
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

serveurFreebsd()
{
	local usrLocal=/usr/local
	
	[ ! -z "$dest" ] || dest="$usrLocal"
	
	local nomPropre="`echo "$nom" | tr -d -`"
	
	for remplace in $remplacer
	do
		SANSSU=0 sudoku "$usrLocal/etc/rc.d/$remplace" stop 2> /dev/null || true
		SANSSU=0 sudoku rm -f "$usrLocal/etc/rc.d/$remplace"
	done

	if [ -z "$fpid" ]
	then
		fpid=$dest/var/run/$nom.pid
		# Bizarre, la doc de daemon dit qu'il faut utiliser -P pour tuer le démon plutôt que le fils (sinon le démon redémarre le fils), mais en pratique ce faisant le stop ne trouve pas le pid. Et comme apparemment le démon ne relance pas le fils, partons sur du -p.
		optionfpiddaemon="-p $fpid"
	fi
	executable="`echo "$commande" | awk '{print $1}'`"
	case "$type" in
		simple)
			lanceur="/usr/sbin/daemon"
			paramCompte=
			[ -z "$compte" ] || paramCompte="-u $compte"
			parametres="$paramCompte $optionfpiddaemon $commande"
			;;
		demon) 
			lanceur="$executable"
			parametres="`echo "$commande" | sed -e 's/^[^ 	]*[ 	]*//'`"
			;;
	esac
	
	if [ ! -z "$serveur_env" ]
	then
		avant="$avant${serveur_sep}export `serveurEnvPourExport`"
	fi
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
procname=$executable
command_args="$parametres"
load_rc_config "\$name"
: \${${nomPropre}_enable="NO"}

`echo "$avant" | tr "$serveur_sep" '\012'`
run_rc_command "\$1"
TERMINE
	chmod u+x "$desttemp/etc/rc.d/$nom"
	if [ "x$serveur_puisCopier" = xoui ]
	then
		SANSSU=0 sudoku sh -c "mkdir -p $dest ; cp -R $desttemp/. $dest/."
	fi
	if [ ! -z "$remplacer" ]
	then
		SANSSU=0 sudoku "$SCRIPTS/rcconfer" ${nomPropre}_enable=YES
	fi
	
	# On l'installe dans le système, si possible de façon compatible avec sutiliser (liens relatifs).
	local relatif="$dest"
	case "$relatif" in
		"$usrLocal") relatif= ;; # On installe directement dans /usr/local, donc inutile de faire un lien vers lui-même.
		"$usrLocal/`basename "$dest"`") relatif="../.." ;; # Vers un dossier au standard sutiliser.
	esac
	if [ ! -z "$relatif" ]
	then
		SANSSU=0 sudoku ln -s "$relatif/etc/rc.d/$nom" "$usrLocal/etc/rc.d/$nom"
	fi
	
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
	
	SANSSU=0 sudoku "$dest/etc/rc.d/$nom" start
}

serveurSystemd()
{
    ajoutService=
	
	for remplace in $remplacer
	do
		SANSSU=0 sudoku systemctl stop "$remplace" 2> /dev/null || true
		SANSSU=0 sudoku systemctl disable "$remplace" 2> /dev/null || true
	done

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
		SANSSU=0 sudoku cp "$desttemp/etc/systemd/system/${nom}.service" /etc/systemd/system/
	fi
	if [ ! -z "$remplacer" ]
	then
		SANSSU=0 sudoku systemctl daemon-reload
		SANSSU=0 sudoku systemctl unmask ${nom}.service > /dev/null 2>&1 || true # Des fois qu'un service avec le même nom existe à l'ancienne (init.d).
		SANSSU=0 sudoku systemctl start ${nom}.service
		SANSSU=0 sudoku systemctl enable ${nom}.service
	fi
	if [ ! -z "$compte" ]
	then
		sudoer "$compte" "/bin/systemctl * $nom"
	fi
}

serveurLinux()
{
	[ ! -z "$dest" ] || dest=
	
	for remplace in $remplacer
	do
		SANSSU=0 sudoku "$dest/etc/init.d/$remplace" stop 2> /dev/null || true
		SANSSU=0 sudoku rm -f "$dest/etc/init.d/$remplace" `find "$dest"/etc/rc[0-9].d/ -type f | grep "/[SK][0-9]*$remplace$"`
	done

	[ ! -z "$desttemp" ] || desttemp="$dest"
	if [ -z "$fpid" ]
	then
		fpid=$dest/var/run/$nom.pid
		# Bizarre, la doc de daemon dit qu'il faut utiliser -P pour tuer le démon plutôt que le fils (sinon le démon redémarre le fils), mais en pratique ce faisant le stop ne trouve pas le pid. Et comme apparemment le démon ne relance pas le fils, partons sur du -p.
		optionfpiddaemon="-p $fpid"
	fi
	[ -z "$compte" ] || commande="su $compte sh -c \"`echo "$commande" | sed -e 's/"/\\"/g'`\""
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

PATH="$INSTALLS/bin:\$PATH"
LD_LIBRARY_PATH="$INSTALLS/lib:\$LD_LIBRARY_PATH"
export PATH LD_LIBRARY_PATH

daemon()
{
	"\$@" < /dev/null >> "$ftrace" 2>&1 &
}

lance()
{
	$commande
	echo \$! > "\$pidfile"
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
		for i in 0 1 6
		do
			ln -s "../init.d/$nom" "$desttemp/etc/rc$i.d/K05$nom"
		done
		for i in 2 3 4 5
		do
			ln -s "../init.d/$nom" "$desttemp/etc/rc$i.d/S95$nom"
		done
	fi
	if [ ! -z "$compte" ]
	then
		sudoer "$compte" "$dest/etc/init.d/$nom *"
	fi
}
