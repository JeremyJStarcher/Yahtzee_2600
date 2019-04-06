;
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

    SEG.U vars
    ORG $80

GameMode:                   ; One or Two players
    ds 1

GameState
    ds 1

CurrentPlayer:             ; 0 for P0 or 1 for P1
    ds 1

LastSWCHB:               ; Avoid multiple detection of console switches
    ds 1

    SEG code
    ORG $F800          ; It's a 2K cart, meaning it has 2048 bytes! #mindblow

;;;;;;;;;;;;;;;;;
;; DATA TABLES ;;
;;;;;;;;;;;;;;;;;

; Tile and digit graphics go in the beginning of the cart to keep page-aligned
; (that is, the address' MSB never changes and we only calculate the LSB)

    INCLUDE "build/graphics.asm"                                                            ;

; Values that change if we are on PAL mode (TV TYPE switch "B•W" position)
; Order: NTSC, PAL. (thanks @SvOlli)
VBlankTime64T:
    .byte 44,74
OverscanTime64T:
    .byte 35,65

;;;;;;;;;;;;;;;
;; CONSTANTS ;;
;;;;;;;;;;;;;;;


; Values of GameState (it's a state machine!)
TitleScreen       = 0  ; => AddingRandomTitle
AddingRandomTile  = 1  ; => WaitingJoyRelease
WaitingJoyRelease = 2  ; => WaitingJoyPress
WaitingJoyPress   = 3  ; => Shifting
Shifting          = 4  ; => ShowingMerged OR WaitingJoyRelease
ShowingMerged     = 5  ; => AddingRandomTile OR GameOverFX
GameOverFX        = 6  ; => GameOver
GameOver          = 7  ; => TitleScreen

; Values of GameMode
OnePlayerGame = 0
TwoPlayerGame = 1

ScoreColor         = $28 ; Colors were chosen to get equal or equally nice
InactiveScoreColor = $04 ; on both PAL and NTSC, avoiding adjust branches
GridColor          = $04
BackgroundColor    = $00

JoyUp    = %11100000      ; Masks to test SWCHA for joystick movement
JoyDown  = %11010000      ; (we'll shift P1's bits into P0s on his turn, so
JoyLeft  = %10110000      ;  it's ok to use P0 values)
JoyRight = %01110000
JoyMask  = %11110000

ColSwitchMask   = %00001000  ; Mask to test SWCHB for TV TYPE switch
SelectResetMask = %00000011  ; Mask to test SWCHB for GAME SELECT/RESET switches
GameSelect      = %00000001  ; Value for GAME SELECT pressed (after mask)
GameReset       = %00000010  ; Value for GAME RESET  pressed (after mask)


;;;;;;;;;
;; RAM ;;
;;;;;;;;;

; Some positions are shared between different coroutines
; (think of them as local variables)

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
StartNewGame:

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
    inx                    ; (this ajust will appear a few times in the code)
NoVBlankPALAdjust:
    lda VBlankTime64T,x
    sta TIM64T             ; Use a RIOT timer (with the proper value) instead
    lda #0                 ; of counting scanlines (since we only care about
    sta VBLANK             ; the overall time)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SELECT, RESET AND P0 FIRE BUTTON ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ldx GameMode              ; Remember if we were on one or two player mode
    lda SWCHB                 ; We only want the switch presses once
    and #SelectResetMask      ; (in particular GAME SELECT)
    cmp LastSWCHB
    beq NoSwitchChange
    sta LastSWCHB             ; Store so we know if it's a repeat next time

    cmp #GameSelect           ; GAME SELECT flips single/multiplayer...
    bne NoSelect
    lda GameMode
    eor #1
    sta GameMode
    jmp StartNewGame          ; ...and restarts with no further game mode change
NoSelect:
    cmp #GameReset            ; GAME RESET restarts the game at any time
    beq Restart
NoSwitchChange:
    lda INPT4
    bpl ButtonPressed         ; P0 Fire button pressed?
    ldx #1                    ; P1 fire button always starts two-player game
    lda INPT5                 ; P1 fire button pressed?
    bmi NoRestart
ButtonPressed:
    lda GameState
    cmp #TitleScreen
    beq Restart               ; Start game if title screen
    cmp #GameOver             ; or game over
    bne NoRestart
Restart:
    stx GameMode
    jmp StartNewGame
NoRestart:

;;;;;;;;;;;;;;;;;;;;;;;;;
;; REMAINDER OF VBLANK ;;
;;;;;;;;;;;;;;;;;;;;;;;;;

WaitForVBlankEndLoop:
    lda INTIM                ; Wait until the timer signals the actual end
    bne WaitForVBlankEndLoop ; of the VBLANK period

    ldx #192
SpaceAboveLoop:
    sta WSYNC
    dex
    bne SpaceAboveLoop

;;;;;;;;;;;;;;
;; OVERSCAN ;;
;;;;;;;;;;;;;;

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
    ldx CurrentPlayer
    beq VerifyGameStateForJoyCheck
    asl                      ; If it's P1's turn, put their bits where P0s
    asl                      ; would be
    asl
    asl
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

CheckJoyDown:
    cmp #JoyDown
    bne CheckJoyLeft

CheckJoyLeft:
    cmp #JoyLeft
    bne CheckJoyRight

CheckJoyRight:
    cmp #JoyRight
    bne EndJoyCheck

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

    ORG $FFFA

    .WORD Initialize
    .WORD Initialize
    .WORD Initialize

    END

; The MIT License (MIT)

; Copyright (c) 2014 Carlos Duarte do Nascimento (Chester)
;
; Original 2048 game Copyright (c) 2014 Gabriele Cirulli

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
