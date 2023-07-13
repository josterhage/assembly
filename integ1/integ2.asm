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

    mov ax, 15
    push ax
    mov ax, 20
    push ax
    mov ax, 25
    push ax
    push ax
    mov ax, 0x0b06
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

draw_rect:
    push bp
    mov bp, sp

    mov ax, [bp + 10]
    mov bx, 40
    mul bx
    mov bx, [bp + 12]
    shr_n 3,bx
    add ax, bx
    push ax
    mov cx, [bp + 12]
    and cx, 7
    mov ah, 0xff
    shr ah, cl
    mov al, 8
    push ax
    mov bx, 0xa000
    mov es, bx
    xor bx, bx
    mov al, [bx]
    mov dx, 0x3ce
    mov ax, 0x0205
    out dx, ax
    mov ax, 0x0003
    out dx, ax
    mov ax, [bp - 4]
    out dx, ax
    mov al, 0xff
    mov bx, [bp - 2]
    mov [bx], al
    mov [bx + 1], al
    mov [bx + 2], al
    mov [bx + 3], al    

.finished:
    mov sp, bp              ; revert sp to initial value
    pop bp                  ; restore the caller's stack frame
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