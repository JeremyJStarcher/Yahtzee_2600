"use strict";

const lib = require("./lib");
const fs = require("fs");

function convertDigits() {

const source = `
@header Digits

@glyph num0
! XXXXXX !
! XX  XX !
! XX  XX !
! XX  XX !
! XXXXXX !

@glyph num1
!   XX   !
! XXXX   !
!   XX   !
!   XX   !
! XXXXXX !

@glyph num2
! XXXXXX !
!     XX !
! XXXXXX !
! XX     !
! XXXXXX !

@glyph num3
! XXXXXX !
!     XX !
!   XXXX !
!     XX !
! XXXXXX !

@glyph num4
! XX  XX !
! XX  XX !
! XXXXXX !
!     XX !
!     XX !

@glyph num5
! XXXXXX !
! XX     !
! XXXXXX !
!     XX !
! XXXXXX !

@glyph num6
! XXXXXX !
! XX     !
! XXXXXX !
! XX  XX !
! XXXXXX !

@glyph num7
! XXXXXX !
!     XX !
!     XX !
!     XX !
!     XX !

@glyph num8
! XXXXXX !
! XX  XX !
! XXXXXX !
! XX  XX !
! XXXXXX !

@glyph num9
! XXXXXX !
! XX  XX !
! XXXXXX !
!     XX !
! XXXXXX !

@glyph numA
!        !
!        !
!        !
!        !
!X X X X !
`;

    const glyphData = lib.all.stringToObject(source);

    const out = [];
    out.push(`${glyphData.header}:`)
    glyphData.glyphs.forEach((bin, idx) => {
        out.push(`Digit${glyphData.names[idx]}`);
        bin.forEach(binary => {
            const comment = binary.replace(/0/g, ".").replace(/1/g, "#");
            out.push(`    .byte %${binary}; ${comment}`);
        });
    });

    fs.writeFileSync('../build/digits_bitmap.asm', out.join("\n"));
}

convertDigits();
