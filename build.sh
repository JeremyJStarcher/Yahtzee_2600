#!/usr/bin/env bash
#
# This is my (ugly) build script. You'll likely need to adapt it
# (at least set the proper program locations)
function build {
  echo "TESTMODE = ${2}" > build/testmode.asm

  $DASM $1.asm -obuild/$1.bin -sbuild/$1.sym -lbuild/$1.lst -f3
  if [ -e build/$1.bin ] &&  [ `wc -c < build/$1.bin` -eq $ROM_SIZE ]
  then
    $STELLA build/$1.bin
  else
    echo ROM issue
  fi
}

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

#build ${TEST_NAME} 1
#build ${TEST_NAME} 2
#build ${TEST_NAME} 3
build ${TEST_NAME} 5
#build ${NAME}