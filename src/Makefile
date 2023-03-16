SRC_FILES = \
	cli.sh \
	progress_bar.sh \
	sys.sh \
	terminal.sh \
	util.sh \
	version.sh \
	main.sh \
# `main.sh` must be the last item!

DESTDIR =
PREFIX = /usr/local
BINDIR = $(DESTDIR)$(PREFIX)/bin

INSTALL = install


default: build

sysinfo: $(SRC_FILES)
	printf "#!/bin/bash\n\n" > $@
	cat $^ >> "$@"
	chmod +x "$@"

version.sh: version.template.sh
	@if command -v git >/dev/null 2>&1 && git rev-parse --show-top-level >/dev/null 2>&1; then \
		sed \
			-e "s/^\(SCRIPT_VERSION=\).*$$/\1\"$$(git describe --always --dirty)\"/" \
			"version.template.sh" > "version.sh"; \
	else \
		sed \
			-e "s/^\(SCRIPT_VERSION=\).*$$/\1\"(unknown)\"/" \
			"version.template.sh" > "version.sh"; \
	fi

build: sysinfo

install: backup
	@$(INSTALL) -D -m 0555 -v "backup" "$(BINDIR)/backup"

clean:
	rm -f sysinfo version.sh

.PHONY: default build install clean version.sh
