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
TEST_NAME=yahtest

# Expected ROM size in bytes
ROM_SIZE=4096

cd ./tools
node digits.js
node scoresheet.js
node dice_faces.js
node labels.js
node testgraphics.js
cd ..

$DASM ${TEST_NAME}.asm -obuild/${TEST_NAME}.bin -sbuild/${TEST_NAME}.sym -lbuild/${TEST_NAME}.lst -f3
if [ -e build/${TEST_NAME}.bin ] &&  [ `wc -c < build/${TEST_NAME}.bin` -eq $ROM_SIZE ]
then
  $STELLA build/${TEST_NAME}.bin
else
  echo ROM issue
fi


$DASM ${NAME}.asm -obuild/${NAME}.bin -sbuild/${NAME}.sym -lbuild/${NAME}.lst -f3
if [ -e build/${NAME}.bin ] &&  [ `wc -c < build/${NAME}.bin` -eq $ROM_SIZE ]
then
  $STELLA build/${NAME}.bin
else
  echo ROM issue
fi

