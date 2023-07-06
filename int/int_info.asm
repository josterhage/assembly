%define CR_LF 0x0d,0x0a
%define EOL '$'

bits 16
org 0x0100

segment .text
    xor ax,ax
    mov dx, hello_message
    mov ah, 0x09
    int 0x21

    mov dx, vector_line
    int 0x21

    xor di, di
main_loop:
    mov ax, di
    mov bx, vector_number
    add bx, 3
    call format_hex

    push ds
    xor ax, ax
    mov ds, ax
    mov bx, di
    add bx, bx
    add bx, bx
    mov ax, [bx]
    pop ds
    mov bx, vector_ip
    call format_hex
    push ds
    mov ax, 0
    mov ds, ax
    mov bx, di
    add bx, bx
    add bx, bx
    mov ax, [bx+2]
    pop ds
    mov bx, vector_cs
    call format_hex

    mov dx, vector_number
    mov ah, 0x09
    int 0x21

    inc di
    cmp di, 0x0100
    jb main_loop
    int 0x20

format_hex:
    mov cl, 0xf0
    and cl, ah
    shr cl, 1
    shr cl, 1
    shr cl, 1
    shr cl, 1
    add cl, 0x30
    cmp cl, 0x3A
    jb fh1
    add cl, 0x07
fh1:
    mov [bx], cl

    mov cl, 0x0f
    and cl, ah
    add cl, 0x30
    cmp cl, 0x3A
    jb fh2
    add cl, 0x07
fh2:
    mov [bx+1], cl

    mov cl, 0xf0
    and cl, al
    shr cl, 1
    shr cl, 1
    shr cl, 1
    shr cl, 1
    add cl, 0x30
    cmp cl, 0x3A
    jb fh3
    add cl, 0x07
fh3:
    mov [bx+2], cl

    mov cl, 0x0f
    and cl, al
    add cl, 0x30
    cmp cl, 0x3A
    jb fh4
    add cl, 0x07
fh4:
    mov [bx+3], cl

    ret

segment .data
    hello_message db "IVT call address printout", CR_LF, CR_LF, EOL
    vector_line db   " Vector | CS   | IP   |",CR_LF
    separator db     "--------+------+------+",CR_LF,'$'
    vector_number db "        | "
    vector_cs db               "     | " 
    vector_ip db                      "     |",CR_LF,'$'

segment .bss
    hex_16 resb 4