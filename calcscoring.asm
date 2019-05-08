    PROCESSOR 6502

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The scores are held in two non-contiguous sequences, which           ;;
;; complicates access.  However, it *does* allow much faster look up    ;;
;; for the msb/lsb during the time-critial drawing sections, so we'll   ;;
;; live with the slightly more complex code here.                       ;;
;;                                                                      ;;
;; In addition, we have two kinds of '0' characters.  The $x0 indicates ;;
;; a normal zero which should be displayed, while $xA indicates a       ;;
;; a leading zero, which is displayed as a blank.                       ;;
;;                                                                      ;;
;; Any math routines have to convert the $xA nibble to be a zero prior  ;;
;; to any calculations.                                                 ;;
;; It is a LOT more complicated, but I believe the appearance results   ;;
;; are well worth it.                                                   ;;
;;                                                                      ;;
;; See: ConvertSpacerNibble                                             ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    .align 128
    IFCONST TESTMODE
    ELSE
TopSubtotalValues:
    .byte 5
    .byte <score_low_L1s, <score_high_L1s
    .byte <score_low_L2s, <score_high_L2s
    .byte <score_low_L3s, <score_high_L3s
    .byte <score_low_L4s, <score_high_L4s
    .byte <score_low_L5s, <score_high_L5s
    .byte <score_low_L6s, <score_high_L6s

LowerTotalValues:
    .byte 6
    .byte <score_low_L3k, <score_high_L3k
    .byte <score_low_L4k, <score_high_L4k
    .byte <score_low_LSmallStraight, <score_high_LSmallStraight
    .byte <score_low_LLargeStraight, <score_high_LLargeStraight
    .byte <score_low_LFullHouse, <score_high_LFullHouse
    .byte <score_low_LYahtzee, <score_high_LYahtzee
    .byte <score_low_LChance, <score_high_LChance

LUpperTotalValues:
    .byte 1
    .byte <score_low_TopBonus, <score_high_TopBonus
    .byte <score_low_TopSubtotal, <score_high_TopSubtotal

LGrandTotalValues
    .byte 1
    .byte <score_low_LUpperTotal, <score_high_LUpperTotal
    .byte <score_low_LLowerTotal, <score_high_LLowerTotal
    ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;

CalcScoreslookupLow:
    .byte <Calculate_L1s
    .byte <Calculate_L2s
    .byte <Calculate_L3s
    .byte <Calculate_L4s
    .byte <Calculate_L5s
    .byte <Calculate_L6s
    .byte <Calculate_TopSubtotal
    .byte <Calculate_TopBonus
    .byte <Calculate_L3k
    .byte <Calculate_L4k
    .byte <Calculate_LSmallStraight
    .byte <Calculate_LLargeStraight
    .byte <Calculate_LFullHouse
    .byte <Calculate_LYahtzee
    .byte <Calculate_LChance
    .byte <Calculate_LYahtzeeBonus
    .byte <Calculate_LLowerTotal
    .byte <Calculate_LUpperTotal
    .byte <Calculate_LGrandTotal

CalcScoreslookupHigh:
    .byte >Calculate_L1s
    .byte >Calculate_L2s
    .byte >Calculate_L3s
    .byte >Calculate_L4s
    .byte >Calculate_L5s
    .byte >Calculate_L6s
    .byte >Calculate_TopSubtotal
    .byte >Calculate_TopBonus
    .byte >Calculate_L3k
    .byte >Calculate_L4k
    .byte >Calculate_LSmallStraight
    .byte >Calculate_LLargeStraight
    .byte >Calculate_LFullHouse
    .byte >Calculate_LYahtzee
    .byte >Calculate_LChance
    .byte >Calculate_LYahtzeeBonus
    .byte >Calculate_LLowerTotal
    .byte >Calculate_LUpperTotal
    .byte >Calculate_LGrandTotal

ScratchpadLength = 7;

CalculateTopHandValues: subroutine
    sed                         ; Set decimal mode
    lda #$00                    ; Zero the counter
    sta ScoreAcc                ; And save it.

    ldy #DiceCount              ; And the number of dice
.loop
    dey                         ; start the loop
    sty ScoreDie                ; Save it
    lda RolledDice,y            ; Get the face
    cmp ScoreFace               ; Is it the face we want?
    bne .skip                   ; Nope
    clc                         ; Clear carry
    adc ScoreAcc                ; Build up the total
    sta ScoreAcc                ; Save it
.skip:
    ldy ScoreDie                ; Get our value
    bne .loop
    jmp FinishedCalculations

ClearScratchpad: subroutine
    lda #0                      ; Our value
    sta ScoreAcc                ; And save it.
    ldx #ScratchpadLength       ; Enough room for all the faces
.l: dex
    sta ScoreScratchpad,x
    bne .l
    rts

CountFaces: subroutine
    sed
    ldy #DiceCount              ; And the number of dice
.loop
    dey                         ; start the loop
    sty ScoreDie                ; Save it
    lda RolledDice,y            ; Get the face
    tax                         ; Save to our offset
    dex                         ; range 0-5

    clc                         ; Clear carry
    adc ScoreAcc                ; Build up the total
    sta ScoreAcc                ; Save it

    inc ScoreScratchpad,x

    ldy ScoreDie                ; Get our value
    bne .loop
    cld                         ; Clear decimal mode
    rts

HasAtLeast: subroutine
    ; A = The qty we are looking for
    ; C -> 1 SUCCESS
    sed
    sta ScoreDie
    ldy #ScratchpadLength
.loop
    dey                         ; start the loop
    sty ScoreFace

   lda ScoreScratchpad,y       ; Get the next size
   cmp ScoreDie
   bcc .skip
   sec                         ; Set the flag
   jmp .done
.skip
    ldy ScoreFace              ; Get our value
    bne .loop
    clc
.done
    cld                         ; Clear decimal mode
    rts

HasExactly: subroutine
    ; A = The qty we are looking for
    ; C -> 1 SUCCESS
    sed
    sta ScoreDie
    ldy #ScratchpadLength
.loop
    dey                         ; start the loop
    sty ScoreFace

   lda ScoreScratchpad,y       ; Get the next size
   cmp ScoreDie
   bne .skip
   sec                         ; Set the flag
   jmp .done
.skip
    ldy ScoreFace              ; Get our value
    bne .loop
    clc
.done
    cld                         ; Clear decimal mode
    rts

CreateBitmask: subroutine
    lda #0
    sta ScoreAcc
    ldx #DiceCount + 1
.l: dex
    stx ScoreFace
    lda ScoreScratchpad,x
    beq .nobit
    inc ScoreAcc
.nobit:
    lda ScoreAcc                ; Load the value
    clc
    asl
    sta ScoreAcc
    ldx ScoreFace
    bne .l
    rts

CheckStraightBitmask: subroutine
; at this point, we could have our dice in a nice bitmask
; with trailing zeros, we we shift through all the possibilities
; and slide them into the lower bits for comparison
    ldx #DiceCount + 0              ; The number of shifts to make
.l: dex
    clc                             ; Perform the shift
    lda ScoreAcc
    ror
    sta ScoreAcc
    lda ScoreFace                   ; Get the mask
    and ScoreAcc                    ; Check it against our incoming mask
    cmp ScoreFace                   ; Do we have overlap?
    beq .found
    cpx #0                          ; End of loop?
    bne .l
    jmp .notfound
.found:
    lda #$30
    sta ScoreAcc
    jmp .rts
.notfound
    lda #0
    sta ScoreAcc
.rts
    rts

Calculate_L1s: subroutine
    lda #1                      ; The face we are counting
    sta ScoreFace               ; Save it
    jmp CalculateTopHandValues

Calculate_L2s:
    lda #2                      ; The face we are counting
    sta ScoreFace               ; Save it
    jmp CalculateTopHandValues

Calculate_L3s:
    lda #3                      ; The face we are counting
    sta ScoreFace               ; Save it
    jmp CalculateTopHandValues

Calculate_L4s:
    lda #4                      ; The face we are counting
    sta ScoreFace               ; Save it
    jmp CalculateTopHandValues

Calculate_L5s:
    lda #5                      ; The face we are counting
    sta ScoreFace               ; Save it
    jmp CalculateTopHandValues

Calculate_L6s:
    lda #6                      ; The face we are counting
    sta ScoreFace               ; Save it
    jmp CalculateTopHandValues

Calculate_L3k: subroutine
    jsr ClearScratchpad
    jsr CountFaces
    lda #3
    jsr HasAtLeast
    bcs .done
    lda #0
    sta ScoreAcc
.done
    jmp FinishedCalculations

Calculate_L4k: subroutine
    jsr ClearScratchpad
    jsr CountFaces
    lda #4
    jsr HasAtLeast
    bcs .done
    lda #0
    sta ScoreAcc
.done
    jmp FinishedCalculations

Calculate_LSmallStraight: subroutine
    jsr ClearScratchpad
    jsr CountFaces
    jsr CreateBitmask

.mask = %00001111
    lda #.mask
    sta ScoreFace
    jsr CheckStraightBitmask
    jmp FinishedCalculations

Calculate_LLargeStraight: subroutine
    jsr ClearScratchpad
    jsr CountFaces
    jsr CreateBitmask

.mask = %00011111
    lda #.mask
    sta ScoreFace
    jsr CheckStraightBitmask
    lda ScoreAcc                        ; Do we have straight?
    beq .skip                           ; Skip if not
    lda #$40                            ; Load value of a large straight
    sta ScoreAcc                        ; And save it
.skip
    jmp FinishedCalculations

Calculate_LFullHouse: subroutine
    jsr ClearScratchpad
    jsr CountFaces
    lda #3
    jsr HasExactly
    bcc .none

    lda #2
    jsr HasExactly
    bcc .none

    lda #$25
    sta ScoreAcc
    jmp .done
.none
    lda #0
    sta ScoreAcc
.done
    jmp FinishedCalculations

Calculate_LYahtzee: subroutine
    jsr ClearScratchpad
    jsr CountFaces
    lda #5
    jsr HasExactly
    bcs .setScore
    lda #0
    sta ScoreAcc
    jmp .done
.setScore
    lda #$50
    sta ScoreAcc
.done
    jmp FinishedCalculations

Calculate_LChance:
    jsr ClearScratchpad
    jsr CountFaces
    jmp FinishedCalculations

Calculate_LYahtzeeBonus:
Calculate_TopSubtotal:
Calculate_TopBonus:
Calculate_LLowerTotal:
Calculate_LUpperTotal:
Calculate_LGrandTotal:
    lda #$00
    sta ScoreAcc
    jmp FinishedCalculations

ConvertSpacerNibble: subroutine
.bitmask1 = $0A
.bitmask2 = $A0

    tay                 ; Save the original value for the second nibble
    sty TempVar3        ; We will strip the nibbles out of this value as needed

    and #.bitmask2      ; Check to see of the bits for the mask are set
    cmp #.bitmask2      ; And *only* those bits
    bne .l3             ; Nope, bail
.l2:
    lda #.bitmask2      ; Load our bit mask
    eor TempVar3        ; Strip just those bits off
    sta TempVar3        ; Resave
.l3:
    tya                 ; Get our original value
    and #.bitmask1      ; Was the bit mask found?
    cmp #.bitmask1      ; And only the bit mask?
    bne l4              ; Nope  bail

    lda #.bitmask1      ; Load our mask
    eor TempVar3        ; Strip those bits off
    sta TempVar3        ; Re-save the value
l4:
    lda TempVar3        ; Retrieve the value
    rts

Add16Bit: subroutine
    ; TempVar1 lsb
    ; TempVar2 msb

    lda TempWord1 + 0
    jsr ConvertSpacerNibble
    sta TempWord1 + 0

    lda TempWord1 + 1
    jsr ConvertSpacerNibble
    sta TempWord1 + 1

    clc
    lda AddResult + 0
    adc TempWord1 + 0
    sta AddResult + 0
    lda TempWord1 + 1
    adc AddResult + 1
    sta AddResult + 1
    rts

FinishedCalculations:
    cld
    IFCONST TESTMODE
        ;; The tests call the calculate functions directly.
        rts
    ELSE
        ;; The game uses an indirect jump to get here.
        lda ScoreAcc            ; Get the score
        and #$F0                ; Anything in the high nibble?
        bne .no                 ; Yes, keep it
        lda ScoreAcc            ; Reget the value
        and #$0F                ; Strip off the high nibble
        ora #$A0                ; Set to our blank character
        sta ScoreAcc            ; Save again
.no
        jmp AfterCalc
    ENDIF

    MAC SetByte
        lda #{2}
        sta score_low_{1}
        lda #0
        sta score_high_{1}
    ENDM

    MAC SetWord
        lda #<{2}
        sta score_low_{1}
        lda #>{2}
        sta score_high_{1}
    ENDM

    MAC AddWordColumn
        ;; {1} == Pointer to the column list
        ;; {2} == The result name

        lda #<{1}
        sta AddColPtr + 0
        lda #>{1}
        sta AddColPtr + 1

        jsr AddWordColumn1

        lda AddResult + 0
        sta score_low_{2}
        lda AddResult + 1
        sta score_high_{2}
    ENDM

    IFCONST TESTMODE
    ELSE

CalcSubtotals: subroutine
        lda ScorePhase
        cmp #ScorePhaseNothing
        bne .calc
        jmp .noreset

.calc
        sed
        lda ScorePhase
        cmp #ScorePhaseCalcUpper
        bne .tryLower
        AddWordColumn TopSubtotalValues, TopSubtotal
        jmp .done

.tryLower
        cmp #ScorePhaseCalcLower
        bne .tryCalcUpperBonus
        AddWordColumn LowerTotalValues, LLowerTotal
        jmp .done

.tryCalcUpperBonus
        cmp #ScorePhaseCalcUpperBonus
        bne .tryUpperTotal
        ;; Calculate the upper bonus
        ;; Compare words, not just bytes, because the top hand subtotal
        ;; can actually be 105.
        ;; (6 * 5) + (5 * 5) + (4 * 5) + (3 * 5) + (2 * 5) + (1 *5)
        ldx #$A0            ; The 'default' bonus
        lda #$AA            ; "Blank" MSB
        cmp score_high_TopSubtotal ; Does it match what we have?
        beq .comparelsb   ; Then compare LSB

        ldx #$35            ; MSB has a value? the word is graater than 63
        jmp .saveTopBonus
.comparelsb:
        lda score_low_TopSubtotal
        and #$F0            ; Just the top nibble
        cmp #$A0            ; Our 'blank' character?
        beq .saveTopBonus   ; Value is < 10

        lda score_low_TopSubtotal
        cmp #$63                ; Min score
        bcc .saveTopBonus

        ldx #$35
.saveTopBonus
        stx score_low_TopBonus
        jmp .done

.tryUpperTotal
        cmp #ScorePhaseCalcLowerGrandTotal
        bne .tryCalcGrandTotal
        AddWordColumn LUpperTotalValues, LUpperTotal
        jmp .done

.tryCalcGrandTotal
        cmp #ScorePhaseCalcGrandTotal
        bne .tryClearLeading
        AddWordColumn LGrandTotalValues, LGrandTotal
        jmp .done

.tryClearLeading
        cmp #ScorePhaseClearLeading
        bne .done
        lda #ScorePhaseNothing
        jmp .noreset

.done
        inc ScorePhase
        lda ScorePhase
        cmp #8
        bcc .noreset
        lda #0
        sta ScorePhase
.noreset
        cld
        rts
    ENDIF

AddByteColumn1: subroutine
    clc                         ; Start from fresh
    lda #$00                    ; Zero out values
    sta AddResult + 0
    sta AddResult + 1

    ldy #0                          ; A constant value, we'll always be bouncing off this
    lda (AddColPtr),y               ; Get the number of items
.loop
    ldy #0                          ; A constant value, we'll always be bouncing off this
    pha                             ; Store it

    inc AddColPtr                   ; First/Next item

    lda (AddColPtr),y               ; Double indirect - low byte
    sta TempWord2                   ; Save it
    lda #0                          ; Zero page     j
    sta TempWord2 + 1               ; Save it
    lda (TempWord2),y               ; Read the actual value

    sta TempWord1 + 0
    lda #0                          ; Fake the high byte
    sta TempWord1 + 1

    jsr Add16Bit

    pla                             ; Get the saved count
    cmp #0
    beq .skip
    tax
    dex
    txa
    jmp .loop
.skip
    rts
    ENDIF

AddWordColumn1: subroutine
    clc                         ; Start from fresh
    lda #0                      ; Zero out values
    sta AddResult + 0
    sta AddResult + 1

    ldy #0                          ; A constant value, we'll always be bouncing off this
    lda (AddColPtr),y               ; Get the number of items
.loop
    pha                             ; Store it
    ldy #0                          ; A constant value, we'll always be bouncing off this

    inc AddColPtr                   ; Low byte
    lda (AddColPtr),y               ; Double indirect - low byte
    sta TempWord2                   ; Save it
    lda #0                          ; Zero page     j
    sta TempWord2 + 1               ; Save it
    lda (TempWord2),y               ; Read the actual value
    sta TempWord1 + 0

    inc AddColPtr                   ; High Byte
    lda (AddColPtr),y               ; Double indirect - low byte
    sta TempWord2                   ; Save it
    lda #0                          ; Zero page     j
    sta TempWord2 + 1               ; Save it
    lda (TempWord2),y               ; Read the actual value
    sta TempWord1 + 1

    jsr Add16Bit

    pla                             ; Get the saved count
    cmp #0
    beq .exitloop
    tax
    dex
    txa
    jmp .loop
.exitloop

    ; Check the Highest byte
    lda AddResult+1         ; Get the score
    and #$F0                ; Anything in the high nibble?
    bne .bail               ; Yes, keep it
    lda AddResult+1         ; Reget the value
    and #$0F                ; Strip off the high nibble
    ora #$A0                ; Set to our blank character
    sta AddResult+1         ; Save again

    and #$0F                ; Anything in the lower nibble?
    bne .bail               ; Yes, keep it
    lda #$AA                ; Just wipe out the whole thing
    sta AddResult+1         ; and save it

    lda AddResult+0         ; Get the score
    and #$F0                ; Anything in the high nibble?
    bne .bail               ; Yes, keep it
    lda AddResult+0         ; Reget the value
    and #$0F                ; Strip off the high nibble
    ora #$A0                ; Set to our blank character
    sta AddResult+0         ; Save again

.bail
    rts
