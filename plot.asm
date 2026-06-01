; Plot.asm
;   Draw a single yellow pixel on the Atari 800XL
;   Using CIO to open GR.7 then writing directly to screen RAM

CIOV    = $E456     ; OS CIO entry point
ICCOM   = $0342     ; IOCB base command
ICBAL   = $0344     ; buffer address low
ICBAH   = $0345     ; buffer address high
ICAX1   = $034A     ; aux byte 1
ICAX2   = $034B     ; aux byte 2
SAVMSC  = $58       ; zero page — screen RAM address low ($59 = high byte)
ATRACT  = $4D       ; attract mode counter — keep at 0 to prevent color washout
ATRMSK  = $4E       ; attract mode color mask

        org $2000

        .proc main

        ; close IOCB6 first (good practice)
        ldx #$60            ; IOCB6
        lda #$0C            ; CLOSE command
        sta ICCOM,x
        jsr CIOV

        ; open graphics mode 7 with text window on IOCB6
        ldx #$60            ; IOCB6
        lda #$03            ; OPEN command
        sta ICCOM,x
        lda #<scrname       ; point to device name "S:"
        sta ICBAL,x
        lda #>scrname
        sta ICBAH,x
        lda #$07            ; graphics mode 7 with text window
        sta ICAX2,x
        lda #$0C            ; read/write access
        sta ICAX1,x
        jsr CIOV            ; call OS CIO — sets up display list and screen RAM

        ; fill screen with black
        ldx #0
clearscreen:
        lda #$00
        sta $B060,x
        inx
        bne clearscreen

        lda #$55
        sta $BCDF

stop:
        mva #0 ATRACT
        mva #$FF ATRMSK
        mva #$1E $02C4
        jmp stop

        .endp

scrname .byte 'S:',$9B      ; device name with end of line marker

        run main