CFLAGS := -Wall -Wextra -fPIC -shared -O2
LDFLAGS := -ldl

SRCS := $(wildcard *.c)
BINS := $(addprefix kaiso-, $(SRCS:.c=))
LIBS := $(addprefix kaiso-, $(SRCS:.c=.so))

BINDIR := $(DESTDIR)/usr/bin/
LIBDIR := $(DESTDIR)/usr/lib/

all: $(LIBS)

clean:
	rm -f $(LIBS)

install: $(BINS) $(LIBS)
	install -d $(BINDIR) $(LIBDIR)
	install -m755 $(BINS) $(BINDIR)
	install -m755 $(LIBS) $(LIBDIR)

uninstall:
	rm $(addprefix $(BINDIR), $(BINS))
	rm $(addprefix $(LIBDIR), $(LIBS))

kaiso-%.so: %.c
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@
	strip $@
