# Makefile.inc.  Generated from Makefile.inc.in by configure.

BUILD_DIR=/koala/networking/unicornscan-0.4.7

prefix=/usr/local
exec_prefix=${prefix}
bindir=${exec_prefix}/bin
libexecdir=${exec_prefix}/libexec
localstatedir=${prefix}/var
libdir=${exec_prefix}/lib
sysconfdir=${prefix}/etc
datadir=${prefix}/share
docdir=${prefix}/share/doc
mandir=${prefix}/share/man



MODDIR=${exec_prefix}/lib/unicornscan/modules
DESTDIR ?= 
TARGETNAME=unicornscan

COPTS=-D_GNU_SOURCE -O2
CDEFS=  $(DEFS) -DLIBDIR=\"${exec_prefix}/lib\" -DSYSCONFDIR=\"${prefix}/etc\" -DLIBEXECDIR=\"${exec_prefix}/libexec\" -DLOCALSTATEDIR=\"${prefix}/var\" -DPROGNAME=\"unicornscan\"
CINCS=  -I$(BUILD_DIR)/src -I$(BUILD_DIR)/libs/fake/include -I$(BUILD_DIR)/ext_src
LDFLAGS=    -luext -lltdl  -L$(BUILD_DIR)/libs/fake/lib -L$(BUILD_DIR)/ext_src

CC=gcc
CFLAGS=$(COPTS) $(CDEFS) $(CINCS) $(CDEPS)
SHELL=/bin/bash

#LIBTOOL_DEPS=autostuff/ltmain.sh
LIBTOOL=$(SHELL) $(BUILD_DIR)/libtool --quiet

USE_MAKE=/usr/bin/gmake
AR=ar
ARFLAGS=cru
AWK=gawk
LN=ln -s
RANLIB=ranlib
EGREP=/usr/bin/grep -E
CHCON=true
BISON=bison -d
FLEX=flex -s -B
INSTALL=/usr/bin/install -c
INSTALL_PROGRAM=${INSTALL}

MODCLFLAGS=-module -export-dynamic -rpath $(MODDIR) -avoid-version

%.lo: %.c
	$(LIBTOOL) --mode=compile $(CC) $(CFLAGS) -c $<
