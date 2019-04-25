    MAC SetDice
        lda #{1}
        sta [RolledDice + 0]
        lda #{2}
        sta [RolledDice + 1]
        lda #{3}
        sta [RolledDice + 2]
        lda #{4}
        sta [RolledDice + 3]
        lda #{5}
        sta [RolledDice + 4]
    ENDM

RunTests: subroutine

    SetDice 1, 2, 3, 4, 5

    lda #$12
    sta score_high_test01

    lda #$99
    sta score_low_test01
    rts 