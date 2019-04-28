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
ScoreFace:                  ; The face we are scoring
    ds 1

PrintLabelID:               ; The ID of the label to print
SPF1:                       ; Shadow PF1
TempVar2:                   ; General use variable
TempDigitBmp:               ; Stores intermediate part of 6-digit score
ScoreDie:                   ; The die we are comparing
    ds 1

ActiveScoreLineColor:       ; What color to display the active scoreline as
TempVar3:                   ; General use variable
SPF2:                       ; Shadow PF2
ScoreAcc:                   ; The accumulator for the score
    ds 1

; Address of the graphic for for each digit (6x2 bytes)
GraphicBmpPtr:
ScoreScratchpad:
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

RollCount: ds 1                 ; Turn counter
RolledDice:     ds 5
RerollDiceMask: ds 1

Rand8: ds 1                     ; Random number collector
; Rand16: ds 1                     ; Random number collector

StatusBits: ds 1                ; Various status things