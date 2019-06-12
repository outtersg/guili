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

args_suppr()
{
	local e=
	local sep=" "
	local S="#" # Séparateur sed, nécessairement différent du $sep fonctionnel.
	local dollar='$'
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
	[ "x$ss" != "x$sep" ] || ss="/"
	while [ $# -gt 0 ]
	do
		vars="$vars $1"
		var="`eval 'echo "$sep$'"$1"'$sep"' | sed -e "s${S}$sep${S}$sep$sep${S}g" -e "s${S}$sep$2$sep${S}$sep${S}g"`"
		eval "$1=\"\$var\""
		shift
		shift
	done
	[ -z "$e" ] || export $vars
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
