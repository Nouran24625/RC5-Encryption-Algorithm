.include "m328Pdef.inc"

.equ __zero_reg__ = 0    ; Define zero register manually

; GPRs Registers
.def A0L = r16
.def A0H = r17
.def B0L = r18
.def B0H = r19
.def temp1 = r20
.def temp2 = r21
.def temp3 = r22
.def temp4 = r23
.def counter = r24

.dseg
L:  .byte 12       ; Secret key array (12 bytes)
S:  .byte 36       ; Expanded key array (18 words = 36 bytes)
Plain:.byte 4
Cipher: .byte 4

.cseg
.org 0x00

; ------------------------------------------------------------
; Key Expansion
; ------------------------------------------------------------
KeyExpansion:
    ldi ZH, high(S)
    ldi ZL, low(S)

    ; Initialize S[0]=p16
    ldi temp1, high(0xB7E1)
    ldi temp2, low(0xB7E1)
    st Z+, temp2
    st Z+, temp1

    ;load Q16
    ldi temp1, high(0x9E37)
    ldi temp2, low(0x9E37)

    ldi counter, 17       ; 17 more entries to fill (after S[0])
KeyExpansionLoop1:
    ld temp3, -Z          ; Load previous word 
    ld temp4, -Z          

    add temp3, temp2
    adc temp4, temp1     ;S[i-1] + Q

    st Z+, temp4          ; Store new s[i]
    st Z+, temp3          

    dec counter
    brne KeyExpansionLoop1

    ; Mixing secret key into S and L
    ldi counter, 54       ; 3 * max(t=18, c=6) = 54
    ldi YH, high(L)
    ldi YL, low(L)

KeyExpansionLoop2:
    ld temp2, Z
    ld temp3, Y
    add temp2, temp3
    st Z+, temp2
    st Y+, temp2

    dec counter
    brne KeyExpansionLoop2

    ret

; ------------------------------------------------------------
; Encryption
; ------------------------------------------------------------
Encrypt:
    ; Load A0, B0
    lds A0L, 0x0100
    lds A0H, 0x0101
    lds B0L, 0x0102
    lds B0H, 0x0103

    ; A0 = A0 + S[0]
    lds temp1, S
    lds temp2, S+1
    add A0L, temp1
    adc A0H, temp2

    ; B0 = B0 + S[1]
    lds temp1, S+2
    lds temp2, S+3
    add B0L, temp1
    adc B0H, temp2

    ldi counter, 8        ; 8 rounds
EncryptLoop:
    mov temp3, A0L
    eor temp3, B0L     ;A0 XOR B0
    mov temp4, A0H
    eor temp4, B0H

    lsl temp3             ; Logical shift left (rotation)
    rol temp4

    lds temp1, S+4
    lds temp2, S+5    ; add S[2] to the rotated value 
    add temp3, temp1
    adc temp4, temp2

    mov A0L, temp3
    mov A0H, temp4     ; saving the updated new values into A0 registers 

  
    mov temp3, B0L
    eor temp3, A0L
    mov temp4, B0H
    eor temp4, A0H

    lsl temp3
    rol temp4

    lds temp1, S+6
    lds temp2, S+7
    add temp3, temp1   ; add S[3] to the rotated value
    adc temp4, temp2

    mov B0L, temp3
    mov B0H, temp4

    subi counter, 1
    brne EncryptLoop

    ret

; ------------------------------------------------------------
; Decryption
; ------------------------------------------------------------
Decrypt:
    ldi counter, 8

DecryptLoop:
    
    lds temp1, S+6
    lds temp2, S+7  ; subtract s[3] from B0
    sub B0L, temp1
    sbc B0H, temp2

    ror B0H
    ror B0L

    eor B0L, A0L
    eor B0H, A0H

    
    lds temp1, S+4
    lds temp2, S+5  ; subtract S[2] from A0
    sub A0L, temp1
    sbc A0H, temp2

    ror A0H
    ror A0L

    eor A0L, B0L
    eor A0H, B0H

    subi counter, 1
    brne DecryptLoop

   
    lds temp1, S+2
    lds temp2, S+3 
    sub B0L, temp1   ; subtract s[1] from B0
    sbc B0H, temp2

    lds temp1, S
    lds temp2, S+1
    sub A0L, temp1   ; subtract s[0] from A0
    sbc A0H, temp2

    ret