;
; scan.asm
; A keyboard scanning example extracted from the Cody BASIC ROM.
;
; Copyright 2025 Frederick John Milens III, The Cody Computer Developers.
;
; This program is free software; you can redistribute it and/or
; modify it under the terms of the GNU General Public License
; as published by the Free Software Foundation; either version 3
; of the License, or (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
;
; To assemble using 64TASS run the following:
;
;   64tass --mw65c02 --nostart -o scan.bin scan.asm
;
ADDR      = $0300               ; The actual loading address of the program

SCRRAM    = $C400               ; Base of screen memory

VIA_BASE  = $9F00               ; VIA base address and register locations
VIA_IORB  = VIA_BASE+$0
VIA_IORA  = VIA_BASE+$1
VIA_DDRB  = VIA_BASE+$2
VIA_DDRA  = VIA_BASE+$3
VIA_T1CL  = VIA_BASE+$4
VIA_T1CH  = VIA_BASE+$5
VIA_SR    = VIA_BASE+$A
VIA_ACR   = VIA_BASE+$B
VIA_PCR   = VIA_BASE+$C
VIA_IFR   = VIA_BASE+$D
VIA_IER   = VIA_BASE+$E

; Variables

KEYROW0   = $10       ; Column bits for the last scan of keyboard row 0
KEYROW1   = $11       ; Column bits for the last scan of keyboard row 1
KEYROW2   = $12       ; Column bits for the last scan of keyboard row 2
KEYROW3   = $13       ; Column bits for the last scan of keyboard row 3
KEYROW4   = $14       ; Column bits for the last scan of keyboard row 4
KEYROW5   = $15       ; Column bits for the last scan of keyboard row 5
KEYROW6   = $16       ; Column bits for the last scan of keyboard row 6 / joystick row 0
KEYROW7   = $17       ; Column bits for the last scan of keyboard row 7 / joystick row 1

KEYLOCK   = $1A       ; Current keyboard shift lock status
KEYMODS   = $1B       ; Current keyboard modifiers (only)
KEYCODE   = $1C       ; Current keyboard scan code (with modifiers)

; Keyboard scan codes

KEY_Q     = $01
KEY_E     = $02
KEY_T     = $03
KEY_U     = $04
KEY_O     = $05
KEY_A     = $06
KEY_D     = $07
KEY_G     = $08
KEY_J     = $09
KEY_L     = $0A
KEY_CODY  = $0B
KEY_X     = $0C
KEY_V     = $0D
KEY_N     = $0E
KEY_META  = $0F
KEY_Z     = $10
KEY_C     = $11
KEY_B     = $12
KEY_M     = $13
KEY_ARROW = $14
KEY_S     = $15
KEY_F     = $16
KEY_H     = $17
KEY_K     = $18
KEY_SPACE = $19
KEY_W     = $1A
KEY_R     = $1B
KEY_Y     = $1C
KEY_I     = $1D
KEY_P     = $1E

; Program header for Cody Basic's loader (needs to be first)

.WORD ADDR                      ; Starting address (just like KIM-1, Commodore, etc.)
.WORD LAST-1                    ; Ending address (so we know when we're done loading)

; The actual program goes below here

.LOGICAL    ADDR                ; The actual program gets loaded at ADDR

;
; MAIN
;
; The starting point of the sample code. Shuts off interrupts (to be safe)
; and sets up the 65C22 I/O chip to read the keyboard. After that it loops
; and displays keyboard presses.
;
MAIN      SEI                   ; Shut off interrupts
          
          STZ KEYLOCK           ; Clear out the major keyboard-related zero page variables
          STZ KEYMODS
          STZ KEYCODE
          
          LDA #$07              ; Set VIA data direction register A to 00000111 (pins 0-2 outputs, pins 3-7 inputs)
          STA VIA_DDRA
          
_LOOP     JSR KEYSCAN           ; Scan the keyboard
          
          JSR KEYDECODE         ; Decode the key we read
          
          LDA KEYCODE           ; Convert scancode to char
          JSR KEYTOCHR
          
          STA SCRRAM            ; Show the we read (hacky but it should work) and repeat
          BRA _LOOP
          
          RTS

;
; KEYSCAN
;
; Performs a single scan of the keyboard rows (including joystick rows) and
; updates the KEYROWX zero page variables. Called by the timer ISR.
;
; Uses:
;
;   KEYROWx       Updated with new value for each row
;
KEYSCAN   PHA                   ; Preserve registers
          PHX
          
          STZ VIA_IORA          ; Start at the first row and first key of the keyboard
          LDX #0

_LOOP     LDA VIA_IORA          ; Get the keys for the current row from the VIA port
          LSR A
          LSR A
          LSR A
          STA KEYROW0,X

          INC VIA_IORA          ; Move on to the next keyboard row
          INX
  
          CPX #8                ; Do we have any rows remaining to scan?
          BNE _LOOP
          
          PLX                   ; Restore registers
          PLA
  
          RTS

;
; KEYDECODE
;
; Decodes the contents of the KEYROWX zero page variables into a scan code,
; updating the KEYMODS and KEYCODE zero page variables. You should usually
; call KEYSCAN before calling this to update the key row data first.
;
; Uses:
;
;   KEYROWx       Read to determine the current pressed keys
;   KEYMODS       Updated with current key modifiers
;   KEYCODE       Updated with current key code
;
KEYDECODE PHX                   ; Preserve registers
          PHY

          STZ KEYMODS           ; Reset scan codes and modifiers at start of new scan
          STZ KEYCODE

          LDX #0                ; Start at the first row and first key scan code
          LDY #0

_ROW      LDA KEYROW0,X         ; Load the current row's column bits from zero page
          INX

          PHX                   ; Preserve row index

          LDX #5                ; Loop over current row's columns

_COL      INY                   ; Increment the current key number at the start of each new key

          LSR A                 ; Shift to get the next column bit

          BCS _NEXT             ; If the current column wasn't pressed, just skip to the next column
  
          CPY #KEY_META         ; Is this the META special key?
          BNE _CODY

          PHA                   ; META key is pressed, update current key modifiers
          LDA KEYMODS
          ORA #$20
          STA KEYMODS
          PLA

          BRA _NEXT             ; Continue on to the next column

_CODY     CPY #KEY_CODY         ; Is this the CODY special key?
          BNE _NORM

          PHA                   ; CODY key is pressed, update current key modifiers
          LDA KEYMODS
          ORA #$40
          STA KEYMODS
          PLA

          BRA _NEXT             ; Continue on to the next column

_NORM     PHA                   ; Not a special key so just store it as the current scan code
          TYA
          STA KEYCODE
          PLA

_NEXT     DEX                   ; Move on to the next keyboard column
          BNE _COL

          PLX                   ; Restore current row index

          CPX #6                ; Continue while we have more rows to process      
          BNE _ROW

          LDA KEYCODE           ; Update the current key scan code with the modifiers
          ORA KEYMODS
          STA KEYCODE

          PLY                   ; Restore registers
          PLX

          RTS

;
; KEYTOCHR
;
; Converts a scan code from KEYSCAN into a CODSCII character code. The scan code value in the
; accumulator will be replaced with the CODSCII character code that it represents.
;
; Uses:
;
;   A             Scan code as input, CODSCII character as output
;
KEYTOCHR  PHX
          DEC A
          TAX
          LDA _LOOKUP,X
          PLX
          RTS

_LOOKUP

.BYTE 'Q', 'E', 'T', 'U', 'O'      ; Key scan code mappings without any modifiers
.BYTE 'A', 'D', 'G', 'J', 'L'
.BYTE $00, 'X', 'V', 'N', $00
.BYTE 'Z', 'C', 'B', 'M', $0A
.BYTE 'S', 'F', 'H', 'K', ' '
.BYTE 'W', 'R', 'Y', 'I', 'P'
.BYTE $00, $00

.BYTE '!', '#', '%', '&', '('      ; Key scan code mappings with META modifier
.BYTE '@', '-', ':', $27, ']'
.BYTE $00, '<', ',', '?', $00
.BYTE '\', '>', '.', '/', $08
.BYTE '=', '+', ';', '[', ' '
.BYTE '"', '$', '^', '*', ')'
.BYTE $00, $00

.BYTE '1', '3', '5', '7', '9'      ; Key scan code mappings with CODY modifier
.BYTE 'A', 'D', 'G', 'J', 'L'
.BYTE $00, 'X', 'V', 'N', $1B
.BYTE 'Z', 'C', 'B', 'M', $18
.BYTE 'S', 'F', 'H', 'K', ' '
.BYTE '2', '4', '6', '8', '0'
.BYTE $00, $00

LAST                              ; End of the entire program

.ENDLOGICAL
