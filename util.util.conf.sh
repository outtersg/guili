# Copyright (c) 2018 Guillaume Outters
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

# Prend un fichier de conf à plat et insère ou remplace les variables données.
changerconf()
{
	cc_f=
	cc_sep="="
	cc_comm='#'
	cc_varsawk=
	while [ $# -gt 0 ]
	do
		case "$1" in
			-d) shift ; cc_sep="$1" ;;
			-c) shift ; cc_comm="$1" ;;
			*=*) cc_varsawk="$cc_varsawk|$1" ;;
			*) [ -z "$cc_f" ] && cc_f="$1" || break ;; # À FAIRE: pouvoir traiter plusieurs fichiers.
		esac
		shift
	done
	
	filtrer "$cc_f" awk '
BEGIN {
	s = "'"$cc_sep"'";
	c = "'"$cc_comm"'";
	split(substr("'"$cc_varsawk"'", 2), t0, "|");
	for(i in t0) { split(t0[i], telem, "="); t[telem[1]] = t[telem[1]]"|"telem[2]; }
	for(i in t) t[i] = substr(t[i], 2);
}
function pondre() {
	for(i in ici)
	{
		split(ici[i], vals, "|");
		for(j in vals)
			print i""s""vals[j];
	}
	delete ici;
}
{
	# Si on trouve un de nos termes dans la ligne courante, on se prépare à insérer nos valeurs pour cette variable.
	for(i in t)
		if(match($0, "^( *"c" *)?"i"[	 ]*"s))
		{
			ici[i] = t[i];
			delete t[i];
		}
}
/^ *#/{
	# Si la ligne est un commentaire, on la laisse en paix.
	print;
	next;
}
{
	# Autre ligne (donc non commentée).
	# Mais va-t-on la commenter? Si elle définit un des paramètres que l on remplace, oui.
	for(i in ici)
		if(match($0, "^"i"[ 	]*"s))
		{
			split(ici[i], vals, "|");
			for(j in vals)
				if($0 == i""s""vals[j]) # Si la ligne contient une des valeurs que l on va insérer, pas la peine de la commenter (puisqu on en insère une version décommentée, vraisemblablement la même ligne en fait).
					next;
			print c""$0;
			next;
		}
	# Première ligne pas commentaire après (ou au moment) le repérage d un de nos mots-clés! On va donc dire tout ce qu on retenait depuis pas mal de temps.
	pondre();
	# Et tout de même on écrit la ligne en question.
	print;
}
END {
	for(i in t)
		ici[i] = t[i];
	pondre();
}
'
}
