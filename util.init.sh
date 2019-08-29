#!/bin/sh
# Copyright (c) 2010i-2011,2016,2018-2019 Guillaume Outters
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

# Utilitaires de constitution d'un environnement de travail.

# S'assure de la présence de, et va dans le $TMP/$$ qui nous servira de bac à sable.
util_tmp()
{
	[ -n "$TMP" ] || TMP="$HOME/tmp"
	
	# Si notre environnement a été pourri par un appelant qui ne tourne pas sous notre compte, il se peut qu'il ait défini un TMP dans lequel nous ne savons pas écrire. En ce cas nous redéfinissons à une valeur "neutre".
	if ! mkdir -p "$TMP/$$" 2> /dev/null
	then
		TMP=/tmp
		mkdir -p "$TMP/$$"
	fi
	
	# Le ménage va être mis en place; il essaiera de supprimer les artéfacts de compilation, supposés dans `pwd` (s'il est sous /tmp/). Aussi nous nous plaçons dans notre répertoire dédié temporaire, afin qu'en cas de sortie nous effacions notre dossier temporaire plutôt que le source d'un de nos appelants duquel nous n'aurions pas eu le temps de "sortir" par cd.
	cd "$TMP/$$"
	
	# Mise en place du ménage des dossiers temporaires et de travail.
	trap util_menage EXIT
	trap util_mechantmenage INT TERM
}

util_menage()
{
	if [ $? -eq 0 ] # En cas de meurtre, on ne fait pas disparaître les preuves.
	then
		# Un minimum de blindage pour éviter de supprimer / en cas de gros, gros problème (genre le shell ne saurait même plus fournir $$).
		case "$TMP/$$" in
			*/[0-9]*)
				rm -Rf "$TMP/$$"
				;;
		esac
		# De même pour le dossier courant s'il contient un bout de /tmp/ dans son nom (ex.: dossier de compilation).
		local dossierCourant="`pwd`"
		case "$dossierCourant" in
			*/tmp/[_A-Za-z0-9]*) cd /tmp/ && rm -Rf "$dossierCourant" ;;
		esac
	fi
}

util_mechantmenage()
{
	util_menage
	exit 1
}
