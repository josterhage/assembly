%define PRINT_LINE 0x09
%define TERMINATE 0x4C
%define DOS_INT 0x21

bits 16
org 0x0100

section .text

start:
    mov eax,1
    cpuid
    and eax,16
    shl eax,1
    mov [cpu_id],al
    mov eax,6
    cpuid
    and eax,8
    shl eax,1
    shl eax,1
    mov [cpu_id+1],al
    mov dx, hello_message
    mov ah, PRINT_LINE
    int DOS_INT
    mov ah,TERMINATE
    int DOS_INT
    ret


section .data
    hello_message db "CPU_ID is: "
    cpu_id db 0,0
    cr_lf db 0x0d, 0x0a
    eol db '$'