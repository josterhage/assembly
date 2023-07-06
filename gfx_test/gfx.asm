; constants
%define VIDEO_MEMORY_BASE 0xA000

bits 16
org 100h

section .text

start:

    int 20h

; draws a box, calling is equivalent to:
;   void draw_box(short x, short y, short h, short w, byte fill, byte border)
draw_box:
    ; establish stack frame
    push bp
    mov bp, sp
    ; passed data is:
    ; bp+4      -> byte border
    ; bp+5      -> byte fill
    ; bp+6      -> short w
    ; bp+8      -> short h
    ; bp+10     -> short y
    ; bp+12     -> short x

    ; draw border
    ; save current data segment base to stack
    push ds

    ; set ds base to 0xA000 (EGA direct memory)
    ; TODO: future versions should use a runtime-established value
    mov ds, VIDEO_MEMORY_BASE

    ;draw first bit-plane
    ;get address of top-left pixel
    ; base address of row Y
    mov ax, [bp+10]
    mov bx, ax
    shl bx, 1
    shl bx, 1
    add bx, ax
    shl bx, 1
    shl bx, 1   ;x20
    shl bx, 1   ;x40
    shl bx, 1   ;x80
    
    mov ax, [bp+12]
    ; integer divide AX by 8 and store the remainder in BX
    mov dx, 7
    and dx, ax
    shr ax, 1
    shr ax, 1
    shr ax, 1
    push dx
    push ax

    
    pop ds
    pop bp
    ret

; returns a pseudo random number from 0-255 on AL
; assumes the generator has already been run
; if the generator hasn't been run, this will run
; the generator
get_random_number:
    push bp
    mov bp, sp
    lea bx, [randoms]
    add bx, next_value
    mov bl, byte [bx]
    and bx, 00ffh
    push bx   ; next value onto the stack
    test bl,0
    jnz get_random_number_return
    call fill_randoms
get_random_number_return:
    inc byte [next_value]
    pop ax
    pop bp
    ret

fill_randoms:
    push bp
    mov bp, sp
    ;get minimal entropy
    mov ah, 2ch
    int 21h
    test dl, 0
    jnz setup_random_generator
    inc dl

setup_random_generator:
    mov [lfsr], dl
    mov [rnd_start_val],dl
    mov di, randoms
    mov cx, 0100h

lfsr_loop:
    mov al, [lfsr]
    mov bl, [lfsr]
    shr bl, 1
    shr bl, 1
    xor al, bl
    mov bl, [lfsr]
    shr bl, 1
    shr bl, 1
    shr bl, 1
    xor al, bl
    mov bl, [lfsr]
    shr bl, 1
    shr bl, 1
    shr bl, 1
    shr bl, 1
    xor al, bl
    and al, 1
    mov bl, [lfsr]
    shr bl, 1
    shl al, 1
    shl al, 1
    shl al, 1
    shl al, 1
    shl al, 1
    shl al, 1
    shl al, 1
    or al, bl
    mov [lfsr], al
    stosb
    push ax
    mov al, 20h
    stosb
    pop ax
    cmp al, [rnd_start_val]
    jne lfsr_loop

    mov byte [next_value], 0ffh
    pop bp
    ret

section .data
    
    
section .bss
    ; values for the random number generator
    lfsr            resb 1
    rnd_start_val   resb 1
    randoms         resb 256
    next_value      resb 1

    ; random display values
    box_x           resw 1
    box_y           resw 1
    box_w           resw 1
    box_h           resw 1
    box_fill        resb 1
    box_border      resb 1