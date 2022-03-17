
print_rst16:    ; prints string in HL terminated with 0 
	ld a,(hl):inc hl:or a:ret z:rst 16:jr print_rst16

getreg:		; in register in a, out value in a 
        push    bc 
        ld      bc,$243B						; Register Select 
        out     (c),a							
        inc     b 
        in      a,(c)                                                   ; value in a 
        pop     bc 
        ret


getbank:	; returns free bank in a 
        ld      hl,$0001  						; H=banktype (ZX=0, 1=MMC); L=reason (1=allocate)
        exx
        ld      c,7 		        				; RAM 7 required for most IDEDOS calls
        ld      de,$01bd 						; IDE_bank
        ld      a,e 			        			; bank is in a 
        ret 
				
free:		; in a = bank to free 
        ld      hl,$0003  			        		; H=banktype (ZX=0, 1=MMC); L=reason (1=allocate)
        ld      e,a							
        exx							
        ld      c,7 							; RAM 7 required for most IDEDOS calls
        ld      de,$01bd 
        ret 