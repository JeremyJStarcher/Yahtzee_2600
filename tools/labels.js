"use strict";

const lib = require("./lib");
const fs = require("fs");

function convertScoreInfo() {

    const source = `
@header ScoreNames
@glyph L1s
!##### #### #### #### ##   ## #   #              !
!  #   #    #  # #    # # # #  # #               !
!  #   ##   #### ##   #  #  #   #                !
!# #   #    # #  #    #     #   #                !
!###   #### #  # #### #     #   #                !
!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX!
`;

    // These glyphs are actually broken up into separate 8-bit chunks.
    // and stored in two separate tables.
    //
    const glyphData = lib.all.stringToObject(source);

    const glyphNames = [];
    const out = [];

    glyphData.glyphs.forEach((bin, idx) => {
        const glyphName = `${glyphData.header}${glyphData.names[idx]}`;
        glyphNames.push(glyphName);

        out.push(glyphName);

        bin.forEach(binary => {
            const bb = binary.replace(/ /g, "0").replace(/#/g, "1");
            const bytes = bb.match(/.{1,8}/g);
            const str = bytes.map(b => `%${b}`).join(", ");
            const comment = binary.replace(/0/g, ".").replace(/1/g, "#");
            out.push(`    .byte ${str}; ${comment}`);

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

    fs.writeFileSync('../build/labels_bitmap.asm', [].concat(out).join("\n"));
    // fs.writeFileSync('../build/score_lookup.asm', lookup.join("\n"));
}

convertScoreInfo();

