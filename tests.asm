FillDice:
    ldy #0
    lda (ScoreScratchpad),y
    sta [RolledDice + 0]

    iny
    lda (ScoreScratchpad),y
    sta [RolledDice + 1]

    iny
    lda (ScoreScratchpad),y
    sta [RolledDice + 2]

    iny
    lda (ScoreScratchpad),y
    sta [RolledDice + 3]

    iny
    lda (ScoreScratchpad),y
    sta [RolledDice + 4]
    rts

    MAC SetDice
        jmp .g
.d: byte {1}, {2}, {3}, {4}, {5}
.g
        lda #>.d
        sta ScoreScratchpad + 1
        lda #<.d
        sta ScoreScratchpad + 0
        jsr FillDice
    ENDM

    MAC RunTest
        subroutine
        ;; {1} Die face
        ;; {2} Die face
        ;; {3} Die face
        ;; {4} Die face
        ;; {5} Die face
        ;; {6} The test to run
        ;; {7} Display Slot
        ;; {8} Expected value
        lda TestsFailed             ; Check if tests have failed
        bne .skipTest               ; If so, don't run this one

        SetDice {1}, {2}, {3}, {4}, {5}
        jsr {6}                     ; Call the test
        lda ScoreAcc                ; Get the test result
        sta score_low_{7}           ; Show it to the user
        lda #$AA                    ; Clear out the high byte
        sta score_high_{7}          ; Save it

        lda #{8}                    ; Get the expected value
        cmp ScoreAcc                ; Compare to the actual value
        beq .testpassed
        lda #1                      ; Set the flag
        sta TestsFailed             ; Save the flag
        lda #{8}                    ; Load the failing value
        sta score_high_{7}          ; Show the user
.testpassed
.skipTest
    ENDM
RunTests: subroutine

    RunTest 1, 1, 1, 1, 1, Calculate_L1s, test01, $05
    RunTest 2, 2, 2, 2, 2, Calculate_L1s, test01, $00
;    RunTest 2, 2, 1, 2, 2, Calculate_L1s, test01, $01
;
    RunTest 2, 2, 2, 2, 2, Calculate_L2s, test02, $10
    RunTest 1, 1, 1, 1, 1, Calculate_L2s, test02, $00
;    RunTest 2, 1, 1, 1, 2, Calculate_L2s, test02, $04

    RunTest 2, 1, 3, 3, 2, Calculate_L3s, test03, $06

    RunTest 2, 4, 3, 3, 4, Calculate_L4s, test04, $08

    RunTest 5, 4, 5, 3, 5, Calculate_L5s, test05, $15

    RunTest 6, 6, 6, 6, 6, Calculate_L6s, test06, $30

;    RunTest 2, 2, 2, 2, 2, Calculate_L3k, test07, $10
    RunTest 6, 6, 6, 6, 4, Calculate_L3k, test07, $28
;    RunTest 6, 6, 6, 1, 1, Calculate_L3k, test07, $20
;    RunTest 1, 6, 6, 1, 4, Calculate_L3k, test07, $00
    RunTest 1, 2, 3, 4, 5, Calculate_L3k, test07, $00

    RunTest 1, 2, 3, 4, 5, Calculate_L4k, test08, $00
;    RunTest 1, 1, 1, 1, 5, Calculate_L4k, test08, $09
    RunTest 1, 1, 1, 1, 1, Calculate_L4k, test08, $05
;    RunTest 1, 1, 1, 4, 5, Calculate_L4k, test08, $00

    RunTest 1, 1, 1, 1, 1, Calculate_LYahtzee, test09, $50
    RunTest 1, 1, 1, 1, 2, Calculate_LYahtzee, test09, $00
;    RunTest 1, 2, 3, 4, 5, Calculate_LYahtzee, test09, $00

    RunTest 6, 1, 6, 1, 6, Calculate_LFullHouse, test10, $25
;    RunTest 1, 1, 1, 2, 2, Calculate_LFullHouse, test10, $25
    RunTest 1, 2, 3, 4, 5, Calculate_LFullHouse, test10, $00
;    RunTest 1, 1, 1, 1, 1, Calculate_LFullHouse, test10, $00

    RunTest 2, 3, 4, 5, 6, Calculate_LSmallStraight, test11, $30
;    RunTest 1, 2, 3, 4, 3, Calculate_LSmallStraight, test11, $30
;    RunTest 2, 3, 4, 5, 3, Calculate_LSmallStraight, test11, $30
;    RunTest 1, 2, 3, 4, 5, Calculate_LSmallStraight, test11, $30
;    RunTest 1, 3, 2, 1, 4, Calculate_LSmallStraight, test11, $30
    RunTest 6, 1, 3, 1, 6, Calculate_LSmallStraight, test11, $00

    RunTest 2, 3, 4, 5, 6, Calculate_LLargeStraight, test12, $40
;    RunTest 1, 2, 3, 4, 3, Calculate_LLargeStraight, test12, $00
;    RunTest 2, 3, 4, 5, 3, Calculate_LLargeStraight, test12, $00
;    RunTest 1, 2, 3, 4, 5, Calculate_LLargeStraight, test12, $40
;    RunTest 1, 3, 2, 1, 4, Calculate_LLargeStraight, test12, $00
    RunTest 6, 1, 3, 1, 6, Calculate_LLargeStraight, test12, $00


    lda TestsFailed                 ; Check if tests passed
    beq .allPassed                  ; Hurrah, they did.
    lda #$F2                        ; NTSC Ugly color
    sta COLUBK                      ; Make the tester suffer
.allPassed
    rts