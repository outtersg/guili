# Copyright (c) 2012,2015,2017-2020 Guillaume Outters
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

# Teste si la version mentionnée en premier paramètre rentre (ou est plus petite ou égale, si le second paramètre vaut 'ppe') dans l'intervalle défini par la suite des arguments (ex.: testerVersion 2.3.1 >= 2.3 < 2.4 renverra vrai).
testerVersion()
{
	[ "x$1" = x ] && return 0 # Sans mention de version, on dit que tout passe.
	versionTestee="$1"
	shift
	plusPetitOuEgal=false
	[ "x$1" = xppe ] && plusPetitOuEgal=true && shift
	while [ $# -gt 0 ]
	do
		case "$1" in
			">=")
				$plusPetitOuEgal || pge "$versionTestee" "$2" || return 1 # Si on teste un PPE, le >= n'est pas filtrant (la clause PPE est prioritaire).
				shift
				;;
			">")
				$plusPetitOuEgal || pg "$versionTestee" "$2" || return 1
				shift
				;;
			"<")
				pg "$2" "$versionTestee" || return 1
				shift
				;;
			"<=")
				pge "$2" "$versionTestee" || return 1
				shift
				;;
			*) # Numéro de version précis.
				if $plusPetitOuEgal
				then
					pge "$1" "$versionTestee" || return 1
				else
					[ "$versionTestee" = "$1" ] || vc "$1" "$versionTestee" || return 1
				fi
				;;
		esac
		shift
	done
	true
}

pge() { pg -e "$1" "$2" ; }

# Compare deux versions.
# Utilisation: vc [--var <var>|-v <var>|-e] <version0> <version1>
#   (sans mode)
#     Renvoie 255, 0, ou 1, selon que <version0> <, =, ou >, à <version1>.
#   --var|-v
#     Affecte -1, 0, ou 1, à $var.
#   -e
#     Fait un echo de -1, 0, ou 1.
vc()
{
	local _vc_r _vc_re _vc_mode=r _vc_var
	
	[ "x$1" = x--var -o "x$1" = x-v ] && _vc_mode=v && _vc_var="$2" && shift && shift || true
	[ "x$1" = x-e ] && _vc_mode=e && shift || true
	
	IFS=.
	_vc "$1" $2 || _vc_r="$?"
	unset IFS
	
	case $_vc_r in
		255) _vc_re=-1 ;;
		*) _vc_re=$_vc_r ;;
	esac
	
	case $_vc_mode in
		v) eval $_vc_var=$_vc_re ;;
		e) printf "%d" $_vc_re ;;
		*) return $_vc_r
	esac
}

_vc()
{
	local a b as="$1" ; shift
	for a in $as
	do
		b="$1"
		[ -n "$b" ] || b=0
		[ "$a" -ge "$b" ] || return 255
		[ "$a" -eq "$b" ] || return 1
		[ $# -le 0 ] || shift
	done
	while [ $# -gt 0 ]
	do
		[ "$1" -le 0 ] || return 255
		[ "$1" -eq 0 ] || return 1
		shift
	done
}

triversions()
{
	# De deux logiciels en même version, on prend le chemin le plus long: c'est celui qui embarque le plus de modules optionnels.
	# À FAIRE: en fait calculer sur le nombre d'options plutôt que sur leur longueur: abc+x+y est plus avancé qu'abc+option_longue.
	# À FAIRE: permettre à l'appelant de fournir une fonction (awk) qui joue sur l'ordre; par exemple parce qu'avoir telle option est au contraire une pénalité, ou pour privilégier +ossl11 par rapport à +ossl10, ou encore pour que, à nombre d'options égal, le logiciel en cours d'installation soit considéré plus plus avancé que les autres déjà installés.
	awk '
		BEGIN {
			# Certaines versions d awk veulent que ls soit initialisée en array avant de pouvoir être length()ée.
			nls = 0;
			nvs = 0;
			ntailles = 0;
		}
		{
			ls[++nls] = $0;
			v = $0;
			sub(/^([^0-9][^-]*-)+/, "", v);
			vs[++nvs] = v;
			ndecoupe = split(v, decoupe, ".");
			for(i = 0; ++i <= ndecoupe;)
			{
				if(i > ntailles)
				{
					++ntailles;
					tailles[i] = 0;
				}
				if(length(decoupe[i]) > tailles[i])
					tailles[i] = length(decoupe[i]);
			}
		}
		END {
			for(nl = 0; ++nl <= nvs;)
			{
				c = "";
				v = vs[nl];
				ndecoupe = split(v, decoupe, ".");
				for(nv = 0; ++nv <= ntailles;)
					c = c sprintf("%0"tailles[nv]"d", nv > ndecoupe ? 0 : decoupe[nv]);
				print c" "sprintf("%04d", length(ls[nl]))" "ls[nl]
			}
		}
	' | sort "$@" | cut -d ' ' -f 3-
}

filtrerVersions()
{
	sed -e '/^.*-\([0-9.]*\)$/!d' -e 's##\1 &#' | while read v chemin
	do
		if testerVersion "$v" $@
		then
			echo "$chemin"
		fi
	done
}

# Renvoie la version maximale donnée par une plage, si une limite haute est donnée.
# Ex.:
#   vmax ">= 5.4" "< 6" "< 5.7" "< 6"
#     5.6
# Attention! Ne prend en compte que les <, <=, et les versions exactes.
# Donc vmax > 5.6 < 5.7 renverra quand même 5.6 (l'option -p 99 renverra 5.6.99)
# vmax > 5.6 ne renverra rien (infini).
vmax()
{
	local prec= saufPremier=
	
	while [ $# -gt 0 ]
	do
		case "$1" in
			-1) saufPremier=oui ;; # L'option -1 permet de virer le premier paramètre, par exemple un nom de logiciel issu de decoupePrerequis.
			-p) prec=".$2" ; shift ;;
			*) break ;;
		esac
		shift
	done
	[ -z "$saufPremier" ] || shift
	
	_vmax $*
}

_vmax()
{
	local pv vmax= vessie moinsUn= rvc # "vessie" comme Version de l'ESSai de l'Itération En cours.
	while [ $# -gt 0 ]
	do
		case "$1" in
			"<"|"<="|">="|">") pv="$1 $2" ; shift ;;
			*) pv="$1" ;;
		esac
		shift
		case "$pv" in
			"<"*|[0-9]*)
				IFS="<=> "
				_vmax_vessie $pv
				[ -n "$vessie" ] || continue # Version vide? Bon, erreur de lecture, en tout cas on n'en tient pas compte.
				# Si $vmax est déjà définie, elle est peut-être déjà trop bas pour que $vessie puisse espérer apporter quelque chose.
				if [ -n "$vmax" ]
				then
					# Si $vessie > $vmax, pas la peine de poursuivre (donc continue pour passer au tour de boucle suivant).
					# Et si $vessie == $vmax, le seul cas intéressant sera si moinsUn est vide (ex.: $vmax vaut 64 après un "<= 64", et maintenant nous sommes soumis à un "< 64" qui pourrait faire changer moinsUn).
					vc --var rvc "$vessie" "$vmax"
					case "$rvc" in
						0) [ -z "$moinsUn" ] || continue ;;
						1) continue ;;
					esac
				fi
				# Allez, on travaille sur ce nouveau maximum.
				vmax="$vessie"
				moinsUn=
				testerVersion "$vessie" $pv || moinsUn=oui # Si le nombre trouvé ne rentre pas dans le filtre qui le contient (ex.: "64" ne rentre pas dans "< 64"), la valeur max sera un epsilon avant.
				;;
		esac
	done
	
	if [ -n "$moinsUn" ]
	then
		IFS=.
		_vmax_prec $vmax
	fi
	
	echo "$vmax"
}

_vmax_vessie()
{
	unset IFS
	for vessie in "$@"
	do
		case "$vessie" in
			[0-9]*) return ;;
		esac
	done
	vessie=
}

_vmax_prec()
{
	unset IFS
	vmax=
	while [ $# -gt 1 ]
	do
		vmax="$vmax$1."
		shift
	done
	case "$1" in
		0) IFS=. ; _vmax_prec $vmax ;;
		*) vmax="$vmax`expr "$1" - 1 || true`$prec" ;;
	esac
}

aliasVersion()
{
	# Inutile de se fatiguer si $guili_alias ne contient rien qui au moins ressemble à un nom suffixé 
	case "$guili_alias:" in
		*$1:*) true ;;
		*) return 0 ;;
	esac
	
	local x="$1" sep="`printf '\003'`" esed=
	IFS=.
	tifs _aliasVersionConstituerEsed $version
	guili_alias="`IFS="$sep" ; echo "$guili_alias:" | sed $esed -e 's/:$//'`"
}

_aliasVersionConstituerEsed()
{
	local rech= rempl= n=1
	while [ $# -gt 0 ]
	do
		rech="$rech\\([._]*\\)$x"
		rempl="$rempl\\$n$1"
		esed="-e${sep}s/$rech:/$rempl:/g$sep$esed" # On cumule par le début, pour que les plus longs soient traités d'abord (_x_x doit être remplacé par _3_14 par l'expression 2 éléments, et non par _x_3 par l'expression un élément).
		n=`expr $n + 1`
		shift
	done
}

# Détermine si un nom est un logiciel(+option)*-version.
# À invoquer en IFS=- ; tifs estUnLOV $truc
estUnLOV()
{
	local verbeux= v
	if [ "x$1" = x-v ] ; then shift ; verbeux=1 ; fi
	eval 'v="$'$#'"'
	case "$v" in
		*[^.0-9]*|.*|*.)
			[ -z "$verbeux" ] || ( IFS=- ; echo "\"$*\" n'est pas un logiciel(+option)*-version." ) >&2
			return 1
			;;
	esac
}
