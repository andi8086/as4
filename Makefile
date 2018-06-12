CC ?= gcc
STRIP ?= strip
STRIPFLAGS = -S \
	-R .note.gnu.gold-version \
	-R .comment \
	-R .note \
	-R .note.gnu.build-id \
	-R .gnu.version \
	-R .note.ABI-tag


CFLAGS = -fno-stack-protector \
	-s \
	-Os

all: as4 as40 as8

as4: as4.c
	$(CC) $(CFLAGS) $< -o $@
	$(STRIP) $(STRIPFLAGS) $@

as40: as40.c
	$(CC) $(CFLAGS) $< -o $@
	$(STRIP) $(STRIPFLAGS) $@

as8: as8.c
	$(CC) $(CFLAGS) $< -o $@
	$(STRIP) $(STRIPFLAGS) $@
