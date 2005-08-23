#!/bin/bash

. `dirname "$0"`/util.sh

version=1.1
version=1.3.7

cd /tmp
tar xzf `obtenir http://switch.dl.sourceforge.net/sourceforge/pyobjc/pyobjc-1.3.7.tar.gz`
cd pyobjc-1.3.7
sudo python setup.py install --prefix=/usr/local/pyobjc-1.3.7
dossier=`find /usr/local/pyobjc-1.3.7 -name \*.pth`
dossier=`dirname "$dossier"`
sudo ln -s "$dossier"/* /System/Library/Frameworks/Python.framework/Versions/Current/lib/python*/site-packages/
