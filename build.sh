#!/bin/sh
clang -Wall -Wextra -g -O1 bmp2asm.c -o bmp2asm -lm || exit
# ./bmp2asm EU0.png EUR_ >map.asm
# ./bmp2asm EU1.png IBE_ >>map.asm
# ./bmp2asm EU2.png FRA_ >>map.asm
# ./bmp2asm EU3.png ITA_ >>map.asm
# ./bmp2asm EU4.png GER_ >>map.asm
# ./bmp2asm EU5.png NOR_ >>map.asm
# #New
# ./bmp2asm EU6.png ENG_ >>map.asm
# ./bmp2asm EU7.png TUR_ >>map.asm
# #
# ./bmp2asm EU8.png BAL_ >>map.asm
# ./bmp2asm EU9.png POL_ >>map.asm
# ./bmp2asm EUA.png NET_ >>map.asm
# ./bmp2asm EUB.png AUS_ >>map.asm
# ./bmp2asm EUC.png ROM_ >>map.asm
# ./bmp2asm EUD.png UKR_ >>map.asm
# ./bmp2asm EUE.png RUS_ >>map.asm
# ./bmp2asm EUF.png FIN_ >>map.asm
./bmp2asm font.png FONT_ >>map.asm
