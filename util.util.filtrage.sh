# Copyright (c) 2010,2016,2020 Guillaume Outters
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

# Filtre un fichier.
# Utilisation: filtrer <fichier> <commande> <arg>...
# Ex.: filtrer /tmp/fichier.conf sed -e /pourri/d # sed, à la différence de grep -v, ne sort pas en erreur s'il n'a pas trouvé.
# En sortie, $FILTRER_RES est définie à 1 si un changement a eu lieu.
filtrer()
{
	FILTRER_RES=
	fichier="$1"
	shift
	if "$@" < "$fichier" > "$TMP/$$/temp"
	then
		if diff -q "$TMP/$$/temp" "$fichier" > /dev/null ; then return 0 ; fi
		FILTRER_RES=1
		cat "$TMP/$$/temp" > "$fichier"
	else
		return $?
	fi
}

sufiltrer()
{
	fichier="$1"
	shift
	"$@" < "$fichier" > "$TMP/$$/temp" && sudo sh -c "cat $TMP/$$/temp > $fichier"
}
