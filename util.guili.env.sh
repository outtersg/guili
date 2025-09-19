# Copyright (c) 2014-2025 Guillaume Outters
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

# Utilitaires de configuration des variables d'environnement dans lequel se lancera la construction d'un GuiLI ($PATH, $LD_LIBRARY_PATH, etc.)

preParamsCompil()
{
	local d
	local paramsPreCFlag=
	if [ "x$1" = x--sans-c-cxx ]
	then
		paramsPreCFlag="$1"
		shift
	fi
	[ ! -e "$1/include" ] || preCFlag $paramsPreCFlag "-I$1/include"
	for d in $1/lib64 $1/lib
	do
		if [ -d "$d" ]
		then
			guili_lflags="-L$d $guili_lflags"
			_rc_export LDFLAGS "-L$d"
		fi
	done
}

postParamsCompil()
{
	local d
	[ ! -e "$1/include" ] || guili_cppflags="$guili_cppflags -I$1/include"
	for d in $1/lib64 $1/lib
	do
		if [ -d "$d" ]
		then
			guili_lflags="$guili_lflags -L$d"
		fi
	done
}
