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

GameMode: ds 1              ; One or Two players
GameState: ds 1
LastSWCHB: ds 1             ; Avoid multiple detection of console switches
MoveVector: ds 1            ; Movement Vector

MaskPF0: ds 1               ; Pre-calculate blink masks
MaskPF1: ds 1
MaskPF2: ds 1

SPF0:                       ; Shadow PF0
TempVar1:                   ; General use variable
ScanLineCounter:            ; Counts lines while drawing the score
    ds 1

SPF1:                       ; Shadow PF1
TempVar2:                   ; General use variable
TempDigitBmp:               ; Stores intermediate part of 6-digit score
    ds 1

ActiveScoreLineColor:      ; What color to display the active scoreline as
TempVar3:                   ; General use variable
SPF2:                       ; Shadow PF2
    ds 1

; Address of the graphic for for each digit (6x2 bytes)
GraphicBmpPtr:
    ds 6 * 2

; 6-digit score is stored in BCD (each nibble = 1 digit => 3 bytes)
ScoreBCD: ds 3

ScoreLineCounter: ds 1          ; How many score lines have been drawn?
ScoreLineIndex: ds 1            ; The index of which actual scoreline
ScreenLineIndex: ds 1           ; The index of which score screen line
OffsetIntoScoreList: ds 1       ; Which is the TOP scoreline to display

ActiveArea: ds 1                ; What area is active for inputs?
HighlightedDie: ds 1            ; Highlight die
BlinkClock: ds 1                ; Time the blink-blink
BlinkPhase: ds 1                ; Which mode is the blink in?

rolledDice:     ds 5
rerollMask: ds 1

Rand8: ds 1                     ; Random number collector
; Rand16: ds 1                     ; Random number collector

statusBits: ds 1                ; Various status things

.preScoreRamTop:
    INCLUDE "build/score_ram.asm";
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
    INCLUDE "build/score_bitmap.asm";

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
    align 256
page2start: = *
    include "build/faces.asm"
    include "build/score_lookup.asm"

;-----------------------------
; This table converts the "remainder" of the division by 15 (-1 to -15) to the correct
; fine adjustment value. This table is on a page boundary to guarantee the processor
; will cross a page boundary and waste a cycle in order to be at the precise position
; for a RESP0,x write
fineAdjustBegin:
            DC.B %01110000; Left 7
            DC.B %01100000; Left 6
            DC.B %01010000; Left 5
            DC.B %01000000; Left 4
            DC.B %00110000; Left 3
            DC.B %00100000; Left 2
            DC.B %00010000; Left 1
            DC.B %00000000; No movement.
            DC.B %11110000; Right 1
            DC.B %11100000; Right 2
            DC.B %11010000; Right 3
            DC.B %11000000; Right 4
            DC.B %10110000; Right 5
            DC.B %10100000; Right 6
            DC.B %10010000; Right 7

fineAdjustTable = fineAdjustBegin - %11110001; NOTE: %11110001 = -15

    echo "------", [ * - [startofrom + 256]  ]d, "bytes of page 2"

   align 256

;;;;;;;;;;;;;;;
;; CONSTANTS ;;
;;;;;;;;;;;;;;;

; Values of GameState (it's a state machine!)
TitleScreen       = 0  ; => AddingRandomTitle
WaitingJoyRelease = 2  ; => WaitingJoyPress
WaitingJoyPress   = 3  ; => ShiftingA

ActiveAreaScores  = 1
ActiveAreaDice    = 2

JoyVectorUp       = 1  ; Last joystick action
JoyVectorDown     = 2  ; last joystick action
JoyVectorLeft     = 3  ; last joystick action
JoyVectorRight    = 4  ; last joystick action

ScoreColor         = $28 ; Colors were chosen to get equal or equally nice
InactiveScoreColor = $04 ; on both PAL and NTSC, avoiding adjust branches
BackgroundColor    = $00
DieFaceColor       = $45
AccentColor        = $98

PlayerOneCopy       = $00 ; P0 and P1 drawing tiles: 1
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

ScoreLinesPerPage = 11
ActiveScoreLine = ScoreLinesPerPage / 2
TopPadding = ScoreLinesPerPage - ActiveScoreLine

MaxScoreLines = 25
BlinkRate = 40

DiceCount = 5               ; Total number of dice to display
MaskedDieFace = 7           ; The face when a die is masked

StatusFireDown = %0000001   ; The fire button is pressed

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
; Pre-fill the graphic pointers' MSBs, so we only have to
; figure out the LSBs for each tile or digit
    lda #>Digits        ; MSB of tiles/digits page
    ldx #11            ; 12-byte table (6 digits), zero-based
.FillMsbLoop1:
    sta GraphicBmpPtr,x
    dex                ; Skip to the next MSB
    dex
    bpl .FillMsbLoop1

    lda #0
    sta OffsetIntoScoreList   ; Reset te top line

    lda #$4c
    sta Rand8                   ; Seed

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
    inc BlinkClock
    lda BlinkClock
    cmp #BlinkRate
    bne .noToggleBlink
    lda BlinkPhase
    eor #%00000001
    sta BlinkPhase
    lda #0
    sta BlinkClock

.noToggleBlink

     jsr CalcBlinkMask
     jsr random

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
    sta ScoreBCD+1

    lda score_high,x
    sta ScoreBCD+2

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
    lda #BackgroundColor
    sta COLUBK                          ; Set playfield color

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
    ; sta rerollMask

    MAC merge
        ;; {1} - The face offset
        ;; {2} - Which line of the dice
        ;; {3} - which shadow register

        ldx #MaskedDieFace
        lda #[1 << {1}]             ; Calculate the bitmask position
        bit rerollMask              ; Compare against the mask
        bne .keepBlank              ; masked? Keep it
        ldx [rolledDice + {1}]      ; The value of the face

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

    ; 262 scan lines total
    ldx #36 + 1 - (DiceRowScanLines * 3)
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

    clearBit StatusFireDown, statusBits
    jmp .NoRestart


.ButtonPressed:
    lda #StatusFireDown
    bit statusBits
    bne .NoRestart

    lda ActiveArea
    cmp #ActiveAreaDice
    bne .checkAreaScore

    jsr handleAreaDiceFire

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
    bne CheckJoyReleaseDice
    jmp checkJoyReleaseScores

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
    jmp EndJoyCheck

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

    cmp #DiceCount  ; THe number of dice
    bcc .CheckJoyReleaseRangeValid
    jmp .CheckJoyReleaseRangeNotValid

.CheckJoyReleaseRangeNotValid:
    sty HighlightedDie

.CheckJoyReleaseRangeValid:
    lda #WaitingJoyPress       ; Joystick released, can accept shifts again
    sta GameState
    jmp EndJoyCheck

EndJoyCheck:
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
    lda #$FF
    sta MaskPF0
    sta MaskPF1
    sta MaskPF2

    lda BlinkPhase
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
    eor rerollMask                  ; Toggle the bit
    sta rerollMask                  ; And re-save

    setBit StatusFireDown, statusBits
    rts

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

;;;;;;;;;;;;;;
;; NEW GAME ;;
;;;;;;;;;;;;;;

StartNewGame:
    ; Prefill the rolled dice with test data
    jsr random_dice;
    sta rolledDice + 0

    jsr random_dice;
    sta rolledDice + 1

    jsr random_dice;
    sta rolledDice + 2

    jsr random_dice;
    sta rolledDice + 3

    jsr random_dice;
    sta rolledDice + 4

    ; Prefill scores with dummy values
    lda #$34
    sta score_high_L1s
    lda #$12
    sta score_low_L1s

    lda #$78
    sta score_high_L2s
    lda #$56
    sta score_low_L2s

    lda #$33
    sta score_high_L3s
    sta score_low_L3s

    lda #$44
    sta score_high_L4s
    sta score_low_L4s

    lda #$55
    sta score_high_L5s
    sta score_low_L5s

    lda #$66
    sta score_high_L6s
    sta score_low_L6s

    lda #$78
    sta score_high_LChance
    sta score_low_LChance

    ; Continue into real prep
    lda #WaitingJoyPress
    sta GameState

    lda #ActiveAreaScores
    ; lda #ActiveAreaDice
    sta ActiveArea

    lda #0
    sta HighlightedDie

    lda #$00
    sta rerollMask

    jmp StartFrame

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
