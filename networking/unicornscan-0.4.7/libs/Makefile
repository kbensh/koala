# libs/Makefile.  Generated from Makefile.in by configure.
include ../Makefile.inc

PCAPVER=0.9.4
DNETVER=1.10

all:  pcap libdnet

pcap: libpcap-$(PCAPVER)/stamp
libdnet: libdnet-$(DNETVER)/stamp
libltdl: libltdl/stamp

libpcap-$(PCAPVER)/stamp: libpcap-$(PCAPVER).tar.gz
	gzip -dc libpcap-$(PCAPVER).tar.gz | tar -xvf -
	cd libpcap-$(PCAPVER) && CC="$(CC)" CFLAGS="$(CFLAGS)" ./configure --build=x86_64-unknown-linux-gnu --host=x86_64-unknown-linux-gnu --prefix=`pwd`/../fake && CC="$(CC)" CFLAGS="$(CFLAGS)" $(USE_MAKE) && $(USE_MAKE) install && touch stamp

libdnet-$(DNETVER)/stamp: libdnet-$(DNETVER).tar.gz
	gzip -dc libdnet-$(DNETVER).tar.gz | tar -xvf -
	cd libdnet-$(DNETVER) && patch -p1 < ../libdnet-no-test-python.patch && CC="$(CC)" CFLAGS="$(CFLAGS)" ./configure --build=x86_64-unknown-linux-gnu --host=x86_64-unknown-linux-gnu --prefix=`pwd`/../fake --enable-shared=no && CC="$(CC)" CFLAGS="$(CFLAGS)" $(USE_MAKE) && $(USE_MAKE) install && touch stamp

libltdl/stamp: libltdl.tar.gz
	gzip -dc libltdl.tar.gz | tar -xvf -
	cd libltdl && CC="$(CC)" CFLAGS="$(CFLAGS)" ./configure --build=x86_64-unknown-linux-gnu --host=x86_64-unknown-linux-gnu --prefix=`pwd`/../fake --enable-shared=no && CC="$(CC)" CFLAGS="$(CFLAGS)" $(USE_MAKE) && $(USE_MAKE) install && touch stamp

distclean: clean
	rm -rf fake

clean:
	rm -rf libdnet-$(DNETVER) libpcap-$(PCAPVER) libltdl

install: all
uninstall:
