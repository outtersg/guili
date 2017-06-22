#!/bin/sh

filtrer()
{
	f="$1" ; shift
	"$@" < "$f" > "$f.filtre" && cat "$f.filtre" > "$f" && rm "$f.filtre"
}

# Si sous Darwin on a compilé notre propre curl, avec son libcurl.pkg, le court-circuitage du build.rs ne détecte pas notre version.
if pkg-config libcurl 2> /dev/null
then
	filtrer build.rs sed -e '/-l curl/s#^#//#'
fi
