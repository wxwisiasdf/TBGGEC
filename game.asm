	PROCESSOR 6502
	INCLUDE "vcs.h"
	INCLUDE "macro.h"
	INCLUDE "xmacro.h"

	SEG.U VARIABLES
	ORG $80

TMP1:
	.BYTE 0
TMP2_BLANKET_SIZE:
	.BYTE 0
TMP2:
	.BYTE 0
TMP3_BLANKET_Y:
	.BYTE 0
TMP3:
	.BYTE 0
TMP4_LOOP_COUNT:
	.BYTE 0
TMP5_BCD_TEMP:
	.BYTE 0
SELECTED_COUNTRY:
	.BYTE 0
OWNED_COUNTRIES:
	.BYTE 0
AI_TIMER:
	.BYTE 0
AI_SEED:
	.BYTE 0
COUNTRY_PFLST:
COUNTRY_PFA0:
	.WORD EUR_PFA0
COUNTRY_PFA1:
	.WORD EUR_PFA1
COUNTRY_PFA2:
	.WORD EUR_PFA2
COUNTRY_PFA3:
	.WORD EUR_PFA3
COUNTRY_PFA4:
	.WORD EUR_PFA4
COUNTRY_PFA5:
	.WORD EUR_PFA5

MONEY_BCD:
	.BYTE 0
	.BYTE 0
	.BYTE 0
	.BYTE 0
	.BYTE 0
MONEY_DPTR:
	.WORD 0
	.WORD 0
	.WORD 0
	.WORD 0
	.WORD 0
	.WORD 0
	.WORD 0
	.WORD 0

SAVE_COUNTRY_COLOURS:
	;Data here

	SEG CODE
	ORG $f000
START:
	CLEAN_START
	;
	LDY #07
.COPY_COLOURS:
	TYA
	ASL ;Multiply by 16
	ASL
	ASL
	ASL
	TAX
	LDA EUR_COLOURS,X
	STA SAVE_COUNTRY_COLOURS,Y
	DEY
	BNE .COPY_COLOURS
	;
	LDA #69
	STA AI_SEED
	;
	LDA #01
	STA OWNED_COUNTRIES
	STA SELECTED_COUNTRY
	STA AI_TIMER
	;
	VERTICAL_SYNC
	TIMER_SETUP 37
	JMP .UPDATE_SELECTED_COUNTRY
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ATLAS_DRAW:
	VERTICAL_SYNC
	TIMER_SETUP 37
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Input handling
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	LDA #%10000000 ;Button
	BIT INPT4
	BNE .INPUT_SKIP_BUTTON
	;
	LDX SELECTED_COUNTRY ;Player is Spain
	LDA SAVE_COUNTRY_COLOURS,X
	CMP #$FF ;FF->Colour of Spain
	BEQ .INPUT_SKIP_BUTTON ;Can't buy itself! (or already bought countries)
	;
	LDA #00
	CMP MONEY_BCD+2
	BNE .SUBTRACT_MONEY ;Early kludge
	;
	LDA MONEY_BCD+1 ;Only if cash >=100
	SBC OWNED_COUNTRIES
	BMI .INPUT_SKIP_BUTTON ;Zero=No action possible
.SUBTRACT_MONEY:
	LDA OWNED_COUNTRIES ;Add +100 per each owned country (to make it fair)
	TAX
	LDA #00
	LDY #00
	JSR SUB_MONEY
	;
	LDX SELECTED_COUNTRY
	LDA SAVE_COUNTRY_COLOURS+1
	STA SAVE_COUNTRY_COLOURS,X
	;
	LDY OWNED_COUNTRIES
	INY
	STY OWNED_COUNTRIES
	CPY #99
	BNE .INPUT_SKIP_BUTTON
	LDY #80
	STY OWNED_COUNTRIES
.INPUT_SKIP_BUTTON:
	LDA #%00010000 ;Up
	BIT SWCHA
	BNE .INPUT_SKIP_UP
.INPUT_SKIP_UP:
	LDA #%00100000 ;Down
	BIT SWCHA
	BNE .INPUT_SKIP_DOWN
.INPUT_SKIP_DOWN:
	LDA #%01000000 ;Left
	BIT SWCHA
	BNE .INPUT_SKIP_LEFT
	;
	DEC SELECTED_COUNTRY ;Previous selected country, if underflow, clamp
	JMP .UPDATE_SELECTED_COUNTRY
.INPUT_SKIP_LEFT:
	LDA #%10000000 ;Right
	BIT SWCHA
	BNE .INPUT_SKIP_RIGHT
	;
	INC SELECTED_COUNTRY ;Previous selected country, if >8, clamp
.UPDATE_SELECTED_COUNTRY: ; Set selected country
	;Each "country area" is around $400 bytes long, this allows us
	;to simply add +04 to the highest nibble instead of doing magic shit
	LDA SELECTED_COUNTRY
	AND #$0F
	STA SELECTED_COUNTRY
	ASL ;Multiply by 16
	ASL
	ASL
	ASL
	TAY
	LDX #00
.COPY_PFLST:
	LDA EUR_PFLST,Y
	STA COUNTRY_PFLST,X
	INY
	INX
	CPX #12
	BNE .COPY_PFLST
.INPUT_SKIP_RIGHT:
	;
	LDA #$BF
	STA COLUP0
	LDA #$BF
	STA COLUP1
	LDA #3
	STA NUSIZ0
	STA NUSIZ1
	STA WSYNC
	SLEEP 26
	STA RESP0
	STA RESP1
	LDA #$10
	STA HMP1
	STA WSYNC
	STA HMOVE
	SLEEP 24
	STA HMCLR
	LDA #01
	STA VDELP0
	STA VDELP1
	;
	LDA #%00010100
	STA CTRLPF
	LDA #$00
	STA COLUBK
	STA COLUPF
	STA PF0
	STA PF1
	STA PF2
	;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Draw blanket section
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.COUNTRY_MAP:
	LDA SELECTED_COUNTRY
	ASL ;Multiply by 16
	ASL
	ASL
	ASL
	TAY
	LDA EUR_BLANKET,Y
	STA TMP2_BLANKET_SIZE
	LDA EUR_BLANKET+1,Y
	STA TMP3_BLANKET_Y
	ADC TMP2_BLANKET_SIZE
	STA TMP1 ;X=Y+Size
	;
	LDY #$00
	TIMER_WAIT
	STA WSYNC
	LDA #$80
	STA COLUBK
	LDA #$B4
	STA COLUPF
.LOOP1:
	STA WSYNC
	LDA EUR_PFA0,Y
	STA PF0
	LDA EUR_PFA1,Y
	STA PF1
	LDA EUR_PFA2,Y
	STA PF2
	SLEEP 6
	LDA EUR_PFA3,Y
	STA PF0
	LDA EUR_PFA4,Y
	STA PF1
	LDA EUR_PFA5,Y
	STA PF2
	INY
	CPY TMP3_BLANKET_Y
	BNE .LOOP1
	;
	STA WSYNC
	LDA #$08
	STA COLUBK
	LDX SELECTED_COUNTRY
	LDA SAVE_COUNTRY_COLOURS,X
	STA COLUPF
	LDY #00
.LOOP2:
	STA WSYNC
	LDA (COUNTRY_PFA0),Y
	STA PF0
	LDA (COUNTRY_PFA1),Y
	STA PF1
	LDA (COUNTRY_PFA2),Y
	STA PF2
	LDA (COUNTRY_PFA3),Y
	STA PF0
	LDA (COUNTRY_PFA4),Y
	STA PF1
	LDA (COUNTRY_PFA5),Y
	STA PF2
	INY
	CPY TMP2_BLANKET_SIZE
	BNE .LOOP2
	;
	STA WSYNC
	LDA #$80
	STA COLUBK
	LDA #$B4
	STA COLUPF
	LDY TMP1
	INY
	INY
.LOOP3:
	STA WSYNC
	LDA EUR_PFA0,Y
	STA PF0
	LDA EUR_PFA1,Y
	STA PF1
	LDA EUR_PFA2,Y
	STA PF2
	SLEEP 6
	LDA EUR_PFA3,Y
	STA PF0
	LDA EUR_PFA4,Y
	STA PF1
	LDA EUR_PFA5,Y
	STA PF2
	INY
	CPY #160
	BNE .LOOP3
	JSR DRAW_STATUS_LEDGE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	TIMER_SETUP 29
	TIMER_WAIT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Europe map frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.EU_MAP:
	VERTICAL_SYNC
	TIMER_SETUP 37
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; AI does stuff(tm)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	INC AI_TIMER
	LDA AI_TIMER
	CMP #$FF ;(256/60)=4.9 seconds per action
	BNE .SKIP_AI_MOVE
	LDA MONEY_BCD ;Country to act as
	ADC AI_SEED
	STA AI_SEED
	AND #7
	TAX
	LDA SAVE_COUNTRY_COLOURS,X
	CMP #00 ;Liberation
	BEQ .AI_LIBERATION
	LDA MONEY_BCD ;Country to "caupture"
	ADC AI_SEED
	STA AI_SEED
	AND #7
	TAX
	STA SAVE_COUNTRY_COLOURS,X
	JMP .SKIP_AI_MOVE
.AI_LIBERATION:
	LDA MONEY_BCD ;Country to "liberate"
	ADC AI_SEED
	STA AI_SEED
	AND #7
	TAY
	ASL ;Multiply by 16
	ASL
	ASL
	ASL
	TAX
	LDA EUR_COLOURS,X
	STA SAVE_COUNTRY_COLOURS,Y
.SKIP_AI_MOVE:
	LDA OWNED_COUNTRIES
	LDX #0
	LDY #0
	JSR ADD_MONEY
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	LDA #%00010100
	STA CTRLPF
	LDA #$00
	STA COLUBK
	STA COLUPF
	STA PF0
	STA PF1
	STA PF2
	TIMER_WAIT
	STA WSYNC
	LDA #$80
	STA COLUBK
	LDA #$B4
	STA COLUPF
.LOOP4:
	STA WSYNC
	LDA EUR_PFA0,Y
	STA PF0
	LDA EUR_PFA1,Y
	STA PF1
	LDA EUR_PFA2,Y
	STA PF2
	SLEEP 6
	LDA EUR_PFA3,Y
	STA PF0
	LDA EUR_PFA4,Y
	STA PF1
	LDA EUR_PFA5,Y
	STA PF2
	INY
	CPY #160
	BNE .LOOP4
	JSR DRAW_STATUS_LEDGE
	TIMER_SETUP 29
	TIMER_WAIT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	JMP ATLAS_DRAW
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Status bar
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DRAW_STATUS_LEDGE:
	LDA SELECTED_COUNTRY
	ASL ;Multiply by 8
	ASL
	ASL
	STA TMP1
	;
	STA WSYNC
	LDA #$FF
	STA PF0
	STA PF1
	STA PF2
	LDX #$F5
	STX COLUPF
	STA WSYNC
	INX
	STX COLUPF
	STA WSYNC
	INX
	STX COLUPF
	STA WSYNC
	DEX
	STX COLUPF
	;
	STA WSYNC
	LDA #00
	STA COLUPF
	STA WSYNC
	LDA #05
	STA COLUPF
	;
	LDY #$00
	LDX TMP1
.LOOP_FLAG_BAND:
	STA WSYNC
	LDA EUR_FLAG_COLOURS,X
	STA COLUPF
	INY
	INX
	CPY #$08
	BNE .LOOP_FLAG_BAND
	;
	STA WSYNC
	LDA #00
	STA COLUPF
	;
DRAW_STATUS_BAR:
	STA WSYNC
	LDA #%00000000
	STA CTRLPF
	LDA #$30
	STA COLUBK
	LDA #$40
	STA COLUPF
	LDX #00
	STX PF0
	STX PF1
	STX PF2
	LDY #32-20
.DRAW_STATUS_BAR_LOOP:
	STA WSYNC
	CPY #9
	BEQ .DRAW_STATUS_ICONS
	DEY
	BNE .DRAW_STATUS_BAR_LOOP
.DRAW_STATUS_ICONS:
	LDA #$44
	STA COLUBK
	;
	STA WSYNC
	LDA #$00
	STA COLUBK
	STA WSYNC
	LDA #$60
	STA COLUBK
	;
	LDX #0
	LDY #2
.LOOP:
	LDA MONEY_BCD,Y
	AND #$F0
	LSR
	STA MONEY_DPTR,X
	LDA #>FONT_TABLE
	STA MONEY_DPTR+1,X
	INX
	INX
	LDA MONEY_BCD,Y
	AND #$0F
	ASL
	ASL
	ASL
	STA MONEY_DPTR,X
	LDA #>FONT_TABLE
	STA MONEY_DPTR+1,X
	INX
	INX
	DEY
	BPL .LOOP
	;
	STA WSYNC
	SLEEP 40
	LDA #7
	STA TMP4_LOOP_COUNT
.STATUS_ICONS:
	LDY TMP4_LOOP_COUNT
	LDA (MONEY_DPTR),Y
	STA GRP0
	LDA (MONEY_DPTR+2),Y
	STA GRP1
	STA WSYNC
	LDA (MONEY_DPTR+4),Y
	STA GRP0
	LDA (MONEY_DPTR+10),Y
	STA TMP5_BCD_TEMP
	LDA (MONEY_DPTR+8),Y
	TAX
	LDA (MONEY_DPTR+6),Y
	LDY TMP5_BCD_TEMP
	STA GRP1
	STX GRP0
	STY GRP1
	STA GRP0
	DEC TMP4_LOOP_COUNT
	BPL .STATUS_ICONS
	LDA #$00
	STA GRP0
	STA GRP1
	STA GRP0
	STA GRP1
	;
	STA WSYNC
	LDA #$00
	STA COLUBK
	;
	LDX #$0A
.GRAY_GRADIENT:
	STA WSYNC
	STX COLUBK
	DEX
	BNE .GRAY_GRADIENT
	;
	RTS

ADD_MONEY: SUBROUTINE
	SED
	CLC
	STA TMP5_BCD_TEMP
	ADC MONEY_BCD
	STA MONEY_BCD
	STX TMP5_BCD_TEMP
	LDA MONEY_BCD+1
	ADC TMP5_BCD_TEMP
	STA MONEY_BCD+1
	STY TMP5_BCD_TEMP
	LDA MONEY_BCD+2
	ADC TMP5_BCD_TEMP
	STA MONEY_BCD+2
	LDA MONEY_BCD+3
	ADC TMP5_BCD_TEMP
	STA MONEY_BCD+3
	CLD
	CLC
	RTS
SUB_MONEY: SUBROUTINE
	SED
	CLC
	STA TMP5_BCD_TEMP
	SBC MONEY_BCD
	STA MONEY_BCD
	STX TMP5_BCD_TEMP
	LDA MONEY_BCD+1
	SBC TMP5_BCD_TEMP
	STA MONEY_BCD+1
	STY TMP5_BCD_TEMP
	LDA MONEY_BCD+2
	SBC TMP5_BCD_TEMP
	STA MONEY_BCD+2
	LDA MONEY_BCD+3
	SBC TMP5_BCD_TEMP
	STA MONEY_BCD+3
	CLD
	RTS

EURO_SIGN:
	.BYTE #%00001110
	.BYTE #%00011001
	.BYTE #%00010000
	.BYTE #%00010000
	.BYTE #%11111110
	.BYTE #%00100000
	.BYTE #%01110011
	.BYTE #%10111101

; 8x80 (3 channels)
; z=0, l=0
	ALIGN $100
FONT_TABLE:
FONT_GRP_TX0_TY0: HEX FF83858991A1C1FF
FONT_GRP_TX0_TY1: HEX FF18181818187818
FONT_GRP_TX0_TY2: HEX FFC038040241433E
FONT_GRP_TX0_TY3: HEX 38C6021E44423E00
FONT_GRP_TX0_TY4: HEX 0404047C44243410
FONT_GRP_TX0_TY5: HEX 386C46027E407E00
FONT_GRP_TX0_TY6: HEX 1E2272727E101C00
FONT_GRP_TX0_TY7: HEX 404020107E0406FF
FONT_GRP_TX0_TY8: HEX 186444643C24243C
FONT_GRP_TX0_TY9: HEX 187C041E3222261C

EUR_FLAG_COLOURS:
	.BYTE $00
	.BYTE $00
	.BYTE $00
	.BYTE $00
	.BYTE $00
	.BYTE $00
	.BYTE $00
	.BYTE $00
SPA_FLAG_COLOURS:
	.BYTE $40
	.BYTE $40
	.BYTE $FF
	.BYTE $FF
	.BYTE $FF
	.BYTE $FF
	.BYTE $40
	.BYTE $40
FRA_FLAG_COLOURS:
	.BYTE $A0
	.BYTE $A0
	.BYTE $0F
	.BYTE $0F
	.BYTE $0F
	.BYTE $0F
	.BYTE $40
	.BYTE $40
ITA_FLAG_COLOURS:
	.BYTE $B0
	.BYTE $B0
	.BYTE $0F
	.BYTE $0F
	.BYTE $0F
	.BYTE $0F
	.BYTE $40
	.BYTE $40
GER_FLAG_COLOURS:
	.BYTE $00
	.BYTE $00
	.BYTE $00
	.BYTE $40
	.BYTE $40
	.BYTE $FF
	.BYTE $FF
	.BYTE $FF
NOR_FLAG_COLOURS:
	.BYTE $A8
	.BYTE $A8
	.BYTE $A8
	.BYTE $00
	.BYTE $00
	.BYTE $00
	.BYTE $0F
	.BYTE $0F
ENG_FLAG_COLOURS:
	.BYTE $0F
	.BYTE $0F
	.BYTE $0F
	.BYTE $40
	.BYTE $40
	.BYTE $40
	.BYTE $0F
	.BYTE $0F
TUR_FLAG_COLOURS:
	.BYTE $40
	.BYTE $40
	.BYTE $40
	.BYTE $40
	.BYTE $40
	.BYTE $40
	.BYTE $40
	.BYTE $40
BAL_FLAG_COLOURS:
	.BYTE $FA
	.BYTE $FA
	.BYTE $FA
	.BYTE $B8
	.BYTE $B8
	.BYTE $B8
	.BYTE $40
	.BYTE $40
POL_FLAG_COLOURS:
	.BYTE $0F
	.BYTE $0F
	.BYTE $0F
	.BYTE $0F
	.BYTE $40
	.BYTE $40
	.BYTE $40
	.BYTE $40
NET_FLAG_COLOURS:
	.BYTE $A0
	.BYTE $A0
	.BYTE $A0
	.BYTE $0F
	.BYTE $0F
	.BYTE $40
	.BYTE $40
	.BYTE $40
AUS_FLAG_COLOURS:
	.BYTE $00
	.BYTE $00
	.BYTE $00
	.BYTE $00
	.BYTE $F8
	.BYTE $F8
	.BYTE $F8
	.BYTE $F8
ROM_FLAG_COLOURS:
	.BYTE $A0
	.BYTE $A0
	.BYTE $A0
	.BYTE $F8
	.BYTE $F8
	.BYTE $40
	.BYTE $40
	.BYTE $40
UKR_FLAG_COLOURS:
	.BYTE $90
	.BYTE $90
	.BYTE $90
	.BYTE $90
	.BYTE $F8
	.BYTE $F8
	.BYTE $F8
	.BYTE $F8
RUS_FLAG_COLOURS:
	.BYTE $00
	.BYTE $00
	.BYTE $00
	.BYTE $FD
	.BYTE $FD
	.BYTE $FD
	.BYTE $0F
	.BYTE $0F
FIN_FLAG_COLOURS:
	.BYTE $0F
	.BYTE $0F
	.BYTE $0F
	.BYTE $A0
	.BYTE $0F
	.BYTE $0F
	.BYTE $0F
	.BYTE $0F

EUR_PFLST:
	.WORD EUR_PFA0
	.WORD EUR_PFA1
	.WORD EUR_PFA2
	.WORD EUR_PFA3
	.WORD EUR_PFA4
	.WORD EUR_PFA5
EUR_BLANKET:
	.BYTE #1	;Size
	.BYTE #1	;Y
EUR_COLOURS:
	.BYTE $00 ;Europe
	.BYTE $00
IBE_PFLST:
	.WORD IBE_PFA0
	.WORD IBE_PFA1
	.WORD IBE_PFA2
	.WORD IBE_PFA3
	.WORD IBE_PFA4
	.WORD IBE_PFA5
	.BYTE #30	;Size
	.BYTE #123+1	;Y
	.BYTE $FF ;Colour
	.BYTE $00
FRA_PFLST:
	.WORD FRA_PFA0
	.WORD FRA_PFA1
	.WORD FRA_PFA2
	.WORD FRA_PFA3
	.WORD FRA_PFA4
	.WORD FRA_PFA5
	.BYTE #33	;Size
	.BYTE #94+1	;Y
	.BYTE $A0 ;Colour
	.BYTE $00
ITA_PFLST:
	.WORD ITA_PFA0
	.WORD ITA_PFA1
	.WORD ITA_PFA2
	.WORD ITA_PFA3
	.WORD ITA_PFA4
	.WORD ITA_PFA5
	.BYTE #44	;Size
	.BYTE #106+1	;Y
	.BYTE $B0 ;Colour
	.BYTE $00
GER_PFLST:
	.WORD GER_PFA0
	.WORD GER_PFA1
	.WORD GER_PFA2
	.WORD GER_PFA3
	.WORD GER_PFA4
	.WORD GER_PFA5
	.BYTE #43	;Size
	.BYTE #70+1	;Y
	.BYTE $00 ;Colour
	.BYTE $00
NOR_PFLST:
	.WORD NOR_PFA0
	.WORD NOR_PFA1
	.WORD NOR_PFA2
	.WORD NOR_PFA3
	.WORD NOR_PFA4
	.WORD NOR_PFA5
	.BYTE #63	;Size
	.BYTE #0+1	;Y
	.BYTE $AF	;Colour
	.BYTE $00
ENG_PFLST:
	.WORD ENG_PFA0
	.WORD ENG_PFA1
	.WORD ENG_PFA2
	.WORD ENG_PFA3
	.WORD ENG_PFA4
	.WORD ENG_PFA5
	.BYTE #40	;Size
	.BYTE #57	;Y
	.BYTE $48	;Colour
	.BYTE $00
TUR_PFLST:
	.WORD TUR_PFA0
	.WORD TUR_PFA1
	.WORD TUR_PFA2
	.WORD TUR_PFA3
	.WORD TUR_PFA4
	.WORD TUR_PFA5
	.BYTE #31	;Size
	.BYTE #117+1	;Y
	.BYTE $40	;Colour
	.BYTE $00
BAL_PFLST:
	.WORD BAL_PFA0
	.WORD BAL_PFA1
	.WORD BAL_PFA2
	.WORD BAL_PFA3
	.WORD BAL_PFA4
	.WORD BAL_PFA5
	.BYTE #28	;Size
	.BYTE #52	;Y
	.BYTE $B8	;Colour
	.BYTE $00
POL_PFLST:
	.WORD POL_PFA0
	.WORD POL_PFA1
	.WORD POL_PFA2
	.WORD POL_PFA3
	.WORD POL_PFA4
	.WORD POL_PFA5
	.BYTE #26	;Size
	.BYTE #71+1	;Y
	.BYTE $4D	;Colour
	.BYTE $00
NET_PFLST:
	.WORD NET_PFA0
	.WORD NET_PFA1
	.WORD NET_PFA2
	.WORD NET_PFA3
	.WORD NET_PFA4
	.WORD NET_PFA5
	.BYTE #15	;Size
	.BYTE #82	;Y
	.BYTE $3D	;Colour
	.BYTE $00
AUS_PFLST:
	.WORD AUS_PFA0
	.WORD AUS_PFA1
	.WORD AUS_PFA2
	.WORD AUS_PFA3
	.WORD AUS_PFA4
	.WORD AUS_PFA5
	.BYTE #35	;Size
	.BYTE #91	;Y
	.BYTE $0F	;Colour
	.BYTE $00
ROM_PFLST:
	.WORD ROM_PFA0
	.WORD ROM_PFA1
	.WORD ROM_PFA2
	.WORD ROM_PFA3
	.WORD ROM_PFA4
	.WORD ROM_PFA5
	.BYTE #22	;Size
	.BYTE #104	;Y
	.BYTE $F8	;Colour
	.BYTE $00
UKR_PFLST:
	.WORD UKR_PFA0
	.WORD UKR_PFA1
	.WORD UKR_PFA2
	.WORD UKR_PFA3
	.WORD UKR_PFA4
	.WORD UKR_PFA5
	.BYTE #42	;Size
	.BYTE #71	;Y
	.BYTE $FD	;Colour
	.BYTE $00
RUS_PFLST:
	.WORD RUS_PFA0
	.WORD RUS_PFA1
	.WORD RUS_PFA2
	.WORD RUS_PFA3
	.WORD RUS_PFA4
	.WORD RUS_PFA5
	.BYTE #38	;Size
	.BYTE #38	;Y
	.BYTE $5D	;Colour
	.BYTE $00
FIN_PFLST:
	.WORD FIN_PFA0
	.WORD FIN_PFA1
	.WORD FIN_PFA2
	.WORD FIN_PFA3
	.WORD FIN_PFA4
	.WORD FIN_PFA5
	.BYTE #48	;Size
	.BYTE #3	;Y
	.BYTE $0F
	.BYTE $00

; 160x160 (3 channels)
EUR_PFA0: HEX 0000000000400000000000000000000000000000000000000000000000000000000000000000000000000000C0000000000000000000000000000000808080C080C00000800000800040E0E0C0F0F0F0F0F0E0F0F0F0F070300000000000000000000000000000000000000000000000000000000000000000000060E0E0E0E0E0E0C0E060E0E0E0E0E0E0E0E0E0E0F0E0E0E0E0E0E0E0808080808000000080
EUR_PFA1: HEX 000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000081818000000202020E0E0C0C0F0F0F0F0F0E0E0E0F0F0F0F0F0B07878383C7C7C7C7E7E7EFEFE7E7E7F7FFFC3830307171F1F3F7F7F7F3F3F1F1F1F1F1F1F0F0F0F0F0F0F0F0F0F0F9FEFFFFEFFFFFFFFFFFFFFFEFCFCFCFCFCF9F9F9FAFCFCF8F8F8F8F0F0F0818307878F8F
EUR_PFA2: HEX 0000000000000000000000000000000000000000000000000000000000808080008080C0C0C0E0F0F0F0F8F8FCFEFEFEFEFEFAFEFEFEFCFEFEFEFCBC9C9C9C8080E0E070F07070B0F0F0F0F0F030F0F0F0F0FCFEFEFEFEFEFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFCFCFC7E0C0F0B0B0302000203030303031313030100000000000002020FC7F7F7F7F7F7F
EUR_PFA3: HEX 0000000000000000000000000080C0C0E0E0E0D0D0C0C0E0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0E0F0F0F0F0F0F0F0F0F0703030301040008090F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0D0E0F0F0F0F0F0F0F0F0F0F0E0E0C0C0C0C0D090903030303030F0F0F0F0E0E0C0C0C080808080808080C070707070606000000000000000
EUR_PFA4: HEX 00010307070F1F1F7F7F7F7FFFFFFFFFFFFFFFFFFFFFFFFFFFF9F9F9F3F3F3F3F7F7FFEFEFCFDFDF9F9F9F8F8F9F1F1F1E9CACC3C3C7CFCF8F8B0B0B434F5F5F5F1F1F1F1F1F1F1F1F3FFFFFFFFFFBFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFDFFFFFFFFFFFFEF9FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFB7F7F7F3F3F3F3E3EBEBDF8787D3C1E1F1C1E1E1E1C0D0C0C04000000070703000000
EUR_PFA5: HEX 1E0F2FF7FFFFFFFFFEF9FFFFFFFFFF3F7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7FFFFFFFEFCFCFEFEFEFFDF9FCFEFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7FFFFFDFFBFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFCFEFEFC7CF4707070707070303030383C3E3E3E3F1F3FFFFFFFDFFFFFFFFFFFFFFFFFFFFFFFEFF7F7E6E0F804260616020000000008080
; 160x30 (3 channels)
IBE_PFA0: HEX E0E0E0E0E0E0C08000808080808080000000808080808080808080808080
IBE_PFA1: HEX 80E0F0F8FBFFFFFFFFFFFFFEFCFCFCFCFCF9F9F9FAFCFCF8F8F8F8F0F0F0
IBE_PFA2: HEX 000000000000000000000000000000000101000000000000000000000000
; 160x33 (3 channels)
FRA_PFA1: HEX 03030307171F1F3F7F7F7F3F3F1F1F1F1F1F1F0F0F0F0F0F0F0F0F0F0F1F0F0F0E
FRA_PFA2: HEX 010101030F0F0F07070707070707070707070707070707070707070F0F0F0F0700
; 160x44 (3 channels)
ITA_PFA2: HEX 80E0F8F8FCFCFCFCFCFCFCFCFCF8F8F8D8C0C0C0E0C0F0B0B030200020303030303030303010000000000000
ITA_PFA3: HEX 0000001030303030302020000000001010103030303030F0F0F0F0E0E0C0C0C080808080808080C070707070
ITA_PFA4: HEX 0000000000000000000000000000000000000000000000000000008080C04040000000000000000000000000
; 160x43 (3 channels)
GER_PFA2: HEX 607070707030F0F0F0F0F030F0F0F0F0F8F8F8F8F8F8F8F8F8F8F8FCFCFCFEFEF8F8F8F8F8F8F8F8783808
GER_PFA3: HEX 00000000000000000000001030707070707070707070707070301010101010000010101010301000000000
; 160x63 (3 channels)
NOR_PFA2: HEX 0000000000000000000000000000000000000000000000000000000000808080008080C0C0C0E0F0F0F0F8F8FCFEFEFEFEFEFAFEFEFEFCFEFEFEFCBC9C9C9C
NOR_PFA3: HEX 0000000000000000000000000080C0C0E0E0E0D0D0C0C0E0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0E0F0F0F0
NOR_PFA4: HEX 00010307070F1F1F7F7F7F7EFEFEFEFEFEFEFEFCFCFCFCFCFCF8F8F8F0F0F0F0F0F0F0E0E0C0C0C080808080808000000080A0C0C0C0C0C080800000404040
NOR_PFA5: HEX 1E0F0F171F0F0F0F06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
; 159x40 (3 channels)
ENG_PFA0: HEX 000000808080C080C00000800000800040E0E0C0F0F0F0F0F0E0F0F0F0F070300000000000000000
ENG_PFA1: HEX 202020E0E0C0C0F0F0F0F0F0E0E0E0F0F0F0F0F0B07878383C7C7C7C7E7E7EFEFE7E7E7E7EFCC080
; 160x31 (3 channels)
TUR_PFA4: HEX 18183838787B7F7F7F3F3F3F3E3E3E3D38383D3C1E1F1C1E1E1E1C0D0C0C04
TUR_PFA5: HEX 80C0E0E0E0F0F3FFFFFFFDFFFFFFFFFFFFFFFFFFFFFFFEFF7F7E6E0F804260
; 158x28 (3 channels)
BAL_PFA4: HEX 0D0307070F0F0F0B0B0B031F1F1F1F1F1F1F1F1F1F1F1F1F0F0F0F06
BAL_PFA5: HEX 01010101010103030303030101010101010101010101010000000080
; 160x26 (3 channels)
POL_PFA3: HEX 000000008080C0C0C0C0C0C0C0C0C0C0C0C0C080808000000000
POL_PFA4: HEX 1030F0F8F8F8F8FCFCFCFCFCFCFCFCFCFCFCFCFCFCFCF8787810
; 160x15 (3 channels)
NET_PFA1: HEX 000000000000000000000101000000
NET_PFA2: HEX 040606060606060707070707030202
; 160x35 (3 channels)
AUS_PFA3: HEX 202060E0F0F0F0F0F0E0E0E0C0C0E0F0F0F0F0E0E0E0C0C0E0E0E0C0C0C0C0C0808000
AUS_PFA4: HEX 000000048787CFFFFFFFFFFEFEF8F8F8F0F0F0F0F0F0F0F0F0F0F0F0F0E0E0E0C08080
AUS_PFA5: HEX 0000000000000101000000000000000000000000000000000000000000000000000000
; 160x22 (3 channels)
ROM_PFA4: HEX 0107070F1F1F1F1F0F0F0F0F0F0F0F0F0F0F0F070700
ROM_PFA5: HEX 01010303030303030307070703030303030303030301
; 160x42 (3 channels)
UKR_PFA4: HEX 000000000000010307070707070707070707070707070701000000000000000000000000000000000000
UKR_PFA5: HEX 181C1C3F3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFCEEEEEC6CC440404
; 160x38 (3 channels)
RUS_PFA5: HEX C0C0C0C0C0E0E0E0F8F8FCFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEFEF6F6E6E0C0
; 160x48 (3 channels)
FIN_PFA4: HEX 000000000000010101010103030303030303030307070101010303030307070F0F0F0F1F1F1F1F1F0F0F1F1F1F1E1C0C
FIN_PFA5: HEX F0F0F0F0F0F8F9FFFFFFFFFF3F7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7F7F7F7F2F0F0F0F0F0F050100000000

IBE_PFA3: ;HEX 000000000000000000000000000000000000000000000000000000000000
IBE_PFA4: ;HEX 000000000000000000000000000000000000000000000000000000000000
IBE_PFA5: ;HEX 000000000000000000000000000000000000000000000000000000000000
FRA_PFA0: ;HEX 000000000000000000000000000000000000000000000000000000000000000000
FRA_PFA3: ;HEX 000000000000000000000000000000000000000000000000000000000000000000
FRA_PFA4: ;HEX 000000000000000000000000000000000000000000000000000000000000000000
FRA_PFA5: ;HEX 000000000000000000000000000000000000000000000000000000000000000000
ITA_PFA0: ;HEX 0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ITA_PFA1: ;HEX 0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ITA_PFA5: ;HEX 0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
GER_PFA0: ;HEX 00000000000000000000000000000000000000000000000000000000000000000000000000000000000000
GER_PFA1: ;HEX 00000000000000000000000000000000000000000000000000000000000000000000000000000000000000
GER_PFA4: ;HEX 00000000000000000000000000000000000000000000000000000000000000000000000000000000000000
GER_PFA5: ;HEX 00000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ENG_PFA2: ;HEX 00000000000000000000000000000000000000000000000000000000000000000000000000000000
ENG_PFA3: ;HEX 00000000000000000000000000000000000000000000000000000000000000000000000000000000
ENG_PFA4: ;HEX 00000000000000000000000000000000000000000000000000000000000000000000000000000000
ENG_PFA5: ;HEX 00000000000000000000000000000000000000000000000000000000000000000000000000000080
TUR_PFA0: ;HEX 00000000000000000000000000000000000000000000000000000000000000
TUR_PFA1: ;HEX 00000000000000000000000000000000000000000000000000000000000000
TUR_PFA2: ;HEX 00000000000000000000000000000000000000000000000000000000000000
TUR_PFA3: ;HEX 00000000000000000000000000000000000000000000000000000000000000
BAL_PFA0: ;HEX 00000000000000000000000000000000000000000000000000000000
BAL_PFA1: ;HEX 00000000000000000000000000000000000000000000000000000000
BAL_PFA2: ;HEX 00000000000000000000000000000000000000000000000000000000
BAL_PFA3: ;HEX 00000000000000000000000000000000000000000000000000000000
POL_PFA0: ;HEX 0000000000000000000000000000000000000000000000000000
POL_PFA1: ;HEX 0000000000000000000000000000000000000000000000000000
POL_PFA2: ;HEX 0000000000000000000000000000000000000000000000000000
POL_PFA5: ;HEX 0000000000000000000000000000000000000000000000000000
NET_PFA0: ;HEX 000000000000000000000000000000
NET_PFA3: ;HEX 000000000000000000000000000000
NET_PFA4: ;HEX 000000000000000000000000000000
NET_PFA5: ;HEX 000000000000000000000000000000
AUS_PFA0: ;HEX 0000000000000000000000000000000000000000000000000000000000000000000000
AUS_PFA1: ;HEX 0000000000000000000000000000000000000000000000000000000000000000000000
AUS_PFA2: ;HEX 0000000000000000000000000000008000000000000000000000000000000000000000
ROM_PFA0: ;HEX 00000000000000000000000000000000000000000000
ROM_PFA1: ;HEX 00000000000000000000000000000000000000000000
ROM_PFA2: ;HEX 00000000000000000000000000000000000000000000
ROM_PFA3: ;HEX 00000000000000000000000000000000000000000000
UKR_PFA0: ;HEX 000000000000000000000000000000000000000000000000000000000000000000000000000000000000
UKR_PFA1: ;HEX 000000000000000000000000000000000000000000000000000000000000000000000000000000000000
UKR_PFA2: ;HEX 000000000000000000000000000000000000000000000000000000000000000000000000000000000000
UKR_PFA3: ;HEX 000000000000000000000000000000000000000000000000000000000000000000000000000000000000
RUS_PFA0: ;HEX 0000000000000000000000000000000000000000000000000000000000000000000000000000
RUS_PFA1: ;HEX 0000000000000000000000000000000000000000000000000000000000000000000000000000
RUS_PFA2: ;HEX 0000000000000000000000000000000000000000000000000000000000000000000000000000
RUS_PFA3: ;HEX 0000000000000000000000000000000000000000000000000000000000000000000000000000
RUS_PFA4: ;HEX 0000000000000000000000000000000000000000000000000000000000000000000000000000
FIN_PFA0: ;HEX 000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
FIN_PFA1: ;HEX 000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
FIN_PFA2: ;HEX 000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
FIN_PFA3: ;HEX 000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
NOR_PFA0: ;HEX 000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
NOR_PFA1: HEX 000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

	ORG $FFFC
	.WORD START ;Restart
	.WORD START ;BRK