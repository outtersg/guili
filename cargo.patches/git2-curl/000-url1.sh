#!/bin/sh

filtrer()
{
	f="$1" ; shift
	"$@" < "$f" > "$f.filtre" && cat "$f.filtre" > "$f" && rm "$f.filtre"
}

# pseudocargo semble ne pas interpréter "1.0" comme cargo (qui d'après les spécs devrait le voir comme un "^1.0", donc ">= 1.0 < 2". On force donc la chose pour que ce module utilise la même version d'url que le module principal (cargo).
filtrer Cargo.toml sed -e '/^ *url =/s/"1.0"/">= 1.0, < 2"/g'
