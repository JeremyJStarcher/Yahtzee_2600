Calc_scores_lookup:
    .word Calculate_L1s
    .word Calculate_L2s
    .word Calculate_L3s
    .word Calculate_L4s
    .word Calculate_L5s
    .word Calculate_L6s
    .word Calculate_TopSubtotal
    .word Calculate_TopBonus
    .word Calculate_L3k
    .word Calculate_L4k
    .word Calculate_LSmallStraight
    .word Calculate_LLargeStraight
    .word Calculate_LFullHouse
    .word Calculate_LYahtzee
    .word Calculate_LChance
    .word Calculate_LYahtzeeBonus
    .word Calculate_LLowerTotal
    .word Calculate_LUpperTotal
    .word Calculate_LGrandTotal

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
    cld                         ; Clear decimal mode
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

Calculate_TopSubtotal:
Calculate_TopBonus:
Calculate_L3k:
Calculate_L4k:
Calculate_LSmallStraight:
Calculate_LLargeStraight:
Calculate_LFullHouse:
Calculate_LYahtzee:
Calculate_LChance:
Calculate_LYahtzeeBonus:
Calculate_LLowerTotal:
Calculate_LUpperTotal:
Calculate_LGrandTotal:
    rts
