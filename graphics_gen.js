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
//
// graphics_gen.js
//
// Builds the graphics.asm file from the template below.
//
// Graphic glyphs are built with "X" and spaces, and surrounded on
// the template with either "!" (X = bit "0") or "|" (X = bit "1"),
// so we can easily draw tiles, score digits, etc.
//
// In either case, glyphs are written upside-down, so we can use
// (cheaper) decreasing counter loops

const glyphs = `
;;;;;;;;;;;;;;
;; GRAPHICS ;;
;;;;;;;;;;;;;;

; Actually, the value-colored kernel can't really
; update the rightmost pixel on the first tile, so
; if you want to roll your own tiles...
;
;       ┌─── ...don't set THIS bit
;       ↓;

Digits:

! XXXXXX !
! XX  XX !
! XX  XX !
! XX  XX !
! XXXXXX !

!   XX   !
! XXXX   !
!   XX   !
!   XX   !
! XXXXXX !

! XXXXXX !
!     XX !
! XXXXXX !
! XX     !
! XXXXXX !

! XXXXXX !
!     XX !
!   XXXX !
!     XX !
! XXXXXX !

! XX  XX !
! XX  XX !
! XXXXXX !
!     XX !
!     XX !

! XXXXXX !
! XX     !
! XXXXXX !
!     XX !
! XXXXXX !

! XXXXXX !
! XX     !
! XXXXXX !
! XX  XX !
! XXXXXX !

! XXXXXX !
!     XX !
!     XX !
!     XX !
!     XX !

! XXXXXX !
! XX  XX !
! XXXXXX !
! XX  XX !
! XXXXXX !

! XXXXXX !
! XX  XX !
! XXXXXX !
!     XX !
! XXXXXX !

! XXXXXX !
! X    X !
! XXXXXX !
! X    X !
! X    X !

@score L1s:
!   XX    XXX    !
! XXXX   X       !
!   XX    XX     !
!   XX      X    !
! XXXXXX XXX     !

@score L2s:
! XXXXXX  XXX    !
!     XX X       !
! XXXXXX  XX     !
! XX        X    !
! XXXXXX XXX     !

@score L3s:
! XXXXXX  XXX    !
!     XX X       !
!   XXXX  XX     !
!     XX    X    !
! XXXXXX XXX     !

@score L4s:
! XX  XX  XXX    !
! XX  XX X       !
! XXXXXX  XX     !
!     XX    X    !
!     XX XXX     !

@score L5s:
! XXXXXX  XXX    !
! XX     X       !
! XXXXXX  XX     !
!     XX    X    !
! XXXXXX XXX     !

@score L6s:
! XXXXXX  XXX    !
! XX     X       !
! XXXXXX  XX     !
! XX  XX    X    !
! XXXXXX XXX     !

@score TopSubtotal:
!                !
! XXXXXXXXXXX    !
!                !
! XXXXXXXXXXX    !
!                !

@score TopBonus:
!     XXX XXX    !
!  X    X X      !
! XXX XXX XXX    !
!  X    X   X    !
!     XXX XXX    !

@score L3k:
! XXXXXX X  X    !
!     XX X X     !
!   XXXX XX      !
!     XX X X     !
! XXXXXX X  X    !

@score L4k:
! XX  XX X  X    !
! XX  XX X X     !
! XXXXXX XX      !
!     XX X X     !
!     XX X  X    !

@score LSmallStraight:
!   XXX  XXX     !
!  X    X        !
!   XX   XX      !
!     X    X     !
!  XXX  XXX      !

@score LLargeStraight:
!  X     XXX     !
!  X    X        !
!  X     XX      !
!  X       X     !
!  XXXX XXX      !

@score LFullHouse:
! XXXX X   X     !
! X    X   X     !
! XXX  XXXXX     !
! X    X   X     !
! X    X   X     !

@score LYahtzee:
! X   X  XX      !
! X   X X  X     !
!  XXX  XXXX     !
!   X   X  X     !
!   X   X  X     !

@score LChance:
!  XXX X   X     !
! X    X   X     !
! X    XXXXX     !
! X    X   X     !
!  XXX X   X     !

@score LYahtzeeBonus:
! X   X XXX      !
! X   X X  X     !
!  XXX  XXX      !
!   X   X  X     !
!   X   XXX      !

@score LLowerTotal:
!  X    XXX      !
!  X     X       !
!  X     X       !
!  X     X       !
!  XXXX  X       !

@score LUpperTotal:
!  X  X XXX      !
!  X  X  X       !
!  X  X  X       !
!  X  X  X       !
!  XXXX  X       !

@score LGrandTotal:
!  XXXX XXX      !
!  X     X       !
!  X XX  X       !
!  X  X  X       !
!  XXXX  X       !

`;

const fs = require('fs');
let glyph = [];
let gfx = [];
let gfx_names = [];
let glyphBytes = [];
let isText = false;
let textLabel = "-none-set";

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

function createDiceFunctions() {
  // For each position, these are the possible places to display it
  // .......... 0000000000111111111122222222223333333333
  // .......... 0123456789012345678901234567890123456789
  const mask = "000 111 222 333 444                     ";

  // And these are the actual positions used.
  const bitmap = [
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

  const blanks = Array.from(' .');

  // Sanity check the data, just to make sure there are no collisions
  bitmap.forEach((face, faceIdx) => {
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

  const maxLine = 2;
  const maxPosition = 4;
  maxFace = 6;
  for (let l = 0; l <= maxLine; l++) {
    for (let p = 0; p <= maxPosition; p++) {
      for (f = 0; f <= maxFace; f++) {

        const bS = bitmap[f][l];
        // filter out just the bitmap for this position.
        let pf = Array.from(bS).map(s => s === "" + p ? "1" : "0").join("");

        const pfLeft = pf.substring(0, 20);
        const leftValue = pfToRegisters(pfLeft);

        const hash = [l, p, f].join("_");
        dataLeft[hash] = leftValue;
      }
    }
  }

  let thisCode = [];
  let values = [];
  for (let l = 0; l <= maxLine; l++) {
    for (let p = 0; p <= maxPosition; p++) {
      values = [];
      for (f = 0; f <= maxFace; f++) {
        const hash = [l, p, f].join("_");
        const dval = dataLeft[hash];

        // For each combo there is only one byte that we need.
        // Doing this is cheap and dirty, but hey, I don't mind
        // cheap and dirty in code like this

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

      thisCode.push(`LP_${l}_${p}:`);
      binaryValues.forEach(v => {
        thisCode.push(`  .byte ${v}`);
      });

    }
  }
  fs.writeFileSync('build/faces.asm', thisCode.join("\n"));
}

function lineToBinary(line, lineNo, isReverse) {
  const digitZero = isReverse ? "0" : "1";
  const digitOne = isReverse ? "1" : "0";

  const binary = line
    .replace(/\||!/g, "")
    .replace(/ /g, digitZero)
    .replace(/X/g, digitOne);

  if (binary.length !== 8 && binary.length !== 16) {
    throw new Error(`Length of line is off on line ${lineNo}: ${line}`);
  }

  if (binary.length === 8) {
    const s = `    .BYTE %${binary}   ; ${binary.length} - ${line.length}`;
    glyph.push(s);
  } else {
    const s = `    .WORD %${binary}   ; ${binary.length} - ${line.length}`;
    glyph.push(s);
  }

  const bytes = binary.match(/.{1,8}/g);
  glyphBytes.push(bytes);
}

function title(line, lineNo) {
  lineToBinary(line, lineNo, false);
}

function digit(line, lineNo) {
  lineToBinary(line, lineNo, true);
}

function normal(line) {
  gfx = gfx.concat(glyph.reverse());
  gfx.push(line);

  glyph = [];
  glyphBytes = [];
}

function generateScoreSub(line, lineNo) {
  if (gfx_names.indexOf(textLabel) === -1) {
    gfx_names.push(textLabel);
  }

  const bytes0 = [];
  const bytes1 = [];
  for (var i = 0; i < 5; i++) {
    const b0 = glyphBytes[i][0];
    const b1 = glyphBytes[i][1];

    bytes0.push(b0);
    bytes1.push(b1);
  }

  gfx.push(`${textLabel}_0:`);
  bytes0.reverse().forEach(b => {
    gfx.push(`  .byte %${b}`);
  });

  gfx.push(`${textLabel}_1:`);
  bytes1.reverse().forEach(b => {
    gfx.push(`  .byte %${b}`);
  });

  glyph = [];
  glyphBytes = [];
}

glyphs.split(/\r\n|\r|\n/).forEach((line, lineNo) => {
  if (line[0] === '|') {
    title(line, lineNo);
  } else if (line[0] === "!") {
    digit(line, lineNo);
  } else if (line.indexOf("@score") === 0) {
    textLabel = line.split(" ").pop().replace(/:/, "");
    isText = true;
  } else {
    if (isText) {
      generateScoreSub(line, lineNo);
    } else {
      normal(line);
    }
    isText = false;
  }
});

createDiceFunctions();

fs.writeFileSync('build/graphics.asm', gfx.join("\n"));
const LINE_BUFFER_SIZE = 0;

const drawMap0 = [
  `DisplayBufferSize = ${LINE_BUFFER_SIZE}`,
  `drawMap0:`
];
const drawMap1 = [`drawMap1:`];
const drawMap2 = [`drawMap2:`];
const drawMap3 = [`drawMap3:`];
const ram = [];

gfx_names.forEach(textLabel => {
  drawMap0.push(`  .byte <${textLabel}_0`);
  drawMap1.push(`  .byte >${textLabel}_0`);
  drawMap2.push(`  .byte <${textLabel}_1`);
  drawMap3.push(`  .byte >${textLabel}_1`);
});

ram.push(`scores_low:`);
gfx_names.forEach(textLabel => {
  ram.push(`score_low_${textLabel}:  .ds 1`);
});

ram.push(`scores_high:`);
gfx_names.forEach(textLabel => {
  ram.push(`score_high_${textLabel}:  .ds 1`);
});



const newData = []
  .concat(drawMap0)
  .concat(drawMap1)
  .concat(drawMap2)
  .concat(drawMap3)

fs.writeFileSync('build/faces_lookup.asm', newData.join("\n"));
fs.writeFileSync('build/scores.asm', ram.join("\n"));