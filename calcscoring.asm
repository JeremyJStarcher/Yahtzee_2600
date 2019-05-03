    PROCESSOR 6502

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
;; For display purposes, we don't want leading zeros on the numbers, so
;; we use the "BCD" value of "$A" a leading zero.
;; Convert those nibbles to real zeros to make the math work.

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

    MAC AddByteToWord
        lda score_low_{1}
        sta TempWord1 + 0
        lda #0
        sta TempWord1 + 1

        lda score_low_{2}
        sta AddResult + 0
        lda score_high_{2}
        sta AddResult + 1

        jsr Add16Bit

        lda AddResult + 0
        sta score_low_{2}
        lda AddResult + 1
        sta score_high_{2}
    ENDM

    MAC AddWordToWord
        lda score_low_{1}
        sta TempWord1 + 0
        lda score_high_{1}
        sta TempWord1 + 1

        lda score_low_{2}
        sta AddResult + 0
        lda score_high_{2}
        sta AddResult + 1

        jsr Add16Bit

        lda AddResult + 0
        sta score_low_{2}
        lda AddResult + 1
        sta score_high_{2}
    ENDM

    MAC ClearWord
        lda $0
        sta score_low_{1}
        sta score_high_{1}
    ENDM

    IFCONST TESTMODE
    ELSE
CalcSubtotals: subroutine
        sed

        clc
        ClearWord TopSubtotal
        AddByteToWord L1s, TopSubtotal
        AddByteToWord L2s, TopSubtotal
        AddByteToWord L3s, TopSubtotal
        AddByteToWord L4s, TopSubtotal
        AddByteToWord L5s, TopSubtotal
        AddByteToWord L6s, TopSubtotal

        ;; Calculate the upper bonus
        ;; Compare words, not just bytes, because the top hand subtotal
        ;; can actually be 105.
        ;; (6 * 5) + (5 * 5) + (4 * 5) + (3 * 5) + (2 * 5) + (1 *5)
        ldx #0              ; The 'default' bonus
        lda #$00            ; MSB
        cmp score_high_TopSubtotal
        bne .compareBonus
        lda #$65
        cmp score_low_TopSubtotal
.compareBonus:
        bcs .noTopBonus
        ldx #$35
.noTopBonus
        stx score_low_TopBonus

        ClearWord LUpperTotal
        AddByteToWord TopSubtotal, LUpperTotal
        AddByteToWord TopBonus, LUpperTotal

        ClearWord LLowerTotal
        AddByteToWord L3k, LLowerTotal
        AddByteToWord L4k, LLowerTotal
        AddByteToWord LSmallStraight, LLowerTotal
        AddByteToWord LLargeStraight, LLowerTotal
        AddByteToWord LFullHouse, LLowerTotal
        AddByteToWord LYahtzee, LLowerTotal
        AddByteToWord LChance, LLowerTotal

        ;ClearWord LGrandTotal
        ;AddByteToWord LUpperTotal, LGrandTotal
        ;AddByteToWord LLowerTotal, LGrandTotal

        cld
        rts
    ENDIF
