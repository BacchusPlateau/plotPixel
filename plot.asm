; Plot.asm
CIOV    = $E456     ; OS CIO entry point
ICCOM   = $0342     ; IOCB base command  
ICBAL   = $0344     ; buffer address low
ICBAH   = $0345     ; buffer address high
ICAX1   = $034A     ; aux byte 1
ICAX2   = $034B     ; aux byte 2
SAVMSC  = $58       ; zero page — screen RAM address low
                    ; $59 = high byte

        org $2000

        .proc main

        ; close IOCB6 first (good practice)
        ldx #$60            ; IOCB6
        lda #$0C            ; CLOSE command
        sta ICCOM,x
        jsr CIOV

        ; open graphics mode 7 on IOCB6
        ldx #$60            ; IOCB6
        lda #$03            ; OPEN command
        sta ICCOM,x
        lda #<scrname       ; point to "S:"
        sta ICBAL,x
        lda #>scrname
        sta ICBAH,x
        lda #$07            ; graphics 7 with text window
        sta ICAX2,x
        lda #$0C            ; read/write
        sta ICAX1,x
        jsr CIOV

        ; set yellow color
        lda #$1E
        sta $02C5           ; COLOR1 shadow register

        ; find screen RAM address from SAVMSC
        ; lower right pixel is at last byte of screen RAM
        ; GR.7 = 160x96, 40 bytes per row, 96 rows = 3840 bytes
        ; last byte = SAVMSC + 3839 = SAVMSC + $EFF

        lda #$1E
        sta $02C4           ; COLOR0 shadow — for pixel value $01

        lda $58             ; low byte of screen RAM address
        clc
        adc #$FF            ; add low byte of offset $EFF
        sta $80             ; store in zero page pointer
        lda $59             ; high byte
        adc #$0E            ; add high byte of offset $EFF
        sta $81             ; store high byte

        ldy #0
        lda #$01            ; color 1 pixel value
        sta ($80),y         ; write pixel!

stop:
        jmp stop

        .endp

scrname .byte 'S:',$9B      ; device name with end of line marker

        run main