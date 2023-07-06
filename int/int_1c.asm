%define CR_LF 0x0d,0x0a
%define EOL '$'
%define TICK_INTERRUPT 0x1C
%define PRINT_LINE 0x09
%define TERMINATE 0x4C
%define DOS_INT 0x21
%define GET_VECTOR 0x35
%define SET_VECTOR 0x25

bits 16
org 0x0100

section .text

start:

    mov dx, hello_message
    mov ah, PRINT_LINE
    int DOS_INT

    mov ah, GET_VECTOR
    mov al, TICK_INTERRUPT
    int DOS_INT

    mov [old_tick_vector_segment], es
    mov [old_tick_vector_ip], bx

    mov dx, do_tick
    mov ah, SET_VECTOR
    int DOS_INT

halt:
    hlt
;    inc byte [tick_count]
    cmp byte [tick_count], 50
;    mov dx, tick
;    mov ah, PRINT_LINE
;    int DOS_INT
    jb halt

    mov ah, SET_VECTOR
    mov al, TICK_INTERRUPT
    mov dx, [old_tick_vector_ip]
    push ds
    mov ds, [old_tick_vector_segment]
    int DOS_INT
    pop ds

    mov ah, TERMINATE
    int DOS_INT
    ret

do_tick:
    push ax
    mov ax,cs
    mov ds,ax
    inc byte [tick_count]
    mov dx, tick
    mov ah, PRINT_LINE
    int DOS_INT
    pop ax
    iret

section .data
    old_tick_vector_segment  dw 0
    old_tick_vector_ip       dw 0

    hello_message db "Hooks interrupt 0x1C and ticks every system tick for 60 ticks",CR_LF,EOL
    tick db "TICK!",CR_LF,EOL

    tick_count db 0