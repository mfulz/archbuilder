PROGNM ?= archbuilder
PREFIX ?= /usr
SHRDIR ?= $(PREFIX)/share
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib
CNFDIR ?= /etc
ARCHBUILDER_LIB_DIR ?= $(LIBDIR)/$(PROGNM)
ARCHBUILDER_CONF_DIR ?= $(CNFDIR)/$(PROGNM)
ARCHBUILDER_VERSION ?= 0.9.1

.PHONY: install build archbuilder

build: archbuilder

archbuilder: archbuilder.in
	sed -e 's|ARCHBUILDER_LIB_DIR|$(ARCHBUILDER_LIB_DIR)|' \
	    -e 's|ARCHBUILDER_CONF_DIR|$(ARCHBUILDER_CONF_DIR)|' \
		-e 's|ARCHBUILDER_VERSION|$(ARCHBUILDER_VERSION)|' $< >$@

install-archbuilder: archbuilder
	@install -Dm755 archbuilder -t '$(DESTDIR)$(BINDIR)'

install: install-archbuilder
	@install -Dm644 lib/archbuilder.inc.sh -t '$(DESTDIR)$(LIBDIR)/$(PROGNM)'
	@install -Dm644 lib/buildah.inc.sh -t '$(DESTDIR)$(LIBDIR)/$(PROGNM)'
	@install -Dm644 lib/ext/slog.sh -t '$(DESTDIR)$(LIBDIR)/$(PROGNM)/ext'
	@install -Dm644 lib/ext/bash_log_internals.inc.sh -t '$(DESTDIR)$(LIBDIR)/$(PROGNM)/ext'
	@install -Dm644 archbuilder.env -t '$(DESTDIR)$(CNFDIR)/$(PROGNM)'
