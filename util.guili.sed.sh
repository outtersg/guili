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

# Sur de très vieilles machines, le sed GNU ne fait de la regex étendue que sur -r, au lieu du -E POSIX arrivé plus tard.
# Dans ce cas, on demande un sed 4.2.2, qui a l'avantage de gérer le -E mais aussi de compiler sur ces vieilles bécanes.
guiliHomologuerSed()
{
	case "$1" in
		sed|*/sed) return 0 ;;
	esac
	
	guili_sed="`unalias sed 2> /dev/null || true ; unset -f sed 2> /dev/null || true ; command -v sed`"
	case "`echo gloc | $guili_sed -E -e 's/g|c/p/g' 2> /dev/null`" in
		plop) true ;;
		*) "$SCRIPTS/sed" "< 4.3" ;;
	esac
}

guiliHomologuerSed "$0" "$@"
