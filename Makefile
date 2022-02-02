BINS := kaiso expose
WRAPPERS := wrappers

BINDIR := $(DESTDIR)/usr/bin/

all:
	nimble -d:release build
	strip $(BINS)
	$(MAKE) -C $(WRAPPERS)

clean:
	rm -f $(BINS)
	make -C $(WRAPPERS) clean

install:
	install -Dm755 kaiso $(BINDIR)/kaiso
	install -Dm755 expose $(BINDIR)/kaiso-expose
	make -C $(WRAPPERS) install

uninstall:
	rm -f $(BINDIR)/kaiso $(BINDIR)/kaiso-expose
	make -C $(WRAPPERS) uninstall
