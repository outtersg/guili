#!/bin/bash
# Copyright (c) 2004-2005 Guillaume Outters
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

SCRIPTS="`command -v "$0"`" ; SCRIPTS="`dirname "$SCRIPTS"`" ; echo "$SCRIPTS" | grep -q "^/" || SCRIPTS=`pwd`/"$SCRIPTS"
. "$SCRIPTS/util.bash"

inclure libjpeg
inclure libpng
inclure readline
inclure icu # Pour la 5.1
inclure libxml
inclure curl
inclure mysql

logiciel=php

OPTIONS_CONF=()

# Historique des versions gérées

version=5.0.3
version=5.0.4
# PHP 5.0.3 ne gère pas l'iconv de Panther; il détecte bien l'appel libiconv,
# mais, n'incluant pas iconv.h, il ne voit pas qu'iconv et libiconv sont les
# mêmes. La version 5.1 corrige ça. Pour compiler la 5.0.x, on peut contourner
# en ajoutant un #define HAVE_ICONV 1 dans ext/iconv/php_have_libiconv.h.
version=2005-04-16
version=2005-08-22
# La 2005-08-22 crashe avec Apache 2.0.54, dèl'appel.
version=2005-08-29
# La 2005-08-29 explose sur la recréation du cache de l'album (httpd-2.1.7).
version=2005-09-20
version=2005-09-23
ajouterModif php34617
version=5.1.4
retirerModif php34617
# Apache 2.2.3
version=5.2.0
version=5.2.1
ajouterModif pourTrouverApache
version=5.2.3
# Crétin de 5.2.3, son test pour gd lance une commande ld -L(rien du tout) et échoue.
version=2007-07-29

version=5.2.5

version=5.2.8

# Chier, tombé en plein sur http://bugs.php.net/bug.php?id=48276 (les cookies étaient générés expirant en l'an 0, et Drupal voyait toutes ses dates en 0 lors des filtrages et affichages.
#version=5.2.10

version=5.2.11

version=5.2.13
ajouterModif libpng14
ajouterModif detectionIconvOuLibiconv
ajouterModif mesBibliosDAbord

version=5.2.15

if [ "$1" = 4 ]
then

version=4.4.7

fi

# Modifs

php34617()
{
	patch -p0 << TERMINE
diff -ru Zend/zend.c Zend/zend.c
--- Zend/zend.c	2005-09-23 17:50:39.000000000 +0200
+++ Zend/zend.c	2005-09-23 17:50:10.000000000 +0200
@@ -1602,6 +1602,7 @@
 	zend_destroy_rsrc_list(&EG(regular_list) TSRMLS_CC);
 
 	zend_try {
+		zend_objects_store_destroy(&EG(objects_store));
 		zend_ini_deactivate(TSRMLS_C);
 	} zend_end_try();
 }
diff -ru Zend/zend_execute_API.c Zend/zend_execute_API.c
--- Zend/zend_execute_API.c	2005-09-23 17:48:45.000000000 +0200
+++ Zend/zend_execute_API.c	2005-09-23 17:49:57.000000000 +0200
@@ -297,7 +297,7 @@
 		zend_stack_destroy(&EG(user_error_handlers_error_reporting));
 		zend_ptr_stack_destroy(&EG(user_error_handlers));
 		zend_ptr_stack_destroy(&EG(user_exception_handlers));
-		zend_objects_store_destroy(&EG(objects_store));
+		//zend_objects_store_destroy(&EG(objects_store));
 		if (EG(in_autoload)) {
 			zend_hash_destroy(EG(in_autoload));
 			FREE_HASHTABLE(EG(in_autoload));
TERMINE
}

pourTrouverApache()
{
	export PATH=/usr/local/sbin:/usr/local/bin:$PATH
}

libpng14()
{
	# Voir http://bugs.php.net/bug.php?id=50734
	pge "`libpng-config --version`" 1.4 && patch -p0 <<TERMINE
--- ext/gd/libgd/gd_png.c.bad     2010-01-12 16:16:18.000000000 -0600
+++ ext/gd/libgd/gd_png.c 2010-01-12 16:16:55.000000000 -0600
@@ -145,7 +145,7 @@
		return NULL;
	}
 
-	if (!png_check_sig (sig, 8)) { /* bad signature */
+	if (png_sig_cmp (sig, 0, 8)) { /* bad signature */
		return NULL;
	}
	
TERMINE
}

detectionIconvOuLibiconv()
{
	for i in libiconv iconv
	do
		echo "char $i();int main(int argc, char ** argv) { $i(); return 0; }" > "$TMP/$$/testiconv.c"
		cc -o "$TMP/$$/testiconv" "$TMP/$$/testiconv.c" -liconv 2> /dev/null && filtrer ext/iconv/iconv.c sed -e "s/define iconv .*/define iconv $i/" && break
	done
}

# apxs d'Apache 2.2.3 tel qu'installé sur une de mes bécanes me fournit un
# chemin incomplet (juste /usr/lib; apparemment ça lui a suffi pour compiler).
# On force donc notre $INSTALLS/lib à passer devant.
mesBibliosDAbord()
{
	filtrer configure sed -e "s#MH_BUNDLE_FLAGS=\"#MH_BUNDLE_FLAGS=\"-L$INSTALLS/lib #"
}

# Variables

dest=/usr/local/$logiciel-$version

[ -d "$dest" ] && exit 0

if [[ "$version" = *-* ]] ; then
	obtenirEtAllerDansCvs -d "$version" cvs://cvsread:phpfi@cvs.php.net:/repository:php-src
	./buildconf
else
	obtenirEtAllerDans "http://fr.php.net/get/$logiciel-$version.tar.bz2/from/this/mirror" "$logiciel-$version.tar.bz2"
fi

echo Correction… >&2
for modif in true $modifs ; do $modif ; done

echo Configuration… >&2
versionApache=
`apxs -q SBINDIR`/`apxs -q TARGET` -v | grep version | grep -q 'Apache/2' && versionApache=2
psql --version 2> /dev/null | grep -q PostgreSQL && OPTIONS_CONF=("${OPTIONS_CONF[@]}" --with-pgsql)
./configure --prefix="$dest" --with-apxs$versionApache --with-iconv --with-zlib-dir=/usr/local --enable-exif --with-gd --with-jpeg-dir=/usr/local --with-png-dir=/usr/local --with-ncurses --with-readline --with-curl --enable-sqlite-utf8 --enable-shared --with-mysql --enable-mbstring --disable-mbregex --enable-sysvsem --enable-sysvshm "${OPTIONS_CONF[@]}"

echo Compilation… >&2
make

echo Installation… >&2
sudo make install
sudo sh -c "cat > '$dest/lib/php.ini'" <<TERMINE
upload_max_filesize = 256M;
post_max_size = 256M
mbstring.internal_encoding = UTF-8;

error_reporting = -1
log_errors = On
display_errors = Off
date.timezone = Europe/Paris
magic_quotes_gpc = 0
TERMINE
sutiliser "$logiciel-$version"

echo Configuration d\'Apache… >&2
varap()
{
	"`apxs -q SBINDIR`/`apxs -q TARGET`" -V | sed -e "/$1/"'!d' -e 's/^[^"]*"//' -e 's/"[^"]*$//'
}
conf="`varap SERVER_CONFIG_FILE`"
[[ $conf = /* ]] || conf="`varap HTTPD_ROOT`/$conf"
sed -e '/^#LoadModule.*php5/s/#//' -e '/^LoadModule.*php4/s/^/#/' < "$conf" > /tmp/mod.$$.temp # L'install de PHP a dû rajouter, mais en commenté, le chargement de la biblio.
if grep -q 'application/x-httpd-php' "$conf"
then
	cat /tmp/mod.$$.temp
else
	sed -e '/Section 3/,$d' < /tmp/mod.$$.temp > /tmp/ext.$$.temp
	cat >> /tmp/ext.$$.temp << TERMINE
<IfModule mod_php5.c>
	AddType application/x-httpd-php .php
	AddType application/x-httpd-php-source .phps
	<IfModule mod_dir.c>
		DirectoryIndex index.html index.php
	</IfModule>
</IfModule>
TERMINE
	sed -e '/Section 3/,$!d' < /tmp/mod.$$.temp >> /tmp/ext.$$.temp
	cat /tmp/ext.$$.temp
	rm /tmp/ext.$$.temp
fi | sudo tee "$conf" > /dev/null
[ "$1" = 4 ] && cat "$conf" | sed -e '/^#LoadModule.*php4/s/#//' -e '/^LoadModule.*php5/s/^/#/' -e 's/^Listen 80$/Listen 8080/' | sudo tee "${conf%.conf}.php4.conf" > /dev/null
rm /tmp/mod.$$.temp
