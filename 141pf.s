;----------------------------------------------------------------------------------------------------------------------------------
;LEGAL NOTICE, DO NOT REMOVE
;
;Annotated Busicom 141-PF software based on binaries recovered by Tim McNerney and Fred Huettig in collaboration with the Computer
;History Museum (November 2005). Original disassembly, reverse-engineering, initial analysis and documentation by Barry Silverman,
;Brian Silverman, and Tim McNerney (November 2006). Detailed analysis, commenting, documentation by Lajos Kintli (July 2007).
;
;The original Busicom binary code is not a copyrighted work and may be freely distributed without restriction. The commented code
;and related documentation (the "work") are subject to the terms of this license.
;
;This is version 1.0.1 of the "work" (reconstructed "source code") released on November 15, 2009.
;Version 1.0.0 (November 15, 2007) corresponds to the preliminary version of the file named "BusicomCalculator_071026.asm"
;as submitted for editorial review by Lajos Kintli on October 26, 2007.
;Version 1.0.1 is updated in the incorretly mentioned port directions and timing.
;
;Notice:  This software and documentation is provided "AS IS."  There is no warranty, claims of accuracy or fitness for any 
;         purpose other than for education.  The authoritative version of this file can be located at http://www.4004.com
; 
;You are free:
; 
;* to copy, distribute, display, and perform this work
;* to make derivative works
; 
;Under the following conditions:
; 
;  Attribution.   You must attribute the work in the manner specified by the author or licensor.
; 
;  Noncommercial. You may not use this work for commercial purposes.
; 
;  Share Alike.   If you alter, transform, or build upon this work, you may distribute the resulting work only under a license
;                 identical to this one.
; 
;* For any reuse or distribution, you must make clear to others the license terms of this work.
;* Any of these conditions can be waived if you get permission from the copyright holder.
; 
;Your fair use and other rights are in no way affected by the above.
;
;This is a human-readable summary of the Legal Code (the full license) available at:
;  http://creativecommons.org/licenses/by-nc-sa/2.5/legalcode
;----------------------------------------------------------------------------------------------------------------------------------


$000: clb
$001: jcn TZ $001		;wait for the inactive printer drum sector signal
          jms $0b0		;Keyboard handling
$005: jms $15f		;right shift of keyboard buffer through R13 
          ld 13
          xch 1		;R1=lower half of the possible scan code
          clb
          jms $15f		;right shift of keyboard buffer through R13
          ld 13		;ACC=upper half of the possible scan code
$00d: jcn AN $029		;jump, if valid data was shifted from the buffer

;Status light handling
;RAM1 port:
;	BIT0 = Memory lamp	(MR)
;	BIT1 = Overflow lamp	(SR.S2.bit0)
;	BIT2 = Minus sign lamp	(WR.S0.bit0)

          inc 8		;R4R5 points to WR
          jms $173		;read the overflow bit, CY=SR.S2.bit0
$012: src 3<
          rd0			;read WR.S0 (minus/positive sign, bit 0 is used)
          ral
          xch 3		;R3=WR.S0 << 1 + (overflow bit)
          inc 8		;R4R5 points TR
          clb
          jms $1a0		;check, whether MR contains any number
          cmc			;after negate CY=1, if MR is not empty
          xch 3
          ral			;shift into ACC (8*WR.S0.bit1 + 4*WR.S0.bit0 + 2*(overflow) + (MR ? 1 : 0))
          wmp			;output into RAM1 port
          inc 6
          src 3<
          rdr			;read ROM2 port
          ral
$022: tcc
          jcn AZ $000		;jump back, if ROM2.bit3 is low: paper advance button is not held down
          jms $246		;more advancing the printer paper
          jun $000		;jump back to main loop

;
;A pressed button is found
;

$029:     xch 0		;R0R1=Keyboard scan code
          rd0			;decrement the keyboard buffer pointer (KR.S0) by two
          dac
          dac
          wr0
          src 3<
          rdr			;read the content of ROM1 port (decimal point switch)
          wr3			;write it into WR.S3 (number of decimal places)
          jms $064		;shift one high bit into keyboard shifter
          src 3<
          rdr			;read the content of ROM1 port (rounding switch)
          wr2			;write it into WR.S2
          fin 2<		;translate the scan code into function code and parameter (into R4R5)
          fim 0< $a0
          ld 5
          xch 1
          fin 0<		;fetch the pseudo code entry address of the function code from table $0a0-$0af (into R0R1)
          inc 8
          jms $173		;read the overflow bit, CY=SR.S2.bit0
          ldm 0
          wmp			;put RAM1.port=0 (clear status lamps)
          ldm 1		;ACC=1
          cmc			;CY=!(overflow)
          ral			;ACC=3 (!overflow) or ACC=2 (overflow)
          kbp			;ACC=15 (!overflow) or ACC=2 (overflow)
          add 5		;adding the function code
					;if there is no overflow, all functions set the CY flag
					;if there is overflow, only "C" or "CE" functions set the CY flag
          jcn C0 $000		;jump, if overflow blocks the new function
          clb
          nop
          nop

;----------------------------------------------------------------------------------------------------------------------------------
;Basic pseudo code engine with keyboard handling
;
;	usage of registers:
;		R0R1 - pseudo code instruction pointer
;		R2R3 - pseudo instruction code
;		R4   - parameter (defined by the last pressed button)
;		R5   - function code (defined by the last pressed button)
;		R6R7 - $20 - points to DR
;		R8R9 - $10 - points to WR
;		R12  - printer drum sector counter
;		ACC  - 0
;		CY   - 0
;
;		R10,R11,R13,R14,R15 - generally usable registers
;		(R10R11 - digit point counter)
;		(R13 - digit, used for shifters, loop counting)
;		(R14 - rounding indicator)
;
;Pseudo code interpreter logic:
;
;Pseudo instruction codes are fetched from the address 300-3ff, based on the R0R1 instruction pointer. The pseudo instruction codes
;are executed as CPU native assembly instructions by calling a subroutine and jumping to address $100+code. At the end of the
;execution of a pseudo instruction, the pseudo code instruction pointer is incremented by 1. If the previous pseudo instruction
;returned ACC with 0 value, the execution is continued from the incremented address, otherwise the data byte on the incremented
;address is understood as a pseudo code jump address, which is conditionally executed. If the previously returned CY was 1, it is
;copied into the instruction pointer, otherwise it is skipped by increasing the instruction pointer again.
;----------------------------------------------------------------------------------------------------------------------------------

$04b: jcn TZ $04f		;wait for the inactive printer drum sector signal
$04d: jms $0b0		;keyboard handling
$04f: fim 3< $20
          fim 4< $10
          jms $300		;fetch the pseudo instruction code into R2R3
          jms $100		;execute the associated routine
$057: isz 1 $05a		;inc R0R1, pseudo code instruction pointer
          inc 0


$05a: jcn AZ $04b		;jump back, if ACC returned by the pseudo instruction was 0
          tcc
          jcn AZ $057		;if CY returned by the pseudo instruction was 0, R0R1 is incremented again
				;(the jump address is skipped)
          jun $302		;if CY was set to 1, implement it as a pseudo code jump instruction...


$061: ldm 4		;piece of code, executed when no row is active in the actual column of keyboard matrix
          jun $0d4		;4 is the number of buttons in one column

;	i4003 shift register handling
;
;	bit0=keyboard matrix shifter clock
;	bit1=shifter data
;	bit2=printer hammer shifter clock

$064: ldm 3		;shift high bit into keyboard shifter (Clock=1, Data=1)
$065: src 4<		;R8R9 selects ROM0
          wrr			;assert shifter
          ldm 0		;Clock=0, Data=0
$068: wrr			;assert shifter
          bbl 0

;
;Synchronization with the spinning printer drum. Called strictly after the sector signal becomes inactive. Increment R12, the
;printer sector counter. Wait for a short time, and check the state of the index signal. If it is active, clear R12.
;

$06a: inc 12		;R12, the printer drum sector counter is incremented
          fim 1< $20
$06d: src 1<
          rdr			;read ROM2 input port
          rar			;index signal is rotated into CY
          isz 3 $06d		;jump back 15 times (short wait)
          jcn C0 $076		;jump, if index signal is inactive
          clb
          xch 12		;clear R12, the printer drum sector counter
$076: bbl 0

;
;piece of code for the keyboard matrix handling, buffer clearing, when two buttons are pressed at the same time
;

$077: ld 9		;check the status of the current row
          jcn AZ $0d9		;go back to the next row, if no button is pressed in this column
					;continue, if two buttons are simultaneously pressed in different columns
$07a: fim 4< $00		;clear the keyboard buffer
          clb
          jms $14a		;initialize the keyboard buffer (clear KR.M0-F, KR.S0-1)
          jun $0f7		;jump to exit from keyboard handling

;
;	Keyboard decode table for translating the keyboard scan code into function code and parameter
;	
;	upper half byte=parameter
;	lower half byte=function code
;

= $bb		;CM
= $c7          ;RM
= $63          ;M-
= $53          ;M+
= $19		;SQRT
= $1a          ;%
= $68          ;M=-
= $58          ;M=+
= $05		;diamond
= $41          ;/
= $31          ;*
= $18          ;=
= $22		;-
= $12          ;+
= $05          ;another diamond
= $0c          ;000
= $9d		;9
= $6d          ;6
= $3d          ;3
= $bd          ;.
= $8d		;8
= $5d          ;5
= $2d          ;2
= $06          ;00
= $7d		;7
= $4d          ;4
= $1d          ;1
= $0d          ;0
= $ad		;S
= $a4          ;EX
= $0e          ;CE
= $bf          ;C

;
;	table for translating the function code into pseudo code entry address
;
;Note: table theoretically is started at address 0a0, but the first entry is not used

= $06		;div/mul
= $91		;+/-
= $98		;M+/M-
= $f1		;Ex
= $cd		;diamond
= $d7		;00
= $fd		;RM
= $8a		;=,M=+/M=-
= $05		;Sqrt
= $61		;%
= $f9		;CM
= $d7		;000
= $d7		;digit
= $ca		;CE
= $c5		;C

;----------------------------------------------------------------------------------------------------------------------------------
;Keyboard handling
;
;This part checks the first 8 columns of the keyboard matrix, and calculates the scan code based on the position of the button in
;the matrix. When a button is pressed, the scan code is placed into the keyboard buffer stored in KR. When two buttons are pressed
;or held down simultaneously, the buffer is cleared.
;
;This is synchronized to the printer drum rotation and is called strictly after checking the sector signal (TEST pin of CPU).
;Typically after a "lback1: jcn TZ lback1" loop, so the sector signal just became inactive, and terminated after a
;lback2: jcn TN lback2 loop, when the sector signal becomes active.
;----------------------------------------------------------------------------------------------------------------------------------

$0b0: jms $06a		;R12 synchronization with the printer drum sectors
$0b2:     fim 4< $07
$0b4: jms $064		;shift one high bit into keyboard shifter
          isz 9 $0b4		;loop back, (gives 9 pulses, deactivates the entire keyboard shifter except last column)
          fim 3< $18		;R6=1 for selecting ROM1, R7=loop counter (16-8=8 columns are checked)
          fim 1< $00		;Clear R2 and R3, scan code counter
          ldm 1
          jms $065		;shift one low bit into keyboard shifter (select the first column, other columns are high)

$0bf: src 3<
          rdr			;Read ROM1 port, rows of the selected keyboard column
          kbp			;Decode the lines (0->0, 1->1, 2->2, 4->3, 8->4, rest->15)
          xch 9		;place the code into R9
          ld 2		
          ral			;R2 bit3 is shifted into CY, highest bit of possible scan code
          tcc
          jcn AN $077		;jump, if a pressed button has already been collected (and may continue at $0d9)
          ld 9
          isz 9 $0cd		;inc R9, and jump, if maximum one column is active
          jun $07a		;jump to clear the buffer and exit from the keyboard processing
					;(two buttons are pressed in the same column)
$0cd: jcn AZ $061		;jump, if none of the lines are active (ACC=4, and continue at $0d4)
          xch 2
          ral
          stc
          rar
          xch 2		;R2.bit3 is set to high (indicating, that a button is pressed)
$0d4: add 3		;ACC=1..4, if line is decoded, or 4, if no line is active
          xch 3		;adding ACC to scan code counter, R3=lower half
          ldm 0
          add 2		;adding carry to the upper half
          xch 2
$0d9: jms $064		;shift one high bit into keyboard shifter (select the next column in the matrix)
          isz 7 $0bf		;loop back, check the next columns of the matrix

          src 4<		;select the keyboard buffer
          ld 2		;R2.bit3 indicates, if a button is pressed
          ral			
          tcc
          jcn AZ $0f8		;jump, if no button is pressed (clear the keyboard pressing status)
          rd3			;check KR.S3, the keyboard pressing status
          iac			;ACC=1,CY=0 (when KR.S3=15) or ACC=0,CY=1 (when KR.S3=0)
          tcc			;ACC=0 or ACC=1
          jcn AN $0f7		;jump, if the keyboard pressing status is 15 (a button is held down)
          rd0			;a button is pressed right now, it should be placed into the keyboard buffer
          xch 9		;R9=KR.S0, the keyboard buffer pointer
          src 4<
          ld 3
          wrm			;write R3 (lower half of the scan code) into the buffer
          inc 9
          src 4<
          rdm			;read next byte, and if it is not 0, then
          jcn AN $07a		;jump to clear the buffer and exit from the keyboard processing (overrun case)
          ld 2
          wrm			;write R2 (upper half of the scan code) into the buffer
          inc 9
          ld 9
          wr0			;KR.S0=R9 -> store the incremented buffer pointer
$0f7: ldm 15		;KR.S3=15 -> a button is held down
$0f8: wr3			;write the keyboard pressing status
          fim 4< $00		;exit from the keyboard check, initialize R6R7 -> WR, R8R9 -> KR
          fim 3< $10
$0fd: jcn TN $0fd		;wait for the active printer drum sector signal
          bbl 0

$100: jin 1<		;jump to the pseudo instruction code associated routine

;
;	Store the working register into another register.
;
;BPC_01:	MOV IR,WR
;BPC_02:	MOV CR,WR
;BPC_03:	MOV RR,WR
;BPC_04:	MOV DR,WR

$101: ld 5		;target=IR (function code+4), load function code into ACC
$102: iac			;target=CR
$103: iac			;target=RR
$104: add 6		;target=DR
          xch 8		;source and destination is exchanged
          xch 6
          jun $10e		;jump to copy numbers

;
;	Load the content of a register into the working register
;
;BPC_09:	MOV WR,MR
;BPC_0A:	MOV WR,TR
;BPC_0B:	MOV WR,SR
;BPC_0C:	MOV WR,CR
;BPC_0D:	MOV WR,RR
;BPC_0E:	MOV WR,DR

$109: inc 6		;source=MR
$10a: inc 6		;source=TR
$10b: inc 6		;source=SR
$10c: inc 6		;source=CR
$10d: inc 6		;source=RR
$10e: src 3<		;source=DR,  move number into another number, NR(R8)=NR(R6)
$10f: rdm
$110: src 4<
          wrm			;number is moved digit by digit
          inc 9
          isz 7 $10e		;loop for all digits

          src 3<		;copy status character 0-1
          rd0			;plus/minus sign 
          xch 3
          rd1			;place of digit point
          src 4<
          wr1
          xch 3		;R3=place of plus/minus sign
$11c: wr0
          bbl 0

;
;	Adding two numbers
;
;BPC_1E:	ADD IR,WR
;BPC_21:	ADD DR,WR

$11e: ldm 4		;target=IR	(function code + 4)
          add 5
          xch 6

$121: src 4<		;NR(R6)=NR(R6)+NR(R8), two numbers are added digit by digit
          rdm
          src 3<
          adm			;adding and daa correcting one digit
          daa
          wrm
          inc 9
          isz 7 $121		;loop for all digits
          clc
          bbl 0

;
;	Subtracting two numbers
;
;BPC_2C:	SUB WR,IR, jump, if result is not negative (R13 is incremented at jump)
;BPC_31:	SUB IR,WR, jump, if result is not negative (R13 is incremented at jump)
;BPC_34:	SUB DR,WR, jump, if result is not negative (R13 is incremented at jump)

$12c: ldm 4
          add 5
          xch 8		;source is set to function code + 4
          jun $133		;target is set to 1

$131: ldm 4
          add 5
$133: xch 6		;target is set to function code + 4

$134: stc			;NR(R6)=NR(R6)-NR(R8), two numbers are subtracted digit by digit
$135: tcs			;ACC=9+CY (10 or 9), CY=0
$136: src 4<
          sbm			;ACC=10(9)-NR(R8).M(R9)
          clc
          src 3<
          adm			;ACC=NR(R6).M(R7)+(10(9)-NR(R8).M(R9))
          daa
$13c: wrm			;NR(R6).M(R7)=daa adjusted result
          inc 9
          isz 7 $135		;loop for all digits

$140: jcn C0 $143		;skip R13 incrementing, if last digit does not generate carry
          inc 13
$143: bbl 1		;prepare pseudo code jump

;
; clear a register including status character 0 and 1
;
;BPC_44:	CLR MR	(MR=0)
;BPC_45:	CLR TR	(TR=0)
;BPC_46:	CLR SR	(SR=0)
;BPC_47:	CLR CR	(CR=0)
;BPC_48:	CLR RR	(RR=0)
;BPC_49:	CLR DR	(DR=0)
;BPC_4A:	CLR WR	(WR=0)

$144: inc 8		;target=MR
          inc 8		;target=TR
$146: inc 8		;target=SR
$147: inc 8		;target=CR
$148: inc 8		;target=RR
$149: inc 8		;target=DR

$14a: src 4<		;NR(R8).M(R9)=ACC (=0)
          wrm			;clearing the number digit by digit
          isz 9 $14a		;loop for all digits
          wr0			;clear sign
          wr1			;clear place of digit point
          bbl 0

;
;	On digit left shift. The number is shifted through R13
;
;BPC_51:	SHL RR	one digit left shift of RR with R13
;BPC_52:	SHL DR	one digit left shift of DR with R13
;BPC_53:	SHL WR	one digit left shift of WR with R13

$151: inc 8		;target=RR
$152: inc 8		;target=DR

$153: src 4<
          rdm			;load current digit into ACC
          xch 13		;previous and current digit is exchanged between ACC and R13
          wrm			;save the previous digit
          isz 9 $153		;loop for next digits
          bbl 0


;
;	On digit right shift. The number is shifted through R13
;
;
;BPC_5A:	SSR RR	one digit right shift of 14 digit length RR with R13 (R13 is shifted into digit 14)
;BPC_5D:	SHR RR	one digit right shift of RR with R13 (0 is shifted from right)
;BPC_5E:	SHR DR	one digit right shift of DR with R13 (0 is shifted from right)
;BPC_5F:	SHR WR	one digit right shift of WR with R13 (0 is shifted from right)

$15a: ldm 14		;only 14 digits are shifted
          xch 9
          ld 13
$15d: inc 8		;target=RR
$15e: inc 8		;target=DR

$15f: xch 13		;one digit right shift of NR(R8).M(R9) with R13
          ld 9
$161: dac			;decrement R9, loop counter
          clc
          xch 9
          src 4<
          rdm			;load current digit into ACC
          xch 13		;previous and current digit is exchanged between ACC and R13
          wrm			;save the previous digit
          ld 9
          jcn AN $161		;loop for next digits
          bbl 0

;
;	checking, whether status character 2 of certain RAM register is 0. CY=1, if it is 0
;
;BPC_6C:	JPC MODENN	jump, if RR.S2=0
;BPC_6D:	JPC MOPN	jump, if DR.S2=0
;BPC_6E:	JPC NTRUNC	jump, if WR.S2=0

$16c: inc 8		;source=RR
$16d: inc 8		;source=DR
$16e: src 4<		;source=WR
          rd2			;read status character 2
          dac			;decrement, only 0->15 leaves CY=0
          cmc			;complement carry, the pseudo jump condition
          bbl 1		;prepare pseudo code jump

;
;	read bit 0 of status character 2 of certain RAM into CY
;
;BPC_73:	JPC OVFL	jump, if SR.S2.bit0>0
;BPC_74:	JPC MENTDP	jump, if CR.S2.bit0>0
;BPC_75:	JPC MODEMD	jump, if RR.S2.bit0>0
;BPC_76:	JPC MOPMUL	jump, if DR.S2.bit0>0
;BPC_77:	JPC ROUND	jump, if WR.S2.bit0>0

$173: inc 8		;source=SR
$174: inc 8		;source=CR
$175: inc 8		;source=RR
$176: inc 8		;source=DR
$177: src 4<
          rd2			;read status character 2
          rar			;rotate bit 0 into carry, the pseudo jump condition
          bbl 1		;prepare pseudo code jump

;
;	read bit 3 of status character 2 of certain RAM into CY
;
;BPC_7B:	JPC MOPCONST	jump, if DR.S2.bit3>0

$17b: src 3<
$17c: rd2			;read status character 2
          ral			;rotate bit 3 into CY, the pseudo jump condition
          bbl 1		;prepare pseudo code jump

;
;	clear status character 2 of certain number
;
;BPC_7F:	CLR OVFL	clear SR.S2
;BPC_82:	CLR MOP		clear DR.S2

$17f: inc 6		;target=SR
$180: inc 6		;target=CR
$181: inc 6		;target=RR
$182: src 3<		;target=DR
          wr2			;write status character 2 of target (in fact it is cleared as ACC=0)
          bbl 0

;
;	set status character 2 to a value
;
;BPC_85:	SET OVFL	SR.S2=1, set overflow
;BPC_86:	SET MENTDP	CR.S2=1, set that number is entered with digit point
;BPC_87:	SET MODEMD	RR.S2=1, set that number is used for mul/div operation
;BPC_8A:	SET MODEAS	RR.S2=8, set that number is used for add/sub operation
;BPC_8D:	SET MOPPAR	DR.S2=function parameter, set the multiplication/division from function parameter
;BPC_90:	SET MOPCONST	DR.S2.bit3=1, set that multiply/divide operation is with constant value

$185: inc 6		;target=SR
$186: inc 6		;target=CR
$187: ldm 1		;target=RR
          jun $181		;set NR(R6+1).S2=1

$18a: ldm 8
          jun $181		;set NR(R6+1).S2=8

$18d: ld 4		;ACC = parameter
          jun $182		;set NR(R6).S2=parameter

$190: src 3<
          rd2			;set high bit of NR(R6).S2 to 1
          ral
          stc
          rar
          wr2
          bbl 0

;
;	checking, whether the number contains any nonzero digit
;
;BPC_97:	JPC NBIG_IR	jump, if digits 14-15 of IR does not contain any value
;BPC_9A:	JPC NBIG_WR	jump, if digits 14-15 of WR does not contain any value
;BPC_9E:	CLR DIGIT + JPC NBIG_DR		jump, if digits 14-15 of DR does not contain any value. R13=0
;BPC_A0:	CLR DIGIT + JPC ZERO_DR		clear R13 and jump, if DR does not contain any value
;BPC_A2:	JPC ZERO_WR	jump, if WR does not contain any value

$197: ldm 4
          add 5		;ACC=function code or function code + 4
          xch 8		;R8 points to IR

$19a: ldm 14
          xch 9		;R9=14
          jun $1a2

$19e: ldm 14
          xch 9		;R9=14 and ACC=previous R9 (=0)

$1a0: xch 13		;save ACC=0 into R13
          inc 8

$1a2: src 4<		;check whether the number contains any digit. Return jump with CY=1, if the number is empty
$1a3: ldm 15
          adm			;number is added in binary mode to the maximum value digit by digit
          isz 9 $1a2		;loop for the rest of digits

;BPC_A7:	JMP	Unconditional jump

$1a7: cmc			;negate the pseudo jump condition
          bbl 1		;prepare pseudo code jump

;BPC_A9:	JPC BIG_DIGIT	Jump, if R13>9

$1a9: ld 13		;load R13
$1aa: daa			;set CY=1, the pseudo jump condition, if R13>9
$1ab: bbl 1		;prepare pseudo code jump

;BPC_AC:	JPC ZERO_DIGIT + DEC DIGIT	decrement R13 and jump, if R13 was 0 before the decrement

$1ac: ld 13
          dac			;ACC=decremented R13, will be placed back to R13

;BPC_AE:	CLR DIGIT + JMP		clear R13 and jump

$1ae: xch 13
          cmc			;negate the pseudo jump condition
          bbl 1		;prepare pseudo code jump

;BPC_B1:	JPC NEWOP	jump, if function code < 8 (new add/sub/mul/div operation)

$1b1: ldm 7
          sub 5		;R5=function code; set CY=1, the pseudo jump condition, if R5<8
          bbl 1		;prepare pseudo code jump

;BPC_B4:	JPC MEMOP	jump, if function parameter > 3 (new memory operation)

$1b4: ldm 12
          add 4		;R4=function parameter; set CY=1, the pseudo jump condition, if R4>3
          bbl 1		;prepare pseudo code jump

;BPC_B7:	JPC ROTFC	rotate the function code one bit right, jump if the next bit is 0

$1b7: ld 5		;rotate R5=function code with 1 bit right
          rar			;bit 0 is rotated to CY
          xch 5		;rotated value is saved back
          cmc			;complement CY, the pseudo jump condition
          bbl 1		;prepare pseudo code jump

;BPC_BC:	JPC ODDPAR	jump, if bit0 of parameter>0

$1bc: ld 4		;load R4=parameter into ACC
$1bd: rar			;rotate bit 0 into CY, the pseudo jump condition
          bbl 1		;prepare pseudo code jump

;BPC_BF:	SET DP_IR	set digit point place of indirect register (IR.S1=R11)

$1bf: ldm 4
          add 5		;ACC=function code + 4
          xch 8		;set it to target register

;BPC_C2:	SET DP_WR	set digit point place of working register (WR.S1=R11)

$1c2: src 4<
          ld 11
          wr1			;write place of digit point
          bbl 0

;BPC_C6:	GET DP_WR	get digit point place of working register (R11=WR.S1)

$1c6: src 4<
          rd1			;read place of digit point
          xch 11
          bbl 0

;BPC_CA:	INC DPCNT	increment digit point counter (increment R10R11)

$1ca: isz 11 $1cd		;increment lower part, jump, if not zero
          inc 10		;increment upper part
$1cd: bbl 0

;BPC_CE:	JPC NBIG_DPCNT	jump, if R10R11<14
;BPC_CF:	JPC ZERO_DPCNT	jump, if R10R11=0

$1ce: ldm 13
$1cf: sub 11		;subtract the lower part from 13
          cmc
          ldm 0		;subtract the upper part from 0
          sub 10		;pseudo jump condition is set at no borrow
$1d3: bbl 1		;prepare pseudo code jump

;Pseudo instruction code jump table. Normally pseudo instruction code execution can be directly started on address range $100-$1ff.
;This is a jump table to functions, which are implemented on other pages

$1d4: jun $2d3		;BPC_D4: jump, if WR and IR have different sign
          nop
$1d7: jun $294		;BPC_D7: digit functions
$1d9: jun $2a3		;BPC_D9: WR=TR, clear SR & TR; recall main total
$1db: jun $2aa		;BPC_DB: Set function code=3, and jump
$1dd: jun $2ae		;BPC_DD: decrement R10R11
$1df: jun $2b3		;BPC_DF: WR.S1=WR.S3, R10R11=difference between required an actual digit point
$1e1: jun $2b9		;BPC_E1: digit point counter adjust for division
$1e3: jun $2ca		;BPC_E3: digit point counter adjust for multiplication
$1e5: jun $2de		;BPC_E5: Sign of result register for multiplication or division + R13=15
$1e7: jun $2e7		;BPC_E7: complement WR.S0 (change the sign of WR)
$1e9: jun $2ec		;BPC_E9: rounding, if R13>4 then increment WR (and R14 too)
$1eb: jun $246		;BPC_EB: end of printing with advancing the paper and R10R11=0, R14R15=0
$1ed: jun $400		;BPC_ED: square root (optional)

;BPC_EF: CLR MENT + CLR OVFL + RET  clear CR.S2, SR.S2, TR.S2 and exit
;BPC_F1: CLR MODE + CLR MENT + RET	clear RR.S2, CR.S2 and exit
;BPC_F3: CLR MODE + RET		clear RR.S2 and exit

$1ef: jms $180		; R6=R6+2, clear status character 2 of NR(R6)
$1f1: jms $181		; R6=R6+1, clear status character 2 of NR(R6)
$1f3: jms $181		; R6=R6+1, clear status character 2 of NR(R6)
          fim 5< $00
          jun $000		;exit from the pseudo code interpreter

;BPC_F9..FF: Printing functions:

;BPC_F9:	PRN FPAR,C	print number with function parameter and char=11 "C" in last column (not used)
;BPC_FA:	PRN FPAR,MEM	print number with function parameter and char=12 "M" in last column 
;BPC_FB:	PRN FPAR,FCODE	print number with function parameter and empty character in last column
;BPC_FC:	PRN FPAR	print number with function parameter and empty character in last column
;BPC_FD:	PRN ROUND,FPAR	print number with optional rounding char and function parameter in last column
;				(determined by R14.bit0: 0=empty, 1=code 7 (rounding up char))
;BPC_FE:	PRN FCODE	print number with function code and empty character in last column
;BPC_FF:	PRN OVFL	print unimplemented number (dots with empty extra columns)

          inc 15		; (R15 will be 9)
$1fa: inc 15		; (R15 will be 10)
$1fb: inc 15		; (R15 will be 11)
$1fc: inc 15		; (R15 will be 12)
$1fd: inc 15		; (R15 will be 13)
$1fe: inc 15		; (R15 will be 14)
$1ff: xch 15		; (R15 will be 15)
          cma
          xch 15		; R15 is complemented

;setting the printing method, determined by the value in R15 (and R14=rounding)

          isz 15 $210
					;R15 was 15: unimplemented number (overflow/divide by 0)
          ldm 10		;load 10 (code of digit point)
          jms $14a		;fill WR with 10s (WR.S0 too: positive number, WR.S1 too: not used)
          fim 7< $ff		;R14R15=$FF: last two columns will be empty
          xch 10		;R10=10: "place of digit point" would generate a point too
          ldm 15
          xch 9		;R9=15: 14 valid character
          src 4<
          wrm			;WR.M15=0
          jun $22c		;jump to start the printing

$210: isz 15 $217
					;R15 was 14: number with function code and empty character in last column
          ldm 15
          xch 15		;R15=15 (empty column)
          ld 5		;function code
          jun $226		;jump to save ACC into R14

$217: ldm 1
          add 15
          tcc
          jcn AZ $225		;jump, if R15<13
					;      number with function parameter and a character (can be empty) in the last column

					;R15 was 13: number with optional rounding char and function parameter in the last column
          ld 4
          xch 15		;R15=function parameter
          xch 14		;ACC=R14, set previously by the rounding (0=truncating, 1=rounding up)
          rar			;CY=R14.bit0
          cmc			;CY=complement of R14.bit0
          ldm 14
          rar			;ACC=8*CY+7  (7=rounding up char, 15=empty char)
          jun $226		;jump to save ACC into R14

$225: ld 4		;load parameter into R14
$226: xch 14		;save ACC into R14, code of character in last column
          src 4<
          rd1
          xch 10		;R10=place of digit point
          rd1
          xch 11		;R11=place of digit point

$22c: jcn TZ $22c		;wait for the inactive printer drum sector signal
          ldm 2
          xch 13		;R13=2
          rd0			;read WR.S0 (sign)
          rar
          tcc			;ACC=0 (WR positive) or 1 (WR negative)
          wmp			;switch the printing color into red in case of WR has minus sign, output to RAM0 port
          jms $0b0		;keyboard handling
          inc 8		;R8R9 points to WR again (keyboard handling puts it to KR)
					;R6R7 points to WR too

$237: inc 11		;search for the place of the first digit before the digit point, result in R11
          ld 11
          xch 9		;R9=points to part, to be checked (started from place of digit point + 1)
          jms $1a2		;check, whether the remaining part of the number contains any digit
          tcc
          jcn AZ $237		;jump back, if the remaining part of the number is not empty

;by this point:
; R6=1 (select WR)
; R7=0 (used as a digit loop counter)
; R8=1 (select WR)
; R9=0
; R10=place of digit point
; R11=place of first nonzero digit before the digit point+1
; R13=2 (used as a printer sector loop counter)
; R14=character code on column before the last column (or 13..15, if that is empty)
; R15=character code on the last column (or 13..15, if that is empty)

;printing: R13 loop counter for the printer sectors

$23f: jcn TZ $23f		;wait for the inactive printer drum sector signal
          clb
          wmp			;printer control signals are set to inactive
          wrr
          isz 13 $253		;jump to next sector, if there is

;BPC_EB:	PRN ADVANCE + CLR DPCNT		end of printing with advancing the paper and R10R11=0, R14R15=0

$246: fim 5< $0c 		;R10R11=$0C
          fim 7< $00		;R14R15=$00
          ldm 8
$24b: jcn TZ $24b		;wait for the inactive printer drum sector signal
          wmp			;Write RAM0 port, first 8, later 3 times 0 (advance the printer paper with a line)
          jms $0b0		;Keyboard handling
          isz 11 $24b		;loop back
          bbl 0

$253: jms $06a		;R12 synchronization with the printer drum sectors
          xch 8		;clear R8

;printing: R7 loop for the digits - filling the printer shifter for one sector

$256:     ldm 13		;(if R15=13, then the number is empty)
          sub 15		;ACC=13-R15
          clc
          jcn AN $25f		;jump, if R15<>13
          xch 10		;R10=0 (if R15=13, empty columns are printed)
$25c:     ldm 15		;(handling of empty columns)
          jun $261
$25f: src 3<		;(handling of valid digits)
          rdm			;read one digit into ACC
$261:     isz 7 $277		;jump to next digit, if there is still

          ld 10		;pattern of extra two columns are fetched from R14 and R15
          jcn AN $268		;jump, if R10<>0 (digit point is already shifted)
          jms $28f		;shift one inactive column into printer shifter (CY=0)
$268: ld 15
          jms $28a		;if R15=R12, shift 1 into printer shifter else shift 0
          ld 14
          jms $28a		;if R14=R12, shift 1 into printer shifter else shift 0

$26e: jcn TN $26e		;wait for the active printer drum sector signal
          ldm 2
          src 4<
          wmp			;fire printer hammers
          jms $0b2		;Keyboard handling (R7 is cleared!)
          jun $23f		;loop back for the next sectors

$277: jms $28a		;if ACC=R12, shift 1 into printer shifter else shift 0
          ld 10
          jcn AZ $283		;jump, if R10=0 (there is no digit point)
          sub 7
          clc
          jcn AN $283		;jump, if R10<>R7 (digit point is not in this position)

          ldm 10		;shift the digit point into the shifter
          jms $28a		;if R12=10, shift 1 into printer shifter else shift 0

$283: ld 7		;check, whether the loop counter exceeded the number of valid digits
          sub 11
          tcc
          jcn AZ $256		;loop back for the next valid digits
          jun $25c		;loop back for the empty columns

$28a: sub 12		;if ACC=R12, shift 1 into printer shifter else shift 0
          clc
          jcn AN $28f
          stc
$28f: ldm 1		;shift CY into printer shifter
          ral
          ral			;ACC=4+2*CY
          jun $065		;shift one low bit into printer shifter

;BPC_D7:	DIGIT	this function is called, when a digit, "00", "000", digit point or minus sign button is pressed

$294: ld 4
          xch 13		;R13=digit
          fim 3< $40
          src 3<
          rd2			;read CR.S2, digit entry mode status
          jcn AN $2a1		;Jump, if the calculator is already in digit entry mode
          ldm 8
          wr2			;put 8 into the digit entry mode status
          clb
          jms $14a		;clear WR, WRS0, WRS1
$2a1:     jun $1c6		;R11=WR.S1, place of digit point

;BPC_D9:	MOV WR,TR + CLR TR + CLR SR	recall main total (WR=TR, clear SR & TR)

$2a3: jms $10a		;WR=TR
          jms $146		;clear SR (including S0 and S1)
          jms $149		;clear TR (including S0 and S1)
          bbl 0

;BPC_DB:	SET MRMFUNC + JMP	set function code=3 (memory function), and jump

$2aa: ldm 3
          xch 5		;R5=function code is set to 3
          stc			;set CY=1, the pseudo jump condition
          bbl 1		;prepare pseudo code jump

;BPC_DD:	DEC DPCNT		decrement R10R11

$2ae: ldm 1
          xch 3		;R3=1
          xch 11		;ACC=R11
          jun $2c2		;jump to R10R11 adjust

;BPC_DF:	GET DPDIFF	WR.S1=WR.S3, set R10R11 to the difference between required an actual digit point

$2b3: jms $2f9		;read the decimal places of WR and DR (R2=DR.S1, R3=WR.S1), DR is not used
          rd3			;read the required decimal places defined by the digit point switch
          wr1			;set it to WR.S1
          jun $2c2		;jump to R10R11 adjust

;BPC_E1:	GET DPCNTDIV	digit point counter adjust for division (set R10R11 to DR.S1+(13-R11)-WR.S1)

$2b9: jms $2f9		;read the decimal places of WR and DR (R2=DR.S1, R3=WR.S1)
          ldm 13
          sub 11		;ACC=13-R11
          clc
          add 2		;ACC=R2+(13-R11)
          xch 10
          tcc
          xch 10		;R10=carry

; R10R11 adjust: set R10R11 to the difference between required an actual digit point
; 	input:	ACC=required place of digit point
; 		R3=place of digit point of the actual number

$2c2: sub 3
          xch 11		;R11=ACC-R3
          cmc
          xch 10
          sub 9		;borrow is subtracted from the upper half (R9=0)
          xch 10		;R10=R10-(CY)
          clc
          bbl 0

;BPC_E3:	GET DPCNTMUL	digit point counter adjust for multiplication
;				set R10R11 to the sum of digital places (WR, DR and current in R11)

$2ca: jms $2f9		;read the decimal places of WR and DR (R2=DR.S1, R3=WR.S1)
          ld 3
          add 11
          add 2
          xch 11		;R11=R11+R3+R2
          tcc
          xch 10		;R10=0 or 1
          bbl 0

;BPC_D4:	JPC DIFF_SIGN	jump, if WR and IR have different sign (either is minus, the other is plus)

$2d3: ldm 4
          add 5
          xch 6		;R6=function code + 4
$2d6:     src 3<
          rd0			;read the sign of IR
          xch 2
          src 4<
          rd0			;read the sign of WR
          add 2		;bit0 of result is 0, if both number have the same sign
          rar			;rotate bit 0 into CY, the pseudo jump condition
          bbl 1		;prepare pseudo code jump

;BPC_E5:	SET DIVMUL_SIGN + MOV DIGIT,15
;	Sign of result register is set based on the WR and DR for multiplication or division
;	R13 is set to 15 for loop counting

$2de: jms $2d6		;compare WR and DR sign
          tcc
          inc 6		;R6 points to RR
          src 3<
          wr0			;set sign of RR
          ldm 15
          xch 13		;R13=15, used as "loop end" indicator at divide/multiply
          bbl 0

;BPC_E7:	NEG WR	complement sign of working register (change the sign of WR)

$2e7: src 4<
          rd0			;read the sign
          cma			;complement it
          wr0			;write back the new sign
          bbl 0

;BPC_E9:	ROUNDING	increment WR (and R14 too), if R13>4

$2ec: ldm 11
          add 13		;R13 is added to 11
          jcn C0 $2f1		;if R13<5, CY=0, jump to add (??? jump to $2f8 would have been better)
          inc 14		;save also the fact of rounding into R14 

$2f1: ldm 0		;Add CY to WR
          src 4<
          adm
          daa			;add carry and decimal digit by digit
          wrm
          isz 9 $2f1		;loop for the next digits
          bbl 0

$2f9: src 3<		;read the decimal places of WR and DR (R2=DR.S1, R3=WR.S1)
          rd1
          xch 2		;R2=DR.S1
          src 4<
          rd1
          xch 3		;R3=WR.S1
          bbl 0

$300: fin 1<		;fetch the pseudo instruction code into R2R3 and return
          bbl 0

$302:     fin 0<		;fetch the jump address, as the new value of pseudo code instruction pointer into R0R1
          jun $04b		;jump to the WM code interpreter
        
;----------------------------------------------------------------------------------------------------------------------------------
;Detailed analysis of basic pseudo code list.
;----------------------------------------------------------------------------------------------------------------------------------

fn_sqrt:   = $ed    ;SQRT (+ JMP num_dpadj)			;square root of WR is placed into RR
        
fn_muldiv: = $6c 
	   = $14 ;JPC MODENN,md_prn2			;jump, if new number is entered
           = $75 
	   = $0e ;JPC MODEMD,md_prn1			;jump, if mul or div was the last operation
	   = $d9    ;MOV WR,TR + CLR TR + CLR SR		;if add or sub was the last operation, then main total is recalled
           = $fc    ;PRN FPAR
= $a7 
= $0f ;JMP md_exitf
md_prn1:   = $fb    ;PRN FPAR,FCODE
md_exitf:  = $8d    ;SET MOPPAR				;keep the operation (from the parameter) for the next round
md_exitc:  = $04    ;MOV DR,WR					;put the number into DR and CR
= $02    ;MOV CR,WR
= $87    ;SET MODEMD
= $ef    ;CLR MENT + CLR OVFL + RET
md_prn2:   = $fc    ;PRN FPAR
= $6d 
= $0f ;JPC MOPN,md_exitf				;jump, if the other operand is not entered yet
= $7b 
= $0f ;JPC MOPCONST,md_exitf			;jump, at constant calculation (new number for calculation)
= $76 
= $46 ;JPC MOPMUL,mul_start			;jump, if previous operation is multiply

;----------------------------------------------------------------------------------------------------------------------------------
;dividing:	WR <- RR = DR / WR
;
;DR and WR is left adjusted into position WR.M14<>0 and DR.M14<>0, DR is decreased by WR till it becomes negative. WR is added back
;to DR for getting back the smallest non negative DR. The count, how many times it could be decreased gives the next digit of
;result, which is shifted into RR. DR is shifted left for doing the subfunction for the next digit. The same process is repeated
;14 times. Place of digit point of the result is calculated separately. Finally the result from RR is copied to WR.
;----------------------------------------------------------------------------------------------------------------------------------

= $8d    ;SET MOPPAR				;divide is marked into MOP
div_chk0:  = $a2 
	   = $3c ;JPC ZERO_WR,num_overf			;divide by zero would result overflow
= $48    ;CLR RR
= $a0 
= $73 ;CLR DIGIT + JPC ZERO_DR,num_res		;if dividend is zero, the result will be zero too
= $e1    ;GET DPCNTDIV				;digit point initialization for divide
div_chkDR: 
= $9e 
= $32 ;CLR DIGIT + JPC NBIG_DR,div_lshDR		;rotate DR into leftmost position
div_chkWR: 
= $9a 
= $36 ;JPC NBIG_WR,div_lshWR			;rotate WR into leftmost position
= $e5    ;SET DIVMUL_SIGN + MOV DIGIT,15		;sign of result is set
= $51    ;SHL RR					;15 is shifted into the cleared RR, as a mark for loop end
= $51    ;SHL RR
div_loop:  = $34 
= $29 ;SUB DR,WR + JPC NNEG,div_loop + INC DIGIT	;find, how many times the subtraction can be done
= $21    ;ADD DR,WR					;adding back the last unneeded subtract
= $51    ;SHL RR					;next digit of result is shifted into RR
= $a9 
= $3f ;JPC BIG_DIGIT,div_finsh			;if shifted out number>9, end of division
= $52    ;SHL DR					;next digit (shifted out from RR) is shifted into DR
= $a7
= $29 ;JMP div_loop
div_lshDR: = $52    ;SHL DR					;one digit rotate left of DR
= $ca    ;INC DPCNT
= $a7 
= $22 ;JMP div_chkDR
div_lshWR: = $53    ;SHL WR					;one digit rotate left of WR
= $cf 
= $3c ;JPC ZERO_DPCNT,num_overf			;jump if rotate would cause overflow
= $dd    ;DEC DPCNT
= $a7 
= $24 ;JMP div_chkWR

num_overf: = $ff    ;PRN OVFL					;print overflow
= $85    ;SET OVFL					;set overflow flag
= $f1    ;CLR MODE + CLR MENT + RET			;exit

div_finsh: = $5d    ;SHR RR					;rotate the number right

num_dpadj: = $ce
= $73 ;JPC NBIG_DPCNT,num_res			;jump, if the result contains acceptable number of digits
= $dd    ;DEC DPCNT					;otherwise shift the number to right
= $5d    ;SHR RR					;Note: the place of this instruction could have been saved,
= $a7 
= $40 ;JMP num_dpadj				;  if the jump would go back to div_finsh

;----------------------------------------------------------------------------------------------------------------------------------
;multiplication: WR <- RR = DR * WR
;
;As starting WR is copied to RR and DR copied to WR. DR is cleared.
;DR and RR is shifted right. Last digit of RR is placed into R13, WR is added R13 times to DR. The process is repeated 14 times.
;Two 14 digit operand produces maximum 28 digit result. For us the most significant digits are interesting. Therefore the 28 digit
;result is rotated towards the lower digits, till the upper 14 digits contain nonzero digits, the place of digit point is counted
;in R10 and R11. After rotate the result is finally copied to WR.
;----------------------------------------------------------------------------------------------------------------------------------

mul_start: = $8d    ;SET MOPPAR				;multiplication is marked in MOP
mul_st2:   = $03    ;MOV RR,WR
= $e3    ;GET DPCNTMUL				;digit point initialization for multiply
= $e5    ;SET DIVMUL_SIGN + MOV DIGIT,15		;sign of result is set
= $0e    ;MOV WR,DR
= $49    ;CLR DR
= $52    ;SHL DR					;shift R13=15 into DR, but it is immediately shifted into RR
mul_loopn: = $5e    ;SHR DR					;DR-RR is shifted right
= $5a    ;SSR RR
= $a9 
= $56 ;JPC BIG_DIGIT,mul_shres			;jump if R13=15 was shifted out (exit from the loop)
mul_loopd: = $ac 
= $4d ;JPC ZERO_DIGIT,mul_loopn + DEC DIGIT	;multiply the number with one digit
= $21    ;ADD DR,WR					;finally DR=DR+R13*WR
= $a7 
= $51 ;JMP mul_loopd
mul_shres:
= $a0 
= $40 ;CLR DIGIT + JPC ZERO_DR,num_dpadj		;rotate nonzero digits from DR to RR
= $cf 
= $3c ;JPC ZERO_DPCNT,num_overf			;jump if overflow occurred
= $5e    ;SHR DR					;DR-RR is shifted right
= $5a    ;SSR RR
= $dd    ;DEC DPCNT
= $a7 
= $56 ;JMP mul_shres

dp_mark:   = $86    ;SET MENTDP				;digit point flag
= $f3    ;CLR MODE + RET

fn_percnt: = $fe    ;PRN FCODE
= $ca    ;INC DPCNT					;increment the digit point place counter by 2
= $ca    ;INC DPCNT
= $a7 
= $67 ;JMP num_md

num_prm:  = $fe    ;PRN FCODE
num_md:   = $7b 
= $6f ;JPC MOPCONST,num_mul2			;jump at const divide/multiply
= $90    ;SET MOPCONST
num_mul1:  = $76 
= $47 ;JPC MOPMUL,mul_st2			;jump to multiply, if previous operation is multiply
= $02    ;MOV CR,WR					;save the divisor for constant divide
= $a7 
= $1c ;JMP div_chk0				;jump to divide
num_mul2:  = $04    ;MOV DR,WR					;save the number into DR
= $0c    ;MOV WR,CR					;recall previous number from CR
= $a7 
= $6a ;JMP num_mul1				;jump to divide or multiply

num_res:   = $0d    ;MOV WR,RR					;copy the RR result to WR
= $c2    ;SET DP_WR					;set the digit point position from R10R11
= $b1 
= $10 ;JPC NEWOP,md_exitc			;jump to exit at new mul and div operation
= $b4 
= $7b ;JPC MEMOP,num_adj				;jump to adjust at M=+/M=-
= $6e 
= $9e ;JPC NTRUNC,num_pra2			;jump to result print, if digit point should not be adjusted
num_adj:   
= $df    ;GET DPDIFF				;WR.S1=WR.S3, set R10R11 to the difference between required an actual digit point
								;Rotate the number into the required digit point place
num_rotl:  = $cf 
= $9a ;JPC ZERO_DPCNT,num_pra1			;jump, if number is at the right digit point place
= $ce 
= $84 ;JPC NBIG_DPCNT,num_lrot

= $ca    ;INC DPCNT					;Rotate right
= $5f    ;SHR WR
= $a7 
= $7c ;JMP num_rotl

num_lrot:   = $dd    ;DEC DPCNT					;Rotate left
= $53    ;SHL WR
= $9a 
= $7c ;JPC NBIG_WR,num_rotl
= $a7 
= $3c ;JMP num_overf				;print overflow

fn_memeq:  = $6c 
= $66 ;JPC MODENN,num_prm			;jump, if new number is entered
= $75 
= $66 ;JPC MODEMD,num_prm			;jump, if there is started mul/div operation
= $d9    ;MOV WR,TR + CLR TR + CLR SR		;recall main total
= $a7 
= $98 ;JMP fn_memadd				;jump to add functions
               
;entry address at add or subtract button
fn_addsub: = $6c 
= $98 ;JPC MODENN,fn_memadd			;jump, if new number is enterer
= $75 
= $97 ;JPC MODEMD,clr_md				;jump, if there is started mul/div operation
= $a7 
= $98 ;JMP fn_memadd				;jump to add functions

clr_md:    = $82    ;CLR MOP					;ignore previous mul/div operation

fn_memadd: = $ae 
= $7b ;CLR DIGIT + JMP num_adj			;jump to adjust the number to the required digits

num_pra1:  = $b1 
= $aa ;JPC NEWOP,num_pra3			;jump at new add/sub operation
= $77 
= $a3 ;JPC ROUND,num_round			;jump to rounding, if rounding switch is in that position

num_pra2:  = $fd    ;PRN ROUND,FPAR
= $eb    ;PRN ADVANCE + CLR DPCNT
= $b4 
= $a8 ;JPC MEMOP,mem_add				;jump to change the function code at M=+/M=-/M+/M-
= $f1    ;CLR MODE + CLR MENT + RET

num_round: = $e9    ;ROUNDING					;do the rounding based on the last shifted out digit in R13
= $9a 
= $9e ;JPC NBIG_WR,num_pra2			;may generate overflow too
= $a7 
= $3c ;JMP num_overf				;print overflow

mem_add:   = $db 
= $ab ;SET MEMFUNC + JMP do_prpadd		;Set M+/M- function code

;----------------------------------------------------------------------------------------------------------------------------------
;add/subtract functions:
;
;By this point, numbers are shifted into the place determined by the digit point switch, thus no shifting is needed.
;
;!!! Note, if the digit point switch is changed during an operation, the numbers are incorrectly added/subtracted.
;
;	function code	    parameter		pre1		operation1	pre2	operation2
;+		2		1		RR=WR		TR=TR+WR	WR=RR	SR=SR+WR
;-		2		2		RR=WR		TR=TR-WR	WR=RR	SR=SR-WR
;M+ (M=+)	3		5		RR=WR		MR=MR+WR
;M- (M=-)	3		6		RR=WR		MR=MR-WR
;----------------------------------------------------------------------------------------------------------------------------------

num_pra3:   = $fc    ;PRN FPAR
do_prpadd: = $c6    ;GET DP_WR

do_addsub: = $03    ;MOV RR,WR

= $bc 
= $b0 ;JPC ODDPAR,skp_neg			;skip negate the number at add
= $e7    ;NEG WR					;negate the number at sub (convert it to add)
skp_neg:   = $d4 
= $b7 ;JPC DIFF_SIGN,do_sub			;jump, when adding a negative and a positive number

= $1e    ;ADD IR,WR					;ADD - may generate overflow
= $97 
= $bd ;JPC NBIG_IR,do_next
								;jump, if there is no overflow
= $31 
= $3c ;SUB IR,WR + JPC NNEG,num_overf + INC DIGIT	;correct back IR at overflow and jump always

do_sub:    = $31 
= $bd ;SUB IR,WR + JPC NNEG,do_next + INC DIGIT	;SUB - never generates overflow
= $1e    ;ADD IR,WR
= $2c 
= $bc ;SUB WR,IR + JPC NNEG,do_cont		;always goes to the next instruction
do_cont:   = $01    ;MOV IR,WR

do_next:   = $0d    ;MOV WR,RR					;take the original number from RR
= $bf    ;SET DP_IR					;set the place of digit point

= $b4 
= $ff ;JPC MEMOP,do_exit				;exit at memory function
= $b7 
= $ac ;JPC ROTFC,do_addsub			;do the addsub for the next number, if there is instruction for it
= $8a    ;SET MODEAS				;mark, that last operation was add or sub
= $ef    ;CLR MENT + CLR OVFL + RET			;exit

;
;"C" Clear:	clear WR,DR,SR,TR and print. it does not clear RR,CR and RR.S2
;
fn_clear:  = $82    ;CLR MOP
= $49    ;CLR DR
= $d9    ;MOV WR,TR + CLR TR + CLR SR
= $4a    ;CLR WR
= $fc    ;PRN FPAR

;
;"CE" Clear:	clear WR, RR.S2, CR.S2
;
fn_cleare: = $4a    ;CLR WR
= $7f    ;CLR OVFL
= $f1    ;CLR MODE + CLR MENT + RET

;
;"Diamond" - subtotal: print the number or the subtotal
;
fn_diamnd: = $6c 
= $d5 ;JPC MODENN,dm_prn2			;jump in entry mode, print the number, and close the entry mode
= $75 
= $d3 ;JPC MODEMD,dm_prn1			;jump in mul/div mode, print the number, and init
= $0b    ;MOV WR,SR					;in add/sub mode, recall the subtotal number from SR and clear SR
= $46    ;CLR SR
dm_prn1:   = $fc    ;PRN FPAR
= $ef    ;CLR MENT + CLR OVFL + RET
dm_prn2:   = $fd    ;PRN ROUND,FPAR
= $f1    ;CLR MODE + CLR MENT + RET
               
;entry address at digit, digit number, minus sign button
;		fuction code		parameter
;0..9		13			0..9
;sign		13			10
;digit point	13			11
;00		6			0
;000		12			0

fn_digit:  = $d7    ;DIGIT					;save digit into R13, place of digit point (WR.S1) into R11
								;at first entry: WR=0, CR.S2=8
= $a9 
= $df ;JPC BIG_DIGIT,dig_dpsgn			;jump at digit point, minus sign

dig_numsh: = $53    ;SHL WR					;rotate the number into WR
= $9a 
= $e3 ;JPC NBIG_WR,dig_chkdp			; jump, if there is now overflow
= $5f    ;SHR WR					;at overflow, rotate back the number (additional digits are lost)
= $f3    ;CLR MODE + RET				;mark that new number is entered since the last operation, and exit

dig_dpsgn: = $bc 
= $5f ;JPC ODDPAR,dp_mark			;digit point button is pressed

= $e7    ;NEG WR					;minus sign button is pressed
= $f3    ;CLR MODE + RET				;mark that new number is entered since the last operation, and exit

dig_chkdp: = $74 
= $e8 ;JPC MENTDP,dig_incdp			;if digit point is already entered, jump to adjust it
= $a7 
= $ee ;JMP dig_nextd

= $00    ;(unimplemented, never used)

dig_incdp: = $ca    ;INC DPCNT					;adjust the digit point place with one digit more
= $ce 
= $ed ;JPC NBIG_DPCNT,dig_savdp
= $dd    ;DEC DPCNT					;if already too much digit entered after the digit point,
= $5f    ;SHR WR					; ignore the new digit
dig_savdp: = $c2    ;SET DP_WR					;save the place of digit point

dig_nextd: = $b7 
= $da ;JPC ROTFC,dig_numsh			;function code contains, how many '0's has to be entered yet
								;implementation of button '00' and '000' is here
= $f3    ;CLR MODE + RET				;mark that new number is entered since the last operation, and exit

;
;Exchange function:	CR=WR, WR <- RR <- DR <- WR
;
fn_ex:     = $fd    ;PRN ROUND,FPAR
= $02    ;MOV CR,WR					;CR=WR (WR is saved to CR)
= $0e    ;MOV WR,DR
= $03    ;MOV RR,WR					;RR=DR
= $0c    ;MOV WR,CR
= $04    ;MOV DR,WR					;DR=saved WR
= $0d    ;MOV WR,RR					;WR=RR
= $f1    ;CLR MODE + CLR MENT + RET

;
;Clear memory:	recall (WR=MR), print and clear (R7=0)
;
fn_clrmem: = $09    ;MOV WR,MR
= $fa    ;PRN FPAR,MEM
= $44    ;CLR MR
= $f1    ;CLR MODE + CLR MENT + RET

;
;Recall memory:	recall (WR=MR) and print
;
fn_rm:     = $09    ;MOV WR,MR
= $fa    ;PRN FPAR,MEM
do_exit:   = $f1    ;CLR MODE + CLR MENT + RET

;----------------------------------------------------------------------------------------------------------------------------------
; Optional program for making the SQRT function
;----------------------------------------------------------------------------------------------------------------------------------

*= 0x400
$400: fim 0< $28		;pseudo code entry address of the SQRT function

;
;Similar pseudo code interpreter implementation, like at $04b-05f, just uses the pseudo instruction codes from address range $400-$4ff
;

$402: jcn TZ $406		;wait for the inactive printer drum sector signal
          jms $0b0		;keyboard handling
$406: fim 3< $20
          fim 4< $10
          fin 1<		;fetch pseudo instruction code into R2R3
          clb
          jms $450		;execute the associated routine
$40e: isz 1 $411		;inc R0R1, pseudo code instruction pointer
          inc 0
$411: jcn AZ $402		;jump back, if ACC returned by the pseudo instruction was 0
          tcc
          jcn AZ $40e		;if CY returned by the pseudo instruction was 0, R0R1 is incremented again
          fin 0<		;if CY was set to 1, read the pseudo code jump address
          jun $402		;jump to continue the pseudo code from the modified address


;----------------------------------------------------------------------------------------------------------------------------------
;Square root pseudo code implementation
;----------------------------------------------------------------------------------------------------------------------------------
*= 0x428
sq_start:  = $51    ;PRN FCODE					;print number with function code (9: SQRT)
= $a7    ;MOV CR,WR					;save the number to the constant register
= $53    ;CLR RR					;clear result register
= $61 
= $3e ;JPC ZERO_WR,sq_exit			;jump, if number is zero (the result will be also zero)
= $65    ;CLR DIGIT + GET DP_WR 			;R10R11=place of digit point
sq_bshift: = $63 
= $44 ;JPC NBIG_WR,sq_lshift			;number is adjusted to the leftmost position
= $9c    ;SHR WR					;one digit overshift is corrected back
= $5b    ;MOV DR,WR					;remainder (DR) is initialized to the shifted number
= $55    ;CLR WR					;initial subtrahend (WR) is cleared
= $6a 
= $36 ;SET LPCSQRT + SET DPCNTSQRT + JPC EVENDP,sq_loopns	;R15=13, sqrt digit point calculation
								;jump if original digit point position was even
sq_loopsh: = $58    ;SHL DR					;multiplication by 10 of the remaining part
								;(and possible additional shift if it is needed)
sq_loopns: = $7a    ;INC WR_POS				;increment the subtrahend (WR from position in R15) by 1
= $5d 
= $41 ;SUB DR,WR + JPC NNEG,sq_rptinc + INC DIGIT;remainder is decremented by the subtrahend (DR=DR-WR)
								;and jump, if the result is not negative
								;digit counter (R13) is incremented too
= $5f    ;ADD DR,WR					;add the subtrahend to get back the last non negative value
= $85    ;DEC WR_POS				;decrement the subtrahend by one (prepare it for the next round)
= $57    ;SHL RR					;shift the new digit into the number, R13 is cleared too
= $98 
= $35 ;JPC NZERO_LPCSQRT,sq_loopsh + DEC LPCSQRT	;decrement R15, and jump, except when R15 becomes 0
								;(next round calculates with one more digit)
sq_exit:   = $a9    ;MOV DR,WR	(MOV WR,CR ???)			;??? subtrahend is saved (originally it may be WR=CR)
= $5b    ;MOV DR,WR					;??? duplicated, but not disturbing code
= $9f    ;CLR MOP + RET_BPC				;return back to basic pseudo code interpreter to address $40
sq_rptinc: = $7a    ;INC WR_POS				;increment the subtrahend by 1 (WR from position in R15)
= $96 
= $36 ;JMP sq_loopns				;jump back

sq_lshift: = $59    ;SHL WR					;rotate number into left position
= $93 
= $2e ;INC DPCNT + JMP sq_bshift			;increment R10R11, and jump back

;----------------------------------------------------------------------------------------------------------------------------------

*= 0x450
$450: jin 1<		;jump to the pseudo instruction code associated routine

$451: jun $1fe		;PRN FCODE
$453: jun $148		;CLR RR
$455: jun $14a		;CLR WR
$457: inc 8		;SHL RR
$458: inc 8		;SHL DR
$459: jun $153		;SHL WR
$45b: jun $104		;MOV DR,WR
$45d: jun $134		;SUB DR,WR + JPC NNEG + INC DIGIT
$45f: jun $121		;ADD DR,WR
$461: jun $1a2		;JPC ZERO_WR
$463: jun $19a		;JPC NBIG_WR

;QPC_65:	CLR DIGIT + GET DP_WR

$465: xch 13		;clear digit (R13=0)
          src 4<
          rd1
          xch 11		;R11=WR.S1, get the digit point place of WR
          bbl 0

;QPC_6A:	SET LPCSQRT + SET DPCNTSQRT + JPC EVENDP
;		R15=13, R10R11=(R10R11/2+6+((R10R11 mod 2))), jump, if original R10R11 was even

$46a: fim 7< $6d		;R14=6, R15=13
          ld 11
          xch 7		;R7=R11 (save original R11 into R7)
          xch 10		;ACC=R10  (R10=0 [previous R7])
          rar			;CY=R10.bit0
          ld 11
          rar			;ACC=8*(R10.bit0)+(R11 div 2),  CY=(R11 mod 2)
          add 14		;ACC=8*(R10.bit0)+(R11 div 2)+(R11 mod 2)+6, CY=overflow
          xch 11		;store it to R11
          tcc			;ACC=overflow
          xch 10		;R10=0 or 1
          xch 7		;ACC=original R11
          rar			;CY=(R11 mod 2), rotate bit 0 into CY
          cmc			;CY=1-(R11 mod 2), negate the pseudo jump condition
          bbl 1		;prepare pseudo code jump

;QPC_7A:	INC WR_POS	increment WR from position in R15

$47a: ld 15
          xch 9		;R9=R15
          stc
$47d:     ldm 0		;clear ACC
          src 4<
          adm
          daa			;add carry to number digit by digit
          wrm
          isz 9 $47d		;loop back for the next digits
          bbl 0

;QPC_85:	DEC WR_POS	Decrement WR from position in R15
;
;inside the loop when R7 is subtracted from ACC and CY is complemented:
;
;		CY=0			CY=1
;-------------------------------------------------------
;ACC 0		ACC=0, CY=0		ACC=15->9, CY=1
;ACC 1..9	ACC=ACC, CY=0		ACC=ACC-1, CY=0

$485: ld 15
          xch 9		;R9=R15
$487:     cmc			;at first: set CY=1, later complement the borrow bit
          src 4<
          rdm			;read next digit from WR
          sub 7		;subtract R7 (=0) from it, ACC=ACC+15+(1-CY)
          jcn C1 $48e		;jump, if there is no borrow
          ldm 9		;set the number to 9 (BCD adjust)
$48e:     wrm			;write back the result
          isz 9 $487		;loop back for the next digits
          clb
          bbl 0

;QPC_93:	INC DPCNT + JMP		Increment digit point counter (R10R11) and unconditional jump
;QPC_96:	unconditional jump

$493: isz 11 $496		;inc R11, and skip if result is nonzero
          inc 10		;inc R10
$496: stc			;set CY=1, the pseudo jump condition
          bbl 1		;prepare pseudo code jump

;QPC_98:	JPC NZERO_LPCSQRT + DEC LPCSQRT		decrement R15, and jump, except when R15 was 0

$498: ld 15		;decrement R15, sqrt loop counter
          dac
          xch 15		;the pseudo jump condition is set, if R15 was nonzero
          bbl 1		;prepare pseudo code jump

;QPC_9C:	SHR WR		Right shift of working register
$49c: jun $15f		;one digit right shift of WR with R13 (0 is shifted from left)

          nop

;QPC_9F:	CLR MOP + RET_BPC	Clear divide/multiply operation and return back to basic pseudo code interpreter

$49f: src 3<		;clear DR.S2
          wr2
          fim 0< $40		;entry address is $40
          fim 3< $00
          jun $04b		;jump back to basic pseudo code interpreter

;QPC_A7:	MOV CR,WR	Move working register into constant register (CR=WR)
$4a7: jun $102		;CR=WR

;QPC_A9:	MOV DR,WR (or MOV WR,CR)
;	Move working register into dividend/multiplicand register (DR=WR), but it is very probable that this would be
;	move constant register into working register (WR=CR)

$4a9: jun $104		;Maybe it is "jun $10c"
					;(the difference is only one bit in the code - was the source ROM damaged?)

;4ab          00 00 00 00 00		;Unused NOPs
