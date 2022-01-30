CFLAGS := -Wall -Wextra -fPIC -shared -O2
LDFLAGS := -ldl

kaiso-wrap.so: kaiso-wrap.c
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@
	strip $@

run: kaiso-wrap.so
	KAISO_IP=localhost KAISO_PORT=37812 KAISO_SERVICE=native LD_PRELOAD=./$< pulsemixer --server tcp:localhost:37812
.PHONY: run
