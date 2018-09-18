.include "libSFX.i"


;Very hacky, really not proud of this code. Written in ~30 minutes

;Offsets of several registers and strings present in the SPC header.
;See http://vspcplay.raphnet.net/spc_file_format.txt for format specifications

SPCHEADER = $81FF25 ;CPU Registers
SPCTITLE = $81FF2E	
SPCGAME = $81FF4E
SPCDUMPER = $81FF6E
SPCARTIST = $81FFB1
SPCLENGTH = $81FFA9


Main:

;VRAM destination addresses
VRAM_MAP_LOC     = $0000
VRAM_TILES_LOC   = $8000

;Just uploading the tileset, palette and tilemap (logo.bin) to VRAM
VRAM_memcpy VRAM_TILES_LOC, Tiles, sizeof_Tiles
VRAM_memcpy VRAM_MAP_LOC, logomap, sizeof_logomap
CGRAM_memcpy $0, Palette, sizeof_Palette


;This copies the first 32kb, second 32kb, DSP Registers and CPU Registers from the ROM to WRAM.
;Normally this could be handled by the SPC_Play macro included in libSFX,
;But that routine expects DSP and CPU registers to be right after eachother which is not the case for SPC files
;Since i wanted to make it so you can drop in the SPC file unmodified without reassembling, i had to do some manual work.
;This very closely mimics the libSFX macro though.
WRAM_memcpy SFX_SPC_IMAGE, LOWB, $8000				;Low 32k
WRAM_memcpy SFX_SPC_IMAGE + $8000, HIGHB, $8000		;High 32k
WRAM_memcpy SFX_DSP_STATE, DSPSTATE, $80			;DSP Registers
WRAM_memcpy SFX_DSP_STATE+$80, SPCHEADER, $7		;CPU Registers

;This calls the libSFX copy and exec routine
RW_push set:a8i16
jsl     SFX_SMP_execspc
RW_pull


;The next few lines each read a string of metadata from rom, prepares it for VRAM and then copies it to VRAM.
;Horribly inefficient, but it only does this once when starting so whatever.
WRAM_memcpy $00, SPCTITLE, $20 
jsl preparetext
VRAM_memcpy $150, $100, $30

WRAM_memcpy $00, SPCGAME, $20 
jsl preparetext
VRAM_memcpy $1D0, $100, $30

WRAM_memcpy $00, SPCARTIST, $20 
jsl preparetext
VRAM_memcpy $250, $100, $30

WRAM_memcpy $00, SPCDUMPER, $20 
jsl preparetext
VRAM_memcpy $2D0, $100, $20

WRAM_memcpy $00, SPCLENGTH, $20 
jsl preparetext
VRAM_memcpy $350, $100, $6

;The screen setup is straight up copied from the Hello example of libSFX. Couldn't be bothered tbh.
;Set up screen mode
lda     #bgmode(BG_MODE_1, BG3_PRIO_NORMAL, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8)
sta     BGMODE
lda     #bgsc(VRAM_MAP_LOC, SC_SIZE_32X32)
sta     BG1SC
ldx     #bgnba(VRAM_TILES_LOC, 0, 0, 0)
stx     BG12NBA
lda     #tm(ON, OFF, OFF, OFF, OFF)
sta     TM

;Turn on screen
lda     #inidisp(ON, DISP_BRIGHTNESS_MAX)
sta     SFX_inidisp
        VBL_on
		
		
VBL_set handler ;Sets up the VBlank interrupt handler that copies the SPC port values to VRAM every frame.
 
:       wai
        bra     :-

		
handler:

;In desperate need for a loop. Basically does the same exact thing 4 times. Once for each byte
;Basically it explodes a byte into 2 nibbles which then corospond to the tiles $0-F. Also every second VRAM byte is 0 to not mess with palette and stuff.
lda $2140 ;Port 0
and #$F0 ;Only the high nibble
lsr a	 ;shift right 4 times to put high nibble in low nibble
lsr a
lsr a
lsr a
sta $100 ;store to RAM to get copied to VRAM later

lda $2140;Still port 0
and #$0F ;Only the low nibble
sta $102 ;No need to shift it since it's already in the low nibble. Also stored in WRAM for upload


lda #$20 ;Tile for a blank space
sta $104 ;Space inbetween 2 shown bytes

;And now basically the whole thing 3 more times. Did i mention i could've looped this. oh well.

lda $2141
and #$F0
lsr a
lsr a
lsr a
lsr a
sta $106

lda $2141
and #$0F
sta $108


lda #$20
sta $10a

lda $2142
and #$F0
lsr a
lsr a
lsr a
lsr a
sta $10c

lda $2142
and #$0F
sta $10e


lda #$20
sta $110

lda $2143
and #$F0
lsr a
lsr a
lsr a
lsr a
sta $112

lda $2143
and #$0F
sta $114

VRAM_memcpy $4D5, $100, $16 ;Aaaaaaaaaand ship it off to VRAM and return.
rtl 


;oof where do i even start on this one...
;This is the routine that prepares the text for VRAM
;VRAM doesn't accept straight up bytes for the tilemap. The tilemap data is interleaved with palette, priority and flip data for each tile. 
; Some of the bits in the second byte are also used to select tiles higher than $FF. Just read up in fullsnes, not that difficult.
; For this it basically means i have to add a $00 byte after each character byte. I probably massively overcomplicated this.

preparetext:
ldx #$00	;Sets the X index to 0
phx			;Pushes the X index to the stack. The index will later be used both for source and destination with some switcharoo trickery.

ptloop:		;Processing loop starts here
LDA $00, X	;Loads the current byte at index $00+X
cmp #$00	;Compares it with $00. $00 is used in SPC files as a placeholder if the string is shorter than the full 32b. 
			;In my tileset that's not a blank time (0 tile from the hex font)
bne skip0	;So if it detects that it's a $00 character...
LDA #$20	;It replaces it with a blank $20 tile.
skip0:		;Otherwise it just skips this.
inx			;Alright loading the byte into A complete, source X index gets incremented.
txy			;Temporarily puts X into Y, for safe keeping.
plx			;Pulls X from the stack (this is where the destination X index was, or $00 in the first iteration)
phy			;Puts Y on the stack (This gets pulled as X from the stack later)   We basically do a switcharoo. Pull one x from the stack and push the other onto it.
STA $100, X	;Store byte in A into the destination address
STZ $101, X	;Store zero into the byte right after it, for obvious reasons.
inx			;Increment X twice because we just wrote 2 bytes.
inx
txy			;Puts X into Y, same as before
plx			;Pulls source X from the stack
phy			;Pushes Y (destination X) to the stack. same thing as above.
cpx #$20	;Check if we copied 32bytes
bne ptloop	;If no, go back to the beginning of the loop
plx			;Otherwise, pull the leftover X from the Stack to make room for the return address that's still on the stack
rtl			;Return



;Import graphics stuff.
incbin logomap, "Data/logo.bin"
incbin  Palette,        "Data/font.png.palette"
incbin  Tiles,          "Data/font.png.tiles"

;Import placeholder music
.segment "SPCHeader"
 .incbin "Data/placeholder.spc", $0, $100
.SEGMENT "ROM2"
LOWB: .incbin "Data/placeholder.spc", $100, $8000
.SEGMENT "ROM3"
HIGHB: .incbin "Data/placeholder.spc", $8100, $8000
.SEGMENT "ROM4"
DSPSTATE: .incbin "Data/placeholder.spc", $10100


