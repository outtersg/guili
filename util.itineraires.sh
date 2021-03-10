# Copyright (c) 2019-2021 Guillaume Outters
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

#- Système: environnement chemins ----------------------------------------------

# À FAIRE: chemins() et chemins_init devraient venir se caler dans ce fichier.

# Déclinaison de guili_ppath en guili_lpath, guili_ipath, etc.
itineraireBis()
{
	case "$guili_ppath_dernier_itineraire_bis" in
		"$guili_ppath") return 0 ;;
	esac
	guili_ppath_dernier_itineraire_bis="$guili_ppath"
	
	IFS=:
	_itineraireBis $guili_ppath
}

_itineraireBis()
{
	unset IFS
	local racine v
	for v in \
		guili_xpath guili_lpath guili_lpath guili_pcpath guili_acpath
	do
		eval $v=
	done
	
	for racine in "$@"
	do
		[ "$racine" != "<" ] || continue
		
		guili_xpath="$guili_xpath$racine/bin:"
		guili_lpath="$guili_lpath$racine/lib:"
		[ ! -e "$racine/lib64" ] || guili_lpath="$guili_lpath$racine/lib64:"
		guili_ipath="$guili_ipath$racine/include:"

		guili_pcpath="$guili_pcpath$racine/lib/pkgconfig:"
		[ ! -e "$racine/lib64/pkgconfig" ] || guili_pcpath="$guili_pcpath$racine/lib64/pkgconfig:"
		if [ -e "$racine/share/aclocal" ] ; then # aclocal est pointilleux: si on lui précise un -I sur quelque chose qui n'existe pas, il sort immédiatement en erreur.
			guili_acpath="$guili_acpath$racine/share/aclocal:"
		fi
	done
}
