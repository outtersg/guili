# Les fonctions serveurXxx() attendent les variables suivantes:
# - $nom: petit nom du serveur
# - $commande: commande, avec ses paramètres
# - $avant: éventuellement, trucs à exécuter avant le lancement
# - $compte: compte sous lequel doit tourner le serveur
# - $groupe: son groupe
# - $installer: si oui, le serveur sera démarré avec la machine (et est lancé dès maintenant).

serveur()
{
	local nom commande fpid avant compte groupe installer dest desttemp
	
	analyserParametresServeur "$@"
	
	case "`uname`" in
		FreeBSD)
			serveurFreebsd "$@"
			;;
		Linux)
			serveurSystemd "$@"
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
# Utilisation: serveur [-n] [-d0 <desttemp>] [-d <dest>] [-u <compte>] [-p <fichier pid>] [-pre <précommande>] <type> <nom> <commande>
  -n
    Ne pas activer au démarrage de la machine.
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
	installer=oui
	desttemp= # Destination temporaire.
	dest= # Destination définitive.
	while [ $# -gt 0 ]
	do
		case "$1" in
			-d0) shift ; desttemp="$1" ;;
			-d) shift ; dest="$1" ;;
			-n) installer=non ;;
			-u) shift ; compte="$1" ;;
			-p) shift ; fpid="$1" ;;
			-pre) shift ; avant="$1" ;;
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
	
	[ ! -z "$desttemp" ] || desttemp="$dest"
}

serveurFreebsd()
{
	[ ! -z "$dest" ] || dest=/usr/local
	[ ! -z "$desttemp" ] || desttemp="$dest"
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
			parametres="`echo "$commande" | sed -e 's/^[^ 	]*[ 	]//'`"
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
load_rc_config "\$name"
: \${${nom}_enable="NO"}

$avant
run_rc_command "\$1"
TERMINE
	chmod u+x "$desttemp/etc/rc.d/$nom"
	if [ "x$installer" = xoui ]
	then
		sudo "$SCRIPTS/rcconfer" ${nom}_enable=YES
	fi
	if [ ! -z "$compte" ]
	then
		cat >> /etc/sudoers <<FINI
$compte ALL=(ALL) NOPASSWD:$dest/etc/rc.d/$nom *
FINI
	fi
}

serveurSystemd()
{
	[ -z "$avant" ] || avant="ExecStartPre=$avant"
	[ $type != simple ] && echo "# Je ne sais pas gérer d'autre type que simple." >&2 && return 1
	
    cat > /etc/systemd/system/${nom}.service <<TERMINE
[Unit]
Description=$nom
After=network-online.target

[Service]
User=$compte
Group=$groupe
$avant
ExecStart=$commande
Restart=on-failure

[Install]
WantedBy=multi-user.target
TERMINE
	if [ "x$installer" = xoui ]
	then
		systemctl start ${nom}.service
		systemctl enable ${nom}.service
	fi
}
