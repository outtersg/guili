# Copyright (c) 2019 Guillaume Outters
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

#-------------------------------------------------------------------------------
# Ensemble de fonctions de bidouilles shell (traitement des args, etc.)
#-------------------------------------------------------------------------------

#- Paramètres ------------------------------------------------------------------
# Voir aussi garg.sh

# Supprime les redondances d'une liste d'arguments
# Redondance étant entendu comme suite de la même chaîne d'éléments.
# Ex. pour 6 éléments: on cherchera les répétitions AA...., .AA..., ..AA.., ...AA., ....AA, ABAB.., .ABAB., ..ABAB, ABCABC
# Utilisation: args_reduc [-d <séparateur>] <arg>
# Exemples:
#   args_reduc "-L/usr/local/libtruc-x.x.x/lib -lc -L/usr/local/lib -L/usr/lib -L/usr/local/lib -L/usr/lib -lc"
#     -> -L/usr/local/libtruc-x.x.x/lib -lc -L/usr/local/lib -L/usr/lib -lc
#     N.B.: le -lc n'est pas supprimé, car il peut être vu différemment selon l'endroit où il se trouve. Ne seraient supprimées que les répétitions -lc -lc ou -L/usr/lib -lc -L/usr/lib -lc.
#   args_reduc -d : /usr/local/libtruc-x.x.x/lib:/usr/local/lib:/usr/lib:/usr/local/lib:/usr/lib
#     -> /usr/local/libtruc-x.x.x/lib:/usr/local/lib:/usr/lib
args_reduc()
{
    local sep=" "
    [ "x$1" = x-d ] && sep="$2" && shift && shift || true
    ( if [ $# -gt 0 ] ; then echo "$*" ; else cat ; fi ) | awk -F "$sep" '
{
    n = split($0, t);
    # On cherche des sous-chaînes de plus en plus longues.
    for(taille = 0; ++taille <= n / 2;)
        # On cherche toute succession de deux occurrences de la même chaîne.
        for(pos = 0; ++pos <= n - 2 * taille + 1;)
        {
            for(posDansChaine = -1; ++posDansChaine < taille;)
            {
                if(t[pos + posDansChaine] != t[pos + taille + posDansChaine])
                    # Un élément diffère entre les deux sous-chaînes, inutile de poursuivre.
                    break;
            }
            # Si on est arrivé au bout, on peut réduire.
            if(posDansChaine >= taille)
            {
                # Surimpression de la fin de chaîne sur ce qui disparaît; on ne s embarrasse pas à supprimer les derniers éléments, car on ne se fie qu à notre n comme fin de chaîne.
                for(i = pos; ++i + taille <= n;)
                    t[i] = t[i + taille];
                # Notre chaîne a diminué de taille.
                n -= taille;
                # Et pour pouvoir retester cette sous-chaîne, on recule d un coup.
                --pos;
            }
        }
    res = t[1];
    for(posr = 1; ++posr <= n;)
        res = res""FS""t[posr];
    print res;
}
'
}

# Sur son entrée standard, vire tous les blocs mentionnés (un bloc étant délimité par un séparateur donné, par défaut l'espace).
# Ex.: echo a b z c d z e z | stdin_suppr z # Donne a b c d e
stdin_suppr()
{
	local sep=" "
	local S="#" # Séparateur sed, nécessairement différent du $sep fonctionnel.
	local SP="`printf '\005'`"
	local dollar='$'
	while [ $# -gt 0 ]
	do
		case "$1" in
			-d) sep="$2" ; shift ;;
			*) break ;;
		esac
		shift
	done
	[ "x$S" != "x$sep" ] || S="/"
	local paramsSed=
	while [ $# -gt 0 ]
	do
		[ -z "$paramsSed" ] || paramsSed="$paramsSed$SP"
		paramsSed="$paramsSed-e${SP}s${S}$sep$1$sep${S}$sep${S}g"
		shift
	done
	( IFS="$SP" ; sed -e "s${S}$sep${S}$sep$sep${S}g" -e "s${S}^${S}$sep${S}" -e "s${S}$dollar${S}$sep${S}" $paramsSed -e "s${S}$sep$sep$sep*${S}$sep${S}g" -e "s${S}^$sep${S}${S}" -e "s${S}$sep$dollar${S}${S}" )
}

args_suppr()
{
	local e=
	local sep=" "
	local vars=
	local var
	while [ $# -gt 0 ]
	do
		case "$1" in
			-e) e=oui ;;
			-d) sep="$2" ; shift ;;
			*) break ;;
		esac
		shift
	done
	while [ $# -gt 0 ]
	do
		vars="$vars $1"
		var="`eval 'echo "$sep$'"$1"'$sep"' | stdin_suppr -d "$sep" "$2"`"
		eval "$1=\"\$var\""
		shift
		shift
	done
	[ -z "$e" ] || export $vars
}

dernierParam()
{
	while [ $# -gt 1 ]
	do
		shift
	done
	echo "$1"
	
	# N.B.: la version:
	# eval "echo \$$#"
	# est sensiblement équivalente, entre 9,1 s et 9,4 s pour:
	# time ./util eval 'f() { n=10000 ; while [ $n -gt 0 ] ; do $1 hui hui hui hui hui huih hu ; n=`expr $n - 1` ; done ; } ; f dernierParam > /dev/null'
}

#- Chemins ---------------------------------------------------------------------

# basename en pur shell: sur mon FreeBSD, roule 30 fois plus vite que basename (car pas de fork+exec)
bn()
{
	IFS=/
	_bn $1
	unset IFS
}

_bn()
{
	eval "echo \"\$$#\""
}

#- Options ---------------------------------------------------------------------

# Affecte une valeur à la prochaine variable d'une liste $vars de noms de variable; fait à peu près le même boulot que getopt.
# Décale $vars.
# Appelle auSecours() si plus aucune variable n'est à remplir.
# Utilisation:
#   vars="prenom nom"
#   superutilisateur=non
#   while [ $# -gt 0 ]
#   do
#       case "$1" in
#           -s) superutilisateur=oui ;;
#           *) apAffecter "$1" $vars ;;
#       esac
#   done
#   [ -z "$vars" ] || auSecours # Les paramètres obligatoires n'ont pas été fournis.
# (N.B.: ap comme analyserParametres)
apAffecter()
{
	# On considère que, tournant dans le cadre d'un script ayant inclus util.sh, tout paramètre ressemblant à une contrainte de version n'est pas destiné à l'appelant, mais a déjà été mis de côté dans $argVersion.
	if [ -n "$1" ]
	then
		case "`argVersion "$1"`" in
			"$1"*) return 0 ;; # Avec un * car argVersion a tendance à rajouter des espaces.
		esac
		# Idem pour les options.
		case "$1" in
			+*|--sans-*) return 0 ;;
		esac
	fi
	# Si l'on n'a plus de variable à laquelle affecter, on pète.
	if [ $# -lt 2 ]
	then
		auSecours
		return 1
	fi
	# Allez, c'est validé, bossons.
	eval $2='"$1"'
	shift
	shift
	vars="$*"
}

#- Versions --------------------------------------------------------------------

# Coupe un <logiciel>(+<option>)*-<version> en <logiciel>(+<option>)* <version>
# Utilisation: love [-e "varL varO varV"] <chemin>
#   -e "varL varO varV"
#     Plutôt que de sortir <logiciel>, <options> et <version>, les mettra à disposition respectivement en tant que $varL, $varO, $varV.
#   <chemin>
#     Chemin absolu d'install GuiLI, sous la forme /<racine>/<logiciel>(+<option>)*-<version>
love()
{
	# On fait le maximum d'opérations dans le shell: un fork+exec, ça coûte cher.
	
	local d _lo _ve velo= _l _seplo _o exports=
	
	while [ $# -gt 0 ]
	do
		case "$1" in
			--velo) velo=1 ; shift ; continue ;;
			-e) exports="$2" ; shift ; shift ; continue ;;
		esac
		IFS=-
		tifs _love `bn "$1"`
		if [ -z "$velo$exports" ]
		then
		echo "$_lo $_ve"
		else
			[ -n "$_ve" ] || ve=0
			IFS=+
			_velo $_lo
			[ -n "$exports" ] || echo "$_ve $_l$_seplo$_o"
		fi
		shift
	done
	unset IFS
	[ -z "$exports" ] || _love_affection "$exports" "$_l" "$_o" "$_ve"
}

_love_affection()
{
	local vars="$1" var ; shift
	for var in $vars
	do
		eval $var='"$1"'
		shift
	done
}

_love()
{
	_lo="$1" ; shift
	while [ $# -gt 1 ]
	do
		_lo="$_lo$IFS$1"
		shift
	done
	case "$1" in
		[0-9]*.[0-9]*) _ve="$1" ;;
		"") true ;;
		*) _ve= ; _lo="$_lo$IFS$1" ;;
	esac
}

# Découpe un "logiciel(+option)*-version" en "version logiciel (+option)*"
velo()
{
	love --velo "$@"
}

_velo()
{
	_l="$1" ; shift
	_o=
	[ $# -gt 0 ] || return 0
	_o="+$*"
	_seplo=" "
}

#- Listes de prérequis ---------------------------------------------------------
# <prérequis> = <logiciel> (+<option>)* (<contrainte version>)*

decoupePrerequis()
{
	ecosysteme -d "$@" || decoupePrerequisSansCompilo "$@"
}

decoupePrerequisSansCompilo()
{
	echo "$*" | sed -e 's#  *\([<>0-9]\)#@\1#g' | tr ' :' '\012 ' | sed -e 's#@# #g' -e '/^$/d' -e 's/\([<>=]\)/ \1/' | fusionnerPrerequis
}

# Fusionne les prérequis, de manière à ce que plusieurs occurrences du même prérequis n'en fassent plus qu'une.
# Ex.: ( echo "postgresql+ossl10 < 10" ; echo "postgresql >= 8" ; echo riensansrien ) | fusionnerPrerequis | tr '\012' ' ' -> postgresql+ossl10 < 10 >= 8 riensansrien
fusionnerPrerequis()
{
	# On souhaite avoir en sortie l'ordre d'apparition en entrée. Le for(tableau) n'est pas prédictible (certains awk sortent par ordre d'arrivée, d'autre par ordre alphabétique). On utilise donc un tableau d'ordre à indices numériques, prédictibles.
	# Les \ se combinant dans le sens inverse (on garde la position du dernier), en cas de double \ on décale tout le monde pour prendre la position du dernier rencontré.
	awk '
BEGIN{ nPrerequis = 0; }
{
	lo=$1;
	l=lo;
	sub(/[+].*/,"",l);
	o=lo;
	sub(/^[^+]*/,"",o);
	v=$0;
	sub(/^[^ ]* */,"",v);
	if(!logiciels[l])
	{
		ordre[nPrerequis++]=l;
		logiciels[l]=1;
	}
	else if(l == "\\")
	{
		for(i = -1; ordre[++i] != l;) {}
		while(++i < nPrerequis)
			ordre[i - 1] = ordre[i];
		ordre[i - 1] = l;
	}
	options[l]=options[l]""o;
	versions[l]=versions[l]" "v;
}
END{
	for(i = 0; i < nPrerequis; ++i)
	{
		l = ordre[i];
		v = versions[l];
		sub(/^  */, "", v);
		if(v != "") v = " "v;
		print l""options[l]""v;
	}
}
'
}

# Des $prerequis, n'affiche que ceux après le \ (qui sépare prérequis de compilation de ceux d'exécution).
prerequisExecution()
{
	IFS='\'
	dernierParam $prerequis
	unset IFS
}
