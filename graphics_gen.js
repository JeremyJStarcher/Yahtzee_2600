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
!     XXXXXX     !
!                !
!     XXXXXX     !
!                !

@score TopBonus:
!     XXX XXXX   !
!  X    X X      !
! XXX XXX XXXX   !
!  X    X    X   !
!     XXX XXXX   !

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
!  XXX  XXX      !
! X    X         !
!  XX   XX       !
!    X    X      !
! XXX  XXX       !

@score LLargeStraight:
! X     XXX      !
! X    X         !
! X     XX       !
! X       X      !
! XXXX XXX       !

@score LFullHouse:
! XXXX X   X     !
! X    X   X     !
! XXX  XXXXX     !
! X    X   X     !
! X    X   X     !

@score LYahtzee:
! X     X  XXX   !
!  X   X  X   X  !
!   XXX   XXXXX  !
!    X    X   X  !
!    X    X   X  !

@score LChance:
!  XXX X   X     !
! X    X   X     !
! X    XXXXX     !
! X    X   X     !
!  XXX X   X     !

@score LYahtzeeBonus:
! X     X XXXX   !
!  X   X  X   X  !
!   XXX   XXXX   !
!    X    X   X  !
!    X    XXXX   !

@score LLowerTotal:
!  X    XXXXX    !
!  X      X      !
!  X      X      !
!  X      X      !
!  XXXXXX X      !

@score LUpperTotal:
!  X    X XXXXX  !
!  X    X   X    !
!  X    X   X    !
!  X    X   X    !
!  XXXXXX   X    !

@score LGrandTotal:
! XXXXXX XXXXX   !
! X        X     !
! X  XXX   X     !
! X    X   X     !
! XXXXXX   X     !

`;

const fs = require('fs');
let glyph = [];
let gfx = [];
let code = [];
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
  gfx = gfx.concat(glyph.reverse());
  gfx.push(line);

  glyph = [];
  glyphBytes = [];
}

function generateScoreSub(line, lineNo) {

  const c = `
show_${textLabel}:
  lda #<${textLabel}_0
  sta DrawSymbolsMap+0
  lda #>${textLabel}_0
  sta DrawSymbolsMap+1

  lda #<${textLabel}_1
  sta DrawSymbolsMap+2
  lda #>${textLabel}_1
  sta DrawSymbolsMap+3
  rts
  `;
  code = code.concat(c);

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

fs.writeFileSync('build/graphics.asm', gfx.join("\n"));
fs.writeFileSync('build/graphics_code.asm', code.join("\n"));