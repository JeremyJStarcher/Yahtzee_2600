#!/bin/bash
#
# This is my (ugly) build script. You'll likely need to adapt it
# (at least set the proper program locations)

rm -rf build;
mkdir build;

# Program locations
RUBY=ruby
DASM=../bin/dasm-2.20.11-20140304/bin/dasm
STELLA=stella
NAME=yahtzee

# Expected ROM size in bytes
ROM_SIZE=4096

cd ./tools
node digits.js
node scoresheet.js
node dice_faces.js
node labels.js
cd ..

$DASM ${NAME}.asm -obuild/${NAME}.bin -sbuild/${NAME}.sym -lbuild/${NAME}.lst -f3
if [ -e build/${NAME}.bin ] &&  [ `wc -c < build/${NAME}.bin` -eq $ROM_SIZE ]
then
  $STELLA build/${NAME}.bin
else
  echo ROM issue
fi
