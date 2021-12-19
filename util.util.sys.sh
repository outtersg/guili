# Copyright (c) 2021 Guillaume Outters
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

# Le Mac a la fâcheuse tendance d'embarquer ses propres versions de composants Open Source (iconv, sqlite3…);
# et d'y lier certaines de ses bibliothèques système.
# Donc pour peu qu'un logiciel se lie à ses dernières (ex.: un truc cherchant un pontage vers CoreGraphics, ou un Python et son scproxy),
# on est condamnés à se lier à ces versions système des Open Source, ou au moins à une version très compatible.

# Pour un logiciel amené à se lier à des bibliothèques système, remplace dans $prerequis celles fournies par ledit système par un équivalent proche (voire se débrouille pour utiliser celle système).
similisys()
{
	prerequis="`_similisys`"
}

_similisys()
{
	decoupePrerequis "$prerequis" | sed -e 's/+/ &/' | while read l reste
	do
		commande "similisys_$l" || { echo "$l $reste" ; continue ; }
		similisys_$l "$reste"
	done | sed -e 's/ +/+/g' | tr '\012' ' '
}
