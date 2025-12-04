include ../../../Makefile.inc

HDRS=

DBTYPES=

G_LDPATH=-L$(BUILD_DIR)/src/unilib -L$(BUILD_DIR)/src/parse -L$(BUILD_DIR)/src/scan_progs
CFLAGS += -DMODULE=1 

all: $(DBTYPES)

mysql: mysqldb.la
pgsql: pgsqldb.la

mysqldb.la: mysqldb.lo $(HDRS)
		$(LIBTOOL) --mode=link $(CC) $(MODCLFLAGS) $(CFLAGS)  -o mysqldb.la mysqldb.lo  $(G_LDPATH) -lmysqlclient -lunilib

pgsqldb.la: pgsqldb.lo $(HDRS)
	$(LIBTOOL) --mode=link $(CC) $(MODCLFLAGS) $(CFLAGS)  -o pgsqldb.la pgsqldb.lo $(G_LDPATH)  -lpq -lunilib

clean:
	dbtypes="$(DBTYPES)" && for g in $$dbtypes; do \
		$(LIBTOOL) --mode=clean rm -f $${g}db.la;\
		$(LIBTOOL) --mode=clean rm -f $${g}db.lo;\
	done

distclean: clean
	rm -f template.h

install: all
	mkdir -p $(DESTDIR)/$(MODDIR)
	dbtypes="$(DBTYPES)" && for g in $$dbtypes; do \
		$(LIBTOOL) --mode=install $(INSTALL_PROGRAM) -m 755 $${g}db.la $(DESTDIR)/$(MODDIR)/; \
		if test -f $(DESTDIR)/$(MODDIR)/$${g%%.la}db.so; then \
			$(CHCON) system_u:object_r:shlib_t $(DESTDIR)/$(MODDIR)/$${g%%.la}db.so; \
			$(CHCON) system_u:object_r:unicornscan_share_t $(DESTDIR)/$(MODDIR)/$${g%%.la}db.la; \
		fi \
	done
	$(LIBTOOL) --mode=finish $(DESTDIR)/$(MODDIR)

uninstall:
	for g in $(DBTYPES); do \
		$(LIBTOOL) --mode=uninstall rm -f $(DESTDIR)/$(MODDIR)/$${g}db.la; \
	done
