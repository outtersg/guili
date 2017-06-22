#!/bin/sh

filtrer()
{
	f="$1" ; shift
	"$@" < "$f" > "$f.filtre" && cat "$f.filtre" > "$f" && rm "$f.filtre"
}

filtrer Cargo.toml sed -e 's/, path = "[^"]*"//g'
