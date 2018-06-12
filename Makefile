CC ?= gcc

as4: main.c
	$(CC) $< -o $@
