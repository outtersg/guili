# Copyright (c) 2013,2015-2017,2019 Guillaume Outters
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

# Depuis un dossier de compilation d'une extension PHP, à appeler après la compil pour activer l'extension dans le PHP.
# Utilisation: php_iext [-z] <radical> [<param activation>]
#   -z
#     À préciser s'il s'agit d'une Zend Extension
#   <radical>
#     Nom de la bibliothèque. Sera recherchée en <radical>* (ainsi apc trouvera apcu).
#   <param activation>
#     Si précisé, php_iext supprimera ces paramètres dans le php.ini pour restaurer le comportement par défaut (supposé être: l'extension est active).
php_iext()
{
	local biblio text= # text = Type EXT.
	[ "x$1" = x-z ] && text=zend_ && shift || true
	local radicalBiblio="$1"
	local menageParamActivation=
	[ -z "$2" ] || menageParamActivation="-e /$2/d"
	
	# Recherche du nom sous lequel l'extension a été compilée.
	
	biblio="`cd modules && find . -name "*$radicalBiblio*.so*" | tail -1`" # Entre les apc.so et les libapc.so.0.0, youpi.
	biblio="`basename "$biblio"`"
	
	# Lien symbolique.
	# Selon les versions de PHP, les extensions, et le fait d'être Zend Ext ou non, mentionner juste toto.so dans le php.ini va aller chercher soit dans lib/, soit dans lib/php/extension/machin-non-zts-xxx/. Mais le .so n'est pas forcément installé à l'endroit où ce nom simple irait chercher. Ex.:
	# - PHP 5.4 + Zend OpCache PECL: le make install place le zendopcache.so dans le dossier à rallonge, mais mettre un zend_extension = zendopcache.so plante. Il faut copier le .so directement sous lib/ pour qu'il soit vu (sinon utiliser le chemin absolu, moche)
	# - PHP 7.3 + Zend OpCache interne: installé dans le nom à rallonge, mais vu avec un zend_extension = zendopcache.so
	# - PHP 5.4 + Xdebug: installé sous lib/, et vu de cet emplacement.
	# On uniformise donc en créant un lien symbolique dans lib/ vers le nom à rallonge, pour que la biblio soit vue d'à peu près toutes les typologies.
	
	local lib="`php-config --prefix`/lib"
	local libation="`echo "$lib" | sed -e 's#[^-_.a-zA-Z0-9]#.#g'`" # Expression sed pour pouvoir retirer le préfixe et obtenir des liens un peu plus courts.
	[ -f "$lib/$biblio" -a ! -L "$lib/$biblio" ] || find "`php-config --extension-dir`" -name "$biblio" | sed -e "s#^$libation/*##" | while read f
	do
		sudo ln -s "$f" "$lib/$biblio"
	done
	
	# Ajout au php.ini.
	
	ini="`php -i | sed -e '/^Loaded Configura/!d' -e 's/.* => //'`"
	sufiltrer "$ini" sed -e "\$a\\
${text}extension = $biblio
" -e "/extension = .*$radicalBiblio.*\\.so/d" $menageParamActivation
}
