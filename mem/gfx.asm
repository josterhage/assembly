; constants
%define SEGMENT_SIZE 0FFFFh

bits 16
org 100h

section .text

start:

    int 20h

; malloc - Memory ALLOCation
; returns a pointer to a block of memory
; size is pushed onto the stack before calling
; pointer is returned in the AX register
malloc:
    push bp
    mov bp, sp

    ;check if memory has already been allocated
    cmp word [allocated_segment], 0
    jnz do_malloc
    ;if it hasn't, ask DOS for 64k
    call get_memory

; memory block structure:
; cribbed from a lecture diagram that talked about knuth's
; boundary tag implementation
; blocks are word-aligned and tagged at either end with the block size
; and bit 0 describing allocated (1) or free (0)
; access to the next block is done by looking SIZE+4 bytes forward in memory
;
;      +----------------+
;base  |sssssssssssssssa|
;      +----------------+
;block |  memory block  |
;      +----------------+
;foot  |sssssssssssssssa|
;      +----------------+
;
;   actual memory base address = block base + 2
;   footer address = block base + 2 + size
;   next header address = block base + 4 + size


do_malloc:
    mov bx, [bp+4] ; get requested size from stack
    cmp bx, 2       ; minimum allocation is 2 bytes
    jae continue_malloc
    mov bx, 2       ; set block size to 2 bytes if request was smaller
    mov [bp+4], bx

continue_malloc:
    push ds                     ; save DS and DI
    push di

    mov ds,[allocated_segment]  ; set DS to the allocated segment address
                                ; to make all writes local
    xor di,di                   ; point to DS:0x0000

is_block_free:
    mov ax, [di]                ; get header
    test ax, 1                  ; is bit 0 set?
    jz block_is_free            ; if not, block is free
    ;block is not free
    and ax, 0xFFFE              ; mask off bit 0
    add di, ax                  
    add di, 4                   ; point to next block header
    cmp di, ax                  ; if DI <= AX, we've wrapped around and there
                                ; is no free memory in the segment
    ja is_block_free            
    ; end the program - it is doubtful this will
    ; happen in the use cases i'm writing this for
    mov dx, [no_memory_error]
    mov ah, 09h
    int 21h
    int 20h
    
block_is_free:
    mov ax, [di]                ; get size of block
    cmp ax, [bp+4]              ; is block large enough?
    jae block_is_large_enough
    add di, ax                  ; if not, move to next block
    add di, 4
    je block_is_perfect         ; block size = request size
    jmp is_block_free

block_is_large_enough:
    push di                     ; save header address to stack
    mov bx, [di]                ; save size
    mov [di], ax                ; new size into header
    inc [di]                    ; set allocated bit
    add di, ax
    add di, 2                   ; point to the footer
    mov [di], ax
    inc [di]                    ; new size and allocated flag

    add di, 2                   ; point to new footer for next block
    sub bx, 4
    sub bx, ax                  ; adjust size of next block for header
    move [di], bx               ; save in header location
    add di,2
    add di, bx                  ; point to block footer
    mov [di], bx                ; save size in footer

    pop ax                      ; header address from stack
    add ax, 2                   ; [ax] --> base address of allocated memory

    pop di
    pop ds
    ret

get_memory:
    mov bx, SEGMENT_SIZE
    mov ah, 48h
    int 21h
    ;if DOS won't give us 64k, we print an error message and quit
    jnc initialize_segment
    mov dx, [no_memory_error]
    mov ah, 09h
    int 21
    int 20h

initialize_segment:
    push ds
    push di
    ;store base location of the allocated memory
    mov [allocated_segment], ax
    mov ds, ax ;set DS to the new segment address so our writes are all local
    ;clear the memory
    xor di, di
    mov bx, 0x7fff
    xor ax, ax
    rep stosw
    ;create the header and footer for the allocated segment
    xor di,di   ;use di as our pointer

;    Initial structure of memory segment
;        +--------+--------+
;      0 |11111111|11111110|  
;        +--------+--------+
;    .   |  Memory Block   |
;        +--------+--------+
; 0xfffe |11111111|11111110|  
;        +--------+--------+
;

    mov [di],0xFFFE          ;initial block, block is free and max size
    mov [di+0xFFFE],0xFFFE   ;repeated at end of segment
    pop di              ; restore DI and DS
    pop ds
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
    ; values for the random number generator
    lfsr            db 0
    rnd_start_val   db 0
    randoms     times 256 db 0
    next_value      db 0
    allocated_segment   dw 0
    no_memory_error     db "Not enough free memory", 0dh, 0ah, '$'

section .bss
