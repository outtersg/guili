#!/bin/sh

TOP="$1"

zVersion="`cat "$TOP/VERSION"`"
nVersion="`echo "$zVersion" | tr '.' ' ' | cut -d ' ' -f 1-3`"
nVersion="`printf "%d%03d%03d" $nVersion`"

zUuid="`cat "$TOP/manifest.uuid"`"

zDate="`grep ^D < "$TOP/manifest" | head -1 | cut -d ' ' -f 2 | tr T ' '`"

sed -E \
	-e "s/--VERS--/$zVersion/" \
	-e "s/--VERSION-NUMBER--/$nVersion/" \
	-e "s/--SOURCE-ID--/$zDate $zUuid/" \
	-e '/define SQLITE_EXTERN extern/{
a\

a\
#ifndef SQLITE_API
a\
# define SQLITE_API
a\
#endif
a\

}' \
	-e '/^[a-zA-Z][a-zA-Z_0-9 *]+sqlite3_[_a-zA-Z0-9]+(\[|;| =)/s/^/SQLITE_API /' \
	-e '/^ *[a-zA-Z][a-zA-Z_0-9 ]+ \**sqlite3_[_a-zA-Z0-9]+\(/s/^/SQLITE_API /' \
	< "$TOP/src/sqlite.h.in"
