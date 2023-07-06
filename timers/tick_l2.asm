;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
; TICK_LEN.ASM                                                                 ;
;   FIND THE AVERAGE TIME IN ms BETWEEN TWO TIMER TICKS AFTER 1000 TICKS       ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CONSTANTS                             ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%define CR_LF           0x0d, 0x0a
%define EOL             '$'
%define TICK_INTERRUPT  0x4a
%define TICK_VECTOR     TICK_INTERRUPT*4

%define PRINT_LINE      0x09
%define SET_VECTOR      0x25
%define GET_TIME        0x2c
%define GET_VECTOR      0x35
%define TERMINATE       0x4c

%define DOS_INT         0x21

%define TIMER0          0x40
%define TIMER_CTL       0x43


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CODE SECTION                          ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

bits 16
org 0x0100

section .text

start:
; print hello message
    mov dx, hello_message
    mov ah, PRINT_LINE
    int DOS_INT

; hook tick vector
    mov ah, GET_VECTOR
    mov al, TICK_INTERRUPT
    int DOS_INT

    mov [old_tick_vector_segment], es
    mov [old_tick_vector_ip], bx

    mov dx, tick_handler
    mov ah, SET_VECTOR
    int DOS_INT

; increase ticks/sec
;    mov al, 0x30
;    out TIMER_CTL, al
    xor al,al
    out TIMER0, al
    mov al, 0x80
    out TIMER0, al

; start counting
gettime:
    mov ah, GET_TIME
    int DOS_INT
    ; if seconds on the timestamp is <30, reset
    cmp dh, 30
    ja gettime

    mov [start_time], dx
    mov byte [ticks], 128
_wait:
    hlt
    or byte [ticks],0
    jnz _wait

;get end stamp
    mov ah, GET_TIME
    int DOS_INT
    mov [stop_time], dx

; return vector control
    mov ah, SET_VECTOR
    mov al, TICK_INTERRUPT
    mov dx, [old_tick_vector_ip]
    push ds
    mov ds, [old_tick_vector_segment]
    int DOS_INT
    pop ds

    mov bx, [start_time]
    mov ax, [stop_time]
    sub ax, bx
    mov bx, ax          
    and bx, 0x00ff      ; erase whole seconds from BX
times 8 shr ax, 1        ; move whole seconds into lsb
    mov cx, 1000
    mul cx              ; ax *= 1000
    add ax, bx          
times 7 shr ax, 1       ; ax = total ms / 128

;format the number
    mov bx, 4

format:
    mov cx, 10
    div cx              ; ensure that we don't get an overflow
    add dl, 0x30        ; convert remainder to ascii char

    dec bx
    mov [avg_fmt+bx],dl
    xor dx,dx
    cmp bx, 0
    jnz format

; display message
    mov dx, end_msg_begin
    mov ah, PRINT_LINE
    int DOS_INT
    mov ah, TERMINATE
    int DOS_INT
    ret

tick_handler:
    push ax
    mov ax, cs
    mov ds, ax
    dec byte [ticks]
    pop ax
    iret
    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Global variables                      ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .data
; vectors

    hello_message   db "Find the average time for a tick in ms.", CR_LF, EOL
    end_msg_begin   db "The system averaged "
    avg_fmt         dd 0
    end_msg_fin     db " ms per tick", CR_LF, EOL

section .bss
; vectors
    old_tick_vector_segment     resw 1
    old_tick_vector_ip          resw 1

    ticks           resb 1
    start_time      resw 1
    stop_time       resw 1