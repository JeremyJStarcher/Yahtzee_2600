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
  
;===============================================================================
; Digit Graphics
;===============================================================================
        align 256
DigitGfx:
! XXX XXX!
! X X X X!
! X X X X!
! X X X X!
! XXX XXX!
        
!   X   X!
!   X   X!
!   X   X!
!   X   X!
!   X   X!
        
! XXX XXX!
!   X   X!
! XXX XXX!
! X   X  !
! XXX XXX!
        
! XXX XXX!
!   X   X!
!  XX  XX!
!   X   X!
! XXX XXX!
        
! X X X X!
! X X X X!
! XXX XXX!
!   X   X!
!   X   X!
        
! XXX XXX!
! X   X  !
! XXX XXX!
!   X   X!
! XXX XXX!
           
! XXX XXX!
! X   X  !
! XXX XXX!
! X X X X!
! XXX XXX!
        
! XXX XXX!
!   X   X!
!   X   X!
!   X   X!
!   X   X!
        
! XXX XXX!
! X X X X!
! XXX XXX!
! X X X X!
! XXX XXX!
        
! XXX XXX!
! X X X X!
! XXX XXX!
!   X   X!
! XXX XXX!
        
BigDigits:
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
`;

const fs = require('fs');
let glyph = [];
let assembly = [];

function lineToBinary(line, isReverse) {
  const digitZero = isReverse ? "1" : "0";
  const digitOne = isReverse ? "0" : "1";

  const binary = line
    .replace(/\||!/g, "")
    .replace(/ /g, digitZero)
    .replace(/X/g, digitOne);

  const s = `    .BYTE %` + binary;
  glyph.push(s);
}

function title(line) {
  lineToBinary(line, true);
}

function digit(line) {
  lineToBinary(line, true);
}

function normal(line) {
  if (glyph.length) {
    assembly = assembly.concat(glyph.reverse());
  }

  glyph = [];

  assembly.push(line);
}

glyphs.split(/\r\n|\r|\n/).forEach((line) => {
  if (line[0] === '|') {
     title(line);
  } else if (line[0] === "!") {
     digit(line);
  } else {
     normal(line);
  }
});

fs.writeFileSync('build/graphics.asm', assembly.join("\r"));