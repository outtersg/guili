# cmake embarque libuv, qui à partir d'une certaine version (1.24.1) requiert une glibc récente (avec un certain nombre d'appels).
# On doit donc détecter deux seuils:
# - à partir de quand cmake embarque une libuv récente (on pourra toujours se lier à une libuv à part, ancienne mouture)
# - à partir de quand cmake repose sur les fonctions de la libuv récente (alors on ne pourra même plus se lier à l'ancienne libuv externe)

eventfd()
{
	[ `uname` = Linux ] || return 0
	
	echo '#include <sys/eventfd.h>' > /tmp/1.c
	$CC -c -o /tmp/1.o /tmp/1.c 2> /dev/null || return 1
}

prerequisLibuv()
{
	[ `uname` = Linux ] && ! eventfd || return 0
	
	prerequis="$prerequis libuv"
	OPTIONS_CONF="$OPTIONS_CONF --system-libuv"
}
