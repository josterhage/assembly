;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MACROS                                ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; usage: shl_n [r/m] bits
;  shl_n bx 5 <-- shift the bits in BX left 5 times
%macro shl_n 2
%rep %1
    shl %2, 1
%endrep
%endmacro

%macro shr_n 2
%rep %1
    shr %2, 1
%endrep
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CONSTANTS                             ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; character constants
%define CR_LF               0x0d, 0x0a
%define EOL                 '$'

; interrupt constants
%define TIMER_INTERRUPT     0x08
%define TIMER_INT_IVT       TIMER_INTERRUPT*4
%define IBM_INT8_HANDLER_CS 0xf000  
; This has been the CS pointer for the 
; INT8 handler since the 5150

; DOS functions
%define PRINT_LINE      0x09
%define GET_TIME        0x2c
%define TERMINATE       0x4c

%define DOS_INT         0x21

; MMIO ports
%define TIMER0          0x40
%define TIMER_CTL       0x43

; code

bits 16
org 0x0100

segment .text

start:
;say hello
    mov dx, hello_message
    mov ah, PRINT_LINE
    int DOS_INT

;hook interrupt handler
    xor ax,ax                       ; clear ax
    mov es, ax                      ; set extra segment to 0000
    mov bx, es:[TIMER_INT_IVT]      ; get 0000:0020
    mov ax, es:[TIMER_INT_IVT+2]    ; get 0000:0022

    mov [old_ip], bx
    mov [old_seg], ax

    cli
    mov WORD es:[TIMER_INT_IVT], int_08_handler
    mov es:[TIMER_INT_IVT+2], cs


    mov cx, 0x0100  ; 256 iterations
.halt:
    hlt
    mov dx, msg
    mov ah, 0x09
    int 0x21
    loopnz .halt
    
.restore_handler:
    mov ax, [old_ip]
    mov bx, [old_seg]
    mov es:[TIMER_INT_IVT], ax
    mov es:[TIMER_INT_IVT+2], bx

;say goodbye
    mov dx, [goodbye_message]
    mov ah, PRINT_LINE
    int DOS_INT

    mov ah, TERMINATE
    int DOS_INT

    ret

int_08_handler:
;    call .handler
;    
;.handler:
;    mov dx, .msg
;    mov ah, PRINT_LINE
;    int DOS_INT
;
;.return:
    ;pop bx
    ;add sp, byte 2
    iret

;initialized data
segment .data
    hello_message   db "This program finds the average time of a tick in ms.", CR_LF, EOL
    goodbye_message db "Goodbye.", CR_LF, EOL
    tick_len_msg    db "The system averaged "
    avg_fmt         dd 0
    end_msg_fin     db " ms per tick", CR_LF, EOL
    clock_divisor   dw 1
    ticks_remaining dw 1
    old_ip          dw 0
    old_seg         dw 0
    msg    db "Tick", CR_LF, EOL

;uninitialized data
segment .bss
    start_time      resw 1
    stop_time       resw 1