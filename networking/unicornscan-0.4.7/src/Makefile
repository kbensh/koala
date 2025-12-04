include ../Makefile.inc

SRCS=chld.c drone_setup.c getconfig.c main.c usignals.c vip.c
OBJS=$(SRCS:.c=.lo)
HDRS=$(SRCS:.c=.h) config.h packageinfo.h settings.h 

G_LDPATH=-L$(BUILD_DIR)/src/unilib -L$(BUILD_DIR)/src/parse -L$(BUILD_DIR)/src/scan_progs
G_LDADD=$(LDFLAGS) -lscan -lparse -lunilib -lpcap -lltdl -ldnet -luext

# build order matters
SUBDIRS=unilib parse scan_progs tools payload_modules output_modules report_modules

all: alld unicornscan

unicornscan: compile.h $(OBJS) parse/libparse.la scan_progs/libscan.la unilib/libunilib.la
	$(LIBTOOL) --mode=link $(CC) -export-dynamic $(CFLAGS) -o unicornscan $(OBJS) $(G_LDPATH) $(G_LDADD)

compile.h: ../configure
	CC="$(CC)" ./compiledby.sh > compile.h

alld:
	@for g in $(SUBDIRS); do \
		echo "Entering $$g" && cd $$g && /usr/bin/gmake all || exit 1 && cd ..;\
	done

install: all
	@for g in $(SUBDIRS); do \
		echo "Entering $$g" && cd $$g && /usr/bin/gmake install || exit 1 && cd ..;\
	done
	mkdir -p $(DESTDIR)/$(bindir)
	mkdir -p $(DESTDIR)/$(localstatedir)/unicornscan
	$(INSTALL_PROGRAM) unicornscan $(DESTDIR)/$(bindir)
	$(CHCON) system_u:object_r:unicornscan_exec_t $(DESTDIR)/$(bindir)/unicornscan
	( cd $(DESTDIR)/$(bindir) && ln -sf unicornscan us ) || exit 1

uninstall:
	@for g in $(SUBDIRS); do \
		echo "Entering $$g" && cd $$g && /usr/bin/gmake uninstall || exit 1 && cd ..;\
	done
	rm -f $(DESTDIR)/$(bindir)/unicornscan
	rm -f $(DESTDIR)/$(bindir)/us

clean:
	$(LIBTOOL) --mode=clean rm -f $(OBJS) unicornscan
	rm -f compile.h
	@for g in $(SUBDIRS); do \
		echo "Entering $$g" && cd $$g && /usr/bin/gmake clean || exit 1 && cd ..;\
	done

distclean: clean
	@for g in $(SUBDIRS); do \
		echo "Entering $$g" && cd $$g && /usr/bin/gmake distclean || exit 1 && cd ..;\
	done

check:
	for g in `ls test_scripts`; do \
		echo -e "\nRunning test script $$g\n";\
		./test_scripts/$$g;\
	done
