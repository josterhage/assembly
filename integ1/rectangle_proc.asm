; establish a stack frame
; find the base memory offset for y, 0
; find the base memory offset for y, x
; create the leading byte bitmask
;   in cases where W < 8-(x%8):
;       create the top/bottom bitmask
;       create the middle-row bitmask
;       set the byte-width to 0
;       jump to the drawing routine
; create the trailing byte bitmask
; 


; the stack
;   [BP + 0xE] - X Coordinate
;   [BP + 0xC] - Y coordinate
;   [BP + 0xA]  - Width in PX
;   [BP + 0x8]  - Height in PX
;   [BP + 0x7]  - Border color  - passed as LSB of a word
;   [BP + 0x6]  - Fill Color    - passed as MSB of a word
;   [BP + 0x4]  - Return Pointer
;   [BP + 0x2]  - Old Base pointer
;   [BP]        - memory offset of the rectangle's X,Y position
;   [BP - 0x2]  - (border) leading bit-mask      - passed as LSB of a word
;   [BP - 0x3]  - (fill) leading bit-mask       - passed as LSB of a word
;   [BP - 0x4]  - width of box in bytes
;   [BP - 0x6]  - (border) trailing bit-mask     - passed as LSB of a word
;   [BP - 0x7]  - (fill) trailing bit-mask      - passed as LSB of a word
;   [BP - 0x8]  - (border) leading bit-mask: mid-rows - passed as LSB of a word
;   [BP - 0x9]  - (border) trailing bit-mask: mid-rows - passed as MSB of a word
draw_rect:
    push bp
    mov bp, sp

.set_row_offset:
    ; get the row-level offset from the y coord and push it onto the stack
    mov cx, [bp + 0xc]      ;cx = y-Coord               17
    shl cx, 1               ;cx = y*2                   19
    shl cx, 1               ;cx = y*2*2 = y*4           21
    add cx, [bp + 0xc]      ;cx = (y*4)+y = y*5         39
    shl cx, 1               ;cx = y*5*2=y*10            41
    shl cx, 1               ;cx = y*10*2=y*20           43
    shl cx, 1               ;cx = y*20*2=y*40           45
    push cx                 ;[BP] = row-level offset    56
    ; Developer's note: there are no net instruction cycles saved, in
    ; the aggregate, by checking for 0 and skipping the shifts

    ; add the column offset to the row offset
    mov cx, [bp + 0xe]      ;cx = x-Coord               17
    shr cx, 1               ;cx = x / 2 (no remainder)  23
    shr cx, 1               ;cx = x / 4 (no remainder)  25
    shr cx, 1               ;cx = x / 8 (no remainder)  27
    pop dx                  ;dx = row-based offset      35
    add cx, dx              ;cx = row offset + column   38
    push cx                 ;[bp] = mem-offset          49

    ;get the leading byte bitmask
    mov cx, [bp + 0xe]      ;cx = x-coord               17
    xor ax, ax              ;                           20
    and cx, 0x0007          ;cx = x % 8                 24
    jz .j1                  ;if there is no remainder we can leave 28
    mov ah, 0xff            ;8 full pixels              32
    shr ah, cl              ;clear empty pixels         40 + 4-28
.j1:                        ; TODO: create descriptive label
    mov al, ah
    shr al, 1               ;leading fill bitmask
    ; [bp - 2] = leading bit-mask (border top)
    ; [bp - 3] = leading bit-mask (fill )
    push ax                 ; leading bit-masks          51 or 55-79
    
    ; if W < (8 - X % 8) then we have to merge the leading and trailing
    ; bit-masks and nullify the box width in bytes
    neg cx                  ; cx = 0 - X%8
    add cx, 8               ; cx = 8 - X%8
    mov bx, [bp + 0xa]      ; bx = W
    cmp cx, bx              ; is (8 - X%8) > W?
    jna .j2                 ; TODO: create descriptive label
    ;it's not, create the merged bit-masks
    sub cl, bl              ; cl = (8 - X%8) - W
    inc cl                  ; cl = cl + 1
    mov bl, 1               ; bl = 1
    shl bl, cl              ; bl <<= cl
    dec bl                  ; bl -= 1 (2^CL - 1)
    mov al, [bp - 3]        ; al = the fill leading bit-mask
    xor al, bl              ; al = the merged leading bit-mask
    mov [bp-3], al          ; back in memory
    shr bl, 1               ; bl >>= 1
    mov al, [bp - 2]        ; al = the border top/bottom leading bit-mask
    xor al, bl              ; al = the border top/bottom merged bit-mask
    mov al, [bp - 2]        ; back in memory
    ;since the box doesn't spill out of the first byte, the byte width and
    ;trailing bit-masks are null
    xor ax, ax
    push ax                 ; [bp - 4] width of box in bytes
    push ax                 ; [bp - 6] trailing byte bit-masks
    ;the border bit mask for the mid can be easily found by XORing the 
    ;border top row bit mask with the middle-row fill bitmask
    mov al, [bp-2]          ; al = merged top/bottom border bit-mask
    mov bl, [bp-3]          ; bl = merged fill bit-mask
    xor al, bl              ; al = al ^ bl = middle-row border bit-mask
    push ax                 ; [bp - 7] leading bit-mask (LSB of AX)
                            ; [bp - 8] trailing bit-mask (MSB - already 0)
    jmp .j3                 ; TODO: label this jump

    ;if W > (8 - X % 8) we have to determine the width of the box in bytes
    ;(excluding leading and trailing bytes) and build the:
    ; trailing border top/bottom bit-mask
    ; trailing fill bit-mask
    ; leading mid-row border bit-mask
    ; trailing mid-row border bit-mask
.j2:
    ; get x%8
    mov cx, [bp + 0xe]
    and cx, 0x0007
    mov bx, [bp + 0xe]
    sub bx, cx
    mov cx, bx              ; cx = bx = W - X%8
    ; get the width in bytes, leading/trailing byte exclusive
    shr bx, 1
    shr bx, 1
    shr bx, 1               ; bx = (W - X%8) / 8 (no remainder)
    push bx                 ; [BP - 0x4] -- width in bytes
    ;get the border top/bottom trailing byte bitmask
    and cx, 0x0007          ; cx = (W - X%8) % 8
    jz .j3                  ; TODO: create a descriptive label
    mov al, 0xff            ; filled bit-mask
    shl al, cl              ; so much easier than building the leading edge
    mov ah, al
    shl ah, 1
    push ax                 ; [BP - 0x6] - LSB: trailing border mask
                            ; [BP - 0x7] - MSB: trailing fill mask
    xchg al, ah
    xor al, ah
    mov ah, [bp - 0x2]
    mov bl, [bp - 0x3]
    xor ah, bl
    push ax                 ; [BP - 0x8] - LSB: leading mid-row border mask
                            ; [BP - 0x9] - MSB: trailing mid-row border mask

    ;set the control registers and draw the rectangle
.j3:
    

    ; we need to get the value of the leading and trailing bitmasks and 
    ; push them on to the stack, trailing first