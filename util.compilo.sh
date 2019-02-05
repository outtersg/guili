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

versionCompiloChemin()
{
	case "$1" in
		clang) clang --version | sed -e '1!d' -e 's/.* clang version //' -e 's/ .*//' ;;
		gcc) gcc --version | sed -e '1!d' -e 's/^gcc (GCC) //' -e 's/ .*//' ;;
	esac
}

compiloSysVersion()
{
	local systeme
	local bienVoulu
	local bienTente
	local bienVoulus
	local versionVoulue
	
	# Quels compilos nos paramètres connaissent-ils?
	bienVoulus="`
		for bienTente in "$@"
		do
			echo "$bienTente"
		done | sed -e 's/[ >=].*//' -e 's/^/^/' -e 's/$/$/' | tr '\012' '|' | sed -e 's/|$//'
	`"
	
	# Parmi ceux-ci, quel est celui qui arrive en première position des connus de notre OS?
	systeme="`uname`"
	bienVoulu="`
		case "$systeme" in
			Linux) echo gcc ;;
			*) echo clang ;;
		esac | egrep "$bienVoulus" | head -1
	`"
	
	versionVoulue="`
		for bienTente in "$@"
		do
			case "$bienTente" in
				$bienVoulu" "*|$bienVoulu) echo "$bienTente" | ( read trucVoulu versionVoulue ; echo "$versionVoulue" ) ; break ;;
			esac
		done
	`"
	
	# Concentrons-nous sur celui-ci. La version actuellement dans notre $PATH répond-elle au besoin?
	if commande "$bienVoulu"
	then
		if testerVersion "`versionCompiloChemin "$bienVoulu"`" $versionVoulue
		then
			return 0
		fi
	fi
	
	prerequerir "$bienVoulu" "$versionVoulue"
}
