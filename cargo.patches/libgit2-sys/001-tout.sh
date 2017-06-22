#!/bin/sh

filtrer()
{
	f="$1" ; shift
	"$@" < "$f" > "$f.filtre" && cat "$f.filtre" > "$f" && rm "$f.filtre"
}

filtrer Cargo.toml sed -e 's#, optional = true##'

filtrer Cargo.toml grep -v '^default *='
filtrer Cargo.toml sed -e '/\[features/a\
default = [ "ssh", "https", "curl" ]
'
