;SPDX short identifier: MIT

;Copyright 2019 Andreas J. Reichel

;Permission is hereby granted, free of charge, to any person obtaining a copy of
;this software and associated documentation files (the "Software"), to deal in
;the Software without restriction, including without limitation the rights to
;use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
;of the Software, and to permit persons to whom the Software is furnished to do
;so, subject to the following conditions:

;The above copyright notice and this permission notice shall be included in all
;copies or substantial portions of the Software.

;THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;SOFTWARE.

	MVI H,0x00
	MVI L,0x20
newcyc:	MOV A,M
	OUT 11		; port 3 (traffic light)
	OUT 8		; port 0 (panel)
	INR L
	MOV A,L
	ANI 0x23
	MOV L,A		
wait:	MVI C,32
	MVI B,0
wait1:	DCR B
	JNZ wait1
	DCR C
	JNZ wait1
	JMP newcyc	
*= 0x20
	.BYTE 0x80
	.BYTE 0xC0
	.BYTE 0x20
	.BYTE 0x40
