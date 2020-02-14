# Copyright (c) 2003-2005,2008,2011-2020 Guillaume Outters
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

# Renvoie les versions pour un logiciel donnée, triées par version croissante.
versions()
{
	local GUILI_PATH="$GUILI_PATH"
	[ ! -z "$GUILI_PATH" ] || GUILI_PATH="$INSTALLS"
	
	versions_expr_version='[0-9.]+'
	local filtreDernier=0 filtreComplet=0 fouines= fouine versions_liste=
	while [ $# -gt 0 ]
	do
		case "$1" in
			-1) filtreDernier=1 ;;
			-f|--finalisees|--full|--completes|--fear-the-partial) filtreComplet=1 ;;
			-v) versions_expr_version="$2" ; shift ;;
			-li) fouines="$fouines versions_listerInstallees" ;;
			-lv) fouines="$fouines versions_listerListe" ; versions_liste="$versions_liste$2 " ; shift ;;
			*) break ;;
		esac
		shift
	done
	[ -n "$fouines" ] || fouines=versions_listerInstallees
	
	local logiciel options filtreVersion
	while [ $# -gt 0 ]
	do
		# Découpage des paramètres: logiciel, options, filtre version.
		
		logiciel="`echo "$1" | sed -e 's/[<>]/ &/g' -e 's/  *+/+/g'`" ; shift
		case "$logiciel" in
			*" "*)
				filtreVersion="`echo "$logiciel" | cut -d ' ' -f 2-`"
				logiciel="`echo "$logiciel" | cut -d ' ' -f 1`"
				;;
			*) filtreVersion= ;;
		esac
		case "$logiciel" in
			*+*)
				options="`echo "$logiciel" | cut -d + -f 2-`"
				logiciel="`echo "$logiciel" | cut -d + -f 1`"
				;;
			*) options= ;;
		esac
		while [ $# -gt 0 ]
		do
			case "$1" in
				+*) options="$options$1" ;;
				"<"*|">"*) filtreVersion="$filtreVersion $1" ;;
				[0-9]*) argVersion "$1" || break ; filtreVersion="$filtreVersion $1" ;;
				*) break ;;
			esac
			shift
		done
	options="`options "+$options" | sed -e 's/[-=+][-=+]*\([-=+]\)/\1/g' -e 's/[-=+]$//'`"
		
		versions_logiciel="$logiciel" # Pour compatibilité, du temps où je préfixais les variables du nom de la fonction, ne sachant pas qu'on pouvait faire du local.
		
		# Calcul des expressions sed correspondantes.
		
	local versions_expr_options= versions_expr_excl=
	case "$options" in
		*+*) versions_expr_options="`argOptions="$options" argOptions | sed -e 's/-[^-=+]*//g' -e 's#[+]#([+][^+]*)*[+]#g'`" ;;
	esac
	local versions_expr="(^|/)$versions_logiciel$versions_expr_options([+][^+]*)*-$versions_expr_version$"
	case "$options" in
		*-*) versions_expr_excl="(^|/)$versions_logiciel([+][^+]*)*`echo "$options" | sed -e 's/[+][^-=+]*//g' -e 's#-#|[+]#g' -e 's#|#(#'`)([+][^+]*)*-$versions_expr_version$" ;;
	esac
		for fouine in $fouines ; do $fouine ; done \
		| egrep "$versions_expr" \
		| ( [ -z "$versions_expr_excl" ] && cat || egrep -v "$versions_expr_excl" ) \
		| filtrerVersions "$filtreVersion" \
		| triversions \
		| _v_filtreTrouves
	done
}

versions_listerInstallees()
{
	tifs find --sep : "$GUILI_PATH" -maxdepth 1 \( -name "$versions_logiciel-*" -o -name "$versions_logiciel+*-*" \)
}

versions_listerListe()
{
	for truc in $versions_liste
	do
		echo "$truc"
	done
}

_v_filtreTrouves()
{
	case "$filtreDernier$filtreComplet" in
		"11") while read d ; do [ -f "$d/$COMPLET" -o "$d/$ENCOURS" ] && echo "$d" || true ; done | tail -1 ;;
		"10") tail -1 ;;
		"01") while read d ; do [ -f "$d/$COMPLET" -o "$d/$ENCOURS" ] && echo "$d" || true ; done ;;
		*) cat ;;
	esac
}

# Logiciel-Options-Version Explicite ou Rapporté
# Récupère le triplet LOV d'un dossier, en lisant le .guili.version si présent, sinon le dossier lui-même.
lover()
{
	local d="$1" r="$1"
	case "$d" in
		*/*) r="`bn "$r"`" ;;
		*) d="$INSTALLS/$d" ;;
	esac
	if [ -s "$d/$GUILI_F_VERSION" ] ; then r="`cat "$d/$GUILI_F_VERSION"`" ; fi
	IFS=-
	tifs estUnLOV -v $r || return 1
	echo "$r"
}

# Liste les versions "supérieures" à une version donnée: soit version ultérieure, soit même version mais plus d'options.
# Utilisation: cadets <logiciel>+
#   <logiciel>
#     Peut être un chemin absolu $INSTALLS/<logiciel>+<option>-<version>, ou un simple <l>+<o>-<v>.
#     Attention: s'il n'existe pas dans $INSTALLS, tous les résultats trouvés seront considérés comme supérieurs; ainsi un appel à cadets nginx+cscript-1.17.4 alors que le logiciel mentionné n'existe pas, renverra pour cadet un nginx-1.17.4 (sans cscript).
cadets()
{
	local sep= lov l o v
	[ "x$1" = x-s ] && shift && sep="$1" && shift || true
	for lov in "$@"
	do
		love -e "l o v" "$lov"
		_cadets "$lov" `versions "$l >= $v" | sed -e 's#^.*/##'`
	done
}

_cadets()
{
	local truc="`bn "$1"`" ; shift
	IFS=:
	if ! tifs _cascadets ":$*:" # Si nous figurons dans la liste de cadets potentiels.
	then
		while [ "$1" != "$truc" ] ; do shift ; done
		shift
	fi
	if [ -z "$sep" ]
	then
		for l in "$@" ; do echo "$l" ; done
	else
		IFS="$sep"
		echo "$*"
		unset IFS
	fi
}

_cascadets()
{
	case "$1" in *:$truc:*) return 1 ;; esac
}
