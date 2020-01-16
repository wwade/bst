PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
LIBEXECDIR ?= $(PREFIX)/libexec

CFLAGS ?= -O2
CFLAGS += -std=c99 -Wall -Wextra -Wno-unused-parameter -fno-strict-aliasing
CPPFLAGS += -D_GNU_SOURCE -D_FILE_OFFSET_BITS=64 -DLIBEXECDIR=\"$(LIBEXECDIR)\"

SRCS := main.c enter.c userns.c mount.c cp.c setarch.c usage.c sig.c
OBJS := $(subst .c,.o,$(SRCS))
BINS := bst bst--userns-helper

ifeq ($(shell id -u),0)
SUDO =
else
SUDO = sudo
endif

ifeq ($(NO_SETCAP_OR_SUID),)
SETCAP ?= $(SUDO) setcap
CHOWN = $(SUDO) chown
CHMOD = $(SUDO) chmod
else
SETCAP = :
CHOWN = :
CHMOD = :
endif

all: $(BINS)

generate: usage.txt
	(echo "/* Copyright (c) 2020 Arista Networks, Inc.  All rights reserved."; \
	 echo "   Arista Networks, Inc. Confidential and Proprietary. */"; \
	 echo ""; \
	 echo "/* This file is generated from usage.txt. Do not edit. */"; \
	 xxd -i usage.txt) > usage.c

bst: $(OBJS)
	$(LINK.o) -o $@ $^ -lcap

bst--userns-helper: userns-helper.o
	$(LINK.o) -o $@ $^
	$(SETCAP) cap_setuid,cap_setgid+ep $@ \
		|| ($(CHOWN) root $@ && $(CHMOD) u+s $@)

install: HELPER_INSTALLPATH = $(DESTDIR)$(LIBEXECDIR)/bst--userns-helper
install: $(BINS)
	install -m 755 -D bst $(DESTDIR)$(BINDIR)/bst
	install -m 755 -D bst--userns-helper $(HELPER_INSTALLPATH)
	$(SETCAP) cap_setuid,cap_setgid+ep $(HELPER_INSTALLPATH) \
		|| ($(CHOWN) root $(HELPER_INSTALLPATH) && $(CHMOD) u+s $(HELPER_INSTALLPATH))

check: $(BINS)
	./test/cram.sh test

clean:
	$(RM) $(BINS) $(OBJS) userns-helper.o

.PHONY: all clean install generate check
