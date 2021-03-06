; Yahtzee 2600
; ============
;
; A port of Yahtzee to the Atari 2600
;
; © 2019 Jeremy J Starcher
;   < jeremy.starcher@gmail.com >
;
; The skeleton of this code is ripped from the
; Atari version of 2048 by...
;
; © 2014 Carlos Duarte do Nascimento (chesterbr)
; <cd@pobox.com | @chesterbr | http://chester.me>
;
; Latest version, contributors and general info:
;   http://github.com/chesterbr/2048-2060
;

; Building
; ---------
;
; Building requires DASM (http://dasm-dillon.sourceforge.net/)
; and node.js
;
; You'll want to use the `build.sh` script (Unix only)

; Timings
; -------
;
; Since the shift routine can have unpredictable timing (and I wanted some
; freedom to move routines between overscan and vertical blank), I decided
; to use RIOT timers instead of the traditional scanline count. It is not
; the usual route for games (as they tend to squeeze every scanline of
; processing), but for this project it worked fine.
;
; [1] http://skilldrick.github.io/easy6502/
; [2] http://www.slideshare.net/chesterbr/atari-2600programming

    PROCESSOR 6502
    INCLUDE "vcs.h"
    INCLUDE "macros.h"
    INCLUDE "build/testmode.asm"

;===============================================================================
; Define RAM Usage
;===============================================================================

; define a segment for variables
; .U means uninitialized, does not end up in ROM
    SEG.U VARS

; RAM starts at $80
    ORG $80

; Some positions are shared between different coroutines
; (think of them as local variables)
.startOfRam:
    include "ram.asm"
TestsFailed: ds 1

.preScoreRamTop:
    INCLUDE "build/test_ram.asm";
.postScoreRamTop:
;========================================j=======================================
; free space check before End of Cartridge
;===============================================================================

    if (* & $FF)
        echo "......", [.postScoreRamTop - .preScoreRamTop]d, "bytes RAM used by scores."
        echo "......", [.preScoreRamTop - .startOfRam]d, "bytes RAM used by other."
        echo "######", [$FF - *]d, "bytes free before end of RAM."
        echo "######", [127 - [$FF - *]]d, "Total bytes of RAM used."
    endif

;===============================================================================
; Start ROM
;===============================================================================

    SEG CODE
    ORG $F000
startofrom: ds 0
    INCLUDE "build/digits_bitmap.asm"
    INCLUDE "build/test_bitmap.asm";

; Order: NTSC, PAL. (thanks @SvOlli)
VBlankTime64T:
    .byte 44,74
OverscanTime64T:
    .byte 35,65

    include "build/faces.asm"
    include "build/test_lookup.asm"
    include "build/labels_bitmap.asm"

    include "constants.asm"

;;;;;;;;;;;;;;;
;; BOOTSTRAP ;;
;;;;;;;;;;;;;;;

Initialize: subroutine            ; Cleanup routine from macro.h (by Andrew Davie/DASM)
    sei
    cld
    ldx #0
    txa
    tay
.CleanStack:
    dex
    txs
    pha
    bne .CleanStack

;;;;;;;;;;;;;;;
;; TIA SETUP ;;
;;;;;;;;;;;;;;;

    lda #%00000001      ; Playfield (grid) in mirror (symmetrical) mode
    sta CTRLPF

;;;;;;;;;;;;;;;;;;;
;; PROGRAM SETUP ;;
;;;;;;;;;;;;;;;;;;;
    subroutine
    lda #0
    sta OffsetIntoScoreList   ; Reset te top line

    lda #$4c
    sta Rand8                   ; Seed

    jsr StartNewGame
    jsr RunTests

;;;;;;;;;;;;;;;;;
;; FRAME START ;;
;;;;;;;;;;;;;;;;;

StartFrame: subroutine
    lda #%00000010         ; VSYNC
    sta VSYNC
    REPEAT 3
        sta WSYNC
    REPEND
    lda #0
    sta VSYNC
    sta WSYNC

    ldx #$00
    lda #ColSwitchMask     ; VBLANK start
    bit SWCHB
    bne .NoVBlankPALAdjust  ; "Color" => NTSC; "B•W" = PAL
    inx                    ; (this adjust will appear a few times in the code)
.NoVBlankPALAdjust:
    lda VBlankTime64T,x
    sta TIM64T             ; Use a RIOT timer (with the proper value) instead
    lda #0                 ; of counting scanlines (since we only care about
    sta VBLANK             ; the overall time)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; OTHER FRAME CONFIGURATION ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    inc BlinkClock          ; Increment our timer
    lda BlinkClock          ; Load into into register "A"
    cmp #BlinkRate          ; Compare to the max value
    bne .noToggleBlink      ; Not equal? Skip ahead
    lda StatusBits          ; Otherwise get the current phase
    eor #StatusBlinkOn      ; XOR the bit -- toggle
    sta StatusBits          ; Save the new phase
    lda #0                  ; Load the new timer value
    sta BlinkClock          ; And save it
.noToggleBlink

    jsr CalcBlinkMask
    jsr random

; Pre-fill the graphic pointers' MSBs, so we only have to
; figure out the LSBs for each tile or digit
    lda #>Digits        ; MSB of tiles/digits page
    ldx #11            ; 12-byte table (6 digits), zero-based
.FillMsbLoop1:
    sta GraphicBmpPtr,x
    dex                ; Skip to the next MSB
    dex
    bpl .FillMsbLoop1

;;;;;;;;;;;;;;;;;;;;;;;;;
;; REMAINDER OF VBLANK ;;
;;;;;;;;;;;;;;;;;;;;;;;;;
    subroutine
.WaitForVBlankEndLoop:
    lda INTIM                ; Wait until the timer signals the actual end
    bne .WaitForVBlankEndLoop ; of the VBLANK period

    sta WSYNC

;;;;;;;;;;;;;;;;;
;; SCORE SETUP ;;
;;;;;;;;;;;;;;;;;

ScoreSetup:
; general configuration

    lda #ScoreLinesPerPage
    sta ScoreLineCounter

    lda #[0 - TopPadding]
    sta ScreenLineIndex

    lda GameState
    cmp #TitleScreen

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start showing each scoreline in a loop ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
YesScore:   subroutine
    lda #0                   ; No players until we start
    sta GRP0
    sta GRP1

    ; What color to make this particular score line?
    ldx #ScoreColor

    lda ActiveArea
    cmp #ActiveAreaScores
    bne .UseInactiveColor

    lda ScoreLineCounter
    cmp ActiveScoreLine
    beq .UsePrimaryColor

.UseInactiveColor
    ldx #InactiveScoreColor

.UsePrimaryColor:
    stx ActiveScoreLineColor

; Copy the score to the scratch buffer
    clc
    lda ScreenLineIndex
    adc OffsetIntoScoreList
    tax
    sta ScoreLineIndex

    lda score_low,x
    sta ScoreBCD+2

    lda score_high,x
    sta ScoreBCD+1

    sta WSYNC

; Score setup scanlines 2-3:
; player graphics triplicated and positioned like this: P0 P1 P0 P1 P0 P1
; also, set their colors

    lda #PlayerThreeCopies   ; (2)
    sta NUSIZ0               ; (3)
    sta NUSIZ1               ; (3)

    lda #VerticalDelay       ; (2) ; Needed for precise timing of GRP0/GRP1
    sta VDELP0               ; (3)
    sta VDELP1               ; (3)

    REPEAT 10    ; (20=10x2) ; Delay to position right
        nop
    REPEND
    sta RESP0   ; (3)        ; Position P0
    sta RESP1   ; (3)        ; Position P1
    sta WSYNC

    lda #$E0                 ; Fine-tune player positions to center on screen
    sta HMP0
    lda #$F0
    sta HMP1
    sta WSYNC
    sta HMOVE   ; (3)

    ldx ActiveScoreLineColor

    stx COLUP0
    stx COLUP1

; Score setup scanlines 4-5
; set the graphic pointers for each score digit

    ldy #2            ; (2)  ; Score byte counter (source)
    ldx #10           ; (2)  ; Graphic pointer counter (target)
    clc               ; (2)

.loop:
    lda ScoreBCD,y    ; (4)
    and #$0F          ; (2)  ; Lower nibble
    sta TempVar1      ; (3)
    asl               ; (2)  ; A = digit x 2
    asl               ; (2)  ; A = digit x 4
    adc TempVar1      ; (3)  ; 4.digit + digit = 5.digit
    adc #<Digits      ; (2)  ; take from the first digit
    sta GraphicBmpPtr,x ; (4)  ; Store lower nibble graphic
    dex               ; (2)
    dex               ; (2)

    lda ScoreBCD,y    ; (4)
    and #$F0          ; (2)
    lsr               ; (2)
    lsr               ; (2)
    lsr               ; (2)
    lsr               ; (2)
    sta TempVar1      ; (3)  ; Higher nibble
    asl               ; (2)  ; A = digit x 2
    asl               ; (2)  ; A = digit x 4
    adc TempVar1      ; (3)  ; 4.digit + digit = 5.digit
    adc #<Digits      ; (2)  ; take from the first digit
    sta GraphicBmpPtr,x ; (4)  ; store higher nibble graphic
    dex               ; (2)
    dex               ; (2)
    dey               ; (2)
    bpl .loop         ; (2*)
    sta WSYNC         ;      ; We take less than 2 scanlines, round up

;;;;;;;;;;;
;; SCORE ;;
;;;;;;;;;;;
    subroutine
    ldy #4                   ; 5 scanlines
    sty ScanLineCounter

    ; Check if the line we are drawing is part of the scorecard
    ; or part of the top/bottom filler
    lda ScoreLineIndex
    tax
    adc #TopPadding         ; Move into the a good compare range
    bcs .StartBlankLineFiller

    cmp #MaxScoreLines
    bcs .StartBlankLineFiller

    jmp ShowRealScoreLine

.StartBlankLineFiller:
    ; There is nothing to show for this position, but
    ; we need to still show some data
    LDY #6
.loop:
    sta WSYNC

    lda #%00000001                      ; Reflect bit
    sta CTRLPF                          ; Set it

;    lda #$96                            ; Color
;    sta COLUBK                          ; Set playfield color

    DEY
    bne .loop
    ; lda #BackgroundColor
    ; sta COLUBK                          ; Set playfield color

    jmp ScoreCleanup

ShowRealScoreLine: subroutine
    ; Point the symbol map at the current label to draw
    lda scoreglyph0lsb,x
    sta GraphicBmpPtr+0
    lda #>scoreglyphs0
    sta GraphicBmpPtr+1

    lda scoreglyph1lsb,x
    sta GraphicBmpPtr+2
    lda #>scoreglyphs1
    sta GraphicBmpPtr+3

;; This loop is so tight there isn't room for *any* additional calculations.
;; So we have to calculate DrawSymbolsMap *before* we hit this code.
.loop:
    ldy ScanLineCounter          ; 6-digit loop is heavily inspired on Berzerk's
    lda (GraphicBmpPtr+0),y
    sta GRP0
    sta WSYNC
    lda (GraphicBmpPtr+2),y
    sta GRP1
    lda (GraphicBmpPtr+4),y
    sta GRP0
    lda (GraphicBmpPtr+6),y
    sta TempDigitBmp
    lda (GraphicBmpPtr+8),y
    tax
    lda (GraphicBmpPtr+10),y
    tay
    lda TempDigitBmp
    sta GRP1
    stx GRP0
    sty GRP1
    sta GRP0
    dec ScanLineCounter
    bpl .loop

ScoreCleanup:                ; 1 scanline
    lda #0
    sta VDELP0
    sta VDELP1
    sta GRP0
    sta GRP1

    sta WSYNC

LoopScore
    inc ScreenLineIndex
    dec ScoreLineCounter
    beq FrameBottomSpace
    jmp YesScore

FrameBottomSpace: subroutine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BOTTOM SPACE BELOW GRID ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    sta WSYNC

    lda #DieFaceColor                   ; Color
    sta COLUPF                          ; Set playfield color
    lda #%00000001                      ; Reflect bit
    sta CTRLPF                          ; Set it

    lda #AccentColor
    sta COLUP0
    sta COLUP1

    sta HMCLR

    lda #1                  ; Delay until the next scan line = TRUE
    sta VDELP0              ; Player 0

    lda #19                 ; Position
    ldx #0                  ; GRP0
    jsr PosObject

    lda #PlayerThreeCopies
    sta NUSIZ0

    lda #%1100000           ; The pattern
    sta GRP0

    lda #46                 ; Position
    ldx #1                  ; GRP0
    jsr PosObject

    lda #PlayerThreeCopies
    sta NUSIZ1

    lda #%00000011          ; The pattern
    sta GRP1

    sta WSYNC
    sta HMOVE

DiceRowScanLines = 4
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Calculate the dice PF fields and put them in shadow registers
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; lda #%00010000
    ; sta RerollDiceMask

    MAC merge
        ;; {1} - The face offset
        ;; {2} - Which line of the dice
        ;; {3} - which shadow register

        ldx #MaskedDieFace
        lda #[1 << {1}]             ; Calculate the bitmask position
        bit RerollDiceMask              ; Compare against the mask
        bne .keepBlank              ; masked? Keep it
        ldx [RolledDice + {1}]      ; The value of the face

.keepBlank:
        lda {3}                     ; Load the shadow register
        ora faceL{2}P{1},x          ; merge in the face bitmap
        sta {3}                     ; And re-save
    ENDM

    MAC showLineForAllFaces
        lda #0
        sta SPF0
        sta SPF1
        sta SPF2

        merge 0, {1}, SPF0
        merge 1, {1}, SPF1
        merge 2, {1}, SPF1
        merge 3, {1}, SPF2
        merge 4, {1}, SPF2

        jsr showDice
    ENDM

    showLineForAllFaces 0
    showLineForAllFaces 1
    showLineForAllFaces 2

    ; Let the sprites extend a little more
    sta WSYNC
    sta WSYNC
    sta WSYNC
    sta WSYNC

    lda #0
    sta GRP0
    sta GRP1

    sta WSYNC
    lda ActiveArea
    cmp #ActiveAreaReRoll
    bne .noChangeRerollColor
    ldx #ScoreColor
    stx COLUP0
    stx COLUP1

.noChangeRerollColor
    lda RollCount
    sta PrintLabelID
    jsr PrintLabel

    ; 262 scan lines total
    ldx #20 + 1 - (DiceRowScanLines * 3)
.loop:
    sta WSYNC
    dex
    bne .loop

;;;;;;;;;;;;;;
;; OVERSCAN ;;
;;;;;;;;;;;;;;
    subroutine
    lda #0                  ; Clear pattern
    sta PF0
    sta PF1
    sta PF2

    lda #%01000010           ; Disable output
    sta VBLANK
    ldx #$00
    lda #ColSwitchMask
    bit SWCHB
    bne .NoOverscanPALAdjust
    inx
.NoOverscanPALAdjust:
    lda OverscanTime64T,x    ; Use a timer adjusted to the color system's TV
    sta TIM64T               ; timings to end Overscan, same as VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SELECT, RESET AND P0 FIRE BUTTON ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    subroutine

    ldx GameMode              ; Remember if we were on one or two player mode
    lda SWCHB                 ; We only want the switch presses once
    and #SelectResetMask      ; (in particular GAME SELECT)
    cmp LastSWCHB
    beq .NoSwitchChange
    sta LastSWCHB             ; Store so we know if it's a repeat next time

    cmp #GameSelect           ; GAME SELECT flips single/multiplayer...
    bne .NoSelect
    lda GameMode
    eor #1
    sta GameMode
    jmp StartNewGame          ; ...and restarts with no further game mode change
.NoSelect:
    cmp #GameReset            ; GAME RESET restarts the game at any time
    beq .Restart
.NoSwitchChange:
    lda INPT4
    bpl .ButtonPressed        ; P0 Fire button pressed?

    clearBit StatusFireDown, StatusBits
    jmp .NoRestart

.ButtonPressed:
    lda #StatusFireDown         ; Button still down?
    bit StatusBits
    bne .NoRestart              ; Then wait for release

    setBit StatusFireDown, StatusBits

    lda ActiveArea
    cmp #ActiveAreaScores
    bne .ButtonPressedReroll
    jmp .NoRestart

.ButtonPressedReroll
    lda ActiveArea
    cmp #ActiveAreaReRoll
    bne .buttonPressedDice

    lda RollCount
    beq .noReroll
    jsr RerollDice
.noReroll
    jmp .NoRestart

.buttonPressedDice:
    jsr handleAreaDiceFire
    jmp .NoRestart

.checkAreaScore:
    lda GameState
    cmp #TitleScreen
    beq .Restart               ; Start game if title screen
    ; cmp #GameOver             ; or game over
    bne .NoRestart
.Restart:
    stx GameMode
    jmp StartNewGame
.NoRestart:

;;;;;;;;;;;;;;;;;;;;
;; INPUT CHECKING ;;
;;;;;;;;;;;;;;;;;;;;
    subroutine

; Joystick
    lda SWCHA
;    ldx CurrentPlayer
;    beq VerifyGameStateForJoyCheck
;    asl                      ; If it's P1's turn, put their bits where P0s
;    asl                      ; would be
;    asl
;    asl
VerifyGameStateForJoyCheck:
    and #JoyMask             ; Only player 0 bits

    ldx GameState            ; We only care for states in which we are waiting
    cpx #WaitingJoyRelease   ; for a joystick press or release
    beq CheckJoyRelease

    ldx GameState            ; We only care for states in which we are waiting
    cpx #WaitingJoyPress
    bne .scoresEndJoyCheck

; If the joystick is in one of these directions, trigger the shift by
; setting the ShiftVector and changing mode
CheckJoyUp:
    cmp #JoyUp
    bne CheckJoyDown
    lda #JoyVectorUp
    jmp TriggerShift

CheckJoyDown:
    cmp #JoyDown
    bne CheckJoyLeft
    lda #JoyVectorDown
    jmp TriggerShift

CheckJoyLeft:
    cmp #JoyLeft
    bne CheckJoyRight
    lda #JoyVectorLeft
    jmp TriggerShift

CheckJoyRight:
    cmp #JoyRight
    bne .scoresEndJoyCheck
    lda #JoyVectorRight

TriggerShift:
    sta MoveVector
    lda #WaitingJoyRelease
    sta GameState
    jmp .scoresEndJoyCheck

CheckJoyRelease:
    cmp #JoyMask
    bne .scoresEndJoyCheck

    lda ActiveArea
    cmp #ActiveAreaScores
    bne .dice
    jmp checkJoyReleaseScores

.dice:
    lda ActiveArea
    cmp #ActiveAreaDice
    bne .reroll
    jmp CheckJoyReleaseDice

.reroll:
    lda ActiveArea
    cmp #ActiveAreaReRoll
    bne .scoresEndJoyCheck
    jmp CheckJoyReleaseReroll

.scoresEndJoyCheck
    jmp EndJoyCheck

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Handle the joystick actions for the ScoreArea ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
checkJoyReleaseScores: subroutine
    ldy OffsetIntoScoreList            ; Save value

    lda MoveVector
    cmp #JoyVectorUp
    bne .checkDownVector
    inc OffsetIntoScoreList
    jmp .CheckJoyReleaseEnd

.checkDownVector
    lda MoveVector
    cmp #JoyVectorDown
    bne .checkLeftVector
    dec OffsetIntoScoreList
    jmp .CheckJoyReleaseEnd

.checkLeftVector:
    cmp #JoyVectorLeft
    bne .checkRightVector
    lda #ActiveAreaDice
    sta ActiveArea
    jmp .CheckJoyReleaseEnd

.checkRightVector:

.CheckJoyReleaseEnd:
    clc
    lda ScreenLineIndex
    adc OffsetIntoScoreList

    bcs .CheckJoyReleaseRangeNotValid

    cmp #MaxScoreLines-1
    bcc .CheckJoyReleaseRangeValid
    jmp .CheckJoyReleaseRangeNotValid

.CheckJoyReleaseRangeNotValid:
    sty OffsetIntoScoreList

.CheckJoyReleaseRangeValid:
    lda #WaitingJoyPress       ; Joystick released, can accept shifts again
    sta GameState
    jmp EndJoyRelease

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Handle the joystick actions for the Dice Area ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CheckJoyReleaseDice: subroutine
    ldy HighlightedDie

    lda MoveVector
    cmp #JoyVectorUp
    bne .checkDownVector
    lda #ActiveAreaScores
    sta ActiveArea
    jmp .CheckJoyReleaseEnd

.checkDownVector
    lda MoveVector
    cmp #JoyVectorDown
    bne .checkLeftVector
    lda #ActiveAreaReRoll
    sta ActiveArea
    jmp .CheckJoyReleaseEnd

.checkLeftVector:
    cmp #JoyVectorLeft
    bne .checkRightVector
    dec HighlightedDie
    jmp .CheckJoyReleaseEnd

.checkRightVector:
    cmp #JoyVectorRight
    bne .CheckJoyReleaseEnd
    inc HighlightedDie

.CheckJoyReleaseEnd:
    lda HighlightedDie
    cmp #-1
    bcs .CheckJoyReleaseRangeNotValid

    cmp #DiceCount  ; The number of dice
    bcc .CheckJoyReleaseRangeValid
    jmp .CheckJoyReleaseRangeNotValid

.CheckJoyReleaseRangeNotValid:
    sty HighlightedDie

.CheckJoyReleaseRangeValid:
    lda #WaitingJoyPress       ; Joystick released, can accept shifts again
    sta GameState
    jmp EndJoyRelease

CheckJoyReleaseReroll: subroutine
    lda MoveVector
    cmp #JoyVectorUp
    bne .checkDownVector
    lda #ActiveAreaDice
    sta ActiveArea
    jmp EndJoyRelease

.checkDownVector:
    nop

EndJoyRelease:
    lda #WaitingJoyPress       ; Joystick released, can accept shifts again
    sta GameState

EndJoyCheck:
    nop

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; REMAINDER OF OVERSCAN ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;
    subroutine
.WaitForOverscanEndLoop:
    lda INTIM                   ; Wait until the timer signals the actual end
    bne .WaitForOverscanEndLoop  ; of the overscan period

    sta WSYNC
    jmp StartFrame

showDice: subroutine
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Reveal the dice that are in the shadow registers ;;
    ;;                                                  ;;
    ;; We use shadow registers because we turn the PF   ;;
    ;; on and then off every scan line, keeping the     ;;
    ;; dice display oo just the left-hand side.         ;;
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;A
    lda MaskPF0
    and SPF0
    sta SPF0

    lda MaskPF1
    and SPF1
    sta SPF1

    lda MaskPF2
    and SPF2
    sta SPF2

    subroutine
    REPEAT DiceRowScanLines
        sta WSYNC
        ; Copy the shadow registers
        ldy SPF0
        sty PF0
        ldy SPF1
        sty PF1
        ldy SPF2
        sty PF2

        ; Wait for playfield to be drawn
        REPEAT 10-1
            nop
        REPEND

        ; And clear it before the other side.
        ldy #0
        sty PF0
        sty PF1
        sty PF2
    REPEND
    rts

CalcBlinkMask: subroutine
    lda #$FF                    ; Don't mask out any bits
    sta MaskPF0
    sta MaskPF1
    sta MaskPF2

    lda #StatusBlinkOn
    bit StatusBits
    bne .checkRegion
    rts

.checkRegion
    lda ActiveArea
    cmp #ActiveAreaDice
    beq .setMasks
    rts

.setMasks:
    lda HighlightedDie
    asl
    tax
    lda blinkLookup+1,x
    pha
    lda blinkLookup,x
    pha
    rts

.blink0
    lda #$00
    sta MaskPF0
    rts
.blink1
    lda #$0F
    sta MaskPF1
    rts
.blink2
    lda #$F0
    sta MaskPF1
    rts
.blink3
    lda #$F0
    sta MaskPF2
    rts
.blink4
    lda #$0F
    sta MaskPF2
    rts

blinkLookup:
    word .blink0 -1
    word .blink1 -1
    word .blink2 -1
    word .blink3 -1
    word .blink4 -1

handleAreaDiceFire: subroutine

    lda #1                          ; Load the first bit
    ldx HighlightedDie              ; And find which position
    inx                             ; Start counting at 1
.l  asl                             ; Shift it along
    dex                             ; Counting down
    bne .l                          ; Until we are there
    lsr                             ; Make up for us starting at 1
    eor RerollDiceMask              ; Toggle the bit
    sta RerollDiceMask              ; And re-save
    rts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PrintLabel: subroutine
    lda #0                   ; No players until we start
    sta GRP0
    sta GRP1

    lda #>LabelBitmaps0        ; MSB of tiles/digits page
    ldx #11            ; 12-byte table (6 digits), zero-based
.FillMsbLoop1:
    sta GraphicBmpPtr,x
    dex                ; Skip to the next MSB
    dex
    bpl .FillMsbLoop1

    sta HMCLR

; Score setup scanlines 2-3:
; player graphics triplicated and positioned like this: P0 P1 P0 P1 P0 P1
; also, set their colors
    sta WSYNC  ; !!
    lda #PlayerThreeCopies   ; (2)
    sta NUSIZ0               ; (3)
    sta NUSIZ1               ; (3)

    lda #VerticalDelay       ; (2) ; Needed for precise timing of GRP0/GRP1
    sta VDELP0               ; (3)
    sta VDELP1               ; (3)

    REPEAT 10                ; (20=10x2) ; Delay to position right
        nop
    REPEND
    sta RESP0   ; (3)        ; Position P0
    sta RESP1   ; (3)        ; Position P1
    sta WSYNC

    lda #$E0                 ; Fine-tune player positions to center on screen
    sta HMP0
    lda #$F0
    sta HMP1
    sta WSYNC
    sta HMOVE   ; (3)

; set the graphic pointers for each score digit

    lda #<labelTest5
    sta GraphicBmpPtr + 10

    lda #<labelTest4
    sta GraphicBmpPtr + 8

    lda #<labelTest3
    sta GraphicBmpPtr + 6

    lda #<labelTest2
    sta GraphicBmpPtr + 4

    lda #<labelTest1
    sta GraphicBmpPtr + 2

    lda #<labelTest0
    sta GraphicBmpPtr + 0

    ldx #TESTMODE
    dex
    txa
    sta PrintLabelID

    ; Start checking custom values
    lda PrintLabelID
    cmp PrintLabelRoll1
    bne .tryRoll2

    lda #<Digitnum1
    sta GraphicBmpPtr + 10
    lda #>Digits
    sta GraphicBmpPtr + 11
    jmp .doneChecking

.tryRoll2
    lda PrintLabelID
    cmp PrintLabelRoll2
    bne .tryRoll3

    lda #<Digitnum2
    sta GraphicBmpPtr + 10
    lda #>Digits
    sta GraphicBmpPtr + 11
    jmp .doneChecking

.tryRoll3
    lda PrintLabelID
    cmp PrintLabelRoll3
    bne .nextTest

    lda #<Digitnum3
    sta GraphicBmpPtr + 10
    lda #>Digits
    sta GraphicBmpPtr + 11
    jmp .doneChecking

.nextTest

.doneChecking
; We may have been drawing the end of the grid (if it's P1 score)
    lda #0
    sta PF0
    sta PF1
    sta PF2

;;;;;;;;;;;
;; SCORE ;;
;;;;;;;;;;;

    ldy #4                   ; 5 scanlines
    sty ScanLineCounter
.DrawScoreLoop:
    ldy ScanLineCounter          ; 6-digit loop is heavily inspired on Berzerk's
    lda (GraphicBmpPtr),y
    sta GRP0
    sta WSYNC
    lda (GraphicBmpPtr+2),y
    sta GRP1
    lda (GraphicBmpPtr+4),y
    sta GRP0
    lda (GraphicBmpPtr+6),y
    sta TempDigitBmp
    lda (GraphicBmpPtr+8),y
    tax
    lda (GraphicBmpPtr+10),y
    tay
    lda TempDigitBmp
    sta GRP1
    stx GRP0
    sty GRP1
    sta GRP0
    dec ScanLineCounter
    bpl .DrawScoreLoop

.ScoreCleanup:                ; 1 scanline
    lda #0
    sta VDELP0
    sta VDELP1
    sta GRP0
    sta GRP1
    sta WSYNC
    rts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Positions an object horizontally
; Inputs: A = Desired position.
; X = Desired object to be positioned (0-5).
; scanlines: If control comes on or before cycle 73 then 1 scanline is consumed.
; If control comes after cycle 73 then 2 scanlines are consumed.
; Outputs: X = unchanged
; A = Fine Adjustment value.
; Y = the "remainder" of the division by 15 minus an additional 15.
; control is returned on cycle 6 of the next scanline.

PosObject:  subroutine
            sta WSYNC                ; 00     Sync to start of scanline.
            sec                      ; 02     Set the carry flag so no borrow will be applied during the division.
.divideby15 sbc #15                  ; 04     Waste the necessary amount of time dividing X-pos by 15!
            bcs .divideby15          ; 06/07  11/16/21/26/31/36/41/46/51/56/61/66
            tay
            lda fineAdjustTable,y    ; 13 -> Consume 5 cycles by guaranteeing we cross a page boundary
            sta HMP0,x
            sta RESP0,x              ; 21/ 26/31/36/41/46/51/56/61/66/71 - Set the rough position./Pos

            rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; REROLL DICE                ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RerollDice: subroutine
    lda #[1 << 0]
    bit RerollDiceMask
    beq .reroll1

    jsr random_dice;
    sta RolledDice + 0

.reroll1
    lda #[1 << 1]
    bit RerollDiceMask
    beq .reroll2

    jsr random_dice;
    sta RolledDice + 1

.reroll2
    lda #[1 << 2]
    bit RerollDiceMask
    beq .reroll3

    jsr random_dice;
    sta RolledDice + 2

.reroll3
    lda #[1 << 3]
    bit RerollDiceMask
    beq .reroll4

    jsr random_dice;
    sta RolledDice + 3

.reroll4
    lda #[1 << 4]
    bit RerollDiceMask
    beq .rerollDone

    jsr random_dice;
    sta RolledDice + 4

.rerollDone:
    lda #0
    sta RerollDiceMask

    dec RollCount
    rts

;;;;;;;;;;;;;;
;; NEW GAME ;;
;;;;;;;;;;;;;;

StartNewGame: subroutine
    ;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Mark all the score slots as unscored
    ;;;;;;;;;;;;;;;;;;;;;;;
    lda #Unscored
    ldx #ScoreRamSize
.clearScores:
    dex
    sta score_low,x
    bne .clearScores

    ; Continue into real prep
    lda #WaitingJoyPress
    sta GameState

    lda #ActiveAreaScores
    sta ActiveArea

    lda #0
    sta HighlightedDie

    lda #3
    sta RollCount

    lda #%00011111
    sta RerollDiceMask
    jsr RerollDice

    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Random number generator ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The RNG must be seeded with a non-zero value
;; To keep things "fresh" its recommended this be
;; called on every VBLANK.

random: subroutine
        lda Rand8
        lsr
 ifconst Rand16
        rol Rand16      ; this command is only used if Rand16 has been defined
 endif
        bcc .noeor
        eor #$B4
.noeor
        sta Rand8
 ifconst Rand16
        eor Rand16      ; this command is only used if Rand16 has been defined
 endif
        rts

;; Die value in the A register
random_dice:
    jsr random
    lda Rand8
    and #%0000111
    cmp #6
    bcs random_dice
    clc
    adc #1
    rts

    include "calcscoring.asm"
    include "tests.asm"
;===============================================================================
; free space check before End of Cartridge
;===============================================================================
 if (* & $FF)
    echo "------", [$FFFA - *]d, "bytes free before End of Cartridge"
    align 256
  endif

;===============================================================================
; Define End of Cartridge
;===============================================================================
    ORG $FFFA        ; set address to 6507 Interrupt Vectors

    .WORD Initialize
    .WORD Initialize
    .WORD Initialize

    END

; The MIT License (MIT)

; Copyright (c) 2018 Jeremy J Starcher
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:

; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.

; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.
