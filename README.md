GuiLI
=====

Les GuiLI, *Grosse Usine à Installs Locales Interdépendantes / Guillaume's Lightweight Installers*, sont un gestionnaire de paquets compilés, aptes à être déployés sur une machine POSIX.

Ils suivent une philosophie proche de [Nix](https://nixos.org/nix/) ou des [ports FreeBSD](https://www.freebsd.org/ports/).
Par certains aspects (gestion de dépendances, préparation de l'environnement pour la compilation) les GuiLI se rapprochent de [pkg-config](https://www.freedesktop.org/wiki/Software/pkg-config/).

Plusieurs versions d'un logiciel peuvent cohabiter (numéro de version ou options différentes), des liens symboliques permettant de référencer la version par défaut depuis un dossier du `$PATH` (et le `$LD_LIBRARY_PATH` correspondant).

L'installation initiale se fait toujours par compilation, suite à laquelle le paquet binaire peut être poussé vers un silo central d'où d'autres machines pourront le télécharger et l'installer sans recompilation.

Utilisation
-----------

### Appel

```sh
# Installer nginx
./nginx

# Avec une contrainte de version
./nginx ">= 1.17" "< 1.17.5"

# Avec des modules
./nginx +realip +geoip ">= 1.17" "< 1.17.5"

# Et monter toutes les dépendances (OpenSSL, PCRE, zlib) à la dernière version compatible avec notre nginx.
./nginx +realip +geoip ">= 1.17" "< 1.17.5" +
```

Cet appel générera une arborescence (sous la racine d'installation configurée: $HOME/local, ou /usr/local, etc.) contenant ce genre de choses:
    $HOME/local
    ├ bin
    │ └ openssl     -> ../openssl-1.x.y.z/bin/openssl
    ├ lib
    │ └ libssl.so   -> ../openssl-1.x.y.z/lib/libssl.so
    ├ sbin
    │ └ nginx       -> ../nginx+geoip+realip-1.17.4/sbin/nginx
    ├ nginx+geoip+realip-1.17.4
    │ └ sbin
    │   └ nginx
    └ openssl-1.x.y.z
      ├ bin
      │ └ openssl
      └ lib
        └ libssl.so

```sh
# Installer le service correspondant (installera un _nginx-1.17.4 lançant nginx-1.17.4/sbin/nginx).
./_nginx -u www

# Installer le service correspondant avec alias (installera nginx-1.17.4, un lien symbolique nginx117 -> nginx-1.17.4, _nginx117 qui lancera nginx117/sbin/nginx et ne sera donc pas lié en dur à la version 1.17.4).
./_nginx -u www nginx ">= 1.17" --alias nginx117

# Validation sans installation systématique (si la 1.17.1, qui répond aux critères, est déjà installée, le _nginx s'y liera plutôt que d'installer la toute dernière version de nginx).
./_nginx -u www nginx ">= 1.17" --alias nginx117 -
```

### Configuration

Le fichier util.local.sh peut surcharger:
```sh
INSTALLS="$HOME/local" # Racine d'installation.
INSTALL_MEM="$HOME/tmp/paquets" # Entrepôt local à archives binaires et sources.
INSTALL_SILO="root@silo:/var/guili" # Entrepôt centralisé à archives binaires.
INSTALL_SILO_RECUPERER="silo_ssh_recuperer" # Une fonction appelée pour récupérer un paquet binaire, recevant en paramètres $INSTALL_MEM/<logiciel><options>*-<version>.bin.tar.gz <proc>-<système>-<version>
INSTALL_SILO_POUSSER="silo_ssh_pousser" # Une fonction appelée pour pousser un paquet binaire (mêmes paramètres que $INSTALL_SILO_RECUPERER).
#INSTALL_SANS_COMPIL=1 # Interdit la compilation de paquets sur cette machine, elle ne pourra que recevoir des paquets binaires (précompilés).
```

Une implémentation du silo par scp existe (`silo_ssh_recuperer` et `silo_ssh_pousser`), qui sera utilisée par défaut si `$INSTALL_SILO` a une forme d'URI SSH.

### Prérequis

- POSIX (sh, sed, awk)
- compilateur

Pour utiliser GuiLI pour installer non seulement des logiciels mais aussi des services, ou pour installer dans une racine système (ex.: /usr/local), il faut en plus:
- soit lancer les GuiLI en root (déconseillé)
- soit être sudoer

Pour l'amorçage, les GuiLI vont chercher les sources:
- via tout outil déjà présent sur la machine (curl, fetch, wget)
- à défaut, vous pouvez déposer les paquets de sources dans `$INSTALL_MEM` (scp, http, montage réseau…), où les GuiLI les trouveront.

Créer des GuiLI
---------------

### GuiLI simple

```sh
#!/bin/sh

# Le script doit sortir à la moindre erreur.
set -e

# En-tête obligatoire:
# - Définit $SCRIPTS au dossier contenant les GuiLI
# - Le nom de la fonction (DelieS) indique en outre la modernité du script d'installation, et donc les fonctionnalités des GuiLI activables. DelieS est la version actuelle.
DelieS() { local s2 ; while [ -h "$s" ] ; do s2="`readlink "$s"`" ; case "$s2" in [^/]*) s2="`dirname "$s"`/$s2" ;; esac ; s="$s2" ; done ; } ; SCRIPTS() { local s="`command -v "$0"`" ; [ -x "$s" -o ! -x "$0" ] || s="$0" ; case "$s" in */bin/*sh) case "`basename "$s"`" in *.*) true ;; *sh) s="$1" ;; esac ;; esac ; case "$s" in [^/]*) s="`pwd`/$s" ;; esac ; DelieS ; s="`dirname "$s"`" ; DelieS ; SCRIPTS="$s" ; } ; SCRIPTS
# Inclusion des utilitaires GuiLI; analyse des paramètres standard (options, contraintes de version), définition des variables standard (dont $logiciel comme `basename "$0"`).
. "$SCRIPTS/util.sh"

# Versions gérées par le présent script.
# || true pour que, si les contraintes de version sont défavorables (ex.: "< 1.1"), la sortie en erreur de v 1.1 ne soit pas fatale.
v 1.0 || true
v 1.1 || true

archive="http://mirror.ibcp.fr/pub/gnu/$logiciel/$logiciel-$version.tar.gz"

# Détermine $dest, qui sera la racine d'installation du logiciel incluant sa version et ses options.
# Si $dest existe (et est considéré complet), destiner sortira avec succès.
destiner
# S'assure de la présence des prérequis, et modifie l'environnement pour la compilation qui va suivre (\$CPPFLAGS, etc.).
prerequis
# Télécharge $archive et se place dans le dossier décompressé.
# Au préalable tente de télécharger et installer la version binaire: en cas de succès, l'installeur sort en court-circuitant la compilation.
obtenirEtAllerDansVersion
# Applique les rustines éventuelles.
for modif in true $modifs ; do $modif ; done

# Exemple pour du GNU autotools.
# Notons l'utilisation de sudoku, qui ne recourra à sudo que si $dest n'est pas inscriptible par le compte courant.
# sudo est de toute façon surchargé comme alias vers sudoku.
./configure --prefix="$dest"
make
sudoku make install

# Pose le fichier témoin de bonne installation, tire les liens symboliques d'$INSTALLS/bin/$logiciel -> $dest/bin/$logiciel etc. pour rendre public le logiciel installé.
sutiliser
```

#### Modifs

```sh
v 1.0 && modifs="tropWindows" || true
# Modification plus nécessaire en 1.1.
v 1.1 && prerequis="cmake \\ openssl >= 1.0" || true

tropWindows()
{
	filtrer main.c grep -v '#include <gdi.h>'
}
```

#### Prérequis

```sh
# OpenSSL est un prérequis de notre logiciel.
v 1.0 && prerequis="openssl >= 0.9.8" || true
# CMake nécessaire pour la compilation à partir de la 1.1 (mais non nécessaire à l'exécution).
v 1.1 && prerequis="cmake \\ openssl >= 1.0" || true
```

#### Options

```sh
v 1.1 && prerequis="cmake \\ openssl >= 1.0" || true

option pg && prerequis="$prerequis postgresql+ossl10" && OPTIONS_CONF="$OPTIONS_CONF --enable-postgresql" || true
prerequisOpenssl

prerequis

…

./configure --prefix="$dest" $OPTIONS_CONF
```
permettra de compiler soit `logiciel`, soit `logiciel +pg`.

Notons que prerequisOpenssl est une macro-fonction sensiblement équivalente à `option ossl || virerPrerequis openssl`.\
Elle gère en réalité plus que ça (cantonnement à une version mineure d'OpenSSL, transmission aux prérequis, etc.).

### Amorceur (service système)

`À FAIRE`
