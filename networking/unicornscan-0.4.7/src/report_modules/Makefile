include ../../Makefile.inc

SUBDIRS=osdetect

all:
	@for g in $(SUBDIRS); do \
		cd $$g && /usr/bin/gmake all || exit 1 && cd ..; \
	done

clean:
	@for g in $(SUBDIRS); do \
		cd $$g && /usr/bin/gmake clean || exit 1 && cd ..; \
	done

distclean:
	@for g in $(SUBDIRS); do \
		cd $$g && /usr/bin/gmake distclean || exit 1 && cd ..; \
	done

install:
	@for g in $(SUBDIRS); do \
		cd $$g && /usr/bin/gmake install || exit 1 && cd ..; \
	done

uninstall:
	@for g in $(SUBDIRS); do \
		cd $$g && /usr/bin/gmake uninstall || exit 1 && cd ..; \
	done
