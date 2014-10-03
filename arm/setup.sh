#!/bin/bash
PERLFLAGS=-Uplibpth=
for i in `gcc -print-search-dirs | grep libraries | cut -f2- -d= | tr ':' '\n' | grep -v /gcc`; do
PERLFLAGS="$PERLFLAGS -Aplibpth=$i"
done
export PERLFLAGS
echo $PERLFLAGS
export CFLAGS="-Ofast -march=native -mtune=native"
echo $CFLAGS
./buildtools