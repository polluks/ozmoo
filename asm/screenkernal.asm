; replacement for these C64 kernal routines and their variables:
; printchar $ffd2
; plot      $fff0
; zp_cursorswitch $cc
; zp_screenline $d1-$d2
; zp_screencolumn $d3
; zp_screenrow $d6
; zp_colourline $f3-$f4
;
; needed to be able to customize the text scrolling to
; not include status lines, especially big ones used in
; Border Zone, and Nord and Bert.
;
; usage: first call s_init, then replace
; $ffd2 with s_printchar and so on.
; s_scrollstart is set to the number of top lines to keep when scrolling

!zone screenkernal {

!ifdef TARGET_X16 {
colour_petscii !byte 144,5,28,159,156,30,31,158,129,149,150,151,152,153,154,155
}
zcolours	!byte $ff,$ff ; current/default colour
			!byte 0,2,5,7  ; black, red, green, yellow
			!byte 6,4,3,1  ; blue, magenta, cyan, white
			!byte $ff,$ff,$ff,$ff,$ff,$ff ; Colour 10-15 are unused
			!byte 8,9,10,11,12,13,14,15 ; Colour 16-23 are C64 colours 8-15
darkmode	!byte 0
bgcol		!byte BGCOL, BGCOLDM
fgcol		!byte FGCOL, FGCOLDM
bordercol	!byte BORDERCOL_FINAL, BORDERCOLDM_FINAL
!ifdef USE_INPUTCOL {
inputcol	!byte INPUTCOL, INPUTCOLDM
}
!ifndef Z4PLUS {
statuslinecol !byte STATCOL, STATCOLDM
}
cursorcol !byte CURSORCOL, CURSORCOLDM
current_cursor_colour !byte CURSORCOL
cursor_character !byte CURSORCHAR

!ifdef TARGET_PLUS4 {
plus4_vic_colours
	;     PLUS4  VIC-II
	!byte $00   ; black
	!byte $71   ; white
	!byte $32   ; red
	!byte $63   ; cyan
	!byte $44   ; purple
	!byte $65   ; green
	!byte $26   ; blue
	!byte $77   ; yellow
	!byte $48   ; orange
	!byte $39   ; brown 
	!byte $62   ; light red
	!byte $31   ; dark grey
	!byte $51   ; grey
	!byte $75   ; light green
	!byte $56   ; light blue
	!byte $61   ; light grey
}

!ifdef TARGET_X16 {
!source "vera.asm"

.stored_x_or_y !byte 0
.vera_background !byte 0
vera_composite_colour !byte 0
.vera_temp !byte 0,0

.convert_screenline_y_to_vera_address
    ; convert screenline,y to address in VERA
	tya
	asl
	sta VERA_addr_low
	lda zp_screenline + 1
	adc #$b0 ; Carry is already clear after ASL
	sta VERA_addr_high
    rts

;vera_scroll_line !byte 0,0
.s_scroll_vera
	; scroll routine for VERA
	lda zp_screenrow
	cmp s_screen_height
	bpl +
	rts
+   

	; Setup VERA for scrolling
	; Read address is address 0, write address is address 1 in VERA
	lda s_screen_width
;	asl
	sta .vera_temp
	lda s_screen_height_minus_one
	adc #$b0
	sta .vera_temp + 1
	lda #1
	sta VERA_ctrl
	lda #$11
	sta VERA_addr_bank
	lda window_start_row + 1 ; how many top lines to protect
	adc #$b0
	tay
	lda #0
	sta VERA_ctrl

	; Delay
	ldx scroll_delay
	beq .done_delaying_vera
	dex
	beq ++
-	tya
	pha
	txa
	pha
	jsr wait_an_interval
	pla
	tax
	pla
	tay
	dex
	bne -

++

-	ldx VERA_scanline_l
	cpx #<450
	bne -
	lda VERA_ien
	and #$40
	beq -
	
.done_delaying_vera
	
	; Begin actual scrolling

-	cpy .vera_temp + 1
	bcs +
	; Setup for copying a line
	lda #1
	sta VERA_ctrl
	sty VERA_addr_high
	ldx #0
	stx VERA_addr_low
	stx VERA_ctrl
	iny
	sty VERA_addr_high
	stx VERA_addr_low
	ldx .vera_temp

--	lda VERA_data0
	sta VERA_data1
	lda VERA_data0
	sta VERA_data1
	dex
	bne --
	
	beq - ; Always branch
	
+	; prepare for erase line
	ldy s_screen_height_minus_one
	sty zp_screenrow
	lda #$ff
	sta s_current_screenpos_row ; force recalculation
	jmp s_erase_line

VERASetBorderColour
	stz VERA_ctrl
	sta VERA_dc_border
    rts

VERASetBackgroundColour
	pha
    asl
    asl
    asl
    asl
    sta .vera_background
	ora s_colour
	sta vera_composite_colour
	pla
    rts

VERASetForegroundColour
    sta s_colour
	ora .vera_background
	sta vera_composite_colour
    lda s_colour
    rts

VERAPrintChar
	; a = character, y = column
	pha
	sty .stored_x_or_y
    jsr .convert_screenline_y_to_vera_address
    ; write character
    pla
    sta VERA_data0
	ldy vera_composite_colour
	sty VERA_data0
    ; restore y
	ldy .stored_x_or_y
    rts

; VERAPrintColour
	; pha
	; sty .stored_x_or_y
    ; jsr .convert_screenline_y_to_vera_address
    ; ; increase to colour address
    ; inc VERA_addr_low
    ; bne +
    ; inc VERA_addr_high
    ; ; write colour
; +   pla
    ; ora vera_background
    ; sta VERA_data0
    ; ; restore y
	; ldy .stored_x_or_y
    ; rts

; VERAPrintColourAfterChar
	; ; a = colour
    ; ora .vera_background
    ; sta VERA_data0
    ; rts
}

!ifdef TARGET_C128 {
!source "vdc.asm"

.stored_a !byte 0
.stored_x_or_y !byte 0

; Mapping between VIC-II and VDC colours
; VDC:
; 00 = dark black
; 01 = light black (dark gray)
; 02 = dark blue
; 03 = light blue
; 04 = dark green
; 05 = light green
; 06 = dark cyan
; 07 = light cyan
; 08 = dark red
; 09 = light red
; 10 = dark purple
; 11 = light purple
; 12 = dark yellow (brown/orange)
; 13 = light yellow
; 14 = dark white (light gray)
; 15 = light white
vdc_vic_colours = $ce5c ; The official conversion table in ROM
	; ;     VDC    VIC-II
	; !byte 0    ; black
	; !byte 15   ; white
	; !byte 8    ; red
	; !byte 7    ; cyan
	; !byte 10   ; purple
	; !byte 4    ; green
	; !byte 3    ; blue
	; !byte 13   ; yellow
	; !byte 12   ; orange
	; !byte 12   ; brown 
	; !byte 9    ; light red
	; !byte 1    ; dark grey
	; !byte 14   ; grey
	; !byte 5    ; light green
	; !byte 3    ; light blue
	; !byte 14   ; light grey

C128SetBackgroundColour
	stx .stored_x_or_y
	bit COLS_40_80
	bpl +
	; 80 columns mode selected
	sta .stored_a
	tax
	lda vdc_vic_colours,x
	ldx #VDC_COLORS
	jsr VDCWriteReg
	lda .stored_a
	jmp ++
+	sta reg_backgroundcolour
++	ldx .stored_x_or_y
	rts

C128SetBorderColour
	stx .stored_x_or_y
	bit COLS_40_80
	bmi + ; no border in VDC, only use background
	; 40 column mode
	sta reg_bordercolour
+	ldx .stored_x_or_y
	rts

VDCGetChar
	; 80 columns, use VDC screen
	sty .stored_x_or_y
	lda zp_screenline + 1
	sec
	sbc #$04 ; adjust from $0400 (VIC-II) to $0000 (VDC)
	tay
	lda zp_screenline
	clc
	adc .stored_x_or_y
	bcc +
	iny
+	jsr VDCSetAddress
	ldy .stored_x_or_y
	ldx #VDC_DATA
	jmp VDCReadReg

VDCPrintChar
	; 80 columns, use VDC screen
	sty .stored_x_or_y
	pha
	lda zp_screenline + 1
	sec
	sbc #$04 ; adjust from $0400 (VIC-II) to $0000 (VDC)
	tay
	lda zp_screenline
	clc
	adc .stored_x_or_y
	bcc +
	iny
+	jsr VDCSetAddress
	pla
	ldy .stored_x_or_y
	ldx #VDC_DATA
	jmp VDCWriteReg

VDCPrintColour
	; 80 columns, use VDC screen
	sty .stored_x_or_y
	; adjust color from VIC-II to VDC format
	tax
	lda vdc_vic_colours,x
	ora #$80 ; lower-case
	pha
	lda zp_colourline + 1
	sec
	sbc #$d0 ; adjust from $d800 (VIC-II) to $0800 (VDC)
	tay
	lda zp_colourline
	clc
	adc .stored_x_or_y
	bcc +
	iny
+	jsr VDCSetAddress
	pla
	ldy .stored_x_or_y
	ldx #VDC_DATA
	jmp VDCWriteReg
}

!ifdef TARGET_MEGA65 {

init_mega65
	; MEGA65 IO enable
	jsr mega65io
	; set 40MHz CPU
	lda #65
	sta 0
	; set 80-column mode
	lda #$c0
	sta $d031
	lda #$c8 + 1 ; +1 loses one pixel on the left, +2 loses one pixel on the right. Leftmost pixel usually empty.
	sta $D016
	; Set colour RAM offset to 0
	lda #0
	sta $d064 
	sta $d065
	; set screen at $0800
	;lda #$26
	;sta $d018
	; disable VIC-II/VIC-III hot registers
	lda $d05d
	and #$7f
	sta $d05d
	rts
	
colour2k
	; start mapping 2nd KB of colour RAM to $DC00-$DFFF
	sei
	pha
	jsr mega65io
	lda #$01
	sta $d030
	pla
	rts

colour1k
	; stop mapping 2nd KB of colour RAM to $DC00-$DFFF
	pha
	jsr mega65io
	lda #$00
	sta $d030
	pla
	cli
	rts
}

s_screen_width !byte 0
s_screen_height !byte 0
s_screen_width_plus_one !byte 0
s_screen_width_minus_one !byte 0
s_screen_height_minus_one !byte 0
s_screen_size !byte 0, 0
!ifdef TARGET_X16 {
s_x16_screen_mode	!byte 0
}

convert_petscii_to_screencode
   ; convert from pet ascii to screen code
	cmp #$40
	bcc ++    ; no change if numbers or special chars
	cmp #$60
	bcs +
	and #%00111111
	rts
+   cmp #$80
	bcs +
	and #%11011111
	rts
+	cmp #$c0
	bcs +
	eor #%11000000
+	and #%01111111
++ 	rts

s_init
	; set up screen_width and screen_width_minus_one
!ifdef TARGET_C128 {
	lda #40
	bit COLS_40_80
	bpl +
	; 80 columns mode selected
	lda #80
+
} else ifdef TARGET_X16 {
	sec
	jsr $ff5f
	sta s_x16_screen_mode
	txa
} else {
	lda #SCREEN_WIDTH
}
	sta s_screen_width
	sta s_screen_width_plus_one
	sta s_screen_width_minus_one
	inc s_screen_width_plus_one
	dec s_screen_width_minus_one

	; set up screen_height and screen_width_minus_one
!ifdef TARGET_X16 {
	tya
} else {
	lda #SCREEN_HEIGHT
}
	sta s_screen_height
	sta s_screen_height_minus_one
	dec s_screen_height_minus_one

	; calculate total screen size
	lda #0
	sta multiplier + 1
	lda s_screen_width
	sta multiplier
	lda s_screen_height
	jsr mult8
	lda product
	sta s_screen_size;
	lda product + 1
	sta s_screen_size + 1;

	; init cursor
	lda #$ff
	sta s_current_screenpos_row ; force recalculation first time
	lda #0
	sta zp_screencolumn
	sta zp_screenrow
	; Set to 0: s_ignore_next_linebreak, s_reverse
	ldx #3
-	sta s_ignore_next_linebreak,x
	dex
	bpl -
	rts

s_plot
	; y=column (0-(SCREEN_WIDTH-1))
	; x=row (0- (SCREEN_HEIGHT-1))
	bcc .set_cursor_pos
	; get_cursor
	ldx zp_screenrow
	ldy zp_screencolumn
	rts
.set_cursor_pos
+	cpx s_screen_height
	bcc +
	ldx s_screen_height_minus_one
+	stx zp_screenrow
	sty zp_screencolumn
	jmp .update_screenpos

s_set_text_colour
!ifdef TARGET_X16 {
	jmp VERASetForegroundColour
} else {
	sta s_colour
	rts
}

s_delete_cursor
!ifdef TARGET_MEGA65 {
	jsr colour2k
}
	lda #$20 ; blank space
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +
	jmp VDCPrintChar
+
}
!ifdef TARGET_X16 {
	jmp VERAPrintChar
} else {
	ldy zp_screencolumn
	sta (zp_screenline),y
!ifdef TARGET_PLUS4 {
	ldx s_colour
	lda plus4_vic_colours,x
} else {
	lda s_colour
}
	sta (zp_colourline),y
!ifdef TARGET_MEGA65 {
	jsr colour1k
}
	rts
}

s_printchar
	; replacement for CHROUT ($ffd2)
	; input: A = byte to write (PETASCII)
	; output: -
	; used registers: -
	stx s_stored_x
	sty s_stored_y

	ldx window_start_row + 1
	cpx s_screen_height
	bcc +
	ldx current_window
	bne +
	; There is no free line to print on, return with carry set
	ldx s_stored_x
	rts
+
	; Fastlane for the most common characters
	cmp #$20
	bcc +
	cmp #$80
	bcc ++ ; .normal_char
	cmp #$a0
	bcc + ; bcs .normal_char
++	jmp .normal_char
+	
	cmp #$0d
	bne +
	; newline
	jmp .perform_newline
+
	cmp #20
	bne +
	; delete
	ldy zp_screencolumn
	jsr s_delete_cursor
	dec zp_screencolumn ; move back
	bpl ++
	inc zp_screencolumn ; Go back to 0 if < 0
	lda zp_screenrow
	ldy current_window
	cmp window_start_row + 1,y
	bcc ++
	dec zp_screenrow
	lda s_screen_width_minus_one ; #SCREEN_WIDTH-1
	sta zp_screencolumn
++  jsr .update_screenpos
	lda #$20
	ldy zp_screencolumn
!ifdef TARGET_C128 {
	bit COLS_40_80
	bmi .col80_1
	; 40 columns, use VIC-II screen
	sta (zp_screenline),y
	lda s_colour
	sta (zp_colourline),y
	jmp .col80_1_end
.col80_1
	jsr VDCPrintChar
.col80_1_end
} else ifdef TARGET_X16 {
    jsr VERAPrintChar
} else {
	sta (zp_screenline),y
	!ifdef TARGET_MEGA65 {
		jsr colour2k
	}
	lda s_colour
	sta (zp_colourline),y
	!ifdef TARGET_MEGA65 {
		jsr colour1k
	}
}
	jmp .printchar_end
+   cmp #$93 
	bne +
	; clr (clear screen)
	lda #0
	sta zp_screencolumn
	sta zp_screenrow
	jsr s_erase_window
	jmp .printchar_end
+   cmp #$12 ; 18
	bne +
	; reverse on
	ldx #$80
	stx s_reverse
	jmp .printchar_end
+   cmp #$92 ; 146
	beq +
	jmp .printchar_end
	; reverse off
+   ldx #0
	stx s_reverse
	bne .normal_char
	jmp .printchar_end ; Always jump
	
.normal_char
	; TODO: perhaps we can remove all testing here and just
	; continue at .resume_printing_normal_char	?
	ldx zp_screencolumn
	bpl +
	; Negative column. Increase column but don't print anything.
	inc zp_screencolumn
-	jmp .printchar_end
+	; Skip if column > SCREEN_WIDTH - 1
	cpx s_screen_width ; #SCREEN_WIDTH
	bcs - ; .printchar_end
	; Reset ignore next linebreak setting
	ldx current_window
	ldy s_ignore_next_linebreak,x
	bpl +
	inc s_ignore_next_linebreak,x
	; Check if statusline is overflowing TODO: Do we really need to check any more?
+	pha
	lda zp_screenrow
	ldy current_window 
	cmp window_start_row,y
	pla ; Doesn't affect C
	bcs .outside_current_window
.resume_printing_normal_char	
	jsr convert_petscii_to_screencode
	ora s_reverse
	pha
	jsr .update_screenpos
	pla
	ldy zp_screencolumn
!ifdef TARGET_C128 {
	bit COLS_40_80
	bmi .col80_2
	; 40 columns, use VIC-II screen
	sta (zp_screenline),y
	lda s_colour
	sta (zp_colourline),y
	jmp .col80_2_end
.col80_2
	jsr VDCPrintChar
	lda s_colour
	jsr VDCPrintColour
.col80_2_end
} else ifdef TARGET_X16 {
	jsr VERAPrintChar
	; lda s_colour
	; jsr VERAPrintColourAfterChar
} else {
	sta (zp_screenline),y
	!ifdef TARGET_MEGA65 {
		jsr colour2k
	}
!ifdef TARGET_PLUS4 {
	ldx s_colour
	lda plus4_vic_colours,x
} else {
	lda s_colour
}
	sta (zp_colourline),y
	!ifdef TARGET_MEGA65 {
		jsr colour1k
	}
}
	iny
	sty zp_screencolumn
	ldx current_window
	bne .printchar_end ; For upper window and statusline (in z3), don't advance to next line.
	cpy s_screen_width ; #SCREEN_WIDTH
	bcc .printchar_end
	dec s_ignore_next_linebreak,x ; Goes from 0 to $ff
!ifdef SCROLLBACK {
	jsr copy_line_to_scrollback
}
	lda #0
	sta zp_screencolumn
	inc zp_screenrow
	lda zp_screenrow
	cmp s_screen_height
	bcs +
	jsr .update_screenpos
	jmp .printchar_end
+
!ifdef TARGET_C128 {
	bit COLS_40_80
	bmi .col80_3
	; 40 columns, use VIC-II screen
	jsr .s_scroll
	jmp .col80_3_end
.col80_3
	jsr .s_scroll_vdc
.col80_3_end
} else ifdef TARGET_X16 {
	jsr .s_scroll_vera
} else {
	jsr .s_scroll
}
.printchar_end
	ldx s_stored_x
	ldy s_stored_y
	rts

.outside_current_window
!ifdef Z4 {
	jmp .printchar_end
} else {
	cpy #1
	bne .printchar_end
	; This is window 1. Expand it if possible.
	ldy zp_screenrow
	cpy window_start_row ; Compare to end of screen (window 0)
	bcs .printchar_end
	iny
	sty window_start_row + 1
	; Move lower window cursor if it gets hidden by upper window
	cpy cursor_row
	bcc +
	sty cursor_row
+	jmp .resume_printing_normal_char ; Always branch
}

.perform_newline
	; newline/enter/return
	; Check ignore next linebreak setting
	ldx current_window
	ldy s_ignore_next_linebreak,x
	bpl +
	inc s_ignore_next_linebreak,x
	jmp .printchar_end
+	
!ifdef SCROLLBACK {
	; Copy to scrollback buffer, if we're in lower window
	ldx current_window
	bne +
	jsr copy_line_to_scrollback
+
}
	lda #0
	sta zp_screencolumn
	inc zp_screenrow
!ifdef TARGET_C128 {
	bit COLS_40_80
	bmi .col80_4
	; 40 columns, use VIC-II screen
	jsr .s_scroll
	jmp .col80_4_end
.col80_4
	jsr .s_scroll_vdc
.col80_4_end
} else ifdef TARGET_X16 {
	jsr .s_scroll_vera
} else {
	jsr .s_scroll
}
	jsr .update_screenpos
	jmp .printchar_end

s_erase_window
	lda #0
	sta zp_screenrow
-   jsr s_erase_line
	inc zp_screenrow
	lda zp_screenrow
	cmp s_screen_height
	bne -
	lda #0
	sta zp_screenrow
	sta zp_screencolumn
	rts

.update_screenpos
	; set screenpos (current line) using row
	ldx zp_screenrow
	cpx s_current_screenpos_row
	beq .same_row
	; need to recalculate zp_screenline
	stx s_current_screenpos_row
!ifdef TARGET_X16 {
    txa
	sta zp_screenline + 1
	sta zp_colourline + 1
    lda #0
	sta zp_screenline
	sta zp_colourline
} else ifdef TARGET_MEGA65 {
	; calculate zp_screenline = zp_current_screenpos_row * 40
	; Use MEGA65's hardware multiplier
	jsr mega65io
	stx $d770
	lda #0
	sta $d771
	sta $d772
	sta $d773
	sta $d775
	sta $d776
	sta $d777
	lda s_screen_width ; #SCREEN_WIDTH
	sta $d774
	;
	; add screen offsets
	;
	lda $d778
	sta zp_screenline
	sta zp_colourline
	lda $d779
	and #$07
	clc
	adc #>SCREEN_ADDRESS ; add screen start ($0400 for C64)
	sta zp_screenline+1
	clc
	adc #>COLOUR_ADDRESS_DIFF ; add colour start ($d800 for C64)
	sta zp_colourline+1
} else {
	; calculate zp_screenline = zp_current_screenpos_row * s_screen_width
	stx product + 1
	txa
	asl ; 2x
	asl ; 4x
	adc product + 1 ; 5x
	asl ; 10x
	asl
	ldx #0
	stx product + 1
	rol product + 1 ; 20x
	asl
	rol product + 1 ; 40x
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl ++
	asl
	rol product + 1 ; 80x
++
}
	sta zp_screenline
	sta zp_colourline
	lda product + 1
	;
	; add screen offsets
	;
	adc #>SCREEN_ADDRESS ; add screen start ($0400 for C64)
	sta zp_screenline +1
	adc #>COLOUR_ADDRESS_DIFF ; add colour start ($d800 for C64)
	sta zp_colourline + 1
}
.same_row
	rts

!ifdef TARGET_C128 {
.s_scroll_vdc
	; scroll routine for 80 column C128 mode, using the blitter
	lda zp_screenrow
	cmp s_screen_height
	bpl +
	rts
+   
	ldx scroll_delay
	beq .done_delaying_vdc
-	txa
	pha
	jsr wait_an_interval
	pla
	tax
	dex
	bne -
.done_delaying_vdc

	; set up copy mode
	ldx #VDC_VSCROLL
	jsr VDCReadReg
	ora #$80 ; set copy bit
	jsr VDCWriteReg
	; scroll characters
	lda #$00
	jsr .s_scroll_vdc_copy
!ifdef COLOURFUL_LOWER_WIN {
	; scroll colours
	lda #$08
	jsr .s_scroll_vdc_copy
}
	; prepare for erase line
	sty zp_screenrow
	lda #$ff
	sta s_current_screenpos_row ; force recalculation
	jmp s_erase_line

.s_scroll_vdc_copy
	; input: a = offset (0 for characters, $08 for colours)
	;
	; calculate start position (start_row * screen_width)
	pha
	lda s_screen_width
	sta multiplier
	lda #0
	sta multiplier + 1
	lda window_start_row + 1 ; how many top lines to protect
	jsr mult8
	; set up source and destination
	pla
	clc
	adc product + 1
	tay
	lda product
	jsr VDCSetAddress ; where to copy to (first line)
	clc
	adc s_screen_width
	bcc +
	iny
+	jsr VDCSetCopySourceAddress ; where to copy from (next line)
	; start copying
	ldy window_start_row + 1 ; how many top lines to protect
-	cpy s_screen_height_minus_one
	beq +
	lda #80 ;copy 80 bytes
	ldx #VDC_COUNT
	jsr VDCWriteReg
	iny
	bne - ; Always branch
+	rts
}

!ifdef SCROLLBACK {
s_reset_scrolled_lines
	pha
	lda #0
	sta s_scrolled_lines
	pla
	rts

s_scrolled_lines !byte 0
}

.s_scroll
	lda zp_screenrow
	cmp s_screen_height
	bpl +
	rts

+	
!ifdef SCROLLBACK {
	inc s_scrolled_lines
}
	ldx window_start_row + 1 ; how many top lines to protect
	inx
	stx zp_screenrow
;	inc zp_screenrow
	jsr .update_screenpos
	lda zp_screenline
	sta .scroll_load_screen + 1
	lda zp_screenline + 1
	sta .scroll_load_screen + 2
!ifdef COLOURFUL_LOWER_WIN {
	lda zp_colourline
	sta .scroll_load_colour + 1
	lda zp_colourline + 1
	sta .scroll_load_colour + 2
}
	dec zp_screenrow
	jsr .update_screenpos
	lda zp_screenline
	sta .scroll_store_screen + 1
	lda zp_screenline + 1
	sta .scroll_store_screen + 2
!ifdef COLOURFUL_LOWER_WIN {
	lda zp_colourline
	sta .scroll_store_colour + 1
	lda zp_colourline + 1
	sta .scroll_store_colour + 2
}
!ifdef SMOOTHSCROLL {
	lda smoothscrolling
	beq +
	jsr smoothscroll
+
}

!ifndef TARGET_X16 {
; ----------- Delay for slower scrolling

	ldx scroll_delay
	beq .done_delaying
!ifdef TARGET_MEGA65 {
	clc ; Carry is expected to be clear when entering the following loop
	lda #rasterline_for_scroll
} else {
	lda window_start_row + 1 ; how many top lines to protect
	asl
	asl
	asl ; Multiplied by 8 (There are 8 raster lines per row)
	adc #rasterline_for_scroll
}
	sei
--
	cmp reg_rasterline
	bne --
!ifndef TARGET_MEGA65 {
!ifdef TARGET_PLUS4 {
	pha
	lda reg_rasterline_highbit
	lsr
	pla
	bcs --
} else {
	bit reg_rasterline_highbit
	bmi --
}
}
	adc #0 ; Carry is always set, so this adds 1
;	lda #rasterline_for_scroll + 1
-	cmp reg_rasterline
	bne -
	sbc #1 ; Carry is set, so this subtracts 1
	dex
	bne --
	cli
.done_delaying
}
!ifdef TARGET_MEGA65 {
	jsr colour2k	
}

	lda s_screen_height_minus_one
	sec
	sbc zp_screenrow
	tax
	beq .done_scrolling
	clc
;	sei
-
	ldy s_screen_width_minus_one
.scroll_load_screen
	lda $8000,y ; This address is modified above
.scroll_store_screen
	sta $8000,y ; This address is modified above
!ifdef COLOURFUL_LOWER_WIN {
.scroll_load_colour
	lda $8000,y ; This address is modified above
.scroll_store_colour
	sta $8000,y ; This address is modified above
}
	dey
	bpl .scroll_load_screen
	dex
	beq .done_scrolling
	lda .scroll_store_screen + 1
;	clc
	adc s_screen_width
	sta .scroll_store_screen + 1
!ifdef COLOURFUL_LOWER_WIN {
	sta .scroll_store_colour + 1
}
	bcc +
	clc
	inc .scroll_store_screen + 2
!ifdef COLOURFUL_LOWER_WIN {
	inc .scroll_store_colour + 2
}
+		
; !ifdef COLOURFUL_LOWER_WIN {
	; lda .scroll_store_colour + 1
	; adc s_screen_width
	; sta .scroll_store_colour + 1
	; bcc +
	; clc
	; inc .scroll_store_colour + 2
; +	
; }
	lda .scroll_load_screen + 1
	adc s_screen_width
	sta .scroll_load_screen + 1
!ifdef COLOURFUL_LOWER_WIN {
	sta .scroll_load_colour + 1
}
	bcc -
	clc
	inc .scroll_load_screen + 2
!ifdef COLOURFUL_LOWER_WIN {
	inc .scroll_load_colour + 2
}

; !ifdef COLOURFUL_LOWER_WIN {
	; lda .scroll_load_colour + 1
	; adc s_screen_width
	; sta .scroll_load_colour + 1
	; bcc -
	; clc
	; inc .scroll_load_colour + 2
; }	
	bne - ; Always branch

.done_scrolling
;	cli
;	dec reg_backgroundcolour
;	inc reg_backgroundcolour

!ifdef TARGET_MEGA65 {
	jsr colour1k
}
!ifdef SMOOTHSCROLL {
	+done_smoothscroll
}
	lda s_screen_height_minus_one
	sta zp_screenrow
	lda #$ff
	sta s_current_screenpos_row ; force recalculation
s_erase_line
	; registers: a,x,y
	lda zp_screenrow
	cmp s_screen_height
	bcc +
	rts ; Illegal row, just ignore
+	lda #0
	sta zp_screencolumn
	jsr .update_screenpos
	ldy #0
.erase_line_from_any_col	
!ifdef TARGET_C128 {
	bit COLS_40_80
	bmi .col80_5
	; 40 columns, use VIC-II screen
-	cpy s_screen_width
	bcs .done_erasing
	lda #$20
	sta (zp_screenline),y
	lda s_colour
	sta (zp_colourline),y
	iny
	bne - ; Always branch
	jmp .done_erasing	
.col80_5
	; erase line in VDC
	tya
	clc 
	adc zp_screenline
	pha
	lda zp_screenline + 1
	adc #$00
	sec
	sbc #$04
	sta .stored_a
	ldx #VDC_DATA_HI
	jsr VDCWriteReg
	pla
	pha
	ldx #VDC_DATA_LO
	jsr VDCWriteReg
	lda #$20

	ldx #VDC_DATA
	jsr VDCWriteReg
	; We have written a space character to the first position
	; Now fill the rest of the line.
	lda #0 ; Set to Fill mode
	ldx #VDC_VSCROLL
	jsr VDCWriteReg
	sty .stored_x_or_y
	lda #79
	sec
	sbc .stored_x_or_y
	beq +
	ldx #VDC_COUNT
	jsr VDCWriteReg
+

	lda .stored_a
	clc
	adc #$08 ; Colour RAM starts at $0800, while screen RAM starts at $0000
	ldx #VDC_DATA_HI
	jsr VDCWriteReg
	pla
	ldx #VDC_DATA_LO
	jsr VDCWriteReg

	ldx s_colour
	lda vdc_vic_colours,x
	ora #$80 ; lower-case
	ldx #VDC_DATA
	jsr VDCWriteReg
	; We have written the first byte to colour memory
	; Now fill the rest of the line.
	lda #0 ; Set to Fill mode
	ldx #VDC_VSCROLL
	jsr VDCWriteReg
	sty .stored_x_or_y
	lda #79
	sec
	sbc .stored_x_or_y
	beq +
	ldx #VDC_COUNT
	jsr VDCWriteReg
+


	; tya
	; pha
; -	cpy s_screen_width
	; bcs +
	; lda #$20
	; jsr VDCPrintChar
	; iny
	; bne -
	; also reset attributes/colours
;+	pla
;	tay

; -	cpy s_screen_width
	; bcs .done_erasing
	; lda s_colour
	; jsr VDCPrintColour
	; iny
	; bne -
} else {

; set colour
!ifdef TARGET_MEGA65 {
	jsr colour2k
}
!ifdef TARGET_X16 {
	jsr .convert_screenline_y_to_vera_address
}
-	cpy s_screen_width
	bcs .done_erasing
	; set character
	lda #$20
!ifdef TARGET_X16 {
    sta VERA_data0
} else {
	sta (zp_screenline),y
}
!ifdef TARGET_PLUS4 {
	ldx s_colour
	lda plus4_vic_colours,x
} else {
	lda s_colour
}
!ifdef TARGET_X16 {
	ora .vera_background
    sta VERA_data0
} else {
	sta (zp_colourline),y
}
	iny
	bne -
}
.done_erasing	
!ifdef TARGET_MEGA65 {
	jsr colour1k
}

 	rts
s_erase_line_from_cursor
	jsr .update_screenpos
	ldy zp_screencolumn
	jmp .erase_line_from_any_col

s_cursorswitch !byte 0
!ifdef USE_BLINKING_CURSOR {
s_cursormode !byte 0
}
turn_on_cursor
!ifdef USE_BLINKING_CURSOR {
    jsr reset_cursor_blink
    lda #CURSORCHAR
    sta cursor_character
}
    lda #1
    sta s_cursorswitch
    bne update_cursor ; always branch

turn_off_cursor
    lda #0
    sta s_cursorswitch

update_cursor
    sty object_temp
	jsr .update_screenpos
    ldy zp_screencolumn
	bmi .skip_cursor_update
	cpy s_screen_width
	bcs .skip_cursor_update
    lda s_cursorswitch
    bne +++
    ; no cursor
    jsr s_delete_cursor
    ldy object_temp
    rts
+++ ; cursor
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +
    ; 80 columns
    lda cursor_character
    jsr VDCPrintChar
    lda current_cursor_colour
    jsr VDCPrintColour
    jmp .vdc_printed_char_and_colour
+   ; 40 columns
} else ifdef TARGET_X16 {
	lda s_colour
	pha
	lda current_cursor_colour
	and #15
	jsr VERASetForegroundColour
	lda cursor_character
	jsr VERAPrintChar
	pla
	jsr VERASetForegroundColour
	; lda current_cursor_colour
	; jsr VERAPrintColourAfterChar
}
!ifndef TARGET_X16 {
    lda cursor_character
    sta (zp_screenline),y
    lda current_cursor_colour
!ifdef TARGET_PLUS4 {
    stx object_temp + 1
    tax
    lda plus4_vic_colours,x
    ldx object_temp + 1
}
!ifdef TARGET_MEGA65 {
    jsr colour2k
}
    sta (zp_colourline),y
!ifdef TARGET_MEGA65 {
    jsr colour1k
}
}

.vdc_printed_char_and_colour

.skip_cursor_update
    ldy object_temp
    rts

write_default_colours_to_header
	; On exit:
	; a = fg colour (2-9)
	; x = darkmode
	; y = destroyed
	ldx darkmode
	lda bgcol,x
	ldy #header_default_bg_colour
	jsr write_header_byte
	lda fgcol,x
	ldy #header_default_fg_colour
	jmp write_header_byte

!ifndef NODARKMODE {

.new_bg 		= z_temp + 5 ; New background colour, adapted to target platform
.new_fg_c64		= z_temp + 6 ; New foreground colour, as C64 colour
.new_fg			= z_temp + 7 ; New foreground colour, adapted to target platform
.new_input		= z_temp + 8 ; New input colour, adapted to target platform
.old_input		= z_temp + 9 ; Old input colour, adapted to target platform
.colour_ram_pointer = z_temp + 10 ; (2 bytes) Pointer into colour RAM

toggle_darkmode

!ifdef TARGET_X16 {
	ldy #0
	sty zp_screenline + 1
	jsr .convert_screenline_y_to_vera_address
	lda #0
	sta VERA_ctrl
}

!ifdef Z5PLUS {
	; We will need the old fg colour later, to check which characters have the default colour
	ldx darkmode ; previous darkmode value (0 or 1)
	ldy fgcol,x
	lda zcolours,y
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +
	; 80 columns mode selected
	tay
	lda vdc_vic_colours,y
+
}
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y
}
	sta .old_input ; old fg colour TODO - was +9, but comment says old fg?
} else { ; This is z3 or z4
!ifdef USE_INPUTCOL {

	; We will need the old input colour later, to check which characters are input text
	ldx darkmode ; previous darkmode value (0 or 1)
	ldy inputcol,x
	lda zcolours,y
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +
	; 80 columns mode selected
	tay
	lda vdc_vic_colours,y
+
}
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y
}
	sta .old_input ; old input colour

	; If the mode we switch *from* has inputcol = fgcol, make sure inputcol is never matched
	lda inputcol,x
	cmp fgcol,x
	bne +
	inc .old_input
+
} ; USE_INPUTCOL

} ; else (not Z5PLUS)


; Toggle darkmode
	lda darkmode
	eor #1
	sta darkmode
	tax
	
!ifdef USE_INPUTCOL {
	ldy inputcol,x
	lda zcolours,y
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +
	; 80 columns mode selected
	tay
	lda vdc_vic_colours,y
+
}
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y
}
	sta .new_input ; new input colour

} ; USE_INPUTCOL	
	
; Write colours to header
	jsr write_default_colours_to_header	
	
; Set fgcolour
;	ldy fgcol,x
	; ldy #header_default_fg_colour
	; jsr write_header_byte
	tay
	lda zcolours,y
	sta .new_fg_c64 ; New foreground colour, as C64 colour 
	jsr s_set_text_colour
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +
	; 80 columns mode selected
	tay
	lda vdc_vic_colours,y
+
}
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y
}
	sta .new_fg ; New foreground colour, transformed for target platform
!ifdef TARGET_MEGA65 {
	jsr colour2k
}
; Set cursor colour
	ldy cursorcol,x
	lda .new_fg_c64
	cpy #1
	beq +
	lda zcolours,y
+	sta current_cursor_colour
; Set bgcolour
	ldy bgcol,x
	; ldy #header_default_bg_colour
	; jsr write_header_byte
	; tay
	lda zcolours,y
!ifdef Z5PLUS {
	; We will need the new bg colour later, to check which characters would become invisible if left unchanged
	sta .new_bg ; new background colour
}
	+SetBackgroundColour
; Set border colour 
	ldy bordercol,x
!ifdef BORDER_MAY_FOLLOW_BG {
	beq .store_bordercol
}
!ifdef BORDER_MAY_FOLLOW_FG {
	cpy #1
	bne +
	ldy fgcol,x
+	
}
	lda zcolours,y
.store_bordercol
	+SetBorderColour

	; update colour memory with new colours
!ifndef Z4PLUS {

; For Z3: Set statusline colour
	ldy statuslinecol,x
	lda zcolours,y
!ifdef TARGET_X16 {
	ora .vera_background
} else ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +
	; 80 columns mode selected
	tay
	lda vdc_vic_colours,y
+
}
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y
}
	ldy s_screen_width_minus_one
-
!ifdef TARGET_X16 {
	ldx VERA_data0 ; Go past character
	sta VERA_data0
;	jsr VERAPrintColourAfterChar
} else ifdef TARGET_C128 {
	bit COLS_40_80
	bmi +
	sta COLOUR_ADDRESS,y
	jmp ++
+
	; 80 columns mode selected
	sty s_stored_y
	pha
	ldy #$08
	lda s_stored_y
	jsr VDCSetAddress
	pla
	ora #$80 ; lower-case
	ldx #VDC_DATA
	jsr VDCWriteReg
	ldy s_stored_y
++
} else {
	sta COLOUR_ADDRESS,y
}
	dey
	bpl -
}

; ---------- CHANGE COLOURS IN MAIN WINDOW (both for Z4+)

!ifdef TARGET_X16 {
	lda s_screen_height_minus_one
	sta zp_screenline + 1
--	ldy #0
	jsr .convert_screenline_y_to_vera_address
-	lda VERA_data0 ; Skip character data
	lda VERA_data0 ; Get colour data
;	sta z_temp + 5 ; Temporary storage
	and #$0f
!ifdef USE_INPUTCOL {
	cmp .old_input ; Old input colour
	bne +
	lda .new_input ; New input colour
	jmp ++
+
	; cmp .old_fg
	; beq +++
	; cmp .new_bg ; New background colour
	; bne ++
; +++
}
	lda .new_fg
++	dec VERA_addr_low
	ora .vera_background
	sta VERA_data0
;	jsr VERAPrintColourAfterChar
	iny
	cpy s_screen_width
	bcc -
	dec zp_screenline + 1
	lda zp_screenline + 1
!ifdef Z4PLUS {
	bpl --
} else {
	bne --
}
} else {
	;; Work out how many pages of colour RAM to examine
	ldx s_screen_size + 1
	inx
	ldy #>COLOUR_ADDRESS
	sty .colour_ram_pointer + 1
	ldy #0
	sty .colour_ram_pointer
!ifndef Z4PLUS {
	ldy s_screen_width ; Since we have coloured the statusline separately, skip it now
}
!ifndef Z5PLUS {
;	ldy #0 ; But y is already 0, so we skip this
	lda .new_fg ; For Z3 and Z4 we can just load this value before the loop  
}
.compare
!ifdef TARGET_C128 {
	lda .new_fg  ; too much work to read old colour from VDC
	bit COLS_40_80
	bmi .toggle_80
} ; else {
!ifdef Z5PLUS {
	lda (.colour_ram_pointer),y
!ifndef TARGET_PLUS4 {
	and #$0f
}
	cmp .old_input
	beq .change
	cmp .new_bg ; New background colour
	bne .dont_change
.change	
	lda .new_fg
}

!ifdef USE_INPUTCOL {
	lda (.colour_ram_pointer),y
!ifndef TARGET_PLUS4 {
	and #$0f
}
	cmp .old_input
	bne .change
	lda .new_input
	bne + ; Always branch
.change	
	lda .new_fg
+
}

.toggle_80

; }
!ifdef TARGET_C128 {
	pha
	bit COLS_40_80
	bmi +
	pla
	sta (.colour_ram_pointer),y
	jmp ++
+
	; 80 columns mode selected
	stx s_stored_x
	sty s_stored_y
	lda .colour_ram_pointer + 1
	sec
	sbc #$d0 ; adjust from $d800 (VIC-II) to $0800 (VDC)
	tay
	lda .colour_ram_pointer
	clc
	adc s_stored_y
	bcc +
	iny
+	jsr VDCSetAddress
	pla
	ora #$80 ; lower-case
	ldy s_stored_y
	ldx #VDC_DATA
	jsr VDCWriteReg
	ldx s_stored_x
++
} else {
	sta (.colour_ram_pointer),y
}
.dont_change
	iny
	bne .compare
	inc .colour_ram_pointer + 1
	dex
	bne .compare
!ifdef TARGET_MEGA65 {
	jsr colour1k
}
} ; Not TARGET_X16

!ifdef USE_INPUTCOL {
	; Switch to the new input colour, if input colour is active (we could be at a MORE prompt or in a timed input)
	lda input_colour_active
	beq +
	jsr activate_inputcol
	ldx darkmode
+
}

!ifdef TARGET_X16 {
	ldy zp_screenrow
	sty zp_screenline + 1
}
	jmp update_cursor
} ; ifndef NODARKMODE

!ifdef Z5PLUS {
z_ins_set_colour
	; set_colour foreground background [window]
	; (window is not used in Ozmoo)
	jsr printchar_flush

; Load y with bordercol (needed later)
	ldx darkmode
	ldy bordercol,x

; Set background colour
	ldx z_operand_value_low_arr + 1
	beq .current_background
	lda zcolours,x
	bpl +
	sty zp_temp
	ldy #header_default_bg_colour - 1
	jsr read_header_word
	ldy zp_temp
	lda zcolours,x
+   
	+SetBackgroundColour
; Also set bordercolour to same as background colour, if bordercolour is set to the magic value 0
	cpy #0
	bne .current_background
	+SetBorderColour
.current_background

; Set foreground colour
	ldx z_operand_value_low_arr
	beq .current_foreground
	lda zcolours,x
	bpl + ; Branch unless it's the special value $ff, which means "default colour"
	sty zp_temp
	ldy #header_default_fg_colour - 1
	jsr read_header_word
	ldy zp_temp
	lda zcolours,x
+
; Also set bordercolour to same as foreground colour, if bordercolour is set to the magic value 1
	cpy #1
	bne +
	+SetBorderColour
+
	jsr s_set_text_colour ; change foreground colour
.current_foreground

; Set cursor colour
	lda s_colour
	ldx darkmode
	ldy cursorcol,x
	cpy #1
	beq +
	lda zcolours,y
+	sta current_cursor_colour

	rts
}

!ifdef TESTSCREEN {

.testtext
	;!pet 147,2,"hello",3,"johan",0
	!pet 2, 5,147,18,"Status Line 123         ",146,13    ; white REV
	!pet 3, 28,"resx",20,"t aA@! ",18,"Test aA@!",146,13  ; red
	!pet 155,"third",20,13                                ; light gray
	!pet "fourth line",13
	!pet 13,13,13,13,13,13
	!pet 13,13,13,13,13,13,13
	!pet 13,13,13,13,13,13,13
	!pet "last line",1
	!pet "aaaaaaaaabbbbbbbbbbbcccccccccc",1
	!pet "d",1 ; last char on screen
	!pet "efg",1 ; should scroll here and put efg on new line
	!pet 13,"h",1; should scroll again and f is on new line
	!pet 0

testscreen
	jsr init_screen_colours
!ifdef TARGET_X16 {
    lda #14 
    jsr $ffd2
} else ifdef TARGET_PLUS4 {
	lda #212 ; 212 upper/lower, 208 = upper/special
} else {
	lda #23 ; 23 upper/lower, 21 = upper/special (22/20 also ok)
}
	sta reg_screen_char_mode
	jsr s_init
    lda #3
    +SetBackgroundColour
	lda #1
	sta zp_screenrow
    jsr s_erase_line
    ;rts
	lda s_screen_height
	sta window_start_row ; total number of  lines in window 0
	lda #1
	sta window_start_row + 1 ; 1 status line
	sta window_start_row + 2 ; 1 status line
	lda #0
	sta window_start_row + 3
	ldx #0
-   lda .testtext,x
	bne +
	rts
+   cmp #2
	bne +
	; use upper window
	lda #1
	sta current_window
	jmp ++
+   cmp #3
	bne +
	; use lower window
	lda #0
	sta current_window
	jmp ++
+   cmp #1
	bne +
	txa
	pha
--  jsr kernal_getchar
	beq --
	pla
	tax
	bne ++
	; NOTE: s_printchar no longer recognizes the colour codes, so the
	; colours will not change. But rev on/off still works
+   jsr s_printchar
++  inx
	bne -
}
}

