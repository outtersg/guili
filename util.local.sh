# Ce fichier est inclus par util.sh; vous pouvez y définir votre environnement de compilation:
# 
# $INSTALLS
#   Racine d'installation des logiciels (ex.: /usr/local, /opt, ou bien $HOME/local, qui est la valeur par défaut).
# $INSTALL_MEM
#   Entrepôt local à archives téléchargées, et à versions compilées.
#   Cache tout téléchargement afin de s'épargner de retélécharger par le futur.
#   N.B.: en cas d'environnement à connexion internet limitée (ex.: proxy), si un installeur n'arrive pas à télécharger une archive, téléchargez-la manuellement par un autre biais et déposez-la dans $INSTALL_MEM, puis relancez l'installeur: il trouvera son archive.
# $TMP
#   Dossier temporaire.
#   Peut être /tmp, sauf si vous prévoyez de compiler des gros bidules susceptibles de faire exploser la partition sur laquelle se trouve /tmp (ex.: compiler un compilateur peut prendre plusieurs Go; si votre /tmp est sur une partition système de 4 Go, ça va péter, choisissez à la place un dossier sur un disque spacieux).
# $SANSSU
#   Si à 1 (valeur par défaut), évitera autant que possible de passer root. À 0, passera root sans vergogne.
# $INSTALL_SILO
#   Entrepôt à versions précompilées (les installations tenteront de consulter le silo voir si une version compilée existe; dans la négative, ils compileront puis pousseront vers le silo, à l'intetion des prochains qui tenteront l'installation).
