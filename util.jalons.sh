# Copyright (c) 2026 Guillaume Outters
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

# Création de jalons pour reprendre un GuiLI vautré en plein vol, grâce à un cache de l'environnement (dont le dossier courant).
# Utilisation:
#	if ! jalon source ; then # Pas encore en cache?
#		obtenirEtAllerDansVersion
#		for modif in true $modifs ; do $modif ; done
#		jalonner source # Mémorisation pour pouvoir court-circuiter la prochaine fois.
#	fi
# Le but est de pouvoir rattraper une compilation foirée sans tout reprendre à zéro;
# notamment, lorsque la phase de tar + $modifs touche à un .h qui entraîne la recompil de TOUT le logiciel, on est bien contents de pouvoir simplement repartir de la phase make de juste ce qui manquait.

# À FAIRE: des accroches pour les fonctions qui modifient ailleurs que les sources et l'environnement (ex.: celles qui déposent des binaires de contournement dans $TMP/$$).

jalon()
{
	# À FAIRE: pour du multiarch, le $GUILI_MOIRE mentionne simplement :multiarch, ce qui risque d'entraîner un chevauchement en cas de plusieurs architectures secondaires;
	#   il faudrait du multiarch_i386, multiarch_etc. pour ne pas se marcher sur les pieds.
	local jalon="jalon.$1:`bn "$dest"`$GUILI_MOIRE" PWD=
	eval jalon_$1="$jalon"
	
	[ -f "$TMP/$jalon" ] || return 1
	
	gris "Chargement du jalon $TMP/$jalon (cache)"
	. "$TMP/$jalon"
	case "$PWD" in "") jaune "# jalon sans \$PWD; tant pis, on rebascule sur la version longue" >&2 ; return 1 ;; esac
	cd "$PWD"
}

jalonner()
{
	local jalon
	eval jalon='"$jalon_'$1'"'
	case "$jalon" in "") rouge "# jalonner() appelée sans jalon() préalable" >&2 ; return 1 ;; esac
	
	{
		set # Inclut le PWD, normalement.
		export -p # export -p est le seul qui marche à l'identique sur les /bin/sh de FreeBSD 15.0 ou 10.2, Mac OS X 10.13, et Raspbian sur un RPi3.
	} | _jalonner_filtrer > "$TMP/$jalon.tmp" && mv "$TMP/$jalon.tmp" "$TMP/$jalon"
}

_jalonner_filtrer()
{
	# Sur vieux Mac, le /bin/sh qui est en fait un bash sera aussi strict qu'un sh au moment d'ingérer les affectations… qu'il aura générées comme un bash, donc avec des BASH_ARGC=([0]="1") qui feront exploser la réingestion.
	# En outre quelques variables readonly sont intégrées.
	egrep -v '^[^=]*=\(|^(EUID|PPID|SHELLOPTS|UID)=' || true
}
