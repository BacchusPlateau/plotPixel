; Plot.asm
;   main file for experimenting with graphics

; IOCB 6 fields
CIOV    = $E456                         ; OS CIO entry point
ICCOM   = $0362                         ; IOCB 6 command
ICAX1   = $036A                         ; IOCB 6 auxiliary byte 1
ICAX2   = $036B                         ; IOCB 6 auxiliary byte 2
ICBAL   = $0364                         ; IOCB 6 buffer address low
ICBAH   = $0365                         ; IOCB 6 buffer address high
ICBLL   = $0368                         ; IOCB 6 buffer length low
ICBLH   = $0369                         ; IOCB 6 buffer length high


        org $2000                       ; place the following code at memory address $2000


        .proc main                      ; declare procedure named "main", begin its scope

; Open GR.7 full screen
        lda #$03                        ; $03 = OPEN command
        sta ICCOM                       ; store command in IOCB 6
        lda #$0C                        ; $0C = GR.7 + no text window
        sta ICAX1                       ; store graphics mode
        lda #$00                        ; 
        sta ICAX2                       ; clear aux byte 2
        ldx #$60                        ; X = $60 tells CIOV to use IOCB 6
        

; point ICBAL/ICBAH to device name
        lda #<devname
        sta ICBAL
        lda #>devname
        sta ICBAH
        lda #2                          ; length of "S:"
        sta ICBLL
        lda #0
        sta ICBLH

        jsr CIOV                        ; call OS CIO

stop:
        jmp stop                        ; GOTO stop                   (infinite loop = program halts here)

        .endp                           ; end of main procedure

; =====================================================================
; DATA section
; =====================================================================

        .local devname 
        .byte 'S:'
        .endl

; =====================================================================
; ENTRY POINT
; =====================================================================

        run main                        ; set Atari run address to main (auto-execute when program loads)