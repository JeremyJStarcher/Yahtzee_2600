"use strict";

const lib = require("./lib");
const fs = require("fs");

function convertScoreInfo() {

    const source = `
@header ScoreNames
@glyph test01
!           XX   !
!         XXXX   !
!           XX   !
!           XX   !
!         XXXXXX !

@glyph test02
!         XXXXXX !
!             XX !
!         XXXXXX !
!         XX     !
!         XXXXXX !

@glyph test03
!         XXXXXX !
!             XX !
!           XXXX !
!             XX !
!         XXXXXX !

@glyph test04
!         XX  XX !
!         XX  XX !
!         XXXXXX !
!             XX !
!             XX !

@glyph test05
!         XXXXXX !
!         XX     !
!         XXXXXX !
!             XX !
!         XXXXXX !

@glyph test06
!         XXXXXX !
!         XX     !
!         XXXXXX !
!         XX  XX !
!         XXXXXX !

@glyph test07
!         XXXXXX !
!             XX !
!            XX  !
!           XX   !
!          XX    !

@glyph test08
!         XXXXXX !
!         XX  XX !
!         XXXXXX !
!         XX  XX !
!         XXXXXX !

@glyph test09
!         XXXXXX !
!         XX  XX !
!         XXXXXX !
!             XX !
!         XXXXXX !

@glyph test10
!   XX    XXXXXX !
! XXXX    XX  XX !
!   XX    XX  XX !
!   XX    XX  XX !
! XXXXXX  XXXXXX !

@glyph test11
!   XX      XX   !
! XXXX     XXX   !
!   XX      XX   !
!   XX      XX   !
! XXXXXX  XXXXXX !

@glyph test12
!   XX    XXXXXX !
! XXXX        XX !
!   XX    XXXXXX !
!   XX    XX     !
! XXXXXX  XXXXXX !

@glyph test13
!   XX    XXXXXX !
! XXXX        XX !
!   XX      XXXX !
!   XX        XX !
! XXXXXX  XXXXXX !

@glyph test14
!   XX    XX  XX !
! XXXX    XX  XX !
!   XX    XXXXXX !
!   XX        XX !
! XXXXXX      XX !

@glyph test15
!   XX    XXXXXX !
! XXXX    XX     !
!   XX    XXXXXX !
!   XX        XX !
! XXXXXX  XXXXXX !

@glyph test16
!   XX    XXXXXX !
! XXXX    XX     !
!   XX    XXXXXX !
!   XX    XX  XX !
! XXXXXX  XXXXXX !

@glyph test17
!   XX    XXXXXX !
! XXXX        XX !
!   XX       XX  !
!   XX      XX   !
! XXXXXX   XX    !

@glyph test18
!   XX    XXXXXX !
! XXXX    XX  XX !
!   XX    XXXXXX !
!   XX    XX  XX !
! XXXXXX  XXXXXX !

@glyph test19
!   XX    XXXXXX !
! XXXX    XX  XX !
!   XX    XXXXXX !
!   XX        XX !
! XXXXXX  XXXXXX !

`;

    // These glyphs are actually broken up into separate 8-bit chunks.
    // and stored in two separate tables.
    //
    const glyphData = lib.all.stringToObject(source);
    const out = [0, 1].map((bin, idx) =>
        [`scoreglyphs${idx}:`]
    );

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

    fs.writeFileSync('../build/test_bitmap.asm', [].concat(out[0]).concat(out[1]).join("\n"));
    fs.writeFileSync('../build/test_lookup.asm', lookup.join("\n"));
    fs.writeFileSync('../build/test_ram.asm', ram.join("\n"));
}

convertScoreInfo();
