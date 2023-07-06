bits 16
org 0x100

segment .text
; hook interrupt handler
    mov ax, cs
    mov bx, 0x09
    mov dx, int_09_handler
    call hook_handler
    mov [int_09_ip],dx
    mov [int_09_cs],ax

.halt:
    movzx bx, [last_scan_code]
    shl bx, 1
    add bx, .scan_code_jmp_table
    mov bx, [bx]
    jmp bx

;restore interrupt handler
.quit:
    mov ax, [int_09_cs]
    mov bx, 0x09
    mov dx, [int_09_ip]
    call hook_handler

    mov ah, 0x4c
    int 0x21
    ret

.scan_code_jmp_table:
    dw .zero
    times 15 dw .no_code
    dw .q
    times 111 dw .no_code

.zero:
    jmp .halt

.no_code:
    mov dx, no_proc_message
    mov ah, 0x09
    int 0x21
    jmp .halt

.q:
    mov dx, quit_message
    mov ah, 0x09
    int 0x21
    jmp .quit

hook_handler:
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
    mov al, 0x20
    out 0x20, al
    iret


segment .data
    int_09_ip   dw  0
    int_09_cs   dw  0

    last_scan_code db 0

    no_proc_message db "That scan code doesn't have a procedure", 0x0d, 0x0a, '$'
    quit_message db "You pressed q, quitting", 0x0d, 0x0a, '$'