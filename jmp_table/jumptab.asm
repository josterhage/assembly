org 0x0100
segment .text

start:
.get_char:
    mov ah, 1
    int 0x21

    cmp al, 0x20
    jb .get_char
    cmp al, 0x7e
    ja .get_char

    sub al, 0x30
    movzx bx, al
    add bx, .jump_labels
    jmp [bx]

.quit:
    mov ah, 0x4c
    int 0x21
    ret

.jump_labels:
    times 16 dw .l1
    dw .l2
    times 32 dw .l1
    dw .l3
    times 31 dw .l1
    dw .l3
    times 13 dw .l1

.l1:
    mov dx, no_response
.print:
    mov ah, 0x09
    int 0x21
    jmp .get_char

.l2:
    mov dx, zero
    jmp .print

.l3:
    mov dx, quit_message
    mov ah, 0x09
    int 0x21
    jmp .quit

segment .data
    no_response     db "There is no entry for that key", 0x0d, 0x0a, '$'
    zero            db "You entered the zero key", 0x0d, 0x0a, '$'
    quit_message    db "You entered the letter q, quitting", 0x0d, 0x0a, '$'