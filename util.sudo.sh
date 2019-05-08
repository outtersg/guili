# Copyright (c) 2016,2018-2019 Guillaume Outters
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

# Remplaçons sudo.
# L'usage principal de notre sudo surchargé est l'installation dans les dossiers privilégiés; 
# En effet nous utilisons le sudo pour installer dans $INSTALLS, mais parfois ce n'est pas nécessaire de passer su pour cela.
detecterSudo()
{
	sudo="vraisudo" # sudoku a besoin que $sudo soit définie.
	# Malheureusement, historiquement, on a un peu abusé du sudo pour nos installs (au lieu d'utiliser le sudoku dédié, qui n'est arrivé qu'après); du coup, pour compatibilité, on doit conserver cette surcharge sudo = sudoku.
	sudo() { sudoku "$@" ; }
}

_commandMoinsVSudo()
{
	unalias sudo > /dev/null 2>&1 || true
	unset -f sudo > /dev/null 2>&1 || true
	# Des fois qu'on ait été compilé avec un $PATH minimal des seuls prérequis du logiciel (exclusivementPrerequis), pour les opérations avérées root (ex.: install) il va bien falloir s'adjoindre un sudo même s'il n'est pas prérequis explicite.
	sudoguili="`versions sudo | tail -1 || true`"
	[ -z "$sudoguili" ] || PATH="$PATH:$sudoguili/bin"
	command -v sudo
}

vraisudo()
{
	if [ -z "$sudo" -o "x$sudo" = xvraisudo ]
	then
		local _sudo="`_commandMoinsVSudo`"
		case "$_sudo" in
			/*) sudo="$_sudo" ;;
			*) echo "# sudo introuvable dans le PATH \"$PATH\" (pour \"sudo $@\")" >&2 && return 1 ;;
		esac
	fi
	$sudo "$@"
}

detecterSudo
