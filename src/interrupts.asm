;
; Setup Up a CTC interrupt audio playback and loading chunks from SD 
; 

; 31,250 8 bit stereo 
; 15,625 8 bit stereo 

;
; CTC config originally written by KevB for NextSID
    
INTCTL				equ	0C0h	; Interrupt control
NMILSB				equ	0C2h	; NMI Return Address LSB
NMIMSB				equ	0C3h	; NMI Return Address MSB
INTEN0				equ	0C4h	; INT EN 0
INTEN1				equ	0C5h	; INT EN 1
INTEN2				equ	0C6h	; INT EN 2
INTST0				equ	0C8h	; INT status 0
INTST1				equ	0C9h	; INT status 1
INTST2				equ	0CAh	; INT status 2
INTDM0				equ	0CCh	; INT DMA EN 0
INTDM1				equ	0CDh	; INT DMA EN 1
INTDM2				equ	0CEh	; INT DMA EN 2
CTC0				equ	183Bh	; CTC channel 0 port
CTC1				equ	193Bh	; CTC channel 1 port
CTC2				equ	1A3Bh	; CTC channel 2 port
CTC3				equ	1B3Bh	; CTC channel 3 port
CTC4				equ	1C3Bh	; CTC channel 4 port
CTC5				equ	1D3Bh	; CTC channel 5 port
CTC6				equ	1E3Bh	; CTC channel 6 port
CTC7				equ	1F3Bh	; CTC channel 7 port
CTCBASE             equ $c0		; MSB Base address of buffer 
CTCSIZE             equ $04 	; MSB buffer length 
CTCEND              equ CTCBASE+(CTCSIZE*2)	

    ; */
        
irq_vector	    equ	$8DFE			                        ; 2 BYTES Interrupt vector
vector_table	equ	$8C00		                            ; 257 BYTES Interrupt vector table	

ctc_code:

        disp 	$8000                                       ; we want to relocate this block to $8000

start_ctc_player:

        ld      (int_stack_out+1),sp                        ; store stack before interrupt 
        ld      sp,stack_top                                ; set stack to stack_top 

        ld      hl,textbuffer                               ; open the file 

        call    open_file

        call    read_data_a                                 ; read chunks to ram 
        call    read_data_b

        call    ctc_startup                                 ; call ctc_startup 
wait_loop: 

        ld      a,(chunkloadflag)                           ; check if we reached the end of file flag
        cp      3  
        jr      z, end_wait_loop

        ld      a,0                                         ; else read keys for any pressed 
        out     ($fe),a  
        xor     a
        in      a,(#fe)
        cpl
        and     15
        jr      z,wait_loop

end_wait_loop:

        di                                                  ; stop interrupts and clean up 
        nextreg	VIDEO_INTERUPT_CONTROL_NR_22,0
        nextreg INTCTL,8 
        nextreg INTEN0,%10000001                            ; Interrupt enable DISABLE
        nextreg INTEN1,%00000000  
        
        call    close_file
int_stack_out: 

        ld      sp,0                                        ; stack saved from above 
        jp      finish                                      ; exit interrupts routines 

ctc_startup:	

        di                                                  ; Set stack and interrupts
        
        ld      hl,vector_table                             ; 252 (FCh)
        ld      a,h
        ld      i,a
        im      2
        inc     a                                           ; 253 (FDh)
        ld      b,l                                         ; Build 257 BYTE INT table

.irq:	
        ld      (hl),a
        inc     hl
        djnz    .irq                                        ; B = 0
        ld      (hl),a

        ld      a,$FB                                       ; EI
        ld      hl,$4DED                                    ; RETI
        ld      (irq_vector-1),a
        ld      (irq_vector),hl

        nextreg VIDEO_INTERUPT_CONTROL_NR_22,%00000100
        nextreg VIDEO_INTERUPT_VALUE_NR_23,255

        xor     a 
        ld      bc,192
        ld      de,raster_line
        ld      (raster_frame),a
        
        ld      a,i 
        ld      h,a
        ld		l,0
        ld		(hl),e                                      ; Set LINE interrupt
        inc		l
        ld		(hl),d
        ld		l,6
        ld		de,ctc0                                     ; Set CTC0 interrupt
        ld		(hl),e
        inc		l
        ld		(hl),d
        inc		l
        ld		de,ctc1                                     ; Set CTC1 interrupt
        ld		(hl),e
        inc		l
        ld		(hl),d

        ld		a,b
        and		%00000001
        or		%00000110                                   ; ULA off / LINE interrupt ON

        nextreg	VIDEO_INTERUPT_CONTROL_NR_22,a
        ld		a,c
        nextreg	VIDEO_INTERUPT_VALUE_NR_23,a                ; IM2 on line BC	

        nextreg INTCTL,%00001001                            ; Vector 0x00, stackless, IM2

        nextreg INTEN0,%00000010                            ; Interrupt enable LINE
        nextreg INTEN1,%00000001                            ; CTC channel 0 zc/to
        nextreg INTEN2,%00000000                            ; Interrupters
        nextreg INTST0,%11111111                            ; 
        nextreg INTST1,%11111111                            ; Set status bits to clear
        nextreg INTST2,%11111111                            ; 
        nextreg INTDM0,%00000000                            ; 
        nextreg INTDM1,%00000000                            ; No DMA
        nextreg INTDM2,%00000000                            ; 

        ld		a,(sampletiming)
        ld 		d,a 
        ld		a,0    										; manually set timing 
        ld		hl,timing_tab
        add		a,a
        add		hl,a

        ; CTC Channel 0 

        ld		bc,CTC0                                     ; Channel 0 port
                                                            ; IMPETCRV	; Bits 7-0
        ld		a,%10000101                                 ; / 16
        out		(c),a                                       ; Control word
        out		(c),d                                       ; Time constant

        ; CTC Channel 1

        ld		bc,CTC1                                     ; Channel 1 port
        ;                                                   IMPETCRV	; Bits 7-0
        ld		a,%10101101                                 ; / 256
        out		(c),a                                       ; Control word
        ld      a,192
        out     (c),a 
        ;ld		a,(hl)
        ;outinb                                             ; Time constant		

        ei 
        ret 


;------------------------------------------------------------------------------
; Interrupts routines 

raster_line:	
        ei 
        push	af  ;11
        push    hl  ;11
        push    de  ;11
        push    bc  ;11
        push    ix  ;15 
        

        ld      a,(raster_frame)
        inc	    a
        ld	    (raster_frame),a

        pop     ix 
        pop     bc
        pop     de
        pop     hl
        pop     af
        reti


    ;' CTC 0 handles streaming the data to the left+right DACs

ctc0:
        ; ctc routines by em00k 
        ei
        push 	af 
        push    hl 
        push    de 

        ld      de,(sample_offset)
        ld      a,e                             ; put e into a 
        or      a                               ; was it zero 
        jr      nz,skipload                     ; no skip loading 

        ld      a,d                             ; get d 
        cp      CTCBASE+CTCSIZE                 ; compare to $50
        jr      nz, skiploada                   ; <>50 then skip 
        ld      a,1                             ; else set load flag to 1 
        ld      (chunkloadflag),a 
        
skiploada:        

        ld      a,d                             ; get d 
        cp      CTCBASE                         ; compare to $40
        jr      nz, skipload                    ; <> $40  skip 
        ld      a,2                             ; else set load flag to 2 
        ld      (chunkloadflag),a 

skipload:

        ld      de,(sample_offset)
        ld		a,(sample_stereo)
        ld 		h,a 
        
        bit 	0,h 
        jr		nz,mono_player

        ld      a,(de)                          ; grab sample 
        
        nextreg DAC_C_MIRROR_NR_2E, a           ; send to left channel 
        inc     de      

        ld      a,(de)                          ; grab sample 
        
        nextreg DAC_B_MIRROR_NR_2C, a           ; send to right channel 
        inc     de  

        jr		end_player

mono_player:
        ld      a,(de)                          ; grab sample 
        and		%11111110
        nextreg DAC_AD_MIRROR_NR_2D, a          ; send to left channel 
        inc 	de 

end_player:

        ld      a,d                             ; check if position is not at CTCEND 
        cp      CTCEND                          ; 
        jr      nz,final                        ; if not $60 then jump to final 
        ld      de,CTCBASE*256                  ; else reset de to CTCBASE
final: 
        ld		(sample_offset),de 

        pop     de 
        pop     hl 
        pop 	af 
        ;ei 
        reti

    ; ' CTC 1 for checking if we need to load another block 

ctc1: 
        
        ei 
        push    af 
    
        ld      a,(chunkloadflag)               ; get the load flag 
        or      a                               ; was it zero 
        jr      z,skipload2                     ; yes skip loading for now

        push    de 
        push    hl  
        push    ix   
        push    bc 

        ld      a,(chunkloadflag)               ; get the load flag  
        cp      1                               ; is flag set to 1 
        call    z, read_data_a                  ; then load data block a, first half 

        ld      a,(chunkloadflag) 
        cp      2 
        call    z, read_data_b                  ; no it was 2, so load block b, second half  
        
        pop     bc 
        pop     ix 
        pop     hl  
        pop     de 

skipload2:

        pop     af 
        ;ei 
        reti 

read_data_a:

        ld      hl,CTCBASE*256
        push 	hl : pop ix
        ld      bc,CTCSIZE*256
        ld      a,(filehandle2)
        ESXDOS  F_READ 
        ld		a,b 
        or 		c 
        jr		z, end_of_file
        xor     a 
        ld      (chunkloadflag), a 
        ret 

read_data_b:

        ld      hl,(CTCBASE+CTCSIZE)*256
        push 	hl : pop ix
        ld      bc,CTCSIZE*256
        ld      a,(filehandle2)
        ESXDOS  F_READ
        ld		a,b 
        or 		c 
        jr		z, end_of_file
        xor     a 
        ld      (chunkloadflag), a 
        ret 

end_of_file:
        ld		a,3
        ld		(chunkloadflag),a 
        ret 



open_file:		
        ; open a file and set file handle 

        push hl : push 	hl : pop ix
        ld      a,(filehandle2)
        ESXDOS	F_CLOSE
        pop 	hl 
        push 	hl : pop ix
        ld      a,'*'
        ld      b,FA_READ
        ESXDOS  F_OPEN
        ld      (filehandle2),a 
        ret     nc 

openerror:

        ld		hl,error_opening
        call 	print_rst16

        jp 		int_stack_out 

close_file:

        ld      a,(filehandle2)
        ESXDOS	F_CLOSE
        ret 

filehandle2: 
        db      0 

chunkloadflag:
        db      0 

sample_stereo:
        db 		0 

timing_tab:
        db		250, %10001100 			; 0 28000000 50Hz =  8.75
        db		186, %11000000 			; 1 28571429 50Hz = 12.0  ?
        db		192, %11000000 			; 2 29464286 50Hz = 12.0  ?
        db		250, %10010110 			; 3 30000000 50Hz =  9.375
        db		250, %10011011 			; 4 31000000 50Hz =  9.6875
        db		250, %10100000 			; 5 32000000 50Hz = 10.0
        db		250, %10100101 			; 6 33000000 50Hz = 10.03125
        db		250, %10000111 			; 7 27000000 50Hz =  8.4375
    
    ; 
    ; 

sampletiming:
        db 		56                      ; 1750000 / 31250 = 56  , 1750000 / 15625 = 112 

sample_offset: 
    dw      CTCBASE*256

sample_start:
    dw      CTCBASE*256
            
raster_frame:
        db  	0

;------------------------------------------------------------------------------
; Stack reservation
STACK_SIZE      equ     100

stack_bottom:
        defs    STACK_SIZE * 2
stack_top:
        defw    0

        ent                                                     ; end if relocation code 
interrupt_end: 		 