#!/bin/sh

filtrer()
{
	f="$1" ; shift
	"$@" < "$f" > "$f.filtre" && cat "$f.filtre" > "$f" && rm "$f.filtre"
}

filtrer build.rs sed -e '/env::var("DEP_OPENSSL_VERSION")/i\
env::set_var("DEP_OPENSSL_VERSION", "'"`echo "$version_openssl" | tr -d '[a-z.]' | cut -c 1-3`"'");
'
