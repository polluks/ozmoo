; Which Z-machine to generate binary for
;Z5 = 1
Z5 = 1

; Define DEBUG for additional runtime printouts
DEBUG = 1

; where to store story data
mem_start = $2000

; story file header constants
header_version = $0
header_flags_1 = $1
header_high_mem = $4
header_initial_pc = $6
header_dictionary = $8
header_object_table = $a
header_globals = $c
header_static_mem = $e
header_flags_2 = $10
header_abbreviations = $18
header_filelength = $1a
header_checksum = $1c
header_interpreter_number = $1e
header_interpreter_version = $1f
header_screen_height_lines = $20
header_screen_width_chars = $21
header_screen_width_units = $22
header_screen_height_units = $24
header_font_width_units = $26
header_font_height_units = $27
header_default_bg_color = $2c
header_default_fg_color = $2d
header_terminating_chars_table = $2e
header_standard_revision_number = $32
header_alphabet_table = $34
header_header_extension_table = $36

; basic program (10 SYS2061)
!source "basic-boot.asm"
    +start_at $080d
    jmp .initialize

; global variables
err !byte 0
filelength !byte 0, 0, 0, 0

; include other assembly files
!source "disk.asm"
!source "screen.asm"
!source "memory.asm"

.initialize
    ; read the header
    lda #>mem_start ; first free memory block
    ldx #$00    ; first block to read from floppy
    ldy #$01    ; read 1 block
    jsr readblocks

    ; check z machine version
    lda mem_start + header_version
!if Z5 {
    cmp #5
}
    beq +  ; this version is supported by this binary
    jsr fatalerror
    !pet "unsupported story version", 0

+   ; check file length
!if Z5 {
    ; file length should be multiplied by 4 (for Z5)
	lda #0
	sta filelength
    lda mem_start + header_filelength
	sta filelength + 1
    lda mem_start + header_filelength + 2
	asl
	sta filelength + 2
	rol filelength + 1
	rol filelength
	asl filelength + 2
	rol filelength + 1
	rol filelength
	lda filelength + 1
}

!ifdef DEBUG {
    ; show how many blocks to read (exluding header)
    jsr printstring
    !pet "total blocks: ",0
    ldx filelength + 1
    jsr printx
}

    ; read the rest
    ldx #>mem_start ; first free memory block
    inx        ; skip header
    txa
    ldx #$01    ; first block to read from floppy
    ldy filelength + 1 ; read the rest of the blocks
    dey ; skip the header
    jsr readblocks
    rts
