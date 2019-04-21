    mac clearBit
        ;; {1} the bit pattern
        ;; {2} the address
        lda #[{1} ^ $FF]
        and {2}
        sta {2}
    endm

    mac setBit
        ;; {1} the bit pattern
        ;; {2} the address
        lda #[{1}]
        ora {2}
        sta {2}
    endm

