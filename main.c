/* 
SPDX short identifier: MIT

Copyright 2013,2018 Andreas J. Reichel

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

uint16_t curr_ip;
uint16_t old_ip;
uint8_t prog_mem[4096];	// maximum amount of ROM = 4K

uint16_t curr_label;
uint16_t label_addr[4096];
char* label_name[4096];

char* label_ref[4096];
uint16_t label_ref_loc[4096];
uint16_t curr_refs;

uint16_t curr_line;

char *listing[4096];

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
		printf("Syntax error in line %d: missing register\n",
			curr_line);
		exit(-1);
	}
	if (strcmp(reg, "R0") == 0 || strcmp(reg, "0") == 0 || strcmp(reg, "0000") == 0) {
		return 0;
	} else
	if (strcmp(reg, "R1") == 0 || strcmp(reg, "1") == 0 || strcmp(reg, "0001") == 0) {
		return 1;
	} else
	if (strcmp(reg, "R2") == 0 || strcmp(reg, "2") == 0 || strcmp(reg, "0010") == 0) {
		return 2;
	} else
	if (strcmp(reg, "R3") == 0 || strcmp(reg, "3") == 0 || strcmp(reg, "0011") == 0) {
		return 3;
	} else
	if (strcmp(reg, "R4") == 0 || strcmp(reg, "4") == 0 || strcmp(reg, "0100") == 0) {
		return 4;
	} else
	if (strcmp(reg, "R5") == 0 || strcmp(reg, "5") == 0 || strcmp(reg, "0101") == 0) {
		return 5;
	} else
	if (strcmp(reg, "R6") == 0 || strcmp(reg, "6") == 0 || strcmp(reg, "0110") == 0) {
		return 6;
	} else
	if (strcmp(reg, "R7") == 0 || strcmp(reg, "7") == 0 || strcmp(reg, "0111") == 0) {
		return 7;
	} else
	if (strcmp(reg, "R8") == 0 || strcmp(reg, "8") == 0 || strcmp(reg, "1000") == 0) {
		return 8;
	} else
	if (strcmp(reg, "R9") == 0 || strcmp(reg, "9") == 0 || strcmp(reg, "1001") == 0) {
		return 9;
	} else
	if (strcmp(reg, "R10") == 0 || strcmp(reg, "10") == 0 || strcmp(reg, "1010") == 0) {
		return 10;
	} else
	if (strcmp(reg, "R11") == 0 || strcmp(reg, "11") == 0 || strcmp(reg, "1011") == 0) {
		return 11;
	} else
	if (strcmp(reg, "R12") == 0 || strcmp(reg, "12") == 0 || strcmp(reg, "1100") == 0) {
		return 12;
	} else
	if (strcmp(reg, "R13") == 0 || strcmp(reg, "13") == 0 || strcmp(reg, "1101") == 0) {
		return 13;
	} else
	if (strcmp(reg, "R14") == 0 || strcmp(reg, "14") == 0 || strcmp(reg, "1110") == 0) {
		return 14;
	} else
	if (strcmp(reg, "R15") == 0 || strcmp(reg, "15") == 0 || strcmp(reg, "1111") == 0) {
		return 15;
	} else
	{
		printf("Syntax error in line %d: invalid register: %s\n",
			curr_line, reg);
		exit(-1);
	}
}


uint8_t parse_regpair()
{
	char *pair = strtok(NULL, " \t,");
	if (!pair) {
		printf("Syntax error in line %d: missing register pair\n",
			curr_line);
		exit(-1);
	}
	if (strcmp(pair, "P0") == 0 || strcmp(pair, "P000") == 0 || strcmp(pair, "0<") == 0) {
		return 0;
	} else
	if (strcmp(pair, "P1") == 0 || strcmp(pair, "P001") == 0 || strcmp(pair, "1<") == 0) {
		return 2;
	} else
	if (strcmp(pair, "P2") == 0 || strcmp(pair, "P010") == 0 || strcmp(pair, "2<") == 0) {
		return 4;
	} else
	if (strcmp(pair, "P3") == 0 || strcmp(pair, "P011") == 0 || strcmp(pair, "3<") == 0) {
		return 6;
	} else
	if (strcmp(pair, "P4") == 0 || strcmp(pair, "P100") == 0 || strcmp(pair, "4<") == 0) {
		return 8;
	} else
	if (strcmp(pair, "P5") == 0 || strcmp(pair, "P101") == 0 || strcmp(pair, "5<") == 0) {
		return 0xA;
	} else
	if (strcmp(pair, "P6") == 0 || strcmp(pair, "P110") == 0 || strcmp(pair, "6<") == 0) {
		return 0xC;
	} else
	if (strcmp(pair, "P7") == 0 || strcmp(pair, "P111") == 0 || strcmp(pair, "7<") == 0) {
		return 0xE;
	} else
	{
		printf("Syntax error in line %d: invalid register pair: %s\n",
			curr_line, pair);
		exit(-1);
	}	
}

uint8_t parse_byte()
{
	char *end;
	errno = 0;
	char *imm = strtok(NULL, " \t,");
	if (!imm) {
		printf("Syntax error in line %d: missing immediate data.\n",
			curr_line);
		exit(-1);
	}
	long int i = strtol(imm, &end, 0);
	if (*end != '\0') {
		printf("Syntax error in line %d: invalid number format: %s\n",
			curr_line, imm);
		exit(-1);
	}
	if (i < -128 || i > 255) {
		printf("Syntax error in line %d: value out of range: %s\n",
			curr_line, imm);
		exit(-1);
	}
	return (uint8_t) (((int8_t) i) & 0xFF);
}

uint16_t parse_12bit()
{
	char *end;
	errno = 0;
	char *imm = strtok(NULL, " \t,");
	if (!imm) {
		printf("Syntax error in line %d: missing immediate data.\n",
			curr_line);
		exit(-1);
	}
	long int i = strtol(imm, &end, 0);
	if (*end != '\0') {
		printf("Syntax error in line %d: invalid number format: %s\n",
			curr_line, imm);
		exit(-1);
	}
	if (i < 0 || i > 4095) {
		printf("Syntax error in line %d: value out of range: %s\n",
			curr_line, imm);
		exit(-1);
	}
	return (uint16_t) (i & 0xFFF);
}
			
uint8_t parse_nibble()
{
	char *end;
	errno = 0;
	char *imm = strtok(NULL, " \t,");
	if (!imm) {
		printf("Syntax error in line %d: missing immediate data.\n",
			curr_line);
		exit(-1);
	}
	long int i = strtol(imm, &end, 0);
	if (*end != '\0') {
		printf("Syntax error in line %d: invalid number format: %s\n",
			curr_line, imm);
		exit(-1);
	}
	if (i < 0 || i > 15) {
		printf("Syntax error in line %d: value out of range: %s\n",
			curr_line, imm);
		exit(-1);
	}
	return (uint8_t) (i & 0x0F);
}

void parse_target_addr8()
{
	char *goal = strtok(NULL, " \t,");
	if (!goal) {
		printf("Syntax error in line %d: missing jump goal\n",
			curr_line);
		exit(-1);
	}
	label_ref[curr_refs] = strdup(goal);
	label_ref_loc[curr_refs] = curr_ip;
	curr_refs++;
	prog_mem[curr_ip++] = 0x00;
}

void parse_target_addr12()
{
	char *goal = strtok(NULL, " \t,");
	if (!goal) {
		printf("Syntax error in line %d: missing jump goal\n",
			curr_line);
		exit(-1);
	}
	label_ref[curr_refs] = strdup(goal);
	label_ref_loc[curr_refs] = curr_ip;
	curr_refs++;
	prog_mem[curr_ip++] = 0x00;
}
			
uint8_t parse_cond()
{
	char *cond = strtok(NULL, " \t,");
	if (!cond) {
		printf("Syntax error in line %d: missing condition\n",
			curr_line);
		exit(-1);
	}
	if (strcmp(cond, "NC") == 0) {
		return 0;
	} else
	if (strcmp(cond, "TZ") == 0 || strcmp(cond, "T0") == 0) {
		return 1;
	} else
	if (strcmp(cond, "TN") == 0 || strcmp(cond, "T1") == 0) {
		return 9;
	} else
	if (strcmp(cond, "CN") == 0 || strcmp(cond, "C1") == 0) {
		return 2;
	} else
	if (strcmp(cond, "CZ") == 0 || strcmp(cond, "C0") == 0) {
		return 10;
	} else
	if (strcmp(cond, "AZ") == 0 || strcmp(cond, "A0") == 0) {
		return 4;
	} else
	if (strcmp(cond, "AN") == 0 || strcmp(cond, "NZA") == 0) {
		return 12;
	} else {
		int c = atoi(cond);
		if (c < 1 || c > 15) {
			printf("Syntax error in line %d: invalid condition code: %d\n",
			curr_line, c);
			exit(-1);
		}
		return c;
	}
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
		if (strcmp(token, "NOP") == 0) {
			prog_mem[curr_ip++] = 0x00;
		} else
		if (strcmp(token, "JCN") == 0) {
			uint8_t c = parse_cond();
			prog_mem[curr_ip++] = 0x10 | c;
			parse_target_addr8();
		} else
		if (strcmp(token, "JTZ") == 0) {
			prog_mem[curr_ip++] = 0x11;
			parse_target_addr8();
		} else
		if (strcmp(token, "JTN") == 0 || strcmp(token, "JTO") == 0) {
			prog_mem[curr_ip++] = 0x19;
			parse_target_addr8();
		} else
		if (strcmp(token, "JCZ") == 0 || strcmp(token, "JNC") == 0) {
			prog_mem[curr_ip++] = 0x1A;
			parse_target_addr8();
		} else
		if (strcmp(token, "JCO") == 0 || strcmp(token, "JOC") == 0) {
			prog_mem[curr_ip++] = 0x12;
			parse_target_addr8();
		} else
		if (strcmp(token, "JAZ") == 0) {
			prog_mem[curr_ip++] = 0x14;
			parse_target_addr8();
		} else
		if (strcmp(token, "JNZ") == 0 || strcmp(token, "JAN") == 0) {
			prog_mem[curr_ip++] = 0x1C;
			parse_target_addr8();
		} else
		if (strcmp(token, "FIM") == 0) {
			uint8_t c = parse_regpair();
			prog_mem[curr_ip++] = 0x20 | c;
			uint8_t i = parse_byte();
			prog_mem[curr_ip++] = i;
		} else
		if (strcmp(token, "SRC") == 0) {
			uint8_t c = parse_regpair();
			prog_mem[curr_ip++] = 0x21 | c;	
		} else
		if (strcmp(token, "FIN") == 0) {
			uint8_t c = parse_regpair();
			prog_mem[curr_ip++] = 0x30 | c;
		} else
		if (strcmp(token, "JIN") == 0) {
			uint8_t c = parse_regpair();
			prog_mem[curr_ip++] = 0x31 | c;
		} else
		if (strcmp(token, "JUN") == 0) {
			prog_mem[curr_ip++] = 0x40;
			parse_target_addr12();
		} else
		if (strcmp(token, "JMS") == 0) {
			prog_mem[curr_ip++] = 0x41;
			parse_target_addr12();
		} else
		if (strcmp(token, "INC") == 0) {
			uint8_t r = parse_reg();
			prog_mem[curr_ip++] = 0x60 | r;
		} else
		if (strcmp(token, "ISZ") == 0) {
			uint8_t r = parse_reg();
			prog_mem[curr_ip++] = 0x70 | r;
			parse_target_addr8();
		} else
		if (strcmp(token, "ADD") == 0) {
			uint8_t r = parse_reg();
			prog_mem[curr_ip++] = 0x80 | r;
		} else
		if (strcmp(token, "SUB") == 0) {
			uint8_t r = parse_reg();
			prog_mem[curr_ip++] = 0x90 | r;
		} else
		if (strcmp(token, "LD") == 0) {
			uint8_t r = parse_reg();
			prog_mem[curr_ip++] = 0xA0 | r;
		} else
		if (strcmp(token, "XCH") == 0) {
			uint8_t r = parse_reg();
			prog_mem[curr_ip++] = 0xB0 | r;
		} else
		if (strcmp(token, "BBL") == 0) {
			uint8_t d = parse_nibble();
			prog_mem[curr_ip++] = 0xC0 | d;
		} else
		if (strcmp(token, "LDM") == 0) {
			uint8_t d = parse_nibble();
			prog_mem[curr_ip++] = 0xD0 | d;
		} else
		if (strcmp(token, "WRM") == 0) {
			prog_mem[curr_ip++] = 0xE0;
		} else
		if (strcmp(token, "WMP") == 0) {
			prog_mem[curr_ip++] = 0xE1;
		} else
		if (strcmp(token, "WRR") == 0) {
			prog_mem[curr_ip++] = 0xE2;
		} else
		if (strcmp(token, "WPM") == 0) {
			prog_mem[curr_ip++] = 0xE3;
		} else
		if (strcmp(token, "WR0") == 0) {
			prog_mem[curr_ip++] = 0xE4;
		} else
		if (strcmp(token, "WR1") == 0) {
			prog_mem[curr_ip++] = 0xE5;
		} else
		if (strcmp(token, "WR2") == 0) {
			prog_mem[curr_ip++] = 0xE6;
		} else
		if (strcmp(token, "WR3") == 0) {
			prog_mem[curr_ip++] = 0xE7;
		} else
		if (strcmp(token, "SBM") == 0) {
			prog_mem[curr_ip++] = 0xE8;
		} else
		if (strcmp(token, "RDM") == 0) {
			prog_mem[curr_ip++] = 0xE9;
		} else
		if (strcmp(token, "RDR") == 0) {
			prog_mem[curr_ip++] = 0xEA;
		} else
		if (strcmp(token, "ADM") == 0) {
			prog_mem[curr_ip++] = 0xEB;
		} else
		if (strcmp(token, "RD0") == 0) {
			prog_mem[curr_ip++] = 0xEC;
		} else
		if (strcmp(token, "RD1") == 0) {
			prog_mem[curr_ip++] = 0xED;
		} else
		if (strcmp(token, "RD2") == 0) {
			prog_mem[curr_ip++] = 0xEE;
		} else
		if (strcmp(token, "RD3") == 0) {
			prog_mem[curr_ip++] = 0xEF;
		} else
		if (strcmp(token, "CLB") == 0) {
			prog_mem[curr_ip++] = 0xF0;
		} else
		if (strcmp(token, "CLC") == 0) {
			prog_mem[curr_ip++] = 0xF1;
		} else
		if (strcmp(token, "IAC") == 0) {
			prog_mem[curr_ip++] = 0xF2;
		} else
		if (strcmp(token, "CMC") == 0) {
			prog_mem[curr_ip++] = 0xF3;
		} else
		if (strcmp(token, "CMA") == 0) {
			prog_mem[curr_ip++] = 0xF4;
		} else
		if (strcmp(token, "RAL") == 0) {
			prog_mem[curr_ip++] = 0xF5;
		} else
		if (strcmp(token, "RAR") == 0) {
			prog_mem[curr_ip++] = 0xF6;
		} else
		if (strcmp(token, "TCC") == 0) {
			prog_mem[curr_ip++] = 0xF7;
		} else
		if (strcmp(token, "DAC") == 0) {
			prog_mem[curr_ip++] = 0xF8;
		} else
		if (strcmp(token, "TCS") == 0) {
			prog_mem[curr_ip++] = 0xF9;
		} else
		if (strcmp(token, "STC") == 0) {
			prog_mem[curr_ip++] = 0xFA;
		} else
		if (strcmp(token, "DAA") == 0) {
			prog_mem[curr_ip++] = 0xFB;
		} else
		if (strcmp(token, "KBP") == 0) {
			prog_mem[curr_ip++] = 0xFC;
		} else
		if (strcmp(token, "DCL") == 0) {
			prog_mem[curr_ip++] = 0xFD;
		} else
		if (strcmp(token, "*=") == 0) {
			curr_ip = parse_12bit();
			old_ip = curr_ip;
		}
		else {
			printf("Syntax error: unknown opcode in line %d: %s\n",
				curr_line, token);
			exit(-1);
		}

		if (strtok(NULL, " ,")) {
			printf("Syntax error: garbage at end of line %d\n",
				curr_line);
			exit(-1);
		}
	}
}

int main(int argc, char **argv)
{
	fprintf(stdout, "MCS-4 Assembler for i4004\n");
	fprintf(stdout, "Written 2013,2018 by Andreas J. Reichel\n");

	if (argc < 2) {
		fprintf(stdout, "Syntax: as4 file.s\n");
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
				listing[old_ip] = malloc(strlen(old_line) + 32);
				sprintf(listing[old_ip], "%03X  ", old_ip);
				for (uint16_t i = old_ip; i < curr_ip; i++) {
					sprintf(listing[old_ip]+4+3*(i-old_ip), "%02X              ", prog_mem[i]);
				}
				sprintf(listing[old_ip]+12, "%s", old_line);
			}
			free(old_line);
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

				sprintf(listing[loc-1] + 7, "%02X", label_addr[j] & 0xFF);
				*(listing[loc-1] + 9) = 0x20;

				if (prog_mem[loc-1] == 0x40 || prog_mem[loc-1] == 0x50) {
					prog_mem[loc-1] |= (label_addr[j] >> 8) & 0x0F;

					sprintf(listing[loc-1] + 4, "%02X", prog_mem[loc-1]);
					*(listing[loc-1] + 6) = 0x20;
				}
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
	f = fopen("a4.bin", "wb");
	if (!f) {
		fprintf(stderr, "Cannot open output file.\n");
		return 1;
	}
	if (fwrite(prog_mem, curr_ip, 1, f) != 1) {
		fprintf(stderr, "Could not write code.\n");
		return 1;
	}

	fclose(f);

	for (int i = 0; i < curr_ip; i++) {
		if (listing[i]) {
			fprintf(stdout, "%s\n", listing[i]);
			free(listing[i]);
		}

	}
	return 0;
}
