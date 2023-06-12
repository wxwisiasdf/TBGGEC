#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>
#include <math.h>

#define MAX(x, y) ((x) > (y) ? (x) : (y))
#define MIN(x, y) ((x) < (y) ? (x) : (y))

typedef struct hsl_colour {
    float h;
    float s;
    float l;
} hsl_colour_t;

typedef struct rgb_colour {
    float r;
    float g;
    float b;
} rgb_colour_t;

static hsl_colour_t rgb_to_hsl(rgb_colour_t cs) {
    float max = MAX(cs.r, MAX(cs.g, cs.b)); /* Dis */
    float min = MIN(cs.r, MIN(cs.g, cs.b));
    hsl_colour_t cd;
    cd.l = (max + min) / 2.f;
    if(max == min) {
        cd.h = cd.s = 0.f;
    } else {
        float d = max - min;
        cd.s = cd.l > 0.5f ? d / (2.f - max - min) : d / (max + min);
        if(max == cs.r) {
            cd.h = (cs.g - cs.b) / d + (cs.g < cs.b ? 6.f : 0.f);
        } else if(max == cs.g) {
            cd.h = (cs.b - cs.r) / d + 2.f;
        } else if(max == cs.b) {
            cd.h = (cs.r - cs.g) / d + 4.f;
        }
        cd.h /= 6.f;
    }
    return cd;
}

static hsl_colour_t hsl_normalize_to_ntsc(hsl_colour_t cs) {
    /* HSL values are in range from 0 to 1, the Atari 2600 only allows
       intervals of 16 (from 0 to 255). */
    cs.h = (float)((uint8_t)(cs.h * 16.f));
    cs.l = (float)((uint8_t)(cs.l * 16.f));
    /* Saturation is not taken in account for conversion */
    return cs;
}

static uint8_t hsl_ntsc_to_palette(hsl_colour_t cs) {
    assert(cs.h >= 0.f && cs.h <= 16.f);
    assert(cs.l >= 0.f && cs.l <= 16.f);
    return (((uint8_t)cs.h) << 4) | ((uint8_t)cs.l);
}

uint8_t u8_reverse(uint8_t x) {
    x = (x & 0xF0) >> 4 | (x & 0x0F) << 4;
    x = (x & 0xCC) >> 2 | (x & 0x33) << 2;
    x = (x & 0xAA) >> 1 | (x & 0x55) << 1;
    return x;
}

const char *mem_map[0xFF + 1] = {
    "VSYNC",     /* 00 */
    "VBLANK",    /* 01 */
    "WSYNC",     /* 02 */
    "RSYNC",     /* 03 */
    "NUSIZ0",    /* 04 */
    "NUSIZ1",    /* 05 */
    "COLUP0",    /* 06 */
    "COLUP1",    /* 07 */
    "COLUPF",    /* 08 */
    "COLUBK",    /* 09 */
    "CTRLPF",    /* 0A */
    "REFP0",     /* 0B */
    "REFP1",     /* 0C */
    "PF0",       /* 0D */
    "PF1",       /* 0E */
    "PF2",       /* 0F */
    "RESP0",     /* 10 */
    "RESP1",     /* 11 */
    "RESM0",     /* 12 */
    "RESM1",     /* 13 */
    "RESBL",     /* 14 */
    "AUDC0",     /* 15 */
    "AUDC1",     /* 16 */
    "AUDF0",     /* 17 */
    "AUDF1",     /* 18 */
    "AUDV0",     /* 19 */
    "AUDV1",     /* 1A */
    NULL, /* 1B */
};

static unsigned int gen_reload(uint8_t val, uint8_t last, uint8_t addr) {
    unsigned int cycles = 0;
    if(val == last - 1) {
        printf("\tDEC\t%s\t;5\n", mem_map[addr]);
        cycles += 5;
    } else if(val == last + 1) {
        printf("\tINC\t%s\t;5\n", mem_map[addr]);
        cycles += 5;
    } else if(val != last) {
        printf("\tLDA\t#$%02X\t;2\n", val);
        cycles += 2;
        printf("\tSTA\t%s\t;3\n", mem_map[addr]);
        cycles += 3;
    }
    return cycles;
}

static unsigned int gen_tia_pad(unsigned int cycles, unsigned int pad) {
    /* 76 clocks of the 6502 per scanline */
    if(cycles >= pad) {
        printf("\t;WARNING: Exceeded cycle %u count by %u\n", pad, cycles - pad);
    } else {
        /* 3 clock cycles of TIA passes per 1 clock cycle of the 6502 */
        unsigned int pad_tia = pad * 3;
        unsigned int tia_cycles = (cycles % pad) * 3;
        if(tia_cycles > 0 && (tia_cycles % pad_tia) != 0) {
            unsigned int rem_cycles = pad_tia - (tia_cycles % pad_tia);
#if 0
            for(; rem_cycles != 0; ) {
                if(rem_cycles % 2 == 0) {
                    if(rem_cycles >= 6 * 3) { /* 18 */
                        printf("\tDEC\t$38,X\t;%u+6,INPT0 (rem=%u)\n", cycles, rem_cycles);
                        cycles += 6;
                        rem_cycles -= 6 * 3;
                    } else if(rem_cycles >= 4 * 3) { /* 12 */
                        printf("\tBIT\t$0038\t;%u+4,INPT0 (rem=%u)\n", cycles, rem_cycles);
                        cycles += 4;
                        rem_cycles -= 4 * 3;
                    } else if(rem_cycles >= 2 * 3) { /* 6 */
                        printf("\tCMP\t#00\t;%u+2,INPT0 (rem=%u)\n", cycles, rem_cycles);
                        cycles += 2;
                        rem_cycles -= 2 * 3;
                    } else {
                        abort();
                    }
                } else {
                    if(rem_cycles >= 7 * 3) { /* 21 */
                        printf("\tDEC\t$0038,X\t;%u+7,INPT0 (rem=%u)\n", cycles, rem_cycles);
                        cycles += 7;
                        rem_cycles -= 7 * 3;
                    } else if(rem_cycles >= 5 * 3) { /* 15 */
                        printf("\tDEC\t$38\t;%u+5,INPT0 (rem=%u)\n", cycles, rem_cycles);
                        cycles += 5;
                        rem_cycles -= 5 * 3;
                    } else if(rem_cycles >= 3 * 3) { /* 9 */
                        printf("\tBIT\t$0038\t;%u+3,INPT0 (rem=%u)\n", cycles, rem_cycles);
                        cycles += 3;
                        rem_cycles -= 3 * 3;
                    } else {
                        abort();
                    }
                }
            }
            printf("\t;rem=%u\n", rem_cycles);
#endif
            printf("\tSLEEP %u\n", rem_cycles);
        }
    }
    return cycles;
}

static void output_palmap(uint8_t a[], int w, int h) {
    uint8_t last_colupf = a[0] - 1;
    uint8_t last_colubk = a[0] - 1;
    uint8_t last_pf[3] = { 0, 0, 0 };
/*
  0D      PF0     1111....  playfield register byte 0
  0E      PF1     11111111  playfield register byte 1
  0F      PF2     11111111  playfield register byte 2
*/

    printf("DISPLAY:\n");
    unsigned int cycles;

    /* TODO: Determine "dominant" and "secondary dominant" colours in 20-pixel strip */
    cycles = 0;
    printf("\tVERTICAL_SYNC\n");
    printf("\tTIMER_SETUP 37\n");
    printf("\tTIMER_WAIT\n");
    printf("\tTIMER_SETUP 192\n");
    /**/
    cycles = 0;
    for(int scanline = 0; scanline < h; ++scanline) {
        unsigned int offset = scanline * 160;
        printf("SCANL%03i:\n", scanline);

        /* Do twice, once for left side and another for right one */
        uint8_t colupf = a[offset + 0];
        uint8_t colubk = a[offset + 1];
        cycles += gen_reload(colupf, last_colupf, 0x08); /* Playfield colour */
        last_colupf = colupf;
        cycles += gen_reload(colubk, last_colubk, 0x09); /* Background colour */
        last_colubk = colubk;

        for(int i = 0; i < 2; ++i) {
            unsigned int side_cycles = 0;
            /* 20 pixels processed at once */
            uint8_t bmap[w / 2];
            for(int j = 0; j < w / 2; ++j)
                bmap[j] = a[offset + (i * (w / 2)) + j] == colupf ? 1 : 0;
            uint8_t pf[3];
            /* Reverse order for high nibble */
            pf[0] = (bmap[0] << 4) | (bmap[1] << 5) | (bmap[2] << 6)
                | (bmap[3] << 7);
            side_cycles += gen_reload(pf[0], last_pf[0], 0x0D);
            last_pf[0] = pf[0];
            /**/
            pf[1] = (bmap[4] << 7) | (bmap[5] << 6) | (bmap[6] << 5)
                | (bmap[7] << 4) | (bmap[8] << 3) | (bmap[9] << 2) | (bmap[10] << 1)
                | (bmap[11] << 0);
            side_cycles += gen_reload(pf[1], last_pf[1], 0x0E);
            last_pf[1] = pf[1];
            /**/
            pf[2] = (bmap[12] << 0) | (bmap[13] << 1) | (bmap[14] << 2)
                | (bmap[15] << 3) | (bmap[16] << 4) | (bmap[17] << 5) | (bmap[18] << 6)
                | (bmap[19] << 7);
            side_cycles += gen_reload(pf[2], last_pf[2], 0x0F);
            last_pf[2] = pf[2];

            assert(side_cycles < 76);
            gen_tia_pad(cycles, 76 - side_cycles);
        }
    }
    /*gen_tia_pad(cycles, 76);*/
    /**/
    printf("\tTIMER_WAIT\n");
    printf("\tTIMER_SETUP 29\n");
    printf("\tTIMER_WAIT\n");
    printf("\tJMP\tDISPLAY\t;+3\n");
}

#define STBI_ONLY_PNG 1
#define STB_IMAGE_IMPLEMENTATION 1
#include "stb_image.h"
int main(int argc, char *argv[]) {
    int w = 0, h = 0, channels = 0;
    const stbi_uc *img = stbi_load("map.png", &w, &h, &channels, STBI_rgb);
    printf("; %ix%i (%i channels)\n", w, h, channels);
    assert(channels == STBI_rgb);

    printf("\tPROCESSOR 6502\n");
    printf("\tINCLUDE \"vcs.h\"\n");
    printf("\tINCLUDE \"macro.h\"\n");
    printf("\tINCLUDE \"xmacro.h\"\n");
    printf("\tSEG.U VARIABLES\n");
    printf("\tORG $80\n");
    printf("TEMP .BYTE\n");
    printf("\tSEG CODE\n");
    printf("\tORG $F000\n");
    printf("START:\n");
    printf("\tCLEAN_START\n");

    uint8_t palmap[w * h];
    for(int i = 0; i < w * h; i++) {
        /* Parse from the image */
        rgb_colour_t rc;
        rc.r = (float)img[i * 3 + 0] / 255.f;
        rc.g = (float)img[i * 3 + 1] / 255.f;
        rc.b = (float)img[i * 3 + 2] / 255.f;
        /* Convert to HSL */
        palmap[i] = hsl_ntsc_to_palette(hsl_normalize_to_ntsc(rgb_to_hsl(rc)));
    }
    output_palmap(palmap, w, h);

    printf("\tORG $FFFC\n");
    printf("\t.WORD START ;Restart\n");
    printf("\t.WORD START ;BRK\n");
    return 0;
}
