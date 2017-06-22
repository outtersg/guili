#!/bin/sh

filtrer()
{
	f="$1" ; shift
	"$@" < "$f" > "$f.filtre" && cat "$f.filtre" > "$f" && rm "$f.filtre"
}

# Cet abruti commence par dégommer puis recréer son OUT_DIR. Sauf que (au moins dans le cas pseudocargo), OUT_DIR, c'est là où on a déjà compilé toutes les dépendances, et où on a téléchargé libgit2 lui-même, accessoirement.

filtrer build.rs grep -v OUT_DIR

if false
then
chemins="`echo "$PKG_CONFIG_PATH" | tr : '\012' | sed -e 's#/lib/pkgconfig##' -e 's/^/"/' -e 's/$/"/' | tr '\012' ' '`"
filtrer libgit2/CMakeLists.txt sed -e '/INCLUDE/{
x
s/.//
x
t
h
i\
SET(CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH} '"$chemins"')
}'
fi
