#!/bin/sh

. `dirname "$0"`/util.sh

cd /tmp
tar xjf `obtenir ftp://ftp.cs.tu-berlin.de/pub/net/ftp/lftp/lftp-3.0.6.tar.bz2`
cd lftp-3.0.6
./configure --prefix=/usr/local/lftp-3.0.6
make && sudo make install && sudo utiliser lftp-3.0.6

