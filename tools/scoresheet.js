"use strict";

const lib = require("./lib");
const fs = require("fs");

function convertScoreInfo() {

    const source = `
@header ScoreNames
@glyph L1s
!   XX    XXX    !
! XXXX   X       !
!   XX    XX     !
!   XX      X    !
! XXXXXX XXX     !

@glyph L2s
! XXXXXX  XXX    !
!     XX X       !
! XXXXXX  XX     !
! XX        X    !
! XXXXXX XXX     !

@glyph L3s
! XXXXXX  XXX    !
!     XX X       !
!   XXXX  XX     !
!     XX    X    !
! XXXXXX XXX     !

@glyph L4s
! XX  XX  XXX    !
! XX  XX X       !
! XXXXXX  XX     !
!     XX    X    !
!     XX XXX     !

@glyph L5s
! XXXXXX  XXX    !
! XX     X       !
! XXXXXX  XX     !
!     XX    X    !
! XXXXXX XXX     !

@glyph L6s
! XXXXXX  XXX    !
! XX     X       !
! XXXXXX  XX     !
! XX  XX    X    !
! XXXXXX XXX     !

@glyph TopSubtotal
!                !
! XXXXXXXXXXX    !
!                !
! XXXXXXXXXXX    !
!                !

@glyph TopBonus
!     XXX XXX    !
!  X    X X      !
! XXX XXX XXX    !
!  X    X   X    !
!     XXX XXX    !

@glyph L3k
! XXXXXX X  X    !
!     XX X X     !
!   XXXX XX      !
!     XX X X     !
! XXXXXX X  X    !

@glyph L4k
! XX  XX X  X    !
! XX  XX X X     !
! XXXXXX XX      !
!     XX X X     !
!     XX X  X    !

@glyph LSmallStraight
!   XXX  XXX     !
!  X    X        !
!   XX   XX      !
!     X    X     !
!  XXX  XXX      !

@glyph LLargeStraight
!  X     XXX     !
!  X    X        !
!  X     XX      !
!  X       X     !
!  XXXX XXX      !

@glyph LFullHouse
! XXXX X   X     !
! X    X   X     !
! XXX  XXXXX     !
! X    X   X     !
! X    X   X     !

@glyph LYahtzee
! X   X  XX      !
! X   X X  X     !
!  XXX  XXXX     !
!   X   X  X     !
!   X   X  X     !

@glyph LChance
!  XXX X   X     !
! X    X   X     !
! X    XXXXX     !
! X    X   X     !
!  XXX X   X     !

@glyph LYahtzeeBonus
! X   X XXX      !
! X   X X  X     !
!  XXX  XXX      !
!   X   X  X     !
!   X   XXX      !

@glyph LLowerTotal
!  X    XXX      !
!  X     X       !
!  X     X       !
!  X     X       !
!  XXXX  X       !

@glyph LUpperTotal
!  X  X XXX      !
!  X  X  X       !
!  X  X  X       !
!  X  X  X       !
!  XXXX  X       !

@glyph LGrandTotal
!  XXXX XXX      !
!  X     X       !
!  X XX  X       !
!  X  X  X       !
!  XXXX  X       !

`;

    // These glyphs are actually broken up into separate 8-bit chunks.
    // and stored in two separate tables.
    //
    const glyphData = lib.all.stringToObject(source);
    const out = [0, 1].map((bin, idx) =>
        [`scoreglyphs${idx}:`]
    );

    console.log("-----------------------------------------");
    console.log(out);

    const glyphNames = [];

    glyphData.glyphs.forEach((bin, idx) => {
        const glyphName = `glyph${glyphData.names[idx]}`;
        glyphNames.push(glyphName);

        out[0].push(`${glyphName}0:`);
        out[1].push(`${glyphName}1:`);

        bin.forEach(binary => {
            const bytes = binary.match(/.{1,8}/g);

            bytes.forEach((byte, offset) => {
                const comment = byte.replace(/0/g, ".").replace(/1/g, "#");
                out[offset].push(`    .byte %${byte}; ${comment}`);
            });
        });
    });

    const lookup = [];
    [
        ['<', '0', 'scoreglyph0lsb'],
        ['<', '1', 'scoreglyph1lsb'],
    ].forEach(key => {
        const [sym, byte, header] = key;

        lookup.push(`${header}:`);
        glyphNames.forEach(name => {
            const s = `    .byte ${sym}${name}${byte}`;
            lookup.push(s);
        });
    });

    const ram = [];
    [
        ['score_low'],
        ['score_high'],
    ].forEach(key => {
        const [header] = key;

        ram.push(`${header}:`);

        glyphData.names.forEach(name => {
            const s = `${header}_${name}:    .ds 1 `;
            ram.push(s);
        });
    });

    fs.writeFileSync('../build/score_bitmap.asm', [].concat(out[0]).concat(out[1]).join("\n"));
    fs.writeFileSync('../build/score_lookup.asm', lookup.join("\n"));
    fs.writeFileSync('../build/score_ram.asm', ram.join("\n"));
}

convertScoreInfo();
