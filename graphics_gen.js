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

TopBonus:
!      XXX  XXXX !
!  X     X  X    !
! XXX  XXX  XXXX !
!  X     X     X !
!      XXX  XXXX !


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
let glyphId = 0;

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

  const s = `    .BYTE %${binary}   ; ${binary.length} - ${line.length}`;
  glyph.push(s);
}

function title(line, lineNo) {
  lineToBinary(line, lineNo, false);
}

function digit(line, lineNo) {
  lineToBinary(line, lineNo, true);
}

function normal(line) {
  if (glyph.length) {
    glyphId++;
  }

  assembly = assembly.concat(glyph.reverse());
  assembly.push(line);

  glyph = [];
}

glyphs.split(/\r\n|\r|\n/).forEach((line, lineNo) => {
  if (line[0] === '|') {
     title(line, lineNo);
  } else if (line[0] === "!") {
     digit(line, lineNo);
  } else {
     normal(line);
  }
});

fs.writeFileSync('build/graphics.asm', assembly.join("\n"));