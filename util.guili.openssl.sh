# Copyright (c) 2019-2020 Guillaume Outters
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

prerequisOpenssl()
{
	# À FAIRE: dans les prerequis sans +osslxx, repérer ceux qui contiennent un prerequisOpenssl et leur ajouter alors un +osslxx.
	case "$argOptions" in
		# Au moins une option OpenSSL positive: on va pouvoir passer à la suite (qui gérera l'aiguillage).
		*+ossl*|*+openssl*) true ;;
		# Aucune option positive, mais au moins une négative explicite.
		*-ossl[-+]|*-openssl[-+]) virerPrerequis openssl ; return 0 ;; # On retourne, mais après avoir viré toute référence à OpenSSL.
		# Aucune mention, donc selon le mode d'appel.
		*)
			local opsi=
			case "$1" in
				# Le plus contraignant: s'il existe exclusivement installé par GuiLI.
				--si-guili) opsi="optionSi ossl/openssl" ;;
				# Si on trouve une commande openssl quelque part.
				--si-la|--si-present|--si-installe) opsi="optionSi ossl/openssl commande openssl" ;;
				# Mode par défaut (implicite).
				"") true ;;
				# Toute autre option est une faute de frappe d'un des --si- ci-dessus.
				*) rouge "# prerequisOpenssl: option non reconnue: $1" >&2 ; return 1 ;;
			esac
			# Si un des modes de recherche est mentionné, on le tente.
			[ -z "$opsi" ] || $opsi || ! virerPrerequis openssl || return 0
			# Sinon mode implicite: on prend l'option (un peu à la façon d'opSiPasPas, sauf que là on jongle entre +ossl et +openssl).
			;;
	esac
	
	local osslxx mami ma mi
	
	ma_et_mi() { ma=$1 ; mi=$2 ; }
	for mami in "1 0" "1 1" "3 0" "3 1" "3 2" "3 3" "3 4"
	do
		ma_et_mi $mami
		if option ossl$ma$mi
		then
			osslxx=ossl$ma$mi
			prerequis="`echo " $prerequis " | sed -e "s# openssl # openssl >= $ma.$mi < $ma.$((mi+1)) #"`"
			break
		fi
	done
	if [ -z "$osslxx" ]
	then
		local filtre="`decoupePrerequis "$prerequis" | grep '^openssl[+ ]'`"
		[ -n "$filtre" ] || filtre="openssl"
		local vlocal="`versions "$filtre" | tail -1 | sed -e 's/.*-//'`"
		local vmajlocal="`echo "$vlocal" | sed -e 's/\.//' -e 's/\..*//'`"
		if [ ! -z "$vmajlocal" ]
		then
			argOptions="`options "$argOptions+ossl$vmajlocal" | tr -d ' '`"
			osslxx=ossl$vmajlocal
			prerequis="`echo " $prerequis " | sed -e "s# openssl # openssl $vlocal #"`"
			# Consommons les options explicitant un numéro de version: si on est arrivés ici c'est qu'on répond bien à cette option.
			case "$argOptions" in
				*+ossl[1-9]*|*+openssl[1-9]*)
					local o
					for o in `printf %s $argOptions | sed -e 's/[-+]/ &/g'`
					do
						case "$o" in
							+ossl[1-9]*|+openssl[1-9]*)
								option "`echo "$o" | tr -d +`"
								;;
						esac
					done
					;;
			esac
		fi
	fi
	argOptions="`options "$argOptions-openssl-ossl"`" # Les +openssl ou +ossl disparaissent au profit du +ossl1x.
	prerequis="`echo " $prerequis " | sed -e "s#+osslxx#+$osslxx#g"`"
}
