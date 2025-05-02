;
; plot.asm
; A very simple and non-optimized hires plotting example for the Cody Computer.
;
; Note that color artifacting will be noticeable in this example (as with the
; other hires examples). The color you expect may not always be the color you
; get.
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
;   64tass --mw65c02 --nostart -o plot.bin plot.asm
;
ADDR      = $0300               ; The actual loading address of the program

SCRRAM    = $A000               ; Screen memory location
COLRAM    = $D800               ; Color memory location

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

VID_BLNK  = $D000               ; Video blanking status register
VID_CNTL  = $D001               ; Video control register
VID_COLR  = $D002               ; Video color register
VID_BPTR  = $D003               ; Video base pointer register
VID_SCRL  = $D004               ; Video scroll register
VID_SCRC  = $D005               ; Video screen common colors register
VID_SPRC  = $D006               ; Video sprite control register

; Variables

MEMSPTR   = $20       ; The source pointer for memory-related utility routines (2 bytes)
MEMDPTR   = $22       ; The destination pointer for memory-related utility routines (2 bytes)
MEMSIZE   = $24       ; The size of memory to move for memory-related utility routines (2 bytes)

NUMONE    = $30       ; First parameter for number operations (2 bytes)
NUMTWO    = $32       ; Second parameter for number operations (2 bytes)
NUMANS    = $34       ; Answer for number operations (3 bytes)

PIXELX    = $A0       ; Pixel plotting X coordinate (2 bytes)
PIXELY    = $A2       ; Pixel plotting Y coordinate (1 byte)

NUMBITS   = $A4       ; The number of bits (need to reload when it drops to zero)
IMGBITS   = $A5       ; The last bits read from the image data

IMAGEX    = $A6       ; Image left coordinate (2 bytes)
IMAGEY    = $A8       ; Image top coordinate (1 byte)

; Program header for Cody Basic's loader (needs to be first)

.WORD ADDR                      ; Starting address (just like KIM-1, Commodore, etc.)
.WORD LAST-1                    ; Ending address (so we know when we're done loading)

; The actual program goes below here

.LOGICAL    ADDR                ; The actual program gets loaded at ADDR

;
; MAIN
;
; The starting point of the demo. Sets up the VID and clears out the memory.
; Once the data is in place the high-resolution bitmap mode is enabled.
;
MAIN        JSR CLEAR             ; Clear screen

            JSR VIDEO             ; Start hi-res video
            
            LDA #0                ; Top left pixel
            STA PIXELX
            STA PIXELX+1
            STA PIXELY
            LDA #1
            JSR PLOTPIXEL
            
            LDA #0                ; Bottom left pixel
            STA PIXELX
            STA PIXELX+1
            LDA #199
            STA PIXELY
            LDA #1
            JSR PLOTPIXEL
            
            LDA #<319             ; Top right pixel
            STA PIXELX
            LDA #>319
            STA PIXELX+1
            LDA #0
            STA PIXELY
            LDA #1
            JSR PLOTPIXEL
            
            LDA #<319             ; Bottom right pixel
            STA PIXELX
            LDA #>319
            STA PIXELX+1
            LDA #199
            STA PIXELY
            LDA #1
            JSR PLOTPIXEL
            
            LDA #<40              ; Draw a sample image
            STA IMAGEX
            LDA #>40
            STA IMAGEX+1
            LDA #20
            STA IMAGEY
            JSR PLOTIMAGE
            
            LDA #<140             ; Draw a sample image
            STA IMAGEX
            LDA #>140
            STA IMAGEX+1
            LDA #40
            STA IMAGEY
            JSR PLOTIMAGE
            
            LDA #<250             ; Draw a sample image
            STA IMAGEX
            LDA #>250
            STA IMAGEX+1
            LDA #130
            STA IMAGEY
            JSR PLOTIMAGE
            
_DONE       BRA _DONE             ; Loop forever

;
; PLOTIMAGE
;
; Plots the sample image. The implementation is far from optimal (each pixel is
; plotted separately) and only supports bitmaps up to 256x256.
;
; No error checking or bounds checking is performed.
;
PLOTIMAGE   LDA #<IMG_DATA        ; Use the image data as a source location
            STA MEMSPTR
            LDA #>IMG_DATA
            STA MEMSPTR+1

            LDA IMAGEY            ; Starting y-coordinate for drawing the image
            STA PIXELY

            STZ NUMBITS           ; No bits (yet)
            
            LDY #IMG_HEIGHT       ; Loop over each line in the image
            
_LOOPY      LDA IMAGEX            ; Starting x-coordinate for drawing the image
            STA PIXELX
            LDA IMAGEX+1
            STA PIXELX+1
            
            LDX #IMG_WIDTH        ; Loop over each pixel in the line
            
_LOOPX      LDA NUMBITS
            BNE _PLOT
            
            LDA #8                ; Load a new batch of 8 bits
            STA NUMBITS
            LDA (MEMSPTR)
            STA IMGBITS
            
            INC MEMSPTR           ; Increment source position
            BNE _PLOT
            INC MEMSPTR+1
            
_PLOT       LDA IMGBITS           ; Plot the current pixel
            AND #$80
            JSR PLOTPIXEL
            
            ASL IMGBITS           ; Rotate the image bits right by one
            DEC NUMBITS
                        
            INC PIXELX            ; Next X?
            BNE _NEXTX
            INC PIXELX+1
            
_NEXTX      DEX
            BNE _LOOPX
            
            INC PIXELY            ; Next Y?
            DEY
            BNE _LOOPY

            RTS

;
; PLOTPIXEL
;
; Plots a pixel on the screen. Written for clarity (poorly) rather than for speed.
;
; A               The pixel to draw (0 for color 0, nonzero for color 1)
; PIXELX          The pixel's x-coordinate from 0 to 319.
; PIXELY          The pixel's y-coordinate from 0 to 199.
;
PLOTPIXEL   PHX                   ; Preserve the x-register from clobbering

            PHA                   ; Store the accumulator (pixel) for later

            LDA #<SCRRAM          ; Start at the beginning of screen RAM.
            STA MEMDPTR

            LDA #>SCRRAM
            STA MEMDPTR+1

            LDA PIXELY            ; Calculate the offset in full 8-pixel rows from the y-coordinate
            LSR
            LSR
            LSR
            STA NUMONE
            STZ NUMONE+1
            
            LDA #<320
            STA NUMTWO
            LDA #>320
            STA NUMTWO+1
            
            JSR MUL16             ; NOTE: You could loop-and-add or use a lookup table instead of MUL
            
            CLC
            
            LDA NUMANS
            ADC MEMDPTR
            STA MEMDPTR
            
            LDA NUMANS+1
            ADC MEMDPTR+1
            STA MEMDPTR+1
            
            CLC                   ; Calculate the offset in full 8-pixel columns in the current row
            
            LDA PIXELX
            AND #$F8
            ADC MEMDPTR
            STA MEMDPTR
            LDA PIXELX+1
            ADC MEMDPTR+1
            STA MEMDPTR+1
            
            CLC                   ; Calculate the offset in y-rows within the destination square
            
            LDA PIXELY
            AND #$07
            ADC MEMDPTR
            STA MEMDPTR
            LDA #0
            ADC MEMDPTR+1
            STA MEMDPTR+1
            
            LDA PIXELX            ; Calculate the x-coordinate relative to the destination square
            AND #$07
            TAX
            
            LDA _LOOKUP,X         ; Mask out the pixel's bit in the destination byte in memory
            EOR #$FF
            AND (MEMDPTR)
            STA (MEMDPTR)
            
            PLA                   ; See if we need to plot a 1 in the hole we just made
            BEQ _DONE
            
            LDA _LOOKUP,X         ; Set the pixel's bit in the destination byte in memory
            ORA (MEMDPTR)
            STA (MEMDPTR)
            
_DONE       PLX
            RTS

_LOOKUP     .BYTE %10000000       ; A lookup table for the exact bit to plot (or not)
            .BYTE %01000000
            .BYTE %00100000
            .BYTE %00010000
            .BYTE %00001000
            .BYTE %00000100
            .BYTE %00000010
            .BYTE %00000001

;
; CLEAR
;
; Clears the hires video memory used in this example. All pixels are set to zero and
; all colors are set to white-on-black (though the actual appearance will vary because
; of NTSC color artifacting).
;
CLEAR       LDA #<SCRRAM          ; Clear the screen
            STA MEMDPTR

            LDA #>SCRRAM
            STA MEMDPTR+1

            LDA #<8192
            STA MEMSIZE

            LDA #>8192
            STA MEMSIZE+1
            
            LDA #0
            JSR MEMFILL
            
            LDA #<COLRAM          ; Set all background colors to white-on-black
            STA MEMDPTR

            LDA #>COLRAM
            STA MEMDPTR+1

            LDA #<1024
            STA MEMSIZE

            LDA #>1024
            STA MEMSIZE+1
            
            LDA #$10
            JSR MEMFILL
            
            RTS

;
; VIDEO
;
; Start the hi-res video mode.
;
VIDEO       LDA #$E0            ; Point the video hardware to default color memory, border color black
            STA VID_COLR

            LDA #$05            ; Point the video hardware to the screen memory
            STA VID_BPTR

            LDA VID_CNTL        ; Set high resolution bitmap graphics mode
            ORA #$30
            STA VID_CNTL
            
            RTS

;
; MEMFILL
;
; Sets a range of memory to the current accumulator value. Sets a total of MEMSIZE bytes 
; starting at the address in MEMDPTR. 
;
; Algorithm copied from http://www.6502.org/source/general/memory_move.html.
;
; Uses:
;
;   A             Byte to fill with
;   MEMDPTR       Destination pointer (modified by operation)
;   MEMSIZE       Bytes to copy (modified by operation)   
;
MEMFILL   PHA
          PHX
          PHY

          LDY #0                  ; Handle each group of 256 bytes first before we handle what's left over at the end
          LDX MEMSIZE+1
          BEQ _REST               ; Only 256 bytes or less to begin, so just skip to the end

_PAGE     STA (MEMDPTR),Y         ; Set a byte and continue on for 256 bytes
          INY
          BNE _PAGE
          INC MEMDPTR+1           ; Move to the next 256 byte destination address until we've done all of them
          DEX
          BNE _PAGE

_REST     LDX MEMSIZE+0           ; Handle the remaining 256 or fewer bytes (if we have any)
          BEQ _DONE

_BYTE     STA (MEMDPTR),Y         ; Set a byte and continue on until we've done all that's left
          INY
          DEX
          BNE _BYTE

_DONE     PLY
          PLX
          PLA

          RTS

;
; MUL16
;
; Multiplies 16 bit integers in NUMONE and NUMTWO and stores the result in NUMANS.
;
; This code was taken from Neil Parker's "Multiplying and Dividing on the 6502" at 
; http://nparker.llx.com/a2/mult.html. Minor modifications were made for preserving
; registers across calls and for ignoring the highest (3rd) byte of the result.
;
; Uses:
;
;   NUMONE        The first argument to multiply by (clobbered by routine)
;   NUMTWO        The second argument to multiply by (clobbered by routine)
;   NUMANS        The result of the multiplication
;     
MUL16     PHA
          PHX
          PHY
          
          LDA #0
          STA NUMANS+2
          LDX #16
          
_L1       LSR NUMTWO+1
          ROR NUMTWO
          BCC _L2
          TAY
          CLC
          LDA NUMONE
          ADC NUMANS+2
          STA NUMANS+2
          TYA
          ADC NUMONE+1

_L2       ROR A
          ROR NUMANS+2
          ROR NUMANS+1
          ROR NUMANS
          DEX
          BNE _L1
          
          PLY
          PLX
          PLA
          
          RTS

IMG_WIDTH  = 64
IMG_HEIGHT = 64

IMG_DATA
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %01111111
    .BYTE %11111111
    .BYTE %10000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000011
    .BYTE %11111111
    .BYTE %11111111
    .BYTE %11110000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00011111
    .BYTE %11111111
    .BYTE %11111111
    .BYTE %11111110
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00111111
    .BYTE %11100000
    .BYTE %00000001
    .BYTE %11111111
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %11111110
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00011111
    .BYTE %11000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000001
    .BYTE %11111000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000111
    .BYTE %11100000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000111
    .BYTE %11100000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000001
    .BYTE %11111000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00001111
    .BYTE %11000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %11111100
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00011111
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00111110
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00111110
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00011111
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %01111100
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00001111
    .BYTE %10000000
    .BYTE %00000000
    .BYTE %01111000
    .BYTE %00000000
    .BYTE %00111110
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000111
    .BYTE %10000000
    .BYTE %00000000
    .BYTE %11110000
    .BYTE %00000000
    .BYTE %11111111
    .BYTE %10000000
    .BYTE %00000000
    .BYTE %00000011
    .BYTE %11000000
    .BYTE %00000001
    .BYTE %11100000
    .BYTE %00000001
    .BYTE %11111111
    .BYTE %11000000
    .BYTE %00000000
    .BYTE %00000001
    .BYTE %11100000
    .BYTE %00000001
    .BYTE %11100000
    .BYTE %00000011
    .BYTE %11111111
    .BYTE %11100000
    .BYTE %01111110
    .BYTE %00000001
    .BYTE %11100000
    .BYTE %00000011
    .BYTE %11000000
    .BYTE %00000011
    .BYTE %11111111
    .BYTE %11100000
    .BYTE %11111111
    .BYTE %00000000
    .BYTE %11110000
    .BYTE %00000011
    .BYTE %11000000
    .BYTE %00000111
    .BYTE %11111111
    .BYTE %11110001
    .BYTE %11111111
    .BYTE %10000000
    .BYTE %11110000
    .BYTE %00000111
    .BYTE %10000000
    .BYTE %00000111
    .BYTE %11111111
    .BYTE %11110011
    .BYTE %11111111
    .BYTE %11000000
    .BYTE %01111000
    .BYTE %00000111
    .BYTE %10000000
    .BYTE %00000111
    .BYTE %11110000
    .BYTE %11110111
    .BYTE %11111111
    .BYTE %11100000
    .BYTE %01111000
    .BYTE %00000111
    .BYTE %00000000
    .BYTE %00000111
    .BYTE %11100000
    .BYTE %01110111
    .BYTE %11000111
    .BYTE %11100000
    .BYTE %00111000
    .BYTE %00001111
    .BYTE %00000000
    .BYTE %00000111
    .BYTE %11100000
    .BYTE %01110111
    .BYTE %10000011
    .BYTE %11100000
    .BYTE %00111100
    .BYTE %00001111
    .BYTE %00000000
    .BYTE %00000111
    .BYTE %11100000
    .BYTE %01110111
    .BYTE %10000011
    .BYTE %11100000
    .BYTE %00111100
    .BYTE %00001110
    .BYTE %00000000
    .BYTE %00000011
    .BYTE %11100000
    .BYTE %01100111
    .BYTE %10000011
    .BYTE %11100000
    .BYTE %00011100
    .BYTE %00001110
    .BYTE %00000000
    .BYTE %00000011
    .BYTE %11100000
    .BYTE %01100111
    .BYTE %11000111
    .BYTE %11100000
    .BYTE %00011100
    .BYTE %00001110
    .BYTE %00000000
    .BYTE %00000001
    .BYTE %11110000
    .BYTE %11000111
    .BYTE %11111111
    .BYTE %11100000
    .BYTE %00011100
    .BYTE %00001110
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %11111111
    .BYTE %10000011
    .BYTE %11111111
    .BYTE %11000000
    .BYTE %00011100
    .BYTE %00001110
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00111110
    .BYTE %00000001
    .BYTE %11111111
    .BYTE %10000000
    .BYTE %00011100
    .BYTE %00001110
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %11111111
    .BYTE %00000000
    .BYTE %00011100
    .BYTE %00001110
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %01111110
    .BYTE %00000000
    .BYTE %00011100
    .BYTE %00001110
    .BYTE %00000100
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00011100
    .BYTE %00001110
    .BYTE %00000100
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00011100
    .BYTE %00001110
    .BYTE %00000010
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00011100
    .BYTE %00001110
    .BYTE %00000001
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00011100
    .BYTE %00001110
    .BYTE %00000001
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00011100
    .BYTE %00001111
    .BYTE %00000000
    .BYTE %10000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00111100
    .BYTE %00001111
    .BYTE %00000000
    .BYTE %01000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00111100
    .BYTE %00000111
    .BYTE %00000000
    .BYTE %00100000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00111000
    .BYTE %00000111
    .BYTE %10000000
    .BYTE %00100000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %01111000
    .BYTE %00000111
    .BYTE %10000000
    .BYTE %00011000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00100000
    .BYTE %01111000
    .BYTE %00000011
    .BYTE %11000000
    .BYTE %00000100
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %11000000
    .BYTE %11110000
    .BYTE %00000011
    .BYTE %11000000
    .BYTE %00000010
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000001
    .BYTE %00000000
    .BYTE %11110000
    .BYTE %00000001
    .BYTE %11100000
    .BYTE %00000001
    .BYTE %10000000
    .BYTE %00000000
    .BYTE %00000110
    .BYTE %00000001
    .BYTE %11100000
    .BYTE %00000001
    .BYTE %11100000
    .BYTE %00000000
    .BYTE %01100000
    .BYTE %00000000
    .BYTE %00111000
    .BYTE %00000001
    .BYTE %11100000
    .BYTE %00000000
    .BYTE %11110000
    .BYTE %00000000
    .BYTE %00011110
    .BYTE %00000111
    .BYTE %11000000
    .BYTE %00000011
    .BYTE %11000000
    .BYTE %00000000
    .BYTE %01111000
    .BYTE %00000000
    .BYTE %00000001
    .BYTE %11111000
    .BYTE %00000000
    .BYTE %00000111
    .BYTE %10000000
    .BYTE %00000000
    .BYTE %01111100
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00001111
    .BYTE %10000000
    .BYTE %00000000
    .BYTE %00111110
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00011111
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00011111
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00111110
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00001111
    .BYTE %11000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %11111100
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000111
    .BYTE %11100000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000001
    .BYTE %11111000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000001
    .BYTE %11111000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000111
    .BYTE %11100000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %11111110
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00011111
    .BYTE %11000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00111111
    .BYTE %11100000
    .BYTE %00000001
    .BYTE %11111111
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00011111
    .BYTE %11111111
    .BYTE %11111111
    .BYTE %11111110
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000011
    .BYTE %11111111
    .BYTE %11111111
    .BYTE %11110000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %01111111
    .BYTE %11111111
    .BYTE %10000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000
    .BYTE %00000000

LAST                              ; End of the entire program

.ENDLOGICAL
