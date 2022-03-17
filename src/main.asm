; playwav32 - plays 8Bit 31250Hz Stereo PCM files on the ZX Spectrum Next 
; 
; em00k 03/2022
;
; TODO:
; - check for WAV header 
; - Support mono files (code already exists)
; - detect WAV header and set playback speed / mode 
; - Need to backup CPU speed..... 
; - currently doesnt detect video mode for timning 

        SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION
        DEVICE ZXSPECTRUMNEXT
        CSPECTMAP "playwav32.map"

        INCLUDE "utils.asm" 

        org     $2000

main:   ; header data 
        jr      begin
        db      "playwav32"
        db      "1.0-em00k"
begin: 
        di 
        ld      a,h
        or      l								; check if a command line is empty 
        jr      nz,commandlineOK						; get hl if = 0 then no command line given, else jump to commandlineOK
        ld      hl,emptyline							; show help text 
        call    print_rst16							; print message 
        jp      end_out			
        					                                
commandlineOK: 

        ld      (stack_out2+1),sp                                               ; save system stack 
        ld      sp,stack_low                                                    ; point stack to stack top 
        
        push    iy,ix,hl,de,bc,af                                               ; save std regs 
        
        ld      (stack_out+1),sp                                                ; store this stack position 

        nextreg	TURBO_CONTROL_NR_07,%00000011	        

        ld      a,MMU4_8000_54 : call    getreg : ld     (bank4),a              ; backup slot 4 / $8000 

        ld      de,textbuffer                                                   ; point de to our text buffer 
        ld      b,0                                                             ; flatten b 

scanline:

        ld      a,(hl)								; load char into a 
        cp      ":"     : jr    z,finishscan					; was it : ? then we're done 
        or      a       : jr    z,finishscan					; was it 0 ? 
        cp      13      : jr    z,finishscan					; or was it return 13 ?
        
        ld      (de),a  : inc   hl : inc de				        ; none of the above so copy to de and inc addresses 
        djnz    scanline							; keep going until b = 0 

finishscan: 

	xor     a       : ld    (de),a						; ensure end of filename has a zero 

        call    getbank                                                         ; ask OS for free bank
        nextreg MMU4_8000_54,a                                                  ; place in slot 4 / $8000

        ld      hl,ctc_code                                                     ; copy our ctc player to $8000
        ld      de,$8000
        ld      bc,interrupt_end- ctc_code
        ldir


        call    start_ctc_player                                                ; start player 

finish:

        ld      a,(u_bank)                                                      ; get bank we reserved 
        call    free                                                            ; free it 
        ld      a,(bank4)                                                       ; get original bank 4
        nextreg $54,a                                                           ; replace it 

stack_out:

	ld      sp,0                                                            ; ensure stack is fixed for reg pops
        pop     af,bc,de,hl,ix,iy    

stack_out2:

        ld      sp,0                                                            ; return system stack 
        xor     a
        im      1                                                               ; enable IM1 again 
end_out:

        ei 
        ret                                                                     ; exit 

;------------------------------------------------------------------------------
; Data 
stream_file_name        db      "sugar.pcm",0 
emptyline               db      "PlayWav32 - v1.0 by em00k",13,13
                        db      "Plays 8 Bit 31250Hz Stereo PCM  files.",13,13
                        db      "Usage : ",13
                        db      "   .playwav32 mysong.raw",13
                        db      13,0 
textbuffer              ds      256,0
error_opening           db      "Error opening file",0 
bank4		        db 	4
bank5		        db 	5
bank6		        db 	0
bank7		        db 	1
u_bank                  db      0

buffer_stack:
        defw    0 
        defw    0 
        defw    0 
        defs    64,0 
stack_low:
        

;------------------------------------------------------------------------------
; Includes 

        INCLUDE "interrupts.asm" 
        INCLUDE "banks.asm" 

last:

	savebin "h:/dot/playwav32",main,last-main 

;------------------------------------------------------------------------------
; Output configuration
        ; SAVENEX OPEN "h:/playwav32.nex", main, stack_top 
        ; SAVENEX CORE 2,0,0
        ; SAVENEX CFG 7,0,0,0
        ; SAVENEX AUTO 
        ; SAVENEX CLOSE
