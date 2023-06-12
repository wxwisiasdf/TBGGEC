#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>
#include <string.h>
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

static void fill_pf_array_1(uint8_t pf[3], uint8_t bmap[20]) {
    /* Reverse order for high nibble */
    pf[0] = (bmap[0] << 4) | (bmap[1] << 5) | (bmap[2] << 6)
        | (bmap[3] << 7);
    
    /**/
    pf[1] = (bmap[4] << 7) | (bmap[5] << 6) | (bmap[6] << 5)
        | (bmap[7] << 4) | (bmap[8] << 3) | (bmap[9] << 2) | (bmap[10] << 1)
        | (bmap[11] << 0);
    
    /**/
    pf[2] = (bmap[12] << 0) | (bmap[13] << 1) | (bmap[14] << 2)
        | (bmap[15] << 3) | (bmap[16] << 4) | (bmap[17] << 5) | (bmap[18] << 6)
        | (bmap[19] << 7);
}

static void fill_pf_array(uint8_t pf[6], uint8_t bmap[40]) {
    fill_pf_array_1(pf + 0, bmap + 0);
    fill_pf_array_1(pf + 3, bmap + 20);
}

static void output_palmap_PF(const char *idname, uint8_t a[], int w, int h) {
    uint8_t pf[h][6];
    uint8_t colupf[h];
    uint8_t colubk[h];
    for(int i = 0; i < h; ++i) {
        /* 160 => 40 pixels processed at once */
        unsigned int offset = i * w;
        uint8_t bmap[40];

        /* Obtain most common items */
        uint8_t times[256];
        memset(times, 0, sizeof times);
        for(int j = 0; j < 256; ++j)
            for(int k = 0; k < w; ++k)
                ++times[a[offset]];
        int pf_index = 0, bk_index = 0;
        for(int j = 0; j < 256; ++j)
            if(times[j] >= times[pf_index])
                pf_index = j;
        for(int j = 0; j < 256; ++j)
            if(times[j] >= times[bk_index] && times[j] < times[pf_index])
                bk_index = j;
        
        colupf[i] = (uint8_t)pf_index;
        colubk[i] = (uint8_t)bk_index;

        for(int j = 0; j < 40; ++j) {
            uint8_t c = a[offset + j + 0] | a[offset + j + 1]
                | a[offset + j + 2] | a[offset + j + 3];
            bmap[j] = c >= 0x08 ? 1 : 0;
            offset += w / 45;
        }
        fill_pf_array(pf[i], bmap);
    }

    for(int i = 0; i < 6; ++i) {
        printf("%sPFA%i: HEX ", idname, i);
        /*for(int j = h - 1; j >= 0; --j)
            printf("%02X", pf[j][i]);*/
        for(int j = 0; j < h; ++j)
            printf("%02X", pf[j][i]);
        printf("\n");
    }
#if 0
    /**/
    printf("%sBKDATA:\n", idname);
    printf("\tHEX ");
    for(int i = h - 1; i >= 0; --i)
        printf("%02X", colubk[i]);
    printf("\n");
    /**/
    printf("%sFGDATA:\n", idname);
    printf("\tHEX ");
    for(int i = h - 1; i >= 0; --i)
        printf("%02X", colupf[i]);
    printf("\n");
#endif
}

static void output_palmap_GRP_1(const char *idname, uint8_t a[], int w, int h, int tx, int ty) {
    printf("%sGRP_TX%i_TY%i: HEX ", idname, tx, ty);
    for(int y = ty * 8 + 8 - 1; y >= ty * 8; --y) {
        int bit = 0, c = 0;
        for(int x = tx * 8 + 8 - 1; x >= tx * 8; --x) {
            c |= (a[y * w + x] ? 1 : 0) << bit;
            ++bit;
            if(bit == 8) {
                printf("%02X", c);
                bit = c = 0;
            }
        }
    }
    printf("\n");
}

static void output_palmap_GRP(const char *idname, uint8_t a[], int w, int h) {
    int wide_w = (w + (8 - 1)) & -8;
    int wide_h = (h + (8 - 1)) & -8;
    uint8_t wide_a[wide_w * wide_h];
    memset(wide_a, 0, wide_w * wide_h);
    for(int y = 0; y < wide_h; ++y)
        for(int x = 0; x < wide_w; ++x)
            wide_a[y * wide_w + x] = a[y * w + x];

    int last_zero = 0;
    int first_zero = wide_w;
    for(int i = 0; i < wide_h; ++i)
        for(int j = 0; j < wide_w; ++j)
            if(a[i * wide_w + j] != 0) {
                if(last_zero < j && j % 8 == 0)
                    last_zero = j;
                else if(first_zero > j && j % 8 == 0)
                    first_zero = j;
            }
    

    printf("; z=%i, l=%i\n", first_zero, last_zero);
    printf("\tALIGN $100\n");
    for(int tx = 0; tx < wide_w / 8; ++tx)
        for(int ty = 0; ty < wide_h / 8; ++ty)
            output_palmap_GRP_1(idname, wide_a, wide_w, wide_h, tx, ty);
    printf("\n");
}

#define STBI_ONLY_PNG 1
#define STB_IMAGE_IMPLEMENTATION 1
#include "stb_image.h"

static void output_image(const char *fname, const char *idname) {
    int w = 0, h = 0, channels = 0;
    const stbi_uc *img = stbi_load(fname, &w, &h, &channels, STBI_rgb);
    printf("; %ix%i (%i channels)\n", w, h, channels);
    assert(channels == STBI_rgb);

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
    output_palmap_GRP(idname, palmap, w, h);
}

int main(int argc, char *argv[]) {
    /*output_image("r01.png", "NA_");
    output_image("r02.png", "SA_");
    output_image("r03.png", "AF_");
    output_image("r04.png", "EU_");*/

    output_image(argv[1], argv[2]);
    return 0;
}
