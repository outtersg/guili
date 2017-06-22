#!/bin/sh

filtrer()
{
	f="$1" ; shift
	"$@" < "$f" > "$f.filtre" && cat "$f.filtre" > "$f" && rm "$f.filtre"
}

# Si sous Darwin on a compilé notre propre curl, avec son libcurl.pkg, le court-circuitage du build.rs ne détecte pas notre version.
if pkg-config libgit2 2> /dev/null
then
	filtrer build.rs sed -e 's/env::var("LIBGIT2_SYS_USE_PKG_CONFIG").is_ok()/true/'
fi
