; =====================================================================
; Plot.asm
;   Draw yellow pixels on the Atari 800XL in Graphics Mode 7
;   Uses CIO (Central I/O) to open the graphics mode, then writes
;   pixel data directly to screen RAM.
;
;   GR.7 screen properties:
;   - 160 pixels wide x 96 pixels tall (with text window: 80 rows)
;   - 4 colors using color registers
;   - Each byte contains 4 pixels (2 bits per pixel)
;   - 40 bytes per row x 80 rows = 3200 bytes of screen RAM
;   - Pixel value %01010101 ($55) = 4 yellow pixels using COLOR0
; =====================================================================


; Zero page variables
plotX   = $82       ; X coordinate (0-159)
plotY   = $83       ; Y coordinate (0-79)
temp    = $84       ; temporary storage for multiplication
scrptr_lo = $85     ; calculated screen address low byte
scrptr_hi = $86     ; calculated screen address high byte


; =====================================================================
; CIO (Central I/O) constants
; CIO is the Atari OS I/O system. We use it to open graphics mode.
; Each I/O channel uses an IOCB (I/O Control Block) — a fixed block
; of memory containing command, device, buffer address, and aux bytes.
; We use IOCB6 (base address $0360) for graphics.
; X register = $60 tells CIOV which IOCB to use (IOCB6).
; =====================================================================
CIOV    = $E456     ; OS CIO entry point — call jsr CIOV to execute
ICCOM   = $0342     ; IOCB6 command register
                    ;   $03 = OPEN   (open a device)
                    ;   $0C = CLOSE  (close a device)
ICBAL   = $0344     ; IOCB6 buffer address low byte
                    ;   for OPEN: points to device name string "S:"
ICBAH   = $0345     ; IOCB6 buffer address high byte
                    ;   together with ICBAL forms 16-bit pointer to "S:"
ICAX1   = $034A     ; IOCB6 auxiliary byte 1
                    ;   for OPEN: $0C = read/write access mode
ICAX2   = $034B     ; IOCB6 auxiliary byte 2
                    ;   for OPEN: graphics mode number (7 = GR.7)

; =====================================================================
; Screen RAM pointer
; After CIO opens GR.7, the OS stores the address of screen RAM
; in SAVMSC (two bytes). $58 = low byte, $59 = high byte.
; On our 800XL PAL system screen RAM ends up at $B060.
; =====================================================================
SAVMSC  = $58       ; zero page address — low byte of screen RAM address
                    ; $59 automatically contains the high byte

; =====================================================================
; Attract mode constants
; The Atari OS has an attract mode that kicks in after inactivity
; to prevent screen burn-in. It does this by desaturating all colors
; making everything appear as shades of grey/blue.
; We must continuously reset these in our main loop to keep colors!
; =====================================================================
ATRACT  = $4D       ; attract mode counter — OS increments this each frame
                    ; when it reaches a threshold attract mode activates
                    ; we keep writing 0 to prevent it from activating
ATRMSK  = $4E       ; attract mode color mask
                    ; OS ANDs all colors with this value
                    ; $FE strips hue leaving only luminance (grey/blue)
                    ; $FF = full color (no masking) — what we want

        org $2000                   ; place program at address $2000

        .proc main

; =====================================================================
; STEP 1: Close IOCB6
; Good practice to close before opening — ensures clean state.
; ON ENTRY: X must contain IOCB number × $10 ($60 for IOCB6)
; ON ENTRY: ICCOM must contain the command ($0C = CLOSE)
; ON EXIT:  IOCB6 is closed and ready to be reopened
; =====================================================================
        ldx #$60                    ; X = $60        (select IOCB6)
        lda #$0C                    ; A = $0C        (CLOSE command)
        sta ICCOM,x                 ; ICCOM = $0C    (store command in IOCB6)
        jsr CIOV                    ; CALL CIOV      (execute the close)

; =====================================================================
; STEP 2: Open Graphics Mode 7
; Fills in all IOCB6 fields then calls CIOV to execute the open.
; CIO sets up the display list, allocates screen RAM, configures
; ANTIC — everything needed for graphics mode automatically.
; ON ENTRY: X must contain $60 (IOCB6)
; ON EXIT:  GR.7 screen is active, SAVMSC points to screen RAM
; =====================================================================
        ldx #$60                    ; X = $60        (select IOCB6)
        lda #$03                    ; A = $03        (OPEN command)
        sta ICCOM,x                 ; ICCOM = $03    (store open command)
        lda #<scrname               ; A = low byte of "S:" string address
        sta ICBAL,x                 ; ICBAL = low byte (tell CIO device name location)
        lda #>scrname               ; A = high byte of "S:" string address
        sta ICBAH,x                 ; ICBAH = high byte
        lda #$07                    ; A = $07        (graphics mode 7)
        sta ICAX2,x                 ; ICAX2 = $07    (store graphics mode number)
        lda #$0C                    ; A = $0C        (read/write access)
        sta ICAX1,x                 ; ICAX1 = $0C    (store access mode)
        jsr CIOV                    ; CALL CIOV      (execute open — sets up entire graphics mode!)

; =====================================================================
; STEP 3: Clear Screen RAM to black
; Screen RAM at $B060 may contain garbage from previous programs.
; We fill 256 bytes with $00 (black = all pixels off).
; Note: this only clears the first 256 bytes (one page) of screen RAM.
; Full screen RAM is 3200 bytes — we'd need a 16-bit loop for all of it.
; $00 = %00000000 = all 4 pixels in byte = background color (black)
; =====================================================================

        lda $58         ; A = memory[$58]  (low byte of screen RAM address)
        sta $80         ; store in zero page pointer low byte
        lda $59         ; A = memory[$59]  (high byte of screen RAM address)
        sta $81         ; store in zero page pointer high byte

        ldy #0          ; Y = 0
clearscreen:
        lda #$00        ; A = $00
        sta ($80),y     ; write to memory[strptr + Y] instead of hardcoded $B060
        iny
        bne clearscreen

; =====================================================================
; STEP 4: Draw yellow pixels at lower right corner
; Screen RAM last byte is at $BCDF (row 79, byte 39)
; $55 = %01010101 = 4 pixels all using COLOR0 = yellow
; GR.7 uses color artifacting — adjacent bit pattern determines color
; %01 pixel value = COLOR0, but needs correct bit pattern for true color
; =====================================================================

; proc PlotPixel
; Assumptions:
; 1. plotX contains X value and plotY contains Y value of pixel to plot
;
; Obtain the correct offset from the zero byte video memory to the coordinates
; given in plotX and plotY

        .proc plotPixel

        ; first compute Y offset
        lda plotY       ; A = plotY
        asl             ; Arithmetic Shift Left — multiplies A by 2; 2a
        asl             ; Arithmetic Shift Left — multiplies A by 2; 4a
        asl             ; Arithmetic Shift Left — multiplies A by 2; 8a
        sta temp        ; temp = A
        asl             ; Arithmetic Shift Left — multiplies A by 2; 16a
        asl             ; Arithmetic Shift Left — multiplies A by 2; 32a
        clc             ; clear carry
        adc temp        ; A = A + temp, or A = plotY * 40

        ; save offset in temp and compute X offset
        sta temp        ; save plotY × 40 into temp  ← store AFTER the multiplication is done!
        lda plotX       ; A = plotX
        lsr             ; A = plotX / 2
        lsr             ; A = plotX / 4
        clc
        adc temp        ; A = (plotY × 40) + (plotX / 4)

        sta temp        ; temp now has the offset converted from (x,y) to an offset

        ; add offset to SAVMSC
        

        rts
        .endp


        ;lda #$55                    ; A = $55        (4 yellow pixels)
        
        
        ;lda $58         ; A = low byte of SAVMSC
        ;clc
        ;adc #$7F        ; add low byte of offset $C7F
        ;sta $82         ; store result low byte (using $82 not $80!)
        ;lda $59         ; A = high byte of SAVMSC
        ;adc #$0C        ; add high byte of offset (carry included automatically!)
        ;sta $83         ; store result high byte

        ;ldy #0
        ;lda #$55        ; yellow pixels
        ;sta ($82),y     ; write to calculated lower right address

; =====================================================================
; MAIN LOOP
; We must continuously reset attract mode every loop iteration
; otherwise the OS VBI will desaturate our colors within seconds.
; We also continuously write our yellow color to COLOR0 shadow register
; to ensure it stays yellow despite OS interference.
; =====================================================================
stop:
        mva #0    ATRACT            ; memory[$4D] = 0     (reset attract counter)
        mva #$FF  ATRMSK            ; memory[$4E] = $FF   (full color mask — no desaturation)
        mva #$1E  $02C4             ; memory[$02C4] = $1E (COLOR0 shadow = bright yellow)
        jmp stop                    ; GOTO stop           (loop forever)

        .endp                       ; end of main procedure

; =====================================================================
; DATA
; =====================================================================
scrname .byte 'S:',$9B             ; device name string for CIO OPEN
                                    ; 'S:' = screen device
                                    ; $9B  = ATASCII end-of-line terminator

; =====================================================================
; ENTRY POINT
; =====================================================================
        run main                    ; set Atari run address to main
                                    ; (auto-execute when program loads)