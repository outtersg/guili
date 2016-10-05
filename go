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

absolutiseScripts() { SCRIPTS="$1" ; echo "$SCRIPTS" | grep -q ^/ || SCRIPTS="`dirname "$2"`/$SCRIPTS" ; } ; absolutiseScripts "`command -v "$0"`" "`pwd`/." ; while [ -h "$SCRIPTS" ] ; do absolutiseScripts "`readlink "$SCRIPTS"`" "$SCRIPTS" ; done ; SCRIPTS="`dirname "$SCRIPTS"`"
. "$SCRIPTS/util.sh"

logiciel=go

# Historique des versions gérées

v 1.4.3 && modifs="enPrison incertitudes" || true
v 1.7.1 && prerequis="go < 1.5" || true

prerequis

# Modifications

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
		sed -e '/BEGIN .*PRIVATE/{
s/^.*\(-----BEGIN\)/\1/
h
}' -e '/END.*PRIVATE/s/\(END.*-----\).*$/\1/' -e '{
x
s/././
x
t
d
}' -e '/END.*PRIVATE/{
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
	retaperCertifsTest "$ip" src/net/http/httptest/server.go src/net/http/internal/testcert.go src/net/smtp/smtp_test.go
	
	# Les tests s'attendent à causer à un 127.0.0.1 codé en dur.
	for f in src/net/http/client_test.go src/net/http/serve_test.go src/net/http/transport_test.go src/net/http/httptest/server.go src/net/http/proxy_test.go
	do
		exfiltrer "$f" sed -e "s/127\.0\.0\.1/$ip/g"
	done
	
	exfiltrer src/net/ip.go sed -e 's# \([^ ]*\) == 127#(& || \1 == '"`echo $ip | cut -d . -f 1`"')#'
}

# Variables

archive="https://go.googlesource.com/go/+archive/go$version.tar.gz"
dest=$INSTALLS/$logiciel-$version

[ -d "$dest" ] && exit 0

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
bash all.bash

echo Installation… >&2
mkdir -p "$TMP/$$/build/libexec" "$TMP/$$/build/bin"
ln -s ../libexec/go/bin/go "$TMP/$$/build/bin/"
cp -R ../. "$TMP/$$/build/libexec/go"
chmod -R a+r "$TMP/$$/build/libexec/go"
chmod a+x "$TMP/$$/build/libexec/go/bin/go"
find "$TMP/$$/build/libexec/go" -type d -exec chmod a+x {} \;
sudo cp -R "$TMP/$$/build" "$dest"
sutiliser "$logiciel-$version"

rm -Rf "$TMP/$$"
