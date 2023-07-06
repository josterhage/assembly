%macro shr_n 2
%rep %1
    shr %2, 1
%endrep
%endmacro

CR  EQU 0X0D
LF  EQU 0X0A
EOL EQU '$'

KBD_INT EQU 0X09

GETC        EQU 1
PRINTLINE   EQU 9
TERMINATE   EQU 0X4C
DOSINT      EQU 0X21

INTA00      EQU 0X20
EOI         EQU 0X20
KBD_PORT    EQU 0X60
KBD_CTL     EQU 0X61

org 0x100
bits 16

segment .text

start:
    mov ax, cs
    mov bx, KBD_INT
    mov dx, int_09_handler
    call hook_vector
    mov [int_09_ip], dx
    mov [int_09_cs], ax

.halt:
    mov byte [last_scan_code],0
    hlt
    movzx bx, [last_scan_code]
    cmp bx, 16
    je .quit
    or bx,bx
    jz .halt
    call printf
    jmp .halt

.quit:
    mov ax, [int_09_cs]
    mov dx, [int_09_ip]
    mov bx, KBD_INT
    call hook_vector

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

; converts bx into a >=4 digit hex number
printf:
    push bx
    push di
    push dx
    push ax
;unsafe, don't do this
    mov di, formatted_number
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

int_09_handler:
    sti
    push ax
    in al, 0x60
    push ax
    in al, 0x61
    mov ah, al
    or al, 0x80
    out 0x61, al
    xchg ah, al
    out 0x61, al
    pop ax
    mov [last_scan_code], al
    cli
    mov al, EOI
    out INTA00, al
    pop ax
    iret

segment .data
    int_09_ip   dw  0
    int_09_cs   dw  0

    last_scan_code  db  0

    formatted_number    times 4 db 0
    db  CR, LF, EOL