    PROCESSOR 6502

;;;;;;;;;;;;;;;
;; CONSTANTS ;;
;;;;;;;;;;;;;;;

; Values of GameState (it's a state machine!)
TitleScreen       = 0  ; => AddingRandomTitle
WaitingJoyRelease = 2  ; => WaitingJoyPress
WaitingJoyPress   = 3  ; => ShiftingA

ActiveAreaScores  = 1
ActiveAreaDice    = 2
ActiveAreaReRoll  = 3

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

StatusFireDown = 1 << 0     ; The fire button is pressed
StatusBlinkOn =  1 << 1     ; Blink mode active?
StatusPlayHand = 1 << 2     ; Play the given hand

PrintLabelRoll1 = 2
PrintLabelRoll2 = 1
PrintLabelRoll3 = 0

Unscored = $AA
RollsPerHand = 3
ScoreRamSize = .postScoreRamTop - .preScoreRamTop

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

