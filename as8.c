/* 
SPDX short identifier: MIT

Copyright 2018 Andreas J. Reichel

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

#define SYNTAX_ERR(format, ...) \
	fprintf(stderr, "Syntax error in line %d: "format, \
	curr_line, ##__VA_ARGS__)

#define VERSION "1.0"

uint16_t curr_ip;
uint16_t old_ip;
uint8_t prog_mem[16386];	// maximum amount of ROM = 4K

uint16_t curr_label;
uint16_t label_addr[16386];
char* label_name[16386];

char* label_ref[16386];
uint16_t label_ref_loc[16386];
uint16_t curr_refs;

uint16_t curr_line;

char *listing[16384];

void add_label(char *label)
{
	label_name[curr_label] = label;
	label_addr[curr_label] = curr_ip;
	curr_label++;
}

uint8_t parse_reg()
{
	char *reg = strtok(NULL, " \t,");
	if (!reg) {
		SYNTAX_ERR("missing register\n");
		exit(-1);
	}
	if (strcmp(reg, "A") == 0) {
		return 0;
	} else
	if (strcmp(reg, "B") == 0) {
		return 1;
	} else
	if (strcmp(reg, "C") == 0) {
		return 2;
	} else
	if (strcmp(reg, "D") == 0) {
		return 3;
	} else
	if (strcmp(reg, "E") == 0) {
		return 4;
	} else
	if (strcmp(reg, "H") == 0) {
		return 5;
	} else
	if (strcmp(reg, "L") == 0) {
		return 6;
	} else
	if (strcmp(reg, "M") == 0) {
		return 7;
	} else
	{
		SYNTAX_ERR("invalid register: %s\n", reg);
		exit(-1);
	}
}

uint8_t parse_byte()
{
	char *end;
	errno = 0;
	char *imm = strtok(NULL, " \t,");
	if (!imm) {
		SYNTAX_ERR("missing immediate data.\n");
		exit(-1);
	}
	long int i = strtol(imm, &end, 0);
	if (*end != '\0') {
		SYNTAX_ERR("invalid number format: %s\n", imm);
		exit(-1);
	}
	if (i < -128 || i > 255) {
		SYNTAX_ERR("value out of range: %s\n", imm);
		exit(-1);
	}
	return (uint8_t) (((int8_t) i) & 0xFF);
}

uint16_t parse_14bit()
{
	char *end;
	errno = 0;
	char *imm = strtok(NULL, " \t,");
	if (!imm) {
		SYNTAX_ERR("missing immediate data.\n");
		exit(-1);
	}
	long int i = strtol(imm, &end, 0);
	if (*end != '\0') {
		SYNTAX_ERR("invalid number format: %s\n", imm);
		exit(-1);
	}
	if (i < 0 || i > 16383) {
		SYNTAX_ERR("value out of range: %s\n", imm);
		exit(-1);
	}
	return (uint16_t) (i & 0x3FFF);
}

void parse_addr14()
{
	char *goal = strtok(NULL, " \t,");
	if (!goal) {
		SYNTAX_ERR("missing jump goal\n");
		exit(-1);
	}
	label_ref[curr_refs] = strdup(goal);
	label_ref_loc[curr_refs] = curr_ip;
	curr_refs++;
	prog_mem[curr_ip++] = 0x00;
	prog_mem[curr_ip++] = 0x00;
}

void compile(char *line)
{
	// ignore after a ";" as comment
	char *comment = strstr(line, ";");
	if (comment) {
		*comment = 0;
	}
	if (comment == line) return;

	char *label = strstr(line, ":");
	if (label) {
		char *slabel = strndup(line, label-line);
		add_label(slabel);
		line = label + 1;
	}
	// trim leading spaces
	while (*line == ' ') line++;
	// trim leading tabs
	while (*line == '\t') line++;

	if (!*line) return;
	// trim trailing spaces
	while (line[strlen(line)-1] == ' ') line[strlen(line)-1] = 0;
	// trim trailing tabs
	while (line[strlen(line)-1] == '\t') line[strlen(line)-1] = 0;

	if (!*line) return;
	// find first token
	char *token = strtok(line, " \t");
	if (token) {
		if (strcmp(token, "MOV") == 0) {
			uint16_t d = parse_reg();
			uint16_t s = parse_reg();
			prog_mem[curr_ip++] = 0xC0 | (d << 3) | s;
		} else
		if (strcmp(token, "MVI") == 0) {
			uint16_t d = parse_reg();
			uint8_t i = parse_byte();
			prog_mem[curr_ip++] = 0x06 | (d << 3);
			prog_mem[curr_ip++] = i;
		} else
		if (strcmp(token, "INR") == 0) {
			uint16_t d = parse_reg();
			if (d == 0) {
				SYNTAX_ERR("invalid register A\n");
				exit(1);
			}
			prog_mem[curr_ip++] = (d << 3);
		} else
		if (strcmp(token, "DCR") == 0) {
			uint16_t d = parse_reg();
			if (d == 0) {
				SYNTAX_ERR("invalid register A\n");
				exit(1);
			}
			prog_mem[curr_ip++] = (d << 3) | 1;
		} else
		if (strcmp(token, "ADD") == 0) {
			uint16_t s = parse_reg();
			if (s == 0 || s == 4) {
				SYNTAX_ERR("invalid register A\n");
				exit(1);
			}
			prog_mem[curr_ip++] = (0x40 | s);
		} else
		if (strcmp(token, "ADI") == 0) {
			uint8_t i = parse_byte();
			prog_mem[curr_ip++] = 0x44;
			prog_mem[curr_ip++] = i;
		} else
		if (strcmp(token, "ADC") == 0) {
			uint16_t s = parse_reg();
			if (s == 0 || s == 4) {
				SYNTAX_ERR("invalid register A\n");
				exit(1);
			}
			prog_mem[curr_ip++] = (0x48 | s);
		} else
		if (strcmp(token, "ACI") == 0) {
			uint8_t i = parse_byte();
			prog_mem[curr_ip++] = 0x08;
			prog_mem[curr_ip++] = i;
		} else
		if (strcmp(token, "SUB") == 0) {
			uint16_t s = parse_reg();
			if (s == 0 || s == 4) {
				SYNTAX_ERR("invalid register A\n");
				exit(1);
			}
			prog_mem[curr_ip++] = (0x90 | s);
		} else
		if (strcmp(token, "SUI") == 0) {
			uint8_t i = parse_byte();
			prog_mem[curr_ip++] = 0x10;
			prog_mem[curr_ip++] = i;
		} else
		if (strcmp(token, "SBB") == 0) {
			uint16_t s = parse_reg();
			if (s == 0 || s == 4) {
				SYNTAX_ERR("invalid register A\n");
				exit(1);
			}
			prog_mem[curr_ip++] = (0x98 | s);
		} else
		if (strcmp(token, "SBI") == 0) {
			uint8_t i = parse_byte();
			prog_mem[curr_ip++] = 0x18;
			prog_mem[curr_ip++] = i;
		} else
		if (strcmp(token, "ANA") == 0) {
			uint16_t s = parse_reg();
			if (s == 0 || s == 4) {
				SYNTAX_ERR("invalid register A\n");
				exit(1);
			}
			prog_mem[curr_ip++] = (0xA0 | s);
		} else
		if (strcmp(token, "ANI") == 0) {
			uint8_t i = parse_byte();
			prog_mem[curr_ip++] = 0x20;
			prog_mem[curr_ip++] = i;
		} else
		if (strcmp(token, "XRA") == 0) {
			uint16_t s = parse_reg();
			if (s == 0 || s == 4) {
				SYNTAX_ERR("invalid register A\n");
				exit(1);
			}
			prog_mem[curr_ip++] = (0xA8 | s);
		} else
		if (strcmp(token, "XRI") == 0) {
			uint8_t i = parse_byte();
			prog_mem[curr_ip++] = 0x28;
			prog_mem[curr_ip++] = i;
		} else
		if (strcmp(token, "ORA") == 0) {
			uint16_t s = parse_reg();
			if (s == 0 || s == 4) {
				SYNTAX_ERR("invalid register A\n");
				exit(1);
			}
			prog_mem[curr_ip++] = (0xB0 | s);
		} else
		if (strcmp(token, "ORI") == 0) {
			uint8_t i = parse_byte();
			prog_mem[curr_ip++] = 0x34;
			prog_mem[curr_ip++] = i;
		} else
		if (strcmp(token, "CMP") == 0) {
			uint16_t s = parse_reg();
			if (s == 0 || s == 4) {
				SYNTAX_ERR("invalid register A\n");
				exit(1);
			}
			prog_mem[curr_ip++] = (0xB8 | s);
		} else
		if (strcmp(token, "CPI") == 0) {
			uint8_t i = parse_byte();
			prog_mem[curr_ip++] = 0x38;
			prog_mem[curr_ip++] = i;
		} else
		if (strcmp(token, "RLC") == 0) {
			prog_mem[curr_ip++] = 0x02;
		} else
		if (strcmp(token, "RRC") == 0) {
			prog_mem[curr_ip++] = 0x0A;
		} else
		if (strcmp(token, "RAL") == 0) {
			prog_mem[curr_ip++] = 0x12;
		} else
		if (strcmp(token, "RAR") == 0) {
			prog_mem[curr_ip++] = 0x1A;
		} else
		if (strcmp(token, "JMP") == 0) {
			prog_mem[curr_ip++] = 0x44;
			parse_addr14();
		} else
		if (strcmp(token, "JNC") == 0) {
			prog_mem[curr_ip++] = 0x40;
			parse_addr14();
		} else
		if (strcmp(token, "JNZ") == 0) {
			prog_mem[curr_ip++] = 0x48;
			parse_addr14();
		} else
		if (strcmp(token, "JP") == 0) {
			prog_mem[curr_ip++] = 0x50;
			parse_addr14();
		} else
		if (strcmp(token, "JPO") == 0) {
			prog_mem[curr_ip++] = 0x58;
			parse_addr14();
		} else
		if (strcmp(token, "JC") == 0) {
			prog_mem[curr_ip++] = 0x60;
			parse_addr14();
		} else
		if (strcmp(token, "JZ") == 0) {
			prog_mem[curr_ip++] = 0x68;
			parse_addr14();
		} else
		if (strcmp(token, "JM") == 0) {
			prog_mem[curr_ip++] = 0x70;
			parse_addr14();
		} else
		if (strcmp(token, "JPE") == 0) {
			prog_mem[curr_ip++] = 0x78;
			parse_addr14();
		} else
		if (strcmp(token, "CALL") == 0) {
			prog_mem[curr_ip++] = 0x46;
			parse_addr14();
		} else
		if (strcmp(token, "CNC") == 0) {
			prog_mem[curr_ip++] = 0x42;
			parse_addr14();
		} else
		if (strcmp(token, "CNZ") == 0) {
			prog_mem[curr_ip++] = 0x4A;
			parse_addr14();
		} else
		if (strcmp(token, "CP") == 0) {
			prog_mem[curr_ip++] = 0x52;
			parse_addr14();
		} else
		if (strcmp(token, "CPO") == 0) {
			prog_mem[curr_ip++] = 0x5A;
			parse_addr14();
		} else
		if (strcmp(token, "CC") == 0) {
			prog_mem[curr_ip++] = 0x62;
			parse_addr14();
		} else
		if (strcmp(token, "CZ") == 0) {
			prog_mem[curr_ip++] = 0x6A;
			parse_addr14();
		} else
		if (strcmp(token, "CM") == 0) {
			prog_mem[curr_ip++] = 0x72;
			parse_addr14();
		} else
		if (strcmp(token, "CPE") == 0) {
			prog_mem[curr_ip++] = 0x7A;
			parse_addr14();
		} else
		if (strcmp(token, "RET") == 0) {
			prog_mem[curr_ip++] = 0x07;
		} else
		if (strcmp(token, "RNC") == 0) {
			prog_mem[curr_ip++] = 0x03;
		} else
		if (strcmp(token, "RNZ") == 0) {
			prog_mem[curr_ip++] = 0x0B;
		} else
		if (strcmp(token, "RP") == 0) {
			prog_mem[curr_ip++] = 0x13;
		} else
		if (strcmp(token, "RPO") == 0) {
			prog_mem[curr_ip++] = 0x1B;
		} else
		if (strcmp(token, "RC") == 0) {
			prog_mem[curr_ip++] = 0x23;
		} else
		if (strcmp(token, "RZ") == 0) {
			prog_mem[curr_ip++] = 0x2B;
		} else
		if (strcmp(token, "RM") == 0) {
			prog_mem[curr_ip++] = 0x33;
		} else
		if (strcmp(token, "RPE") == 0) {
			prog_mem[curr_ip++] = 0x3B;
		} else
		if (strcmp(token, "RST") == 0) {
			uint8_t i = parse_byte();
			if (i > 7) {
				SYNTAX_ERR("address must be 0-7\n");
				exit(1);
			}
			prog_mem[curr_ip++] = 0x05 | (i << 3);
		} else
		if (strcmp(token, "HLT") == 0) {
			prog_mem[curr_ip++] = 0x00;
		} else
		if (strcmp(token, "IN") == 0) {
			uint8_t i = parse_byte();
			if (i > 7) {
				SYNTAX_ERR("input ports are 0-7\n");
				exit(1);
			}
			prog_mem[curr_ip++] = 0x41 | i << 1;
		} else
		if (strcmp(token, "OUT") == 0) {
			uint8_t i = parse_byte();
			if (i < 8 || i > 31) {
				SYNTAX_ERR("output ports are 8-31\n");
				exit(1);
			}
			prog_mem[curr_ip++] = 0x51 | i << 1;
		} else
		if (strcmp(token, ".BYTE") == 0) {
			uint8_t i = parse_byte();
			prog_mem[curr_ip++] = i;
		} else
		if (strcmp(token, "*=") == 0) {
			curr_ip = parse_14bit();
			old_ip = curr_ip;
		}
		else {
			SYNTAX_ERR("unknown opcode: %s\n", token);
			exit(-1);
		}

		if (strtok(NULL, " ,")) {
			SYNTAX_ERR("garbage at end of line\n");
			exit(-1);
		}
	}
}

int main(int argc, char **argv)
{
	fprintf(stdout, "MCS-8 Assembler for i8008\n");
	fprintf(stdout, "(c)2018 by Andreas J. Reichel\n");
	fprintf(stdout, "Version "VERSION"\n\n");
	if (argc < 2) {
		fprintf(stdout, "Syntax: as8 file.s\n");
		return 0;
	}
	FILE *f;

	f = fopen(argv[1], "r");
	if (!f) {
		fprintf(stderr, "Cannot open file.\n");
		return 1;
	}

	size_t len = 0;
	ssize_t read;
	char *line = NULL;

	fprintf(stdout, "Pass 1\n");

	while ((read = getline(&line, &len, f)) != -1) {
		curr_line++;
		if (line[strlen(line)-1] == '\r') {
			line[strlen(line)-1] = 0;
		}
		if (line[strlen(line)-1] == '\n') {
			line[strlen(line)-1] = 0;
		}
		if (line[strlen(line)-1] == '\r') {
			line[strlen(line)-1] = 0;
		}
		if (strlen(line) != 0) {
			old_ip = curr_ip;
			char *old_line = strdup(line);
			compile(line);
			if (curr_ip != old_ip) {
				listing[old_ip] = malloc(strlen(old_line) + 48);
				sprintf(listing[old_ip], "%04X  ", old_ip);
				sprintf(listing[old_ip]+5, "%03o               ", prog_mem[old_ip]);
				if (old_ip < curr_ip-1)
				for (uint16_t i = old_ip+1; i < curr_ip; i++) {
					sprintf(listing[old_ip]+6+3*(i-old_ip), "%02X               ", prog_mem[i]);
				}
				sprintf(listing[old_ip]+18, "%s", old_line);
			}
			free(old_line);
			if (curr_ip > 16383) {
				goto oom;
			}
		}
	}

	if (line) {
		free(line);
	}

	fprintf(stdout, "Pass 2\n");
	for (int i = 0; i < curr_refs; i++) {
		uint16_t loc = label_ref_loc[i];
		char* symbol = label_ref[i];

		bool ref_found = false;
		for (int j = 0; j < curr_label; j++) {
			if (strcmp(label_name[j], symbol) == 0) {
				ref_found = true;
				prog_mem[loc] = label_addr[j] & 0xFF;
				prog_mem[loc+1] = label_addr[j] >> 8;
				sprintf(listing[loc-1] + 9, "%02X", label_addr[j] & 0xFF);
				*(listing[loc-1] + 11) = 0x20;
				sprintf(listing[loc-1] + 12, "%02X", label_addr[j] >> 8);
				*(listing[loc-1] + 14) = 0x20;
				break;
			}
		}
		if (!ref_found) {
			fprintf(stderr, "Error, label '%s' not found.\n", symbol);
			exit(-1);
		}
	}

	fprintf(stdout, "Assembled %d bytes\n", curr_ip);

	fclose(f);

	char *bin_file = malloc(strlen(argv[1]) + 4);
	sprintf(bin_file, "%s", argv[1]);
	char *dot = bin_file + strlen(bin_file) - 1;
	while(dot > bin_file) {
		if (*(dot--) == '.') break;
	}
	if (dot != bin_file) {
		sprintf(dot+1, ".bin");
	} else
	{
		strcat(bin_file, ".bin");
	}

	fprintf(stdout, "Binary output : %s\n", bin_file);
	f = fopen(bin_file, "wb");
	if (!f) {
		fprintf(stderr, "Cannot open output file.\n");
		return 1;
	}
	if (fwrite(prog_mem, curr_ip, 1, f) != 1) {
		fprintf(stderr, "Could not write code.\n");
		return 1;
	}

	fclose(f);

	if (dot != bin_file) {
		sprintf(dot+1, ".lst");
	} else
	{
		strcat(bin_file, ".lst");
	}
	fprintf(stdout, "Listing file  : %s\n", bin_file);
	f = fopen(bin_file, "w");
	if (!f) {
		fprintf(stderr, "Cannot open output file.\n");
		return 1;
	}
	for (int i = 0; i < curr_ip; i++) {
		if (listing[i]) {
			fprintf(f, "%s\n", listing[i]);
			free(listing[i]);
		}

	}
	fclose(f);

	free(bin_file);

	return 0;
oom:
	if (line) {
		free(line);
		fprintf(stderr, "Error: Program larger than 16K.\n");
		exit(1);
	}
}
