#!/bin/sh

filtrer()
{
	f="$1" ; shift
	"$@" < "$f" > "$f.filtre" && cat "$f.filtre" > "$f" && rm "$f.filtre"
}

filtrer Cargo.toml awk '/^ *\[/{dedans=0}/cfg.*windows/{dedans=1}!dedans{print}'
