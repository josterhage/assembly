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
    and cx, 0xfff8          ;remove x % 8               21
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
.j1:
    mov al, ah
    shr al, 1               ;leading fill bitmask
    ; [bp - 2] = leading bit-mask (border top)
    ; [bp - 3] = leading bit-mask (fill )
    push ax                 ; leading bit-masks          51 or 55-79
    
    ; if w < 8 - x % 8 then we have to modify the 
    ; leading pixel bit mask
    ; assuming LPO = 2 and W = 4
    neg cx                  ; cl = -2
    add cx, 8               ; cl = 6
    mov bx, [bp + 0xa]        ; bx = 4
    cmp cx, bx              ; cmp 6, 4
    jna .j2                 ; 6 > 4, 
    ;else, modify the leading pixel bit mask
    sub cl, bl              ; cl = 2
    mov bl, 1               ; bl = 1
    shl bl, cl              ; bl = 4
    dec bl                  ; bl = 3
    mov al, [bp - 2]        ; al = bit mask (0b00111111)
    xor al, bl              ; al = 0b00111111 ^ 0b00000011 = 0b00111100
    mov [bp - 2], al        ; [bp - 2] = 0b00011110
    ;if the box doesn't spill out of the first byte we push BYTE 0 twice
    ;and skip 
    xor ax, ax
    push ax

.j2:
    

    ; we need to get the value of the leading and trailing bitmasks and 
    ; push them on to the stack, trailing first