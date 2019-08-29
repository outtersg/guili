#!/bin/sh
# Copyright (c) 2011,2019 Guillaume Outters
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

# MOI REcompilé (avec des options différentes, et donc on espère des reflets différents dans le produit de compil).
# À appeler après le make, mais avant le make install (sans quoi le destiner() du moire fils va se croire déjà installé):
#   make
#   moire [-i x] "$@" <options supplémentaires>
#   if [ $MOIRE_STATUT = pere ]
#   then
#       # Faire toutes les manips voulues avec le produit de la compil précédente.
#   fi
# /!\ Le logiciel ira se recompiler dans notre $dest. Si ce n'est pas souhaité, surchargez $INSTALLS avant d'appeler, ou ajoutez des options supplémentaires en +xxx.
# N.B.: la fonction s'appelait initialement mere (ME REcompiler). Sauf que par son statut la mere pouvait être une mere-fils ou une mere-pere, ça faisait mauvais genre.
moire()
{
	local id
	if [ "x$1" = x-i ]
	then
		id="$2"
		shift
		shift
	else
		[ -n "$MOIRE_ID" ] || MOIRE_ID=0
		MOIRE_ID=`expr $MOIRE_ID + 1`
		id="$MOIRE_ID"
	fi
	
	case "$GUILI_MOIRE:" in
		*":$id:"*)
			MOIRE_STATUT=fils
			;;
		*)
			MOIRE_STATUT=pere
			GUILI_MOIRE="$GUILI_MOIRE:$id" TMP="$TMP/$$/moire$id" "$install_moi" "$@"
			;;
	esac
	
	# Si nous sommes appelés par un moire(), nous ne devons surtout pas terminer notre installation (fichier témoin .complet, poussage du binaire vers un silo, branchement dans $INSTALLS/bin, etc.). Le sutiliser() qui nous suivra sera donc vide.
	case "$GUILI_MOIRE" in
		:*) sutiliser() { true ; } ;;
	esac
}
