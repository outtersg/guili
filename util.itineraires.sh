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
	for v in guili_ppath_mono \
		guili_xpath guili_lpath guili_lpath guili_pcpath guili_acpath
	do
		eval $v=
	done
	
	for racine in "$@"
	do
		[ "$racine" != "<" ] || continue
		
		# Contrôle d'unicité: on ne conserve que le premier de la série.
		# Les variables qui doivent être restituées telles quelles, quitte à apparaître en doublon, doivent être travaillées *avant* cette ligne.
		# Les variables qui souhaiteraient privilégier la *dernière* valeur devraient se faire un args_suppr plutôt à la place du continue.
		case ":$guili_ppath_mono" in
			*:$racine:*) continue ;;
		esac
		guili_ppath_mono="$guili_ppath_mono$racine:"
		
		guili_xpath="$guili_xpath$racine/bin:"
		guili_lpath="$guili_lpath$racine/lib:"
		[ ! -e "$racine/lib64" ] || guili_lpath="$guili_lpath$racine/lib64:"
		guili_ipath="$guili_ipath$racine/include:"

		guili_pcpath="$guili_pcpath$racine/lib/pkgconfig:"
		[ ! -e "$racine/lib64/pkgconfig" ] || guili_pcpath="$guili_pcpath$racine/lib64/pkgconfig:"
		if [ -e "$racine/share/aclocal" ] ; then # aclocal est pointilleux: si on lui précise un -I sur quelque chose qui n'existe pas, il sort immédiatement en erreur.
			guili_acpath="$guili_acpath$racine/share/aclocal:"
		fi
		
		[ $MODERNITE -lt 4 ] || postParamsCompil "$racine"
	done
}

# Mémorise l'environnement que nous allons modifier ($LD_LIBRARY_PATH etc.).
# Ainsi si nous devons l'agréger deux fois, nous saurons retrouver la part d'origine.
itinerairesSauvegardeEnv()
{
	# Uniquement la première fois. Les autres fois l'environnement est supposé déjà brouillé par les util.*.sh.
	[ -z "$guili_memEnv" ] || return 0
	
	local var
	for var in PATH LD_LIBRARY_PATH CMAKE_LIBRARY_PATH LDFLAGS CPPFLAGS CFLAGS CXXFLAGS OBJCFLAGS CMAKE_INCLUDE_PATH PKG_CONFIG_PATH ACLOCAL ACLOCAL_PATH
	do
		eval "guili_env_$var=\"\$$var\""
	done
	
	guili_memEnv=1
}

_cheminsExportes()
{
	itineraireBis # Mise à jour des $guili_*path.
	
	local guili_acflags="`_pverso -I "$guili_acpath"`"
	ACLOCAL="`echo "$guili_env_ACLOCAL" | sed -e 's/^ *$/aclocal/' -e "s#aclocal#aclocal$guili_acflags#"`"
	export \
		PATH="$guili__xpath$guili_xpath$guili_env_PATH" \
		LD_LIBRARY_PATH="$guili_lpath$guili_env_LD_LIBRARY_PATH" \
		CMAKE_LIBRARY_PATH="$guili_lpath$guili_env_CMAKE_LIBRARY_PATH" \
		LDFLAGS="$guili_lflags $guili_env_LDFLAGS" \
		CPPFLAGS="$guili_cppflags $guili_env_CPPFLAGS" \
		CFLAGS="$guili_cflags $guili_env_CFLAGS" \
		CXXFLAGS="$guili_cxxflags $guili_env_CXXFLAGS" \
		CMAKE_INCLUDE_PATH="$guili_ipath$guili_env_CMAKE_INCLUDE_PATH" \
		PKG_CONFIG_PATH="$guili_pcpath$guili_env_PKG_CONFIG_PATH" \
		ACLOCAL \
		ACLOCAL_PATH="$guili_acpath$guili_env_ACLOCAL_PATH"
}
