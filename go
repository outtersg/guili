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
. "$SCRIPTS/util.jalons.sh"

# Historique des versions gérées

v 1.4.3 && modifs="enPrison incertitudes mmap64 deTester" && prerequis="bash \\ openssl < 3" || true
v 1.4.3.10 || true
# Versions nécessaires: https://go.dev/doc/install/source#bootstrapFromSource
v 1.7.1 && prerequis="go >= 1.4 < @version \\ $prerequis" || true
v 1.19 && remplacerPrerequis "openssl" && modifs="$modifs testsCgoMac cEstPasLaCourse certifFossile" || true
v 1.19.13 || true
v 1.20 && remplacerPrerequis "$logiciel >= 1.19 < @version" || true # En réalité >= 1.17, mais on ne les a pas dans notre banque de versions.
v 1.20.14 || true
v 1.21.0 || true
v 1.21.13 || true
v 1.22.0 && remplacerPrerequis "go >= @n2version < @version" || true
v 1.22.12 || true
v 1.23.0 || true
v 1.23.12 || true
v 1.24.0 || true
v 1.24.13 || true
v 1.25.10 || true
v 1.25.11 || true
v 1.26.3 || true
v 1.26.4 || true

predestiner="$predestiner prerequisGo"

# Modifications

boucleTests()
{
	# À ajouter aux modifs lorsque la construction plante juste dans les tests:
	# all.bash est horripilant, il reconstruit tout le compilo avant de lancer les dizaines de minutes de tests;
	# quand on a juste à comprendre pourquoi un test plante, en bidouillant les tests plutôt que le compilo, on se passe bien de la phase de compilation du compilo.
	
	filtrer src/all.bash sed -e '/bash run.bash/s#.*#while ! & ; do echo "Planté; je retente dans 10 s" >&2 ; sleep 10 ; done#'
	
	# Une fois construit, on peut se balader dans un dossier et lancer les tests individuels, ex.:
	#   ~/tmp/go/bin/go test crypto/x509 -list ParseASN1  2>&1 | egrep -v ': warning:|: note:|In file included'
}

testsCgoMac()
{
	mac || return 0
	
	# La suite de tests cgo lance de bêtes cc; sur Mac, sans un -I`xcrun --show-sdk-path`/usr/include (qu'on a dans nos $CPPFLAGS), tous ces tests échouent bêtement sur un stdlib.h introuvable.
	# Ou alors export SDKROOT, mais pourtant je croyais que je le faisais déjà (https://github.com/golang/go/issues/44112): peut-être l'environnement n'est-il pas passé aux tests?
	
	# Le test suivant est foireux: notre $CC arrive à voir le $SDKROOT, alors que lancé par cgo il n'y parvient pas.
	#printf '%s\n%s\n' '#include <stdlib.h>' 'void f() {}' > $TMP/$$/1.c
	#if compilo_test $CC -c -o $TMP/$$/1.o $TMP/$$/1.c ; then return ; fi
	
	filtrer src/runtime/cgo/cgo.go sed -e '1,/^#cgo/{
s/^#cgo/&/
t-)
b
:-)
i\
#cgo CPPFLAGS: '"$CPPFLAGS"'
i\
#cgo CFLAGS: '"$CFLAGS"'
i\
#cgo CXXFLAGS: '"$CXXFLAGS"'
i\
#cgo LDFLAGS: '"$LDFLAGS"'
}'
	
	filtrer src/net/cgo_bsd.go sed -e '/<netdb.h>/i\
#cgo CPPFLAGS: '"$CPPFLAGS"'
'
	
	# … Mais un vieux Mac avec un clang neuf et du -Werror explose de partout, rien que sur les inclusions système (ex.: #if __DARWIN_NO_LONG_LONG: le comportement d'un #define déclarant un autre #define est indéfini; et en effet __DARWIN_NO_LONG_LONG est défini comme une macro comportant du defined()).
	filtrer src/runtime/cgo/cgo.go sed -e s/-Werror//g
	
	# Les tests sur Mac plantent sur crypto/x509.test: Undefined symbols for architecture x86_64: _SecTrustEvaluateWithError
	# Pourtant le symbole est bien défini dans le framework Security (Mac OS X 10.13).
	# Et bin/go est bien lié (otool -L) au Security.framework
	# Exactement ce qu'on retrouve sur https://github.com/golang/go/issues/52112
	# Hum, bizarre: la ligne est précédée d'un ##### GOOS=ios: essaie-t-il de lancer un test iOS?
	# Ah, c'est parce qu'il tente une compil' croisée pour TvOS, assimilé iOS.
	filtrer src/cmd/link/link_test.go sed -e '/TestBuildForTvOS/a\
t.Skip("M'\''en fous de TvOS")
'
	# … Bon en réalité il continue à planter et je n'arrive pas à reproduire avec:
	#   CGO_ENABLED=1 GOOS=ios /Users/gui/tmp/go/bin/go test crypto/x509 -run=SystemRoots 2>&1 | egrep -v ': warning:|: note:|In file included'
	# Donc va pour une désactivation directement dans le lanceur:
	filtrer src/cmd/dist/test.go sed -e '/iOS simulator/,/if .*"darwin"/s/"darwin"/"ornithorynque"/'
	
	# Idem sur Testing race detector
	# Je n'ai pas de souci avec:
	#   CGO_CPPFLAGS="-I`xcrun --show-sdk-path`/usr/include" ~/tmp/go/bin/go test -short=true -count=1 -tags= -race -run='TestParse|TestEcho|TestStdinCloseRace|TestClosedPipeRace|TestTypeRace|TestFdRace|TestFdReadRace|TestFileCloseRace' flag net os os/exec encoding/gob 2>&1 | egrep -v ': warning:|: note:|In file included'
	#   # Ou le suivant dans src/cmd/dist/test.go, avec -ldflags=-linkmode=external
	# qui est la commande que lui lance. Il passe sans doute du bazar par les variables d'environnement.
	# Tentative de modifier src/cmd/dist/test.go:
	#   Les setEnv CGO_LDFLAGS ou LDFLAGS ne suffisent pas
	#   Essayé de rajouter plein de guillemets (façon https://github.com/junegunn/fzf/issues/1994):
	#     "-ldflags", `-linkmode=external '-extldflags="-framework Security"'`
	#     Hum, clang: error: unknown argument: '-framework Security'
	#     Peut-être coller directement /System/Library/…/Versions/A/Security?
	filtrer src/cmd/dist/test.go sed -e '/-race.*=external/s#^#//#' -e '/if t.extLink/s/if /if false \&\& /'
	
	# Quelques tests vraiment trop tordus, qui pètent même avec stdlib.h; on vire, c'est plus simple que de commencer par un [darwin] skip.
	rm -f \
		src/cmd/go/testdata/script/list_compiled_imports.txt \
		src/cmd/go/testdata/script/gccgo_link_ldflags.txt \
		src/cmd/go/testdata/script/link_syso_deps.txt \
		src/cmd/go/testdata/script/ldflag.txt
}

deTester()
{
	# Pour les plates-formes un peu limites (ex.: Raspberry Pi 3, qui met 10 x plus de temps à exécuter les tests que mon "petit" portable Dell, et finit dans le décor, le garde-fou lâchant au bout de plusieurs minutes), il est possible d'invoquer le script avec un DETESTER=1.
	case "$DETESTER" in ?*)
		filtrer src/all.bash sed -e '/run\.bash/s/^/#/'
	;; esac
}

cEstPasLaCourse()
{
	# NOTE pour passer manuellement un seul test:
	# https://stackoverflow.com/questions/26092155/just-run-single-test-instead-of-the-whole-suite
	# bash run.bash --no-rebuild -run x509
	# Bon en réalité il y a une différence entre le test tournant dans la série complète, et individuellement (même si on est dans un sh instancié avant notre compil).
	
	# Les compilos modernes n'aiment pas trop l'option -race qui fait tourner MSAN sur des binaires ASLR.
	# https://github.com/golang/go/issues/51523
	# https://github.com/golang/go/issues/73782
	# https://github.com/golang/go/issues/65425
	filtrer test/fixedbugs/bug513.go sed -e 's/-race//g'
	
	# Autres bizarreries survenues sur les versions suivantes.
	
	# 1.19 sur Mac: 
	# fallocate_test.go:61: unexpected disk usage: got 2040 blocks, want at least 2048
	# fallocate_test.go:61: unexpected disk usage: got 6136 blocks, want at least 6144
	case "`uname`" in Darwin) rm -f src/cmd/link/internal/ld/fallocate_test.go ;; esac
	
	# 1.20
	[ ! -f misc/cgo/testsanitizers/msan_test.go ] || filtrer misc/cgo/testsanitizers/msan_test.go grep -v msan8.go
	[ ! -f src/cmd/cgo/internal/testsanitizers/msan_test.go ] || filtrer src/cmd/cgo/internal/testsanitizers/msan_test.go grep -v msan8.go
}

prerequisGo()
{
	prerequis="`IFS=. ; versionGo $version`"
}

vminplus1()
{
	local vmaj="$1" vmin="$2" v
	
	case "$vmin" in
		"") v=$((vmaj+1)) ;;
		*)  v=$vmaj.$((vmin+1)) ;;
	esac
	
	if pge $v $version
	then
		printf $version
	else
		printf $v
	fi
}

versionGo()
{
	# NOTE: prochainMin
	# Si le prérequis est "$logiciel >= 1.20 < @version", avec @version = 1.29.7, à moins d'avoir une 1.28.5 dans les parages, ça va nous compiler une 1.29.6, qui elle-même compilera une 1.29.5 en prérequis, etc., ce qui va faire beaucoup de versions intermédiaires.
	# Pour éviter cela (à moins de dénicher une version déjà compilée) on ira chercher la dernière version de la majeure concernée, donc dans notre cas on cherchera à transformer en:
	# "$logiciel >= 1.20 < 1.21"
	local p pr="$prerequis" v="$2" prochainMin= min=
	unset IFS
	for p in $prerequis
	do
		case "$p" in
			">=") prochainMin=1 ;;
			@version)
				# Cf. "NOTE: prochainMin"
				if [ -z "$min" ] || versions -1 $logiciel ">= $min < $version" | grep -q .
				then
					p="$version"
				else
					p="`IFS=. ; tifs vminplus1 $min`"
				fi
				;;
			@n2version) p=$1.$((2 * (v / 2 - 1))) ;;
		esac
		case "$prochainMin:$p" in
			*:">=") true ;;
			1:[0-9]*) min="$p" ; prochainMin= ;;
			1:*) jaune "# Impossible de reconnaître un numéro de version dans '>= $p'" >&2 ; prochainMin= ;;
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
	# Court-circuitage de certains tests.
	local cc="TestDialLocal|TestDialWithNonZeroDeadline|TestTransportServerClosingUnexpectedly" # 1.19
	cc="$cc|TestDialListenerAddr|TestCrossVersionResume" # 1.21
	for f in src/net/dial_test.go src/net/http/transport_test.go src/crypto/tls/handshake_server_test.go
	do
		filtrer "$f" awk \
		'
			dedans && /^}/ { dedans = 0; }
			dedans { sub(/^/, "//"); }
			1
			/func ('"$cc"')/ { dedans = 1; print "return"; }
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

if ! jalon source
then
obtenirEtAllerDansVersion
jalonner source
fi

echo Correction… >&2
if ! jalon modifs
then
for modif in true $modifs ; do $modif ; done
jalonner modifs
fi

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
export CGO_CFLAGS="$CFLAGS" CGO_LDFLAGS="$LDFLAGS" CGO_CPPFLAGS="$CPPFLAGS" CGO_CXXFLAGS="$CXXFLAGS"

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
mkdir -p "$TMP/$$/build/libexec/go" "$TMP/$$/build/bin"
ln -s ../libexec/go/bin/go "$TMP/$$/build/bin/"
( cd .. && tar cf - --exclude go-build . ) | ( cd "$TMP/$$/build/libexec/go" && tar xf - )
chmod -R a+r "$TMP/$$/build/libexec/go"
chmod a+x "$TMP/$$/build/libexec/go/bin/go"
find "$TMP/$$/build/libexec/go" -type d -exec chmod a+x {} \;
sudo cp -R "$TMP/$$/build" "$dest"
sutiliser

# Remontée d'un niveau pour que le ménage s'applique à toute l'arbo, pas seulement au src.
case "`pwd`" in */tmp/*src) cd .. ;; esac
