"use strict";

(function () {
  // test stuff

  const tests = [
    {
      fp: "10101010101010101010",
      fp0: "01010000",
      fp1: "10101010",
      fp2: "01010101",
    },
    {
      fp: "10000000000000000000",
      fp0: "00010000",
      fp1: "00000000",
      fp2: "00000000",
    },
    {
      fp: "10010010010010010010",
      fp0: "10010000",
      fp1: "00100100",
      fp2: "01001001",
    }
  ];

  let fail = false;
  tests.forEach(t => {
    const val = pfToRegistersString(t.fp);

    if (val[0] !== t.fp0) {
      console.error(`fp0 failed:\n${t.fp0}\n${val[0]}`);
      fail = true;
    }
    if (val[1] !== t.fp1) {
      console.error(`fp1 failed:\n${t.fp1}\n${val[1]}`);
      fail = true;
    }
    if (val[2] !== t.fp2) {
      console.error(`fp2 failed:\n${t.fp2}\n${val[2]}`);
      fail = true;
    }
  });

  if (fail) {
    throw new Error("Test failed");
  }
})();

const diceFaceBitmaps = [
  [
    "... ... ... ... ...                     ",
    "000 111 222 333 444                     ",
    "... ... ... ... ...                     ",
  ],
  [
    "... ... ... ... ...                     ",
    ".0. .1. .2. .3. .4.                     ",
    "... ... ... ... ...                     ",
  ],
  [
    "..0 ..1 ..2 ..3 ..4                     ",
    "... ... ... ... ...                     ",
    "0.. 1.. 2.. 3.. 4..                     ",
  ],
  [
    "..0 ..1 ..2 ..3 ..4                     ",
    ".0. .1. .2. .3. .4..                    ",
    "0.. 1.. 2.. 3.. 4...                    ",
  ],
  [
    "0.0 1.1 2.2 3.3 4.4                     ",
    "... ... ... ... ...                     ",
    "0.0 1.1 2.2 3.3 4.4                     ",
  ],
  [
    "0.0 1.1 2.2 3.3 4.4                     ",
    ".0. .1. .2. .3. .4.                     ",
    "0.0 1.1 2.2 3.3 4.4                     ",
  ],
  [
    "0.0 1.1 2.2 3.3 4.4                     ",
    "0.0 1.1 2.2 3.3 4.4                     ",
    "0.0 1.1 2.2 3.3 4.4                     ",
  ],
];


const fs = require('fs');

function pfToRegisters(_pf) {
  const regs = pfToRegistersString(_pf);

  const ret = [
    parseInt(regs[0], 2),
    parseInt(regs[1], 2),
    parseInt(regs[2], 2),
  ];

  return ret;
}

function pfToRegistersString(_pf) {
  // The weird bitpattern is the Atart 2600 -- we just have to deal with it.

  let pf = Array.from(_pf).reverse();
  if (pf.length !== 20) {
    throw new Error("pfToRegisters takes exactly 20 bits");
  }

  const emptyByte = Array(8).fill(0);
  const pf0 = [...emptyByte];
  const pf1 = [...emptyByte];
  const pf2 = [...emptyByte];

  let pfi = pf.length - 1;
  pf0[4] = pf[pfi--];
  pf0[5] = pf[pfi--];
  pf0[6] = pf[pfi--];
  pf0[7] = pf[pfi--];

  pf1[7] = pf[pfi--];
  pf1[6] = pf[pfi--];
  pf1[5] = pf[pfi--];
  pf1[3] = pf[pfi--];
  pf1[3] = pf[pfi--];
  pf1[2] = pf[pfi--];
  pf1[1] = pf[pfi--];
  pf1[0] = pf[pfi--];

  pf2[0] = pf[pfi--];
  pf2[1] = pf[pfi--];
  pf2[2] = pf[pfi--];
  pf2[3] = pf[pfi--];
  pf2[4] = pf[pfi--];
  pf2[5] = pf[pfi--];
  pf2[6] = pf[pfi--];
  pf2[7] = pf[pfi--];

  const ret = [
    pf0.reverse().join(""),
    pf1.reverse().join(""),
    pf2.reverse().join(""),
  ];

  return ret;
}

function bitmapsToRegisterMasks(bitmaps, maxLine, maxPosition, maxFace) {
  // For each position, these are the possible places to display it
  // .......... 0000000000111111111122222222223333333333
  // .......... 0123456789012345678901234567890123456789
  const mask = "000 111 222 333 444                     ";

  // And these are the actual positions used.
  const blanks = Array.from(' .');

  // Sanity check the data, just to make sure there are no collisions
  bitmaps.forEach((face, faceIdx) => {
    face.forEach((line, lineIdx) => {
      Array.from(line).forEach((p, i) => {
        if (blanks.indexOf(p) !== -1) {
          return;
        }

        if (mask[i] !== p) {
          throw new Error(`Error: face ${faceIdx} line ${lineIdx} does not fit inside mask`);
        }
      });
    });
  });

  // Reorganize into a very different layout
  // L = Line/ P = Position / F = Face //
  const dataLeft = {};

  for (let l = 0; l <= maxLine; l++) {
    for (let p = 0; p <= maxPosition; p++) {
      for (let f = 0; f <= maxFace; f++) {

        const bS = bitmaps[f][l];
        // filter out just the bitmap for this position.
        let pf = Array.from(bS).map(s => s === "" + p ? "1" : "0").join("");

        const pfLeft = pf.substring(0, 20);
        const leftValue = pfToRegisters(pfLeft);

        const hash = [l, p, f].join("_");
        dataLeft[hash] = leftValue;
      }
    }
  }
  return dataLeft;
}

function createDiceBitmaps() {
  const maxLine = 2;
  const maxPosition = 4;
  const maxFace = 6;

  const dataLeft = bitmapsToRegisterMasks(diceFaceBitmaps, maxLine, maxPosition, maxFace);

  let thisCode = [];
  let values = [];
  for (let l = 0; l <= maxLine; l++) {
    for (let p = 0; p <= maxPosition; p++) {
      values = [];
      for (let f = 0; f <= maxFace; f++) {
        const hash = [l, p, f].join("_");
        const dval = dataLeft[hash];

        // For each combo there is only one byte that we need.
        // Doing this is cheap and dirty, but hey, I don't mind
        // cheap and dirty in code like this
        // (Because the images align to the byte boundary!)

        const oneByte = dval.filter(v => v > 0)[0] || 0;
        values.push(oneByte);
      }

      if (values.length !== 7) {
        throw new Error("Something broke.....");
      }

      const binaryValues = values.map(v => {
        let n = v.toString(2);
        n = "00000000".substr(n.length) + n;
        return `%${n}`;
      });

      thisCode.push(`faceL${l}P${p}:`);
      binaryValues.forEach(v => {
        thisCode.push(`  .byte ${v}`);
      });

    }
  }
  fs.writeFileSync('../build/faces.asm', thisCode.join("\n"));
}

createDiceBitmaps();