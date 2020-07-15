PKG_CONFIG ?= pkg-config

# Installation directories.
PREFIX ?= /usr
SBINDIR ?= $(PREFIX)/sbin
MANDIR = $(PREFIX)/share/man
AUTOSTARTDIR = /etc/xdg/autostart
DBUSSERVICEDIR = $(PREFIX)/share/dbus-1/services
SYSTEMDDIR ?= $(PREFIX)/lib/systemd

autostart_DATA = sealertauto.desktop
INITDIR ?= $(DESTDIR)/etc/rc.d/init.d
SELINUXDIR = $(DESTDIR)/etc/selinux

DBUSFLAGS = -DHAVE_DBUS $(shell $(PKG_CONFIG) --cflags dbus-glib-1)
DBUSLIB = $(shell $(PKG_CONFIG) --libs dbus-glib-1)

CFLAGS ?= -g -Werror -Wall -W
override CFLAGS += $(DBUSFLAGS)

USE_PCRE2 ?= n
ifeq ($(USE_PCRE2),y)
	PCRE_CFLAGS := -DUSE_PCRE2 -DPCRE2_CODE_UNIT_WIDTH=8 $(shell $(PKG_CONFIG) --cflags libpcre2-8)
	PCRE_LDLIBS := $(shell $(PKG_CONFIG) --libs libpcre2-8)
else
	PCRE_CFLAGS := $(shell $(PKG_CONFIG) --cflags libpcre)
	PCRE_LDLIBS := $(shell $(PKG_CONFIG) --libs libpcre)
endif
export PCRE_CFLAGS PCRE_LDLIBS

override LDLIBS += -lselinux $(PCRE_LDLIBS) $(DBUSLIB)

all: restorecond

restorecond.o utmpwatcher.o stringslist.o user.o watch.o: restorecond.h

restorecond:  restore.o restorecond.o utmpwatcher.o stringslist.o user.o watch.o
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

install: all
	[ -d $(DESTDIR)$(MANDIR)/man8 ] || mkdir -p $(DESTDIR)$(MANDIR)/man8
	-mkdir -p $(DESTDIR)$(SBINDIR)
	install -m 755 restorecond $(DESTDIR)$(SBINDIR)
	install -m 644 restorecond.8 $(DESTDIR)$(MANDIR)/man8
	-mkdir -p $(INITDIR)
	install -m 755 restorecond.init $(INITDIR)/restorecond
	-mkdir -p $(SELINUXDIR)
	install -m 644 restorecond.conf $(SELINUXDIR)/restorecond.conf
	install -m 644 restorecond_user.conf $(SELINUXDIR)/restorecond_user.conf
	-mkdir -p $(DESTDIR)$(AUTOSTARTDIR)
	install -m 644 restorecond.desktop $(DESTDIR)$(AUTOSTARTDIR)/restorecond.desktop
	-mkdir -p $(DESTDIR)$(DBUSSERVICEDIR)
	install -m 600 org.selinux.Restorecond.service  $(DESTDIR)$(DBUSSERVICEDIR)/org.selinux.Restorecond.service
	-mkdir -p $(DESTDIR)$(SYSTEMDDIR)/system
	install -m 644 restorecond.service $(DESTDIR)$(SYSTEMDDIR)/system/
relabel: install
	/sbin/restorecon $(DESTDIR)$(SBINDIR)/restorecond 

clean:
	-rm -f restorecond *.o *~

indent:
	../../scripts/Lindent $(wildcard *.[ch])

test:
