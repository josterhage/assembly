EGA_SEGMENT EQU 0xA000
GFX_CONTROL_REGISTER EQU 0x3CE
VR_SET_MODE EQU 5
VR_FUNCTION_SELECT EQU 3
VR_READ_MODE_0 EQU 0
VR_COMPARISON_REPLACE EQU 0
VR_WRITE_MODE_2 EQU 0x0200

; the stack
;   [BP + 12] - X Coordinate
;   [BP + 10] - Y coordinate
;   [BP + 8]  - Width in PX
;   [BP + 6]  - Height in PX
;   [BP + 5]  - Border color  - passed as LSB of a word
;   [BP + 4]  - Fill Color    - passed as MSB of a word
;   [BP + 2]  - Return Pointer
;   [BP]  - Old Base pointer
;   [BP - 2]        - memory offset of the rectangle's X,Y position
;   [BP - 4]  - (border) leading bit-mask      - passed as LSB of a word
;   [BP - 6]  - (fill) leading bit-mask       - passed as LSB of a word
;   [BP - 8]  - width of box in bytes
;   [BP - 10]  - (border) trailing bit-mask     - passed as LSB of a word
;   [BP - 12]  - (fill) trailing bit-mask      - passed as LSB of a word
;   [BP - 14]  - (border) leading bit-mask: mid-rows - passed as LSB of a word
;   [BP - 16]  - (border) trailing bit-mask: mid-rows - passed as MSB of a word
draw_rect:
    push bp
    mov bp, sp

.set_row_offset:
    ; get the row-level offset from the y coord and push it onto the stack
    mov cx, [bp + 12]      ;cx = y-Coord               17
    shl cx, 1               ;cx = y*2                   19
    shl cx, 1               ;cx = y*2*2 = y*4           21
    add cx, [bp + 12]      ;cx = (y*4)+y = y*5         39
    shl cx, 1               ;cx = y*5*2=y*10            41
    shl cx, 1               ;cx = y*10*2=y*20           43
    shl cx, 1               ;cx = y*20*2=y*40           45
    push cx                 ;[BP] = row-level offset    56
    ; Developer's note: there are no net instruction cycles saved, in
    ; the aggregate, by checking for 0 and skipping the shifts

    ; add the column offset to the row offset
    mov cx, [bp + 14]      ;cx = x-Coord               17
    shr cx, 1               ;cx = x / 2 (no remainder)  23
    shr cx, 1               ;cx = x / 4 (no remainder)  25
    shr cx, 1               ;cx = x / 8 (no remainder)  27
    pop dx                  ;dx = row-based offset      35
    add cx, dx              ;cx = row offset + column   38
    push cx                 ;[bp] = mem-offset          49

    ;create the leading byte bitmask
    mov cx, [bp + 14]      ;cx = x-coord               17
    xor ax, ax              ;                           20
    and cx, 0x0007          ;cx = x % 8                 24
    jz .build_masks                  ;if there is no remainder we can leave 28
    mov ah, 0xff            ;8 full pixels              32
    shr ah, cl              ;clear empty pixels         40 + 4-28
.build_masks:                        ; TODO: create descriptive label
    mov al, 8
    push ax                 ; [bp - 2]  set leading bit-mask command
    shr ah, 1               ;leading fill bitmask
    push ax                 ; [bp - 4] set lading fill bit-mask command
    
    ; if W < (8 - X % 8) then we have to merge the leading and trailing
    ; bit-masks and nullify the box width in bytes
    neg cx                  ; cx = 0 - X%8
    add cx, 8               ; cx = 8 - X%8
    mov bx, [bp + 10]      ; bx = W
    cmp cx, bx              ; is (8 - X%8) > W?
    jna .finish_masks                 ; TODO: create descriptive label
    ;it's not, create the merged bit-masks
    sub cl, bl              ; cl = (8 - X%8) - W
    inc cl                  ; cl = cl + 1
    mov bl, 1               ; bl = 1
    shl bl, cl              ; bl <<= cl
    dec bl                  ; bl -= 1 (2^CL - 1)
    mov al, [bp - 4]        ; al = the fill leading bit-mask
    xor al, bl              ; al = the merged leading bit-mask
    mov [bp - 4], al          ; back in memory
    shr bl, 1               ; bl >>= 1
    mov al, [bp - 2]        ; al = the border top/bottom leading bit-mask
    xor al, bl              ; al = the border top/bottom merged bit-mask
    mov al, [bp - 2]        ; back in memory
    ;since the box doesn't spill out of the first byte, the byte width and
    ;trailing bit-masks are null
    xor ax, ax
    push ax                 ; [bp - 6] width of box in bytes
    push ax                 ; [bp - 8] trailing byte bit-masks
    push ax                 ; [bp - 10]
    ;the border bit mask for the mid can be easily found by XORing the 
    ;border top row bit mask with the middle-row fill bitmask
    mov ah, [bp - 2]          ; al = merged top/bottom border bit-mask
    mov bl, [bp - 4]          ; bl = merged fill bit-mask
    xor ah, bl              ; al = al ^ bl = middle-row border bit-mask
    mov al, 8
    push ax                 ; [bp - 12] leading bit-mask (LSB of AX)
    xor ax, ax
    push ax                 ; [bp - 14] trailing bit-mask (MSB - already 0)
    jmp .start_drawing                 ; TODO: label this jump

    ;if W > (8 - X % 8) we have to determine the width of the box in bytes
    ;(excluding leading and trailing bytes) and build the:
    ; trailing border top/bottom bit-mask
    ; trailing fill bit-mask
    ; leading mid-row border bit-mask
    ; trailing mid-row border bit-mask
.finish_masks:
    ; get x%8
    mov cx, [bp + 14]       ; cx = X coordinate
    and cx, 0x0007          ; cx = X % 8
    mov bx, [bp + 10]       ; bx = W
    sub bx, cx              ; bx = W - X%8
    mov cx, bx              ; cx = bx = W - X%8
    ; get the width in bytes, leading/trailing byte exclusive
    shr bx, 1               ; bx = (W - X%8) / 2 (no remainder)
    shr bx, 1               ; bx = (W - X%8) / 4 (no remainder)
    shr bx, 1               ; bx = (W - X%8) / 8 (no remainder)
    push bx                 ; [bp - 6] -- width in bytes
    ;get the border top/bottom trailing byte bitmask
    and cx, 0x0007          ; cx = (W - X%8) % 8
    jz .start_drawing                  ; TODO: create a descriptive label
    mov ah, 0xff            ; filled bit-mask
    shl ah, cl              ; so much easier than building the leading edge
    mov al, 8               ; ax = border trailing edge bit-mask command
    push ax                 ; [bp - 8] border trailing bit-mask
    shl ah, 1
    push ax                 ; [bp - 10] fill trailing bit-mask
    mov ah, [bp - 2]
    mov bh, [bp - 4]
    xor ah, bh
    push bx                 ; [bp - 12] border leading mask mid-rows
    mov ah, [bp - 8]
    mov bh, [bp - 10]
    xor ah, bh
    push ax                 ; [bp - 14] border trailing mask mid-rows

    ;set the control registers and draw the rectangle
.start_drawing:
    push es
    mov bx, EGA_SEGMENT     ; this procedure is assumed to be in program
                            ; that has this as a defined constant
    mov es, bx
    xor bx, bx
    mov al, [bx]            ; this loads the plane data into the latch registers
    mov dx, GFX_CONTROL_REGISTER
    ; set card to read mode 0 and write mode 2
    mov ax, VR_SET_MODE | VR_READ_MODE_0 | VR_WRITE_MODE_2
    out dx, ax
    ; set card to replace pixel data with new data
    mov ax, VR_FUNCTION_SELECT | VR_COMPARISON_REPLACE
    out dx, ax
    ; start drawing
    mov cx, [bp + 8]        ; cx = height in pixels for loop purposes
    push cx                 ; store it at the top of the stack
                            ; we're going to be swapping back-and-forth
                            ; with the width in bytes, so we need to be able to scratch
    mov bx, [bp]            ; bx = memory offset of the rect's x,y position
    call .draw_top_or_bottom
    pop cx                  ; restore the height in pixels
    dec cx                  ; we've already drawn one row
    jz .finished            ; if the height is 1, we're finished
.prepare_middle_rows:
    dec cx
    jz .draw_bottom_row     ; middle rows done, draw bottom row
    add bx, 80              ; next row in memory
    push cx
.draw_middle_row:
    mov ax, [bp - 12]       ; get mid-row border leading-edge mask
    out dx, ax              ; write border leading-edge bit-mask to register
    mov al, [bp + 7]        ; border color
    mov [bx], al            ; draw border
    mov ax, [bp - 4]        ; get fill leading-edge mask
    out dx, ax              ; write mask to register
    mov al, [bp + 6]        ; fill color
    mov [bx], al            ; draw fill
.prepare_middle_row_middle:
    mov cx, [bp - 4]        ; width of box in bytes
    or cx, cx               ; cx == 0?
    jz .draw_middle_row_trail
    mov ax, 0xff08          ; full byte mask
    out dx, ax              ; write mask to register
    mov al, [bp + 6]        ; fill color
    xor di, di              ; clear destination index
.draw_middle_row_middle:
    inc di                  ; the first byte is at bx + 1
    mov [bx + di], al       ; fill byte
    cmp di, cx
    jne .draw_middle_row_middle
.draw_middle_row_trail:
    mov ax, [bp - 10]       ; get the fill trailing bit-mask
    or ah, ah               ; draw border if full
    jz .draw_middle_row_trail_border
    out dx, ax
    mov al, [bp + 6]         ; get fill color
    inc di
    mov [bx + di], al
.draw_middle_row_trail_border:
    mov ax, [bp - 14]       ; get border trailing mask
    out dx, ax
    mov al, [bp + 7]         ; get border color
    mov [bx + di], al
    pop cx
    jmp .prepare_middle_rows

.draw_bottom_row:
    add bx, 80
    call .draw_top_or_bottom

.finished:
    mov sp, bp              ; revert sp to initial value
    pop bp                  ; restore the caller's stack frame
    ret

.draw_top_or_bottom:
    ;assumes everything else is set
    mov ax, [bp - 2]
    out dx, ax
    mov al, [bp + 7]
    mov [bx], al
    mov cx, [bp - 4]
    or cx, cx
    jz .draw_trail
    mov ax, 0xff08
    out dx, ax
    mov al, [bp + 7]
    xor di, di
.draw_mid:
    inc di
    mov [bx + di], al
    cmp di, cx
    jne .draw_mid
.draw_trail:
    mov ax, [bp - 6]
    or ah, ah
    jz .draw_top_bottom_done
    out dx, ax
    mov al, [bp + 7]
    inc di
    mov [bx + di], al
.draw_top_bottom_done:
    ret