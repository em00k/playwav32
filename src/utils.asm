; nextregs & ports 

TURBO_CONTROL_NR_07             equ $07
VIDEO_INTERUPT_CONTROL_NR_22    equ $22
VIDEO_INTERUPT_VALUE_NR_23      equ $23 
DAC_C_MIRROR_NR_2E              equ $2E
DAC_B_MIRROR_NR_2C              equ $2C
DAC_AD_MIRROR_NR_2D             equ $2D
TRANSPARENCY_FALLBACK_COL_NR_4A equ $4A
GLOBAL_TRANSPARENCY_NR_14       equ $14
MMU4_8000_54					equ $54
; macros / esxdos utils 	
M_GETSETDRV 	equ $89
F_OPEN 			equ $9a
F_CLOSE 		equ $9b
F_READ 			equ $9d
F_WRITE 		equ $9e
F_SEEK 			equ $9f
F_GET_DIR 		equ $a8
F_SET_DIR 		equ $a9

FA_READ 		equ $01
FA_APPEND 		equ $06
FA_OVERWRITE 	equ $0C

	macro ESXDOS command
		rst 	8
		db command
	endm

	macro MP3DOS command,bank
		; macro for call NextBasic PLUS3DOS commands 
		exx
		ld 		de,command
		ld 		c,bank
		rst 	$08
		db 		$94
	endm

	macro BREAK
		db		$dd,$01 
	endm