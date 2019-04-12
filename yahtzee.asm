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

GameMode: ds 1              ; One or Two players

SPF0:                       ; Shadow PF0
TempVar1:                   ; General use variable
LineCounter:                ; Counts lines while drawing the score
    ds 1

SPF1:                       ; Shadow PF1
TempVar2:                   ; General use variable
TempDigitBmp:               ; Stores intermediate part of 6-digit score
    ds 1

TempVar3:                   ; General use variable
SPF2:                       ; Shadow PF2

GameState: ds 1

; Address of the graphic for for each digit (6x2 bytes)
DigitBmpPtr:
    ds 6 * 2

; Store each player score separatedly and copy
; from/to ScoreBCD as needed to display, add, etc.
; Note: P1 score will store (and show) the high-score in single-player games
P0ScoreBCD:  ds 3

; 6-digit score is stored in BCD (each nibble = 1 digit => 3 bytes)
ScoreBCD: ds 3

TurnIndicatorCounter: ds 1      ; Controls the time spent changing player turn
CurrentBGColor: ds 1            ; Ensures invisible score keeps invisible during

ScoreLineCount: ds 1

DrawSymbolsMap: ds 4

; FieldName     Size        Max Value
S1s:            ds 1        ;5
S2s:            ds 1        ;10
S3s:            ds 1        ;15
S4s:            ds 1        ;20
S5s:            ds 1        ;25
S6s:            ds 1        ;30
STopSubtotal:   ds 2        ;105
STopBonus:      ds 1        ;35
S3k:            ds 1        ;30
S4k:            ds 1        ;30
SSmallStraight: ds 1        ;30
SLargeStraight: ds 1        ;40
SFullHouse:     ds 1        ;25
SYahtzee:       ds 1        ;50
SChance:        ds 1        ;30
SYahtzeeBonus:  ds 1        ;##
SLowerTotal:    ds 2        ;###
SUpperTotal:    ds 2        ;###
SGrandTotal:    ds 2        ;####

rolledDice:     ds 5
;===============================================================================
; free space check before End of Cartridge
;===============================================================================

    if (* & $FF)
        echo "------", [$FF - *]d, "bytes free before end of RAM"
    endif

;===============================================================================
; Start ROM
;===============================================================================

    SEG CODE
    ORG $F000
startofrom: ds 0
    INCLUDE "build/graphics.asm"

; Order: NTSC, PAL. (thanks @SvOlli)
VBlankTime64T:
    .byte 44,74
OverscanTime64T:
    .byte 35,65

;===============================================================================
; free space check on this page
;===============================================================================

 if (* & $FF)
    echo "------", [* - startofrom]d, "bytes of graphics.asm.  ", [startofrom - * + 256]d, "bytes wasted."
  endif

    ; We ran out of room with graphics.asm.
    ; start a new page.
    ;  align 256
facesstart: = *
    include "build/faces.asm"
    echo "------", [ * - [startofrom + 256]  ]d, "bytes of faces.asm.  "

    INCLUDE "build/graphics_code.asm"

;;;;;;;;;;;;;;;
;; CONSTANTS ;;
;;;;;;;;;;;;;;;

; Values of GameState (it's a state machine!)
TitleScreen       = 0  ; => AddingRandomTitle
AddingRandomTile  = 1  ; => WaitingJoyRelease
WaitingJoyRelease = 2  ; => WaitingJoyPress
WaitingJoyPress   = 3  ; => Shifting

ScoreColor         = $28 ; Colors were chosen to get equal or equally nice
InactiveScoreColor = $04 ; on both PAL and NTSC, avoiding adjust branches
BackgroundColor    = $00

PlayerTwoCopiesWide = $02 ; P0 and P1 drawing tiles: 0 1 0 1
PlayerThreeCopies   = $03 ; P0 and P1 drawing score: 010101
VerticalDelay       = $01 ; Delays writing of GRP0/GRP1 for 6-digit score

JoyUp    = %11100000      ; Masks to test SWCHA for joystick movement
JoyDown  = %11010000      ; (we'll shift P1's bits into P0s on his turn, so
JoyLeft  = %10110000      ;  it's ok to use P0 values)
JoyRight = %01110000
JoyMask  = %11110000

ColSwitchMask   = %00001000  ; Mask to test SWCHB for TV TYPE switch
SelectResetMask = %00000011  ; Mask to test SWCHB for GAME SELECT/RESET switches
GameSelect      = %00000001  ; Value for GAME SELECT pressed (after mask)
GameReset       = %00000010  ; Value for GAME RESET  pressed (after mask)

ScoreLines = 11

;;;;;;;;;;;;;;;
;; BOOTSTRAP ;;
;;;;;;;;;;;;;;;

Initialize:             ; Cleanup routine from macro.h (by Andrew Davie/DASM)
    sei
    cld
    ldx #0
    txa
    tay
CleanStack:
    dex
    txs
    pha
    bne CleanStack

;;;;;;;;;;;;;;;
;; TIA SETUP ;;
;;;;;;;;;;;;;;;

    lda #%00000001      ; Playfield (grid) in mirror (symmetrical) mode
    sta CTRLPF

;;;;;;;;;;;;;;;;;;;
;; PROGRAM SETUP ;;
;;;;;;;;;;;;;;;;;;;

; Pre-fill the graphic pointers' MSBs, so we only have to
; figure out the LSBs for each tile or digit
    lda #>Digits        ; MSB of tiles/digits page
    ldx #11            ; 12-byte table (6 digits), zero-based
FillMsbLoop1:
    sta DigitBmpPtr,x
    dex                ; Skip to the next MSB
    dex
    bpl FillMsbLoop1


    ; Prefill the score with test data
    lda #$AB
    sta P0ScoreBCD

    lda #$00
    sta P0ScoreBCD+1

    lda #$56
    sta P0ScoreBCD+2

    ; Prefill the rolled dice with test data
    lda #5
    sta rolledDice + 0

    lda #5
    sta rolledDice + 1

    lda #5
    sta rolledDice + 2

    lda #5
    sta rolledDice + 3

    lda #5
    sta rolledDice + 4

ShowTitleScreen:
    jmp StartFrame

;;;;;;;;;;;;;;
;; NEW GAME ;;
;;;;;;;;;;;;;;

StartNewGame:
    sta CurrentBGColor

; Start the game with a random tile
    lda #AddingRandomTile
    sta GameState

;;;;;;;;;;;;;;;;;
;; FRAME START ;;
;;;;;;;;;;;;;;;;;

StartFrame:
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
    bne NoVBlankPALAdjust  ; "Color" => NTSC; "B•W" = PAL
    inx                    ; (this adjust will appear a few times in the code)
NoVBlankPALAdjust:
    lda VBlankTime64T,x
    sta TIM64T             ; Use a RIOT timer (with the proper value) instead
    lda #0                 ; of counting scanlines (since we only care about
    sta VBLANK             ; the overall time)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; OTHER FRAME CONFIGURATION ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;
;; REMAINDER OF VBLANK ;;
;;;;;;;;;;;;;;;;;;;;;;;;;

WaitForVBlankEndLoop:
    lda INTIM                ; Wait until the timer signals the actual end
    bne WaitForVBlankEndLoop ; of the VBLANK period

    sta WSYNC

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TOP SPACE ABOVE SCORE ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   ** 262 scanlines total
;    ldx #36
;SpaceAboveLoop:
;    sta WSYNC
;    dex
;    bne SpaceAboveLoop
;    sta WSYNC

;;;;;;;;;;;;;;;;;
;; SCORE SETUP ;;
;;;;;;;;;;;;;;;;;

ScoreSetup:
; Score setup scanline 1:
; general configuration

    lda #ScoreLines
    sta ScoreLineCount

    lda GameState
    cmp #TitleScreen
    bne YesScore            ; No score on title screen
    jmp YesScore            ;

NoScore:
    ldx #13
ScoreSpaceLoop:
    sta WSYNC
    dex
    bne ScoreSpaceLoop
    jmp ScoreCleanup

YesScore:
    lda #0                   ; No players until we start
    sta GRP0
    sta GRP1

    ; Score of the score -- this will have to change later
    lda P0ScoreBCD
    ldx P0ScoreBCD+1
    ldy P0ScoreBCD+2

WriteScore:
    sta ScoreBCD
    stx ScoreBCD+1
    sty ScoreBCD+2
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

    ldx #ScoreColor          ; Animate score for a few seconds when the
    lda TurnIndicatorCounter ; turn changes
    beq NoTurnAnimation
    adc #ScoreColor
    tax
    dec TurnIndicatorCounter
NoTurnAnimation:
   ; beq SetScoreColor

SetScoreColor:
    stx COLUP0
    stx COLUP1

; Score setup scanlines 4-5
; set the graphic pointers for each score digit

    ldy #2            ; (2)  ; Score byte counter (source)
    ldx #10           ; (2)  ; Graphic pointer counter (target)
    clc               ; (2)

ScorePtrLoop:
    lda ScoreBCD,y    ; (4)
    and #$0F          ; (2)  ; Lower nibble
    sta TempVar1      ; (3)
    asl               ; (2)  ; A = digit x 2
    asl               ; (2)  ; A = digit x 4
    adc TempVar1      ; (3)  ; 4.digit + digit = 5.digit
    adc #<Digits; (2)  ; take from the first digit
    sta DigitBmpPtr,x ; (4)  ; Store lower nibble graphic
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
    sta DigitBmpPtr,x ; (4)  ; store higher nibble graphic
    dex               ; (2)
    dex               ; (2)
    dey               ; (2)
    bpl ScorePtrLoop  ; (2*)
    sta WSYNC         ;      ; We take less than 2 scanlines, round up

; We may have been drawing the end of the grid (if it's P1 score)
    lda #0
    sta PF0
    sta PF1
    sta PF2

;;;;;;;;;;;
;; SCORE ;;
;;;;;;;;;;;

    ldy #4                   ; 5 scanlines
    sty LineCounter

    jsr show_TopBonus

;; This loop is so tight there isn't room for *any* additional calculations.
;; So we have to calculate DrawSymbolsMap *before* we hit this code.
DrawScoreLoop:
    ldy LineCounter          ; 6-digit loop is heavily inspired on Berzerk's
    lda (DrawSymbolsMap+0),y
    sta GRP0
    sta WSYNC
    lda (DrawSymbolsMap+2),y
    sta GRP1
    lda #$00                ; Blank space after the label
    nop                     ; Timing...
    nop                     ; Timing
    sta GRP0
    lda (DigitBmpPtr+6),y
    sta TempDigitBmp
    lda (DigitBmpPtr+8),y
    tax
    lda (DigitBmpPtr+10),y
    tay
    lda TempDigitBmp
    sta GRP1
    stx GRP0
    sty GRP1
    sta GRP0
    dec LineCounter
    bpl DrawScoreLoop

ScoreCleanup:                ; 1 scanline
    lda #0
    sta VDELP0
    sta VDELP1
    sta GRP0
    sta GRP1
    sta WSYNC

LoopScore
    dec ScoreLineCount
    beq FrameBottomSpace
    jmp YesScore

FrameBottomSpace:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BOTTOM SPACE BELOW GRID ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #$45                            ; Color
    sta COLUPF                          ; Set playfield color
    lda #%00000001                      ; Reflect bit
    sta CTRLPF                          ; Set it

    sta WSYNC

DiceRowScanLines = 4
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Calculate the dice PF fields and put them in shadow registers
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;; Line 0
    ldy rolledDice + 0
    lda LP_0_0,y
    sta SPF0

    ldy rolledDice + 1
    ldx rolledDice + 2
    lda LP_0_1,y
    ora LP_0_2,x
    sta SPF1

    ldy rolledDice + 3
    ldx rolledDice + 4
    lda LP_0_3,y
    ora LP_0_4,x
    sta SPF2

    jsr showDice

    ;; Line 1
    ldy rolledDice + 0
    lda LP_1_0,y
    sta SPF0

    ldy rolledDice + 1
    ldx rolledDice + 2
    lda LP_1_1,y
    ora LP_1_2,x
    sta SPF1

    ldy rolledDice + 3
    ldx rolledDice + 4
    lda LP_1_3,y
    ora LP_1_4,x
    sta SPF2

    jsr showDice

    ;; Line 3
    ldy rolledDice + 0
    lda LP_2_0,y
    sta SPF0

    ldy rolledDice + 1
    ldx rolledDice + 2
    lda LP_2_1,y
    ora LP_2_2,x
    sta SPF1

    ldy rolledDice + 3
    ldx rolledDice + 4
    lda LP_2_3,y
    ora LP_2_4,x
    sta SPF2

    jsr showDice

;jjs
    ; 262 scan lines total
    ldx #36 + 10 - (DiceRowScanLines * 3) -1
SpaceBelowGridLoop:
    sta WSYNC
    dex
    bne SpaceBelowGridLoop

;;;;;;;;;;;;;;
;; OVERSCAN ;;
;;;;;;;;;;;;;;
    lda #0                  ; Clear pattern
    sta PF0
    sta PF1
    sta PF2

    lda #%01000010           ; Disable output
    sta VBLANK
    ldx #$00
    lda #ColSwitchMask
    bit SWCHB
    bne NoOverscanPALAdjust
    inx
NoOverscanPALAdjust:
    lda OverscanTime64T,x    ; Use a timer adjusted to the color system's TV
    sta TIM64T               ; timings to end Overscan, same as VBLANK

;;;;;;;;;;;;;;;;;;;;
;; INPUT CHECKING ;;
;;;;;;;;;;;;;;;;;;;;

; Joystick
    lda SWCHA
;    ldx CurrentPlayer
;    beq VerifyGameStateForJoyCheck
;    asl                      ; If it's P1's turn, put their bits where P0s
;    asl                      ; would be
;    asl
;    asl
VerifyGameStateForJoyCheck:
    and #JoyMask           ; Only player 0 bits

    ldx GameState            ; We only care for states in which we are waiting
    cpx #WaitingJoyRelease   ; for a joystick press or release
    beq CheckJoyRelease
    cpx #WaitingJoyPress
    bne EndJoyCheck

; If the joystick is in one of these directions, trigger the shift by
; setting the ShiftVector and changing mode
CheckJoyUp:
    cmp #JoyUp
    bne CheckJoyDown
    jmp TriggerShift

CheckJoyDown:
    cmp #JoyDown
    bne CheckJoyLeft
    jmp TriggerShift

CheckJoyLeft:
    cmp #JoyLeft
    bne CheckJoyRight
    jmp TriggerShift

CheckJoyRight:
    cmp #JoyRight
    bne EndJoyCheck

TriggerShift:
    jmp EndJoyCheck

CheckJoyRelease:
    cmp #JoyMask
    bne EndJoyCheck

    lda #WaitingJoyPress       ; Joystick released, can accept shifts again
    sta GameState

EndJoyCheck:
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; REMAINDER OF OVERSCAN ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

WaitForOverscanEndLoop:
    lda INTIM                   ; Wait until the timer signals the actual end
    bne WaitForOverscanEndLoop  ; of the overscan period

    sta WSYNC
    jmp StartFrame

;===============================================================================
; free space check before End of Cartridge
;===============================================================================
showDice:
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Reveal the dice that are in the shadow registers ;;
    ;;                                                  ;;
    ;; We use shadow registers because we turn the PF   ;;
    ;; on and then off every scan line, keeping the     ;;
    ;; dice display oo just the left-hand side.         ;;
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    REPEAT DiceRowScanLines
        sta WSYNC
        lda SPF0
        sta PF0

        lda SPF1
        sta PF1

        lda SPF2
        sta PF2

        REPEAT  10
            nop
        REPEND

        lda #0
        sta PF0
        sta PF1
        sta PF2
    REPEND
    rts

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
