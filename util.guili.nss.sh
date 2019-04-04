# Copyright (c) 2019 Guillaume Outters
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

# En ce début 2019, un nombre incroyable de paquets s'imaginent avoir nss.h (et tout le reste du bazar) directement sous include.
# Pourtant moi quand j'installe ils finissent bien rangés dans include/nss/nss.h.
# Plutôt que de jouer sur les -I de tous les appelants au biblios liées à NSS, on pourra mettre un chemin correct dans les .h de celles-ci.
# NSS doit faire partie des prérequis.
inclusionsNss()
{
	local ou="$*"
	[ ! -z "$ou" ] || ou=.
	local f
	local exprH="`cd "$destnss/include/nss" && find . -maxdepth 1 -name "*.h" | sed -e 's#^\./##' | tr '\012' \| | sed -e 's#|$##'`"
	find $ou -name configure -o -name "*.h" -o -name "*.c" -o -name "*.hxx" -o -name "*.cxx" | while read f
	do
		filtrer "$f" sed -E -e "/^[ 	]*#[ 	]*include[ 	]*<$exprH>/s#<#<nss/#"
		# Pour dans du #if NSS:
		#filtrer "$f" awk 'dedans&&/#endif/{dedans=0}dedans&&/#include <('"$exprH"'glouglou)>/{sub(/</,"<nss/")}{print}/^ *#.*if .*NSS/{dedans=1}'
	done
}
