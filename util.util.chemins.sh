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

# Crée un lien symbolique relatif vers un autre chemin.
# Utilisation: ln_sr [-e <var>] [-a] <original> <lien>
#   -e <var>
#     Externalise. Le ln -s final n'est pas tiré, à la place le résultat est mis dans la variable $<var>.
#   -a
#     Absolu. On ne tente pas de remonter le chemin <lien> pour attendre <original> par lien relatif.
#   <original>
#     Chemin sur lequel pointer.
#   <lien>
#     Chemin qui pointera.
ln_sr()
{
	local var= abs=
	while [ $# -gt 0 ]
	do
		case "$1" in
			-e) var="$2" ; shift ;;
			-a) abs=oui ;;
			*) break ;;
		esac
		shift
	done
	
	local o="$1" l="$2" dl
	case "$o" in
		[^/]*) o="$PWD/$o" ;;
	esac
	case "$l" in
		[^/]*) o="$PWD/$l" ;;
	esac
	if [ -d "$l" ]
	then
		dl="$l"
		l="$l/`basename "$o"`"
	else
		dl="`dirname "$l"`"
	fi
	if [ -z "$abs" ]
	then
		IFS=/
		_ln_sr_relativiser o "$dl" $o
		unset IFS
	fi
	
	if [ -n "$var" ]
	then
		if [ "x$var" = x- ]
		then
			echo "$o"
		else
			eval $var="\"\$o\""
		fi
	else
		ln -s "$o" "$l"
	fi
}

_ln_sr_relativiser()
{
	local var="$1" ; shift
	local accu=
	local l="$1" ; shift
	local bl
	local diff=
	# Supprimons la partie commune.
	for bl in $l
	do
		case "$bl" in
			""|.) true ;;
			..) echo "# ln_sr: je ne sais pas gérer le .. dans le chemin." >&2 ; return 1 ;;
			*)
				while [ -z "$diff" ]
				do
					case "$1" in
						""|.) shift ;;
						..) echo "# ln_sr: je ne sais pas gérer le .. dans le chemin." >&2 ; return 1 ;;
						"$bl") shift ; break ;;
						*) diff=1 ;;
					esac
				done
				if [ -n "$diff" ]
				then
					accu="$accu../"
				fi
				;;
		esac
	done
	eval $var="\"\$accu\$*\""
}
