value   equ     25
CR      equ     0x0d
LF      equ     0x0a
EOL     equ     '$'

TIMER_INTERRUPT     equ 0x08
TIMER_INT_IVT       equ TIMER_INTERRUPT*4

segment .text
mov dx, hello_msg
mov ah, 0x09
int 0x21

segment .data
    hello_msg   db "Hello", CR,LF,EOL