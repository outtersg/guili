#!/bin/sh
# Copyright (c) 2017 Guillaume Outters
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

# Court-circuite un utilitaire du PATH (du même nom que celui-ci), pour l'appeler après avoir éventuellement modifié ses arguments.
# Utilisation: copiez ce fichier, avec pour nom celui de l'utilitaire que vous voulez contrôler, dans un dossier qui se situe dans le PATH quelque part avant celui de l'utilitaire à remplacer. Insérez dans la copie, à l'endroit du commentaire contenant "ici" en majuscules, vos manipulations. 

SCRIPTS="`command -v "$0"`" ; [ -x "$SCRIPTS" -o ! -x "$0" ] || SCRIPTS="$0" ; case "`basename "$SCRIPTS"`" in *.*) true ;; *sh) SCRIPTS="$1" ;; esac ; case "$SCRIPTS" in /*) ;; *) SCRIPTS="`pwd`/$SCRIPTS" ;; esac ; delie() { while [ -h "$SCRIPTS" ] ; do SCRIPTS2="`readlink "$SCRIPTS"`" ; case "$SCRIPTS2" in /*) SCRIPTS="$SCRIPTS2" ;; *) SCRIPTS="`dirname "$SCRIPTS"`/$SCRIPTS2" ;; esac ; done ; } ; delie ; SCRIPTS="`dirname "$SCRIPTS"`" ; delie

moi="`basename "$0"`"
sep="`echo | tr '\012' '\003'`"

appeler()
{
	shift # Le premier séparateur vide.
	depathement="`echo ":$PATH:" | sed -e 's/:/::/g' -e "s#:$SCRIPTS/*:#:#g" -e 's/:::*/:/g' -e 's/^://' -e 's/:$//'`"
	PATH="$depathement" "$moi" "$@"
}

argouille()
{
	for arg in "$@"
	do
		args="$args$sep$arg"
	done
}

faire()
{
	IFS="$sep"
	appeler $args
}

args=

while [ $# -gt 0 ]
do
	case "$1" in
		# Rajoutez ICI vos règles de retraitement des arguments.
		*) argouille "$1" ;;
	esac
	shift
done

faire
