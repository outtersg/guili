# Copyright (c) 2018-2019 Guillaume Outters
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

pyp()
{
	local pvc="`pyla -V 2>&1 | sed -e 's/[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/'`" # Python version courte
	echo "lib/python$pvc/site-packages"
}

pyla()
{
	PATH="$dest/bin:$PATH" LD_LIBRARY_PATH="$dest/lib64:$dest/lib:$LD_LIBRARY_PATH" python "$@"
}

# Renvoie un PYTHONPATH incluant les lib/pythonxx/site-packages de $dest, $INSTALLS/$PYEXT,  et $destpython.
pypadest()
{
	local pyp="`pyp`"
	local r="$dest/$pyp:$INSTALLS/$PYEXT/$pyp"
	[ -z "$destpython" ] || r="$r:$destpython/$pyp"
	echo "$r"
}

# Prépare un dossier à recevoir une installation d'une extension Python.
pyextinit()
{
	local dest="$dest"
	[ -z "$1" ] || dest="$1"
	mkdir -p "$dest/`pyp`"
	export PYTHONPATH="`pypadest`"
	guili_localiser="$guili_localiser finaliserInstallPyExt"
}

sudokupy()
{
	sudoku PATH="$PATH" LD_LIBRARY_PATH="$LD_LIBRARY_PATH" PYTHONPATH="`pypadest`" SSL_CERT_FILE="$SSL_CERT_FILE" "$@"
}

pylanceur()
{
	# /!\ Ne fonctionne qu'au premier niveau, car certains logiciels (ex.: meson), invoqués par leur lanceur, génèrent ensuite des lignes de commande "python meson.py", court-circuitant le lanceur.
	# N.B.: la partie LD_LIBRARY_PATH est normalement prise en charge par pythonenboiter (du moment que le LD_LIBRARY_PATH peut être codé en dur à l'installation).
	# N.B.: la partie PYTHONPATH est normalement prise en charge par pyext.pth.
	# Bref en théorie on n'a plus à appeler cette fonction.
	# À FAIRE: alerte si quelqu'un s'avise encore de l'appeler.
	# À FAIRE: la retirer si le monde continue à tourner alors que plus personne ne l'utilise.
	
	local lance="$1"
	local chaineAbs="`egrep '[dD]elieS\(|absolutiseScripts\(|delie\(' < "$install_moi"`"
	cat <<TERMINE
#!/bin/sh
$chaineAbs
oeufs()
{
	unset IFS
	local d
	find "\$@" -maxdepth 1 -name "*.egg" | tr '\\012' :
}
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
export PYTHONPATH="`pypadest`:\`oeufs "$INSTALLS/$PYEXT/`pyp`"\`"
export SSL_CERT_FILE="$SSL_CERT_FILE"
"\$SCRIPTS/$lance" "\$@"
TERMINE
}

finaliserInstallPyExt()
{
	local pyext="$INSTALLS/$PYEXT"
	( cd "$desto" && tar cf - . ) | ( sudoku mkdir -p "$pyext" && cd "$pyext" && sudoku tar xf - )
}

PYEXT="pyext-1.0"
