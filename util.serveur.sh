# Les fonctions serveurXxx() attendent les variables suivantes:
# - $nom: petit nom du serveur
# - $commande: commande, avec ses paramètres
# - $avant: éventuellement, trucs à exécuter avant le lancement
# - $compte: compte sous lequel doit tourner le serveur
# - $groupe: son groupe
# - $remplacer: si non vide, le serveur sera placé parmi les services système pour être démarré avec la machine (et est lancé dès maintenant). Il remplacera tous les services mentionnés dans $remplacer (il est dès lors judicieux de faire figurer $nom dans $remplacer, afin d'éteindre proprement toute vieille version qui tournerait encore).

serveur_sep="`printf '\003'`"

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
	dest= # Destination définitive.
	serveur_env= # À FAIRE: utiliser garg si disponible.
	while [ $# -gt 0 ]
	do
		case "$1" in
			-d0) shift ; desttemp="$1" ;;
			-d) shift ; dest="$1" ;;
			-n) remplacer="$remplacer -" ;;
			-r) remplacer="$remplacer $1" ;;
			-u) shift ; compte="$1" ;;
			-p) shift ; fpid="$1" ;;
			*=*) serveur_env="$serveur_env $1" ;;
			-e)
				shift
				serveur_var="$1"
				case "$serveur_var" in
					*=*) true ;;
					*) serveur_var="$serveur_var=`eval 'echo "$'"$serveur_var"'"'`" ;;
				esac
				serveur_env="$serveur_env $serveur_var"
				;;
			-pre) shift ; avant="$avant$serveur_sep$1" ;;
			*)
				[ -z "$vars" ] && auSecours
				for i in $vars
				do
					eval $i=\""$1"\"
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
	[ ! -z "$dest" ] || dest=/usr/local
	
	for remplace in $remplacer
	do
		SANSSU=0 sudoku "$dest/etc/rc.d/$remplace" stop 2> /dev/null || true
		SANSSU=0 sudoku rm -f "$dest/etc/rc.d/$remplace"
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
	
	mkdir -p "$desttemp/etc/rc.d"
	cat > "$desttemp/etc/rc.d/$nom" <<TERMINE
#!/bin/sh
# PROVIDE: $nom
# REQUIRE: NETWORKING
. /etc/rc.subr
name=$nom
rcvar=\`set_rcvar\`
command=$lanceur
command_args="$parametres"
pidfile=$fpid
procname=$executable
load_rc_config "\$name"
: \${${nom}_enable="NO"}

`echo "$avant" | tr "$serveur_sep" '\012'`
run_rc_command "\$1"
TERMINE
	chmod u+x "$desttemp/etc/rc.d/$nom"
	if [ "x$serveur_puisCopier" = xoui ]
	then
		sudo sh -c "mkdir -p $dest ; cp -R $desttemp/. $dest/."
	fi
	if [ ! -z "$remplacer" ]
	then
		sudo "$SCRIPTS/rcconfer" ${nom}_enable=YES
	fi
	if [ ! -z "$compte" ]
	then
		sudoer "$compte" "$dest/etc/rc.d/$nom *"
	fi
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
	ajoutService="$ajoutService|`echo "$serveur_env" | sed -e 's/ /|Environment=/g'`"
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
		SANSSU=0 sudoku systemctl start ${nom}.service
		SANSSU=0 sudoku systemctl enable ${nom}.service
	fi
}

serveurLinux()
{
	[ ! -z "$dest" ] || dest=
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
