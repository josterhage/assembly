;MACROS
%macro shr_n 2
%rep %1
    shr %2, 1
%endrep
%endmacro

%macro shl_n 2
%rep %1
    shl %2, 1
%endrep
%endmacro

;CONSTANTS

CR  EQU 0X0D
LF  EQU 0X0A
EOL EQU '$'

;KEYBOARD CONSTANTS
KBD_INT     EQU 0X09
KBD_PORT    EQU 0X60
KBD_CTL     EQU 0X61

;VIDEO CONSTANTS
EGA_SEGMENT             EQU 0XA000
BIOS_VIDEO_INTERRUPT    EQU 0X10
GFX_CONTROL_REGISTER    EQU 0X3CE

;VIDEO MODES
VM_DOS_TEXT             EQU 2
VM_EGA_320_200_16       EQU 14
VM_EGA_640_350_16       EQU 16
VM_EGA_320_200_256      EQU 19

;VIDEO REGISTERS (these get OR'd to the LSB of a register)
VR_SET_RESET            EQU 0
VR_ENABLE_SET_RESET     EQU 1
VR_COLOR_COMPARE        EQU 2
VR_FUNCTION_SELECT      EQU 3
VR_READ_MAP_SELECT      EQU 4
VR_SET_MODE             EQU 5
VR_MISC                 EQU 6
VR_COLOR_DONT_CARE      EQU 7
VR_BIT_MASK             EQU 8

;VIDEO REGISTER VALUES (these get OR'd to the MSB of a register)
VR_WRITE_MODE_0         EQU 0
VR_WRITE_MODE_1         EQU 0x0100
VR_WRITE_MODE_2         EQU 0x0200
VR_READ_MODE_0          EQU 0
VR_READ_MODE_1          EQU 0x0800
VR_COMPARISON_REPLACE   EQU 0
VR_COMPARISON_AND       EQU 0x0800   ;0B0000100000000000
VR_COMPARISON_OR        EQU 0x1000   ;0B0001000000000000
VR_COMPARISON_XOR       EQU 0x1800   ;0B0001100000000000

;HARDWARE INTERRUPT CONSTANTS
INTA00      EQU 0X20
EOI         EQU 0X20

;DOS FUNCTION CONSTANTS
GETC        EQU 1
PRINTLINE   EQU 9
TERMINATE   EQU 0X4C
DOSINT      EQU 0X21

org 0x100
bits 16

segment .text

start:
    ;test 1 will:
    ;   * set the graphics mode
    ;   * draw the following rectangle:
    ;       * X - 15
    ;       * Y - 20
    ;       * W - 25
    ;       * H - 25
    ;       * B - 12
    ;       * F - 6
    ;   * wait for a key
    ;   * restore the graphics mode

    ; set the graphics mode
    mov al, VM_EGA_320_200_16
    call set_graphics_mode

    mov ax, 24
    push ax
    mov ax, 24
    push ax
    mov ax, 26
    push ax
    mov ax, 3
    push ax
    mov ax, 0x0c0a
    push ax
    call draw_rect
    mov ah, GETC
    int DOSINT

    mov al, VM_DOS_TEXT
    call set_graphics_mode

    mov ah, TERMINATE
    int DOSINT
    ret


;hooks interrupt handler
;   AX - CS
;   BX - interrupt
;   DX - pointer
;   returns: AX:DX -> old handler
hook_vector:
    push es
    push ax
    xor ax, ax
    mov es, ax
    pop ax
    shl bx, 1
    shl bx, 1
    cli
    xchg es:[bx], dx
    xchg es:[bx+2], ax
    sti
    pop es
    ret

; AL = mode
set_graphics_mode:
    ;don't assume the programmer cleared AH
    and ax, 0x00ff
    int BIOS_VIDEO_INTERRUPT
    ret

draw_rect:              ; about 146h
    push bp
    mov bp, sp

.set_row_offset:
    ; get the row-level offset from the y coord and push it onto the stack
    mov cx, [bp + 10]      ;cx = y-Coord               17
    shl cx, 1               ;cx = y*2                   19
    shl cx, 1               ;cx = y*2*2 = y*4           21
    add cx, [bp + 10]      ;cx = (y*4)+y = y*5         39
    shl cx, 1               ;cx = y*5*2=y*10            41
    shl cx, 1               ;cx = y*10*2=y*20           43
    shl cx, 1               ;cx = y*20*2=y*40           45
    push cx                 ;[bp - 2] = row-level offset    56
    ; Developer's note: there are no net instruction cycles saved, in
    ; the aggregate, by checking for 0 and skipping the shifts

    ; add the column offset to the row offset
    mov cx, [bp + 12]      ;cx = x-Coord               17
    inc cx                  ; the x-coordinate is 0-indexed but the
			    ; offset arithmetic is 1-indexed
    shr cx, 1               ;cx = x / 2 (no remainder)  23
    shr cx, 1               ;cx = x / 4 (no remainder)  25
    shr cx, 1               ;cx = x / 8 (no remainder)  27
    pop dx                  ;dx = row-based offset      35
    add cx, dx              ;cx = row offset + column   38
    push cx                 ;[bp - 2] mem-offset          49

    ;create the leading byte bitmask
    mov cx, [bp + 12]       ;cx = x-coord               17
    inc cx                  ; same as above
    and cx, 0x0007          ;cx = x % 8                 24
    jz .build_masks         ;if there is no remainder we can leave 28   16dh
    mov ah, 0xff            ;8 full pixels              32
    shr ah, cl              ;clear empty pixels         40 + 4-28
.build_masks:                        ; 173h
    mov al, 8
    push ax                 ; [bp - 4]  set leading bit-mask command
    shr ah, 1               ;leading fill bitmask
    push ax                 ; [bp - 6] set leading fill bit-mask command

    ; if W < (8 - X % 8) then we have to merge the leading and trailing
    ; bit-masks and nullify the box width in bytes
    neg cx                  ; cx = 0 - X%8
    add cx, 8               ; cx = 8 - X%8
    mov bx, [bp + 8]      ; bx = W
    cmp cx, bx              ; is (8 - X%8) > W?
    jna .finish_masks                 ; TODO: create descriptive label
    ;it's not, create the merged bit-masks
    sub cl, bl              ; cl = (8 - X%8) - W
    inc cl                  ; cl = cl + 1
    mov bl, 1               ; bl = 1
    shl bl, cl              ; bl <<= cl
    dec bl                  ; bl -= 1 (2^CL - 1)
    mov al, [bp - 6]        ; al = the fill leading bit-mask
    xor al, bl              ; al = the merged leading bit-mask
    mov [bp - 6], al          ; back in memory
    shr bl, 1               ; bl >>= 1
    mov al, [bp - 4]        ; al = the border top/bottom leading bit-mask
    xor al, bl              ; al = the border top/bottom merged bit-mask
    mov al, [bp - 4]        ; back in memory
    ;since the box doesn't spill out of the first byte, the byte width and
    ;trailing bit-masks are null
    xor ax, ax
    push ax                 ; [bp - 8] width of box in bytes
    push ax                 ; [bp - 10] border trailing byte bit-mask
    push ax                 ; [bp - 12] fill trailing byte bit-mask
    ;the border bit mask for the mid can be easily found by XORing the 
    ;border top row bit mask with the middle-row fill bitmask
    mov ah, [bp - 4]          ; al = merged top/bottom border bit-mask
    mov bl, [bp - 6]          ; bl = merged fill bit-mask
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
.finish_masks:          ; 1B6h
    ; BX = W
    ; CX = 8 - %8
    sub bx, cx              ; bx = W - (8 - X%8)
    mov cx, bx              ; cx = bx = W - X%8
    ; get the width in bytes, leading/trailing byte exclusive
    shr bx, 1               ; bx = (W - X%8) / 2 (no remainder)
    shr bx, 1               ; bx = (W - X%8) / 4 (no remainder)
    shr bx, 1               ; bx = (W - X%8) / 8 (no remainder)
;    dec bx
    push bx                 ; [bp - 8] -- width in bytes
    ;get the border top/bottom trailing byte bitmask
    and cx, 0x0007          ; cx = (W - X%8) % 8
    jz .short_mask          ; 1CAh
    mov ah, 0xff            ; filled bit-mask
    shl ah, cl              ; so much easier than building the leading edge
    mov al, 8               ; ax = border trailing edge bit-mask command
    push ax                 ; [bp - 10] border trailing bit-mask
    shl ah, 1
    push ax                 ; [bp - 12] fill trailing bit-mask
    mov ax, [bp - 4]        ; border leading mask
    mov bx, [bp - 6]        ; fill leading mask
    xor ah, bh
    push ax                 ; [bp - 14] border leading mask mid-rows
    mov ax, [bp - 10]       ; border trailing mask
    mov bx, [bp - 12]       ; fill trailing mask
    xor ah, bh
    push ax                 ; [bp - 16] border trailing mask mid-rows
    jmp .start_drawing

.short_mask:
    dec bx 
    mov [bp - 8], bx        ; if the width brings the box to the edge
			    ; of a byte-box, we need to draw
			    ; one less full box and push special trailing
			    ; masks
    mov ax, 0xff08          ; top/bottom border trailing bit-mask
    push ax
    mov ah, 0xfe            ; 0xfe08    - fill trailing bit-mask
    push ax
    mov ax, [bp - 4]
    mov bx, [bp - 6]
    xor ah, bh
    push ax                 ; border mid-row leading bit-mask
    mov ah, 1               ; ax = 0x0108   - border trailing bit-mask
    push ax 

    ;set the control registers and draw the rectangle
.start_drawing:
    push es
    mov bx, EGA_SEGMENT     ; this procedure is assumed to be in program
			    ; that has this as a defined constant
    mov es, bx
    xor bx, bx
    mov al, es:[bx]            ; this loads the plane data into the latch registers
    mov dx, GFX_CONTROL_REGISTER
    ; set card to read mode 0 and write mode 2
    mov ax, VR_SET_MODE | VR_READ_MODE_0 | VR_WRITE_MODE_2
    out dx, ax
    ; set card to replace pixel data with new data
    ;mov ax, VR_FUNCTION_SELECT | VR_COMPARISON_XOR
    ;out dx, ax
    ; start drawing
    mov cx, [bp + 6]        ; cx = height in pixels for loop purposes
    push cx                 ; store it at the top of the stack
			    ; we're going to be swapping back-and-forth
			    ; with the width in bytes, so we need to be able to scratch
    mov bx, [bp - 2]            ; bx = memory offset of the rect's x,y position
    call .draw_top_or_bottom
    pop cx                  ; restore the height in pixels
    dec cx                  ; we've already drawn one row
    jz .finished            ; if the height is 1, we're finished
.prepare_middle_rows:
    dec cx
    jz .draw_bottom_row     ; middle rows done, draw bottom row
    add bx, 80              ; next row in memory
    push cx
    mov ax, VR_SET_MODE | VR_READ_MODE_0 | VR_WRITE_MODE_0
    out dx, ax
    mov al, VR_FUNCTION_SELECT
    out dx, ax
.draw_middle_row:
    mov ax, [bp - 14]       ; get mid-row border leading-edge mask
    out dx, ax              ; write border leading-edge bit-mask to register
    mov ah, [bp + 5]        ; border color
    mov al, VR_SET_RESET
    out dx, ax
    mov ax, 0xff01
    out dx, ax
    mov es:[bx], al            ; draw border
    mov ax, [bp - 6]        ; get fill leading-edge mask
    or ah, ah
    jz .prepare_middle_row_middle
    out dx, ax              ; write mask to register
    mov ah, [bp + 4]        ; fill color
    mov al, VR_SET_RESET
    out dx, ax
    mov es:[bx], al            ; draw fill
.prepare_middle_row_middle:
    mov cx, [bp - 8]        ; width of box in bytes
    or cx, cx               ; cx == 0?
    jz .draw_middle_row_trail
    mov ax, VR_SET_MODE | VR_WRITE_MODE_2 | VR_READ_MODE_0
    out dx, ax
    mov ax, 0xff08          ; full byte mask
    out dx, ax              ; write mask to register
    mov al, [bp + 4]        ; fill color
    xor di, di              ; clear destination index
.draw_middle_row_middle:
    inc di                  ; the first byte is at bx + 1
    mov es:[bx + di], al       ; fill byte
    cmp di, cx
    jne .draw_middle_row_middle
.draw_middle_row_trail:
    mov ax, [bp - 12]       ; get the fill trailing bit-mask
    or ah, ah               ; draw border if full
    jz .draw_middle_row_trail_border
    out dx, ax
    mov ax, VR_SET_MODE | VR_READ_MODE_0 | VR_WRITE_MODE_0
    out dx, ax
    mov ax, VR_FUNCTION_SELECT | VR_COMPARISON_OR
    out dx, ax
    mov ah, [bp + 4]         ; get fill color
    mov al, VR_SET_RESET
    out dx, ax
    mov ax, 0x0f01
    out dx, ax
    inc di
    mov es:[bx + di], al
.draw_middle_row_trail_border:
    mov ax, [bp - 16]       ; get border trailing mask
    out dx, ax
    mov ah, [bp + 5]         ; get border color
    mov al, VR_SET_RESET
    out dx, ax
    mov ax, 0x0f01
    out dx, ax
    mov es:[bx + di], al
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
    mov ax, [bp - 4]
    out dx, ax
    mov al, [bp + 5]
    mov es:[bx], al
    mov cx, [bp - 8]
    or cx, cx
    jz .draw_trail
    mov ax, 0xff08
    out dx, ax
    mov al, [bp + 5]
    xor di, di
.draw_mid:
    inc di
    mov es:[bx + di], al
    cmp di, cx
    jne .draw_mid
.draw_trail:
    mov ax, [bp - 10]
    or ah, ah
    jz .draw_top_bottom_done
    out dx, ax
    mov al, [bp + 5]
    inc di
    mov es:[bx + di], al
.draw_top_bottom_done:
    ret

; converts bx into a >=4 digit hex number
print_hex_word:
    push bx
    push di
    push dx
    push ax
;unsafe, don't do this
    mov di, .formatted_number
    add di, 4
    ;assume bx > 0
.convert_loop:
    push bx
    and bx, 0x000f
    add bl, 0x30    ;0x2f < bl < 0x40
    cmp bl, 0x3a 
    jb .move_it
    add bl, 7       ;0x40 < bl < 0x47
.move_it:
    dec di
    mov [di],bl
    pop bx
    shr_n 4,bx
    or bx, bx
    jnz .convert_loop

    mov dx, di
    mov ah, PRINTLINE
    int DOSINT

    pop ax
    pop dx
    pop di
    pop bx
    ret
;data for print_hex_word
    .formatted_number times 4 db 0
    db CR, LF, '$'

;custom int 09 handler
;very simple handler, it really just gets the last scancode, appends
; it to the keyboard data queue, then sends the EOI signal
int_09_handler:
    sti
    push bx
    push ax
    push si
    in al, 0x60
    push ax
    in al, 0x61
    mov ah, al
    or al, 0x80
    out 0x61, al
    xchg ah, al
    out 0x61, al
    pop ax
    mov bx, kbd_data_queue
    mov si, [kbd_next_slot]
    mov byte [bx+si], al
    inc si
    mov [kbd_next_slot], si
    cli
    mov al, EOI
    out INTA00, al
    pop si
    pop ax
    pop bx
    iret

segment .data
    int_09_ip   dw  0
    int_09_cs   dw  0

    last_scan_code  db  0

    kbd_data_queue  times 256 db 0
    kbd_next_cmd    db 0
    kbd_next_slot   db 0

segment .bss
    free_data_base  resb 0x8000    ; used just to get an address