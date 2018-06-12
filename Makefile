CC ?= gcc

CFLAGS = -fno-stack-protector \
	-s \
	-Os

as4: main.c
	$(CC) $(CFLAGS) $< -o $@
	strip -S \
	-R .note.gnu.gold-version \
	-R .comment \
	-R .note \
	-R .note.gnu.build-id \
	-R .gnu.version \
	-R .note.ABI-tag $@
