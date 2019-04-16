"use strict";

function stringToObject(s) {
    const digitZero = "0";
    const digitOne = "1";

    const out = {
        header: '',
        glyphs: [],
        names: [],
    };

    let basket = [];
    s.split(/\r\n|\r|\n/).forEach((line, lineNo) => {
        line = line.trim();

        const [code, text] = line.split(" ");

        if (code.indexOf("@header") === 0) {
            out.header = text;
        }

        if (code.indexOf("@glyph") === 0) {
            basket = [];
            out.glyphs.push(basket);
            out.names.push(text);
        }

        if (code.indexOf("!") === 0) {
            const binary = line
                .replace(/\||!/g, "")
                .replace(/ /g, digitZero)
                .replace(/X/g, digitOne);

            basket.push(binary);
        }
    });

    // 2600 graphics are almost always upside down because counting down is a lot easier.
    out.glyphs.forEach((g, i, a) => a[i] = g.reverse());

    return out;
}

exports.all = {
    stringToObject,
};