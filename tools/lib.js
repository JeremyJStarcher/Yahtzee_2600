"use strict";

function lineToBinary(data, line, lineNo, isReverse) {

    const digitZero = isReverse ? "0" : "1";
    const digitOne = isReverse ? "1" : "0";

    const binary = line
        .replace(/\||!/g, "")
        .replace(/ /g, digitZero)
        .replace(/X/g, digitOne);

    if (binary.length % 8 !== 0) {
        throw new Error(`Length of line # ${lineNo}: must be a multiple of 8.\n ${line}`);
    }

    if (binary.length === 8) {
        const s = `    .byte %${binary}   ; ${binary.length} - ${line.length}`;
        data.glyph.push(s);
    } else {
        const s = `    .word %${binary}   ; ${binary.length} - ${line.length}`;
        data.glyph.push(s);
    }

    const bytes = binary.match(/.{1,8}/g);
    data.glyphBytes.push(bytes);
}

function title(data, line, lineNo) {
    lineToBinary(data, line, lineNo, false);
}

function digit(data, line, lineNo) {
    lineToBinary(data, line, lineNo, true);
}

function normal(data, line) {
    data.gfx = data.gfx.concat(data.glyph.reverse());
    data.gfx.push(line);

    data.glyph = [];
    data.glyphBytes = [];
}

exports.all = {
    title,
    digit,
    normal
};