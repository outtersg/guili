#!/bin/sh
# Copyright (c) 2011,2016-2019 Guillaume Outters
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

utiliserSiDerniere()
{
	local dest="$dest"
	[ -n "$1" ] || dest="$1"
	local lv="`basename "$dest"`"
	
	local logicielParam="`echo "$lv" | sed -e 's/-[0-9].*//'`"
	local derniere="`versions "$logicielParam" | tail -1 | sed -e 's#.*/##' -e "s/^$lv-.*/$lv/"`" # Les déclinaisons de nous-mêmes sont assimilées à notre version (ex.: logiciel-x.y.z-misedecôtécarpourrie).
	if [ ! -z "$derniere" ]
	then
		if [ "$lv" != "$derniere" -a -z "$GUILI_INSTALLER_VIEILLE" ]
		then
			echo "# Attention, $lv ne sera pas utilisé par défaut, car il existe une $derniere plus récente. Si vous voulez forcer l'utilisation par défaut, faites un $SCRIPTS/utiliser $lv" >&2
			return 0
		fi
	fi
	[ ! -d "$dest" ] || sudoku $utiliser "$dest"
}
