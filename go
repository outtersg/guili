#!/bin/sh
# Copyright (c) 2006 Guillaume Outters
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

set -e

Delibere() { local s2 ; while [ -h "$s" ] ; do s2="`readlink "$s"`" ; case "$s2" in [^/]*) s2="`dirname "$s"`/$s2" ;; esac ; s="$s2" ; done ; } ; SCRIPTS() { local s="`command -v "$0"`" ; [ -x "$s" -o ! -x "$0" ] || s="$0" ; case "$s" in */bin/*sh) case "`basename "$s"`" in *.*) true ;; *sh) s="$1" ;; esac ;; esac ; case "$s" in [^/]*) local d="`dirname "$s"`" ; s="`cd "$d" ; pwd`/`basename "$s"`" ;; esac ; Delibere ; s="`dirname "$s"`" ; Delibere ; SCRIPTS="$s" ; } ; SCRIPTS
. "$SCRIPTS/util.sh"

# Historique des versions gérées

v 1.4.3 && modifs="enPrison incertitudes mmap64" && prerequis="openssl < 3" || true
v 1.4.3.10 || true
# Versions nécessaires: https://go.dev/doc/install/source#bootstrapFromSource
v 1.7.1 && prerequis="go >= 1.4 < @version \\ $prerequis" || true
v 1.19 && remplacerPrerequis "openssl" && modifs="$modifs certifFossile" || true

predestiner="$predestiner prerequisGo"

prerequis

# Modifications

prerequisGo()
{
	prerequis="`IFS=. ; versionGo $version`"
}

versionGo()
{
	local p pr="$prerequis"
	unset IFS
	for p in $prerequis
	do
		case "$p" in
			@version) p="$version" ;;
			@n2version) p=$1.$((2 * ($2 / 2 - 1))) ;;
		esac
		printf '%s ' "$p"
	done
}

mmap64()
{
	# Pour les AMD64, ils ont rajouté un bout de code pour que le mmap n'utilise pas l'option FIXED, bref, ils laissent le système décider de l'alignement de la zone mémoire;
	# … sauf que derrière ils plantent en gueulant que le pointeur renvoyé est différent de celui demandé.
	# Donc on fait sauter ce code débile, et on repasse par le code 32 bits qui exigeait du système la zone mémoire à l'endroit précis demandé (sachant qu'ils respectent déjà la contrainte de l'alignement sur 4K, c'est juste que FreeBSD 14, pour encore plus aligner, allait chercher l'alignement plus large sur 256 Mo).
	local f
	for f in src/runtime/mem_freebsd.c src/runtime/mem_bsd.go
	do
		[ -f "$f" ] || continue
		filtrer "$f" sed -e 's/!reserved/0 < 0/' # On retape juste la condition qui fait passer dans le code spécifique 64 bits. On voit même passer un commentaire "Ah ça alors, sur DragonflyBSD, étonnamment le code 64 bits plante, donc lui on lui fait une exception". Ben tiens…
	done
}

certifFossile()
{
	# Les certifs de test embarqués dans le source de 2014 sont un peu anciens, forcément.
	# https://gcc.gnu.org/bugzilla/show_bug.cgi?id=118286
	# Ou alors on pourrait s'amuser à les regénérer, en profitant de retaperCertifsTest(). Mais bon.
	# Bon finalement le plus simple est de reposer sur retaperCertifsTest(), via enPrison.
	true
}

exfiltrer()
{
	[ ! -e "$1" ] || filtrer "$@"
}

incertitudes()
{
	# Les tests reposent sur l'assertion que certains répertoires ne sont pas des liens symbolique. Manque de bol, chez moi, si.
	usrPasLien="/usr/`ls -l /usr/ | grep -ve '->' | sed -e '/^d/!d' -e 's/.* //' | head -1`"
	exfiltrer src/os/os_test.go sed -e "/dirs/s#/usr/bin#$usrPasLien#g"
}

retaperCertifsTest()
{
	ip="$1" ; shift
	
	for f in "$@"
	do
		[ -e "$f" ] && grep -qe -----BEGIN < "$f" || continue
		# À FAIRE: passer en awk, car dans certains fichiers on a plusieurs certifs et plusieurs clés, même 1 certif pour 2 clés, bref il faudra retenir les lignes pour caler les certifs devant les bonnes clés.
		sed -e 's#^// *##' -e 's/TESTING/PRIVATE/' -e '/BEGIN .*KEY-----/{
s/^.*\(-----BEGIN\)/\1/
h
}' -e '/END.*KEY-----/s/\(END.*-----\).*$/\1/' -e '{
x
s/././
x
t
d
}' -e '/END.*KEY-----/{
x
s/.*//
x
}' < "$f" > $TMP/$$/cle.pem
		cat > $TMP/$$/req.conf <<TERMINE
[req]
distinguished_name=req_dn
req_extensions=v3_req
[req_dn]
[v3_req]
keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign
extendedKeyUsage=serverAuth
basicConstraints=critical,CA:TRUE
subjectAltName=@SAN
[SAN]
DNS=example.com
IP.1=127.0.0.1
IP.2=0:0:0:0:0:0:0:1
IP.3=$ip
TERMINE
		openssl req -new -key $TMP/$$/cle.pem -out $TMP/$$/req.pem -config $TMP/$$/req.conf -subj "/O=Acme Co"
		openssl x509 -req -days 2048 -in $TMP/$$/req.pem -extensions subjectAltName -signkey $TMP/$$/cle.pem -out $TMP/$$/cert.pem -extensions v3_req -extfile $TMP/$$/req.conf
		exfiltrer "$f" awk '/-----BEGIN CERTIFICATE-----/{sub(/-----.*-----/,"");print;dedans=1}!dedans{print}/-----END CERTIFICATE-----/{sub(/-----.*-----/,"");nouveau="'"`tr '\012' '#' < $TMP/$$/cert.pem`"'";gsub(/#/,"\n",nouveau);print nouveau;print;dedans=0}'
	done
}

enPrison()
{
	# Sous FreeBSD en environnement jail, les tests de bon fonctionnement du réseau sont quelque peu perturbés.
	
	# lo0 ne possède pas d'adresse IP, il faut donc aller chercher lo1.
	exfiltrer src/net/interface_test.go sed -e '/if.*FlagLoopback/{
h
s/[^	].*/ifat, err := ifi.Addrs()/
p
x
s/if /if err == nil \&\& len(ifat) > 0 \&\& /
}'
	
	# Le repérage d'une adresse multicast foire.
	exfiltrer src/net/multicast_test.go sed -e '/func multicastRIBContains/a\
	return true, nil
'
	
	# Le certificat est autorisé pour 127.0.0.1, mais notre interface locale n'a pas cette IP.
	ip="`ifconfig | awk '/^lo/{split($0,ti,/:/);i=ti[1]}/inet /{if(i){print $2;exit}}'`"
	# Une optimisation possible eût été de ne rien retaper si l'IP ne change pas;
	# cependant nous tenons lieu aussi de certifFossile, et à ce titre avons à retaper les certifs même avec la bonne IP, pour une question d'expiration.
	#case "$ip" in 127.0.0.1) return 0 ;; esac
	
	# Version originale où je m'échinais à faire passer des tests à la con qui codent en dur toute la partie réseau + des certifs de test datés du siècle dernier ou presque.
	#retaperCertifsTest "$ip" `grep -rl 'BEGIN.*KEY-----' src | grep test`
	# Finalement c'est trop compliqué, on dézingue tout ce qui nous enquiquine, cf. la section "Dézinguage".
	
	# Les tests s'attendent à causer à un 127.0.0.1 codé en dur.
	for f in src/net/http/client_test.go src/net/http/serve_test.go src/net/http/transport_test.go src/net/http/httptest/server.go src/net/http/proxy_test.go
	do
		exfiltrer "$f" sed -e "s/127\.0\.0\.1/$ip/g"
	done
	
	case "$ip" in 127.*) true ;; *) # On ne retraite pas si l'IP commence déjà par 127, sinon go voit ça comme une erreur: redundant or: ip4[0] == 127 || ip4[0] == 127
	exfiltrer src/net/ip.go sed -e 's# \([^ ]*\) == 127#(& || \1 == '"`echo $ip | cut -d . -f 1`"')#'
	;; esac
	
	# Dézinguage.
	# Pour les tests qui nous enquiquinent encore malgré tous nos efforts.
	find . \
	\( \
		   -name handshake_client_test.go \
		-o -name dial_unix_test.go \
		-o -name tcpsock_unix_test.go \
	\) -exec rm {} \;
	for f in src/net/http/transport_test.go src/net/http/transport_test.go
	do
		filtrer "$f" awk \
		'
			dedans && /^}/ { dedans = 0; }
			dedans { sub(/^/, "//"); }
			1
			/func (TestDialLocal|TestDialWithNonZeroDeadline|TestTransportServerClosingUnexpectedly)/ { dedans = 1; print "return"; }
'
	done
}

# Variables

archive="https://go.dev/dl/go$version.src.tar.gz"
# Archives spéciales pour la branche 1.4, cf. https://go.dev/doc/install/source#bootstrapFromSource
case $version in
	1.4.3.10) archive=https://dl.google.com/go/go1.4-bootstrap-20171003.tar.gz ;;
esac

destiner

prerequis

obtenirEtAllerDansVersion

echo Correction… >&2
for modif in true $modifs ; do $modif ; done

echo Configuration… >&2
# La recommandation est "copiez tout dans le répertoire d'install et c'est bon". Sauf que "tout", c'est un bordel innommable, comprenant les src, des lib non préfixées go, etc. Du coup, il nous faut isoler la chose pour ne pas polluer notre dest. On pourrait choisir un toutdego, un bingo, mais rabattons-nous vers un plus classique libexec/go.
GOROOT_FINAL="$dest/libexec/go"
# Bon alors pour installer un nouveau Go à partir d'un ancien… Il faut qu'il puisse écraser l'ancien! Ce langage est vraiment une bouse d'un point de vue système. Alors pour éviter qu'il foute le boxon et nous laisse avec un ancien Go tout explosé, on lui demande d'aller se mettre ailleurs.
if command -v go > /dev/null 2>&1
then
	GOROOT_BOOTSTRAP="$TMP/$$/ancien"
	sudo cp -R "`go env GOROOT`" "$GOROOT_BOOTSTRAP"
	sudo chown -R "`id -u -n`:" "$GOROOT_BOOTSTRAP"
fi
export GOROOT_FINAL GOROOT_BOOTSTRAP

echo Compilation… >&2
cd src
# Boucle pour éviter de planter en cas de processus buté à un moment de contention mémoire.
# En réalité ça ne sert pas à grand-chose tant que l'on utilise le gros script bourrin qui (re)fait tout: à la différence d'un Makefile, la seconde passe regénère la totalité même si ça replante au même endroit, donc on va détecter du mouvement en faux positif.
while true
do
	touch $TMP/$$/h
	bash all.bash && break ||
	find .. -newer $TMP/$$/h -type f -not -size 0 |
	tee $TMP/$$/z | grep -q . && magenta "Plantage, mais on progresse (`wc -l < $TMP/$$/z` fichiers générés entre-temps). On retente." && tail -10 < $TMP/$$/z | sed -e 's/^/  /' ||
	{ jaune "# Nous vous plaçons dans un shell interactif. Tentez de rattraper le coup." >&2 && sh ; }
done

echo Installation… >&2
mkdir -p "$TMP/$$/build/libexec" "$TMP/$$/build/bin"
ln -s ../libexec/go/bin/go "$TMP/$$/build/bin/"
cp -R ../. "$TMP/$$/build/libexec/go"
chmod -R a+r "$TMP/$$/build/libexec/go"
chmod a+x "$TMP/$$/build/libexec/go/bin/go"
find "$TMP/$$/build/libexec/go" -type d -exec chmod a+x {} \;
sudo cp -R "$TMP/$$/build" "$dest"
sutiliser

# Remontée d'un niveau pour que le ménage s'applique à toute l'arbo, pas seulement au src.
case "`pwd`" in */tmp/*src) cd .. ;; esac
