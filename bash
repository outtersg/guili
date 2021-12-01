#!/bin/sh
# Copyright (c) 2004 Guillaume Outters
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

DelieS() { local s2 ; while [ -h "$s" ] ; do s2="`readlink "$s"`" ; case "$s2" in [^/]*) s2="`dirname "$s"`/$s2" ;; esac ; s="$s2" ; done ; } ; SCRIPTS() { local s="`command -v "$0"`" ; [ -x "$s" -o ! -x "$0" ] || s="$0" ; case "$s" in */bin/*sh) case "`basename "$s"`" in *.*) true ;; *sh) s="$1" ;; esac ;; esac ; case "$s" in [^/]*) s="`pwd`/$s" ;; esac ; DelieS ; s="`dirname "$s"`" ; DelieS ; SCRIPTS="$s" ; } ; SCRIPTS
. "$SCRIPTS/util.sh"

v 3.2.9 && modifs=completionUTF8MAC || true
v 3.2.49 || true
v 4.0.24 || true
v 4.1.0 && modifs=completionUTF8MACreadline60 || true
v 4.1.2 && modifs=
v 4.1.7 || true
v 4.2.45 || true
v 4.3.25 || true
v 4.3.42 || true
v 4.4.23 || true
v 5.0.11 || true
v 5.1.8 || true
v 5.1.12 || true

rustine="`echo "$version" | sed -e 's/^.*\.//'`"
v_maj="`echo "$version" | sed -e 's/\.[^.]*$//'`"

archive="http://ftp.gnu.org/gnu/$logiciel/$logiciel-$v_maj.tar.gz"

completionUTF8MAC()
{
	filtrer Makefile.in sed -e '/LIBRARIES =/s/=/= @LIBICONV@/'
	patch -p0 <<TERMINE
--- lib/readline/complete.c	2006-07-28 17:35:49.000000000 +0200
+++ lib/readline/complete.c	2009-05-24 18:05:52.000000000 +0200
@@ -52,6 +52,14 @@
 #include <pwd.h>
 #endif
 
+/* iconv, for filesystem path conversion. */
+#if defined (MACOSX)
+# define HAVE_ICONV 1
+#endif
+#if HAVE_ICONV && defined (MACOSX)
+# include <iconv.h>
+#endif
+
 #include "posixdir.h"
 #include "posixstat.h"
 
@@ -1898,6 +1906,16 @@
   static char *dirname = (char *)NULL;
   static char *users_dirname = (char *)NULL;
   static int filename_len;
+  char *temp_filename;
+  size_t temp_filename_len;
+  #if HAVE_ICONV && defined (MACOSX)
+  static iconv_t conv_iconv = (iconv_t)NULL;
+  static char *conv_filename = (char *)NULL;
+  static int conv_filename_len = 0;
+  char *temp_filename_ptr;
+  const char *orig_filename_ptr;
+  size_t orig_filename_len;
+  #endif
   char *temp;
   int dirlen;
   struct dirent *entry;
@@ -2003,6 +2021,8 @@
   entry = (struct dirent *)NULL;
   while (directory && (entry = readdir (directory)))
     {
+	  temp_filename = entry->d_name;
+	  temp_filename_len = D_NAMLEN(entry);
       /* Special case for no filename.  If the user has disabled the
          \`match-hidden-files' variable, skip filenames beginning with \`.'.
 	 All other entries except "." and ".." match. */
@@ -2029,9 +2049,31 @@
 	    }
 	  else
 	    {
-	      if ((entry->d_name[0] == filename[0]) &&
-		  (((int)D_NAMLEN (entry)) >= filename_len) &&
-		  (strncmp (filename, entry->d_name, filename_len) == 0))
+	      #if HAVE_ICONV && defined (MACOSX)
+	      if (conv_filename_len < (orig_filename_len = D_NAMLEN(entry))) /* Rough approximation of what space we will need for our conversion result. */ /* @todo Is it sufficient in any case? */
+	        {
+	          conv_filename = conv_filename ? realloc(conv_filename, orig_filename_len + 1) : malloc(orig_filename_len + 1);
+	          if (!conv_iconv)
+	            conv_iconv = iconv_open("UTF-8", "UTF-8-MAC");
+	          conv_filename_len = conv_filename ? orig_filename_len : 0;
+	        }
+	      temp_filename_len = orig_filename_len; /* So, rough approximation of what space we have reserved. */
+	      if (conv_iconv)
+	        {
+              orig_filename_ptr = entry->d_name;
+              orig_filename_len = temp_filename_len;
+	          temp_filename_ptr = conv_filename;
+	          if (iconv(conv_iconv, &orig_filename_ptr, &orig_filename_len, &temp_filename_ptr, &temp_filename_len) >= 0)
+	            {
+	              *temp_filename_ptr = (char)0;
+	              temp_filename = conv_filename;
+	              temp_filename_len = temp_filename_ptr - conv_filename;
+	            }
+	        }
+	      #endif
+	      if ((temp_filename[0] == filename[0]) &&
+		  (temp_filename_len >= filename_len) &&
+		  (strncmp (filename, temp_filename, filename_len) == 0))
 		break;
 	    }
 	}
@@ -2070,7 +2112,7 @@
 	  if (rl_complete_with_tilde_expansion && *users_dirname == '~')
 	    {
 	      dirlen = strlen (dirname);
-	      temp = (char *)xmalloc (2 + dirlen + D_NAMLEN (entry));
+	      temp = (char *)xmalloc (2 + dirlen + temp_filename_len);
 	      strcpy (temp, dirname);
 	      /* Canonicalization cuts off any final slash present.  We
 		 may need to add it back. */
@@ -2083,17 +2125,17 @@
 	  else
 	    {
 	      dirlen = strlen (users_dirname);
-	      temp = (char *)xmalloc (2 + dirlen + D_NAMLEN (entry));
+	      temp = (char *)xmalloc (2 + dirlen + temp_filename_len);
 	      strcpy (temp, users_dirname);
 	      /* Make sure that temp has a trailing slash here. */
 	      if (users_dirname[dirlen - 1] != '/')
 		temp[dirlen++] = '/';
 	    }
 
-	  strcpy (temp + dirlen, entry->d_name);
+	  strcpy (temp + dirlen, temp_filename);
 	}
       else
-	temp = savestring (entry->d_name);
+	temp = savestring (temp_filename);
 
       return (temp);
     }
TERMINE
}

completionUTF8MACreadline60()
{
	patch -p0 <<TERMINE
--- lib/readline/complete.c	2010-01-06 00:05:23.000000000 +0100
+++ lib/readline/complete.c	2010-01-06 00:05:31.000000000 +0100
@@ -2219,7 +2219,7 @@
 		temp[dirlen++] = '/';
 	    }
 
-	  strcpy (temp + dirlen, entry->d_name);
+	  strcpy (temp + dirlen, convfn);
 	}
       else
 	temp = savestring (convfn);
TERMINE
}

destiner

prerequis

echo Obtention et décompression… >&2
obtenirEtAllerDansVersion
n=1
while [ $n -le $rustine ]
do
	v2="`echo $v_maj | tr -d .`"
	arf="`dirname "$archive"`/$logiciel-$v_maj-patches/$logiciel$v2-`printf "%03.3d" $n`"
	patch -p0 < "`obtenir "$arf"`"
	n=`expr $n + 1`
done

echo Correction… >&2
for i in true $modifs
do
	"$i"
done

echo Configuration… >&2
./configure --prefix=$dest

echo Compilation… >&2
make

echo Installation… >&2
sudo make install

sutiliser
