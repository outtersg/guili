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

# Troue l'éventuel pare-feu.
feu()
{
	if [ -f /etc/firewalld/zones/public.xml ]
	then
		feuFirewalld "$@"
	fi
}

feuFirewalld()
{
	for feu_port in "$@"
	do
		# On essaie de trouver un service qui ouvre ce port. Si plusieurs services disponibles, on prend le plus petit (celui qui ouvre juste le port en question plutôt que le fourre-tout).
		feu_service="`grep -rl "port=\"$feu_port\"" /usr/lib/firewalld/services | while read l ; do du -b "$l" ; done | sort -n | head -1 | while read f ; do basename "$f" .xml ; done`"
		feu_err=0
		if [ -z "$feu_service" ]
		then
			firewall-cmd -q --zone=public --permanent --add-port=$feu_port/tcp || feu_err=$?
		else
			firewall-cmd -q --zone=public --permanent --add-service=$feu_service || feu_err=$?
		fi
		case "$feu_err" in
			0) true ;;
			252) return 0 ;; # Pas démarré, donc pas de pare-feu, donc on passe.
			*) return $feu_err ;;
		esac
		# À FAIRE?: si feu_err, modifier manuellement les fichiers de conf pour que les règles soient quand même persistées.
		true || filtrer /etc/firewalld/zones/public.xml sed -e "/<service name=\"$feu_service\"/d" -e "/<\/zone>/i\
  <service name=\"$feu_service\"/>
"
	done
	systemctl restart firewalld
}
