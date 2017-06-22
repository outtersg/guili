#!/bin/sh

filtrer()
{
	f="$1" ; shift
	"$@" < "$f" > "$f.filtre" && cat "$f.filtre" > "$f" && rm "$f.filtre"
}

filtrer Cargo.toml awk '/^ *\[/{dedans=0}/\[dependencies\]/{dedans=1;next}/cfg.*windows/{dedans=-1}/cfg.*unix/{dedans=1;next}{if(!dedans)print;else if(dedans > 0)deps=deps"\n"$0}END{if(deps){print "[dependencies]\n"deps}}'
