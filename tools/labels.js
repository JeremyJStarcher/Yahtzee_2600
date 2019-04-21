"use strict";

const lib = require("./lib");
const fs = require("fs");

function convertScoreInfo() {

    const source = `
@header Labels
@glyph Jeremy
!##### #### #### #### ##   ## #   #              !
!  #   #    #  # #    # # # #  # #               !
!  #   ##   #### ##   #  #  #   #                !
!# #   #    # #  #    #     #   #                !
!###   #### #  # #### #     #   #                !
`;
    const glyphData = lib.all.stringToObject(source);

    const out = [0, 1, 2, 3, 4, 5].map((bin, idx) =>
        [`LabelBitmaps${idx}:`]
    );

    const glyphNames = [];

    glyphData.glyphs.forEach((bin, idx) => {
        const glyphName = `label${glyphData.names[idx]}`;
        glyphNames.push(glyphName);

        for (let i = 0; i < out.length; i++) {
           out[i].push(`${glyphName}${i}:`);
        }

        bin.forEach(binary => {
            binary = binary.replace(/#/g, "1").replace(/ /g, "0");
            const bytes = binary.match(/.{1,8}/g);

            bytes.forEach((byte, offset) => {
                const comment = byte.replace(/0/g, ".").replace(/1/g, "#");
                out[offset].push(`    .byte %${byte}; ${comment}`);
            });
        });
    });

    const lookup = [];
    [
        ['<', '0', 'labelglyph0lsb'],
        ['<', '1', 'labelglyph1lsb'],
    ].forEach(key => {
        const [sym, byte, header] = key;

        lookup.push(`${header}:`);
        glyphNames.forEach(name => {
            const s = `    .byte ${sym}${name}${byte}`;
            lookup.push(s);
        });
    });

    let out2 = [];
    for (let i = 0; i < out.length; i++)
    {
        out2 = out2.concat(out[i]);
    }

    fs.writeFileSync('../build/labels_bitmap.asm', out2.join("\n"));
    // fs.writeFileSync('../build/labels_lookup.asm', lookup.join("\n"));
}

convertScoreInfo();
