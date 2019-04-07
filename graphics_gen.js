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

L1s:
!   XX    XXX    !
! XXXX   X       !
!   XX    XX     !
!   XX      X    !
! XXXXXX XXX     !

L2s:
! XXXXXX  XXX    !
!     XX X       !
! XXXXXX  XX     !
! XX        X    !
! XXXXXX XXX     !

L3s:
! XXXXXX  XXX    !
!     XX X       !
!   XXXX  XX     !
!     XX    X    !
! XXXXXX XXX     !

L4s:
! XX  XX  XXX    !
! XX  XX X       !
! XXXXXX  XX     !
!     XX    X    !
!     XX XXX     !

L5s:
! XXXXXX  XXX    !
! XX     X       !
! XXXXXX  XX     !
!     XX    X    !
! XXXXXX XXX     !

L6s:
! XXXXXX  XXX    !
! XX     X       !
! XXXXXX  XX     !
! XX  XX    X    !
! XXXXXX XXX     !

TopSubtotal:
!                !
!     XXXXXX     !
!                !
!     XXXXXX     !
!                !

@score TopBonus:
!      XXX  XXXX !
!  X     X  X    !
! XXX  XXX  XXXX !
!  X     X     X !
!XXXXXXXXX  XXXX !


L3k:
! XXXXXX X  X    !
!     XX X X     !
!   XXXX XX      !
!     XX X X     !
! XXXXXX X  X    !

L4k:
! XX  XX X  X    !
! XX  XX X X     !
! XXXXXX XX      !
!     XX X X     !
!     XX X  X    !

LSmallStraight:
!  XXX    XXX    !
! X      X       !
!  XX     XX     !
!    X      X    !
! XXX    XXX     !

LLargeStraight:
! X       XXX    !
! X      X       !
! X       XX     !
! X         X    !
! XXXX   XXX     !

LFullHouse:
! XXXX    XXX    !
! X      X       !
! XX      XX     !
! X         X    !
! X      XXX     !

LYahtzee:
! X     X   XXX  !
!  X   X   X   X !
!   XXX    XXXXX !
!    X     X   X !
!    X     X   X !

LChance:
! XXXX   XXX     !
! X     X   X    !
! X     XXXXX    !
! X     X   X    !
! XXXX  X   X    !

LYahtzeeBonus:
! X     X  XXXX  !
!  X   X   X   X !
!   XXX    XXXX  !
!    X     X   X !
!    X     XXXX  !

LLowerTotal:
!  X       XXXXX !
!  X         X   !
!  X         X   !
!  X         X   !
!  XXXXXX    X   !

LUpperTotal:
!  X    X  XXXXX !
!  X    X    X   !
!  X    X    X   !
!  X    X    X   !
!  XXXXXX    X   !

LGrandTotal:
!  XXXXXX  XXXXX !
!  X         X   !
!  X  XXX    X   !
!  X    X    X   !
!  XXXXXX    X   !

`;

const fs = require('fs');
let glyph = [];
let assembly = [];
let glyphBytes = [];
let isText = false;
let textLabel = "-none-set";

function lineToBinary(line, lineNo, isReverse) {
  const digitZero = isReverse ? "0" : "1";
  const digitOne = isReverse ? "1" : "0";

  const binary = line
    .replace(/\||!/g, "")
    .replace(/ /g, digitZero)
    .replace(/X/g, digitOne);

  if (binary.length !== 8 && binary.length !== 16) {
    throw new Error(`Length of line is off on ine ${lineNo}: ${line}`);
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
  assembly = assembly.concat(glyph.reverse());
  assembly.push(line);

  glyph = [];
  glyphBytes = [];
}

function generateScoreSub(line, lineNo) {
  assembly.push(`show_${textLabel}:`);

  const code = `
    lda #_BYTE1_
    sta GRP0
    sta WSYNC
    lda #_BYTE2_
    sta GRP1
    nop
    nop
    lda (DigitBmpPtr+4),y
    sta GRP0
    lda (DigitBmpPtr+6),y
    sta TempDigitBmp
    lda (DigitBmpPtr+8),y
    tax
    lda (DigitBmpPtr+10),y
    tay
    lda TempDigitBmp
    sta GRP1
    stx GRP0
    sty GRP1
    sta GRP0
  `;

  const lines = 5;
  const count = lines * 2; // Two bytes per line
  let yreg = lines;

  for (let i = 0; i < lines; i++) {
    var b1 = '%' + glyphBytes[i][0];
    var b2 = '%' + glyphBytes[i][1];

    const s = code
      .replace("_BYTE1_", b1)
      .replace("_BYTE2_", b2)

    yreg--;
    assembly.push(`  ldy #${yreg}`);
    assembly = assembly.concat(s);
  }

  assembly.push(`  rts`);
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

fs.writeFileSync('build/graphics.asm', assembly.join("\n"));