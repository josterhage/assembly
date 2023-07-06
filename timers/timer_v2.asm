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
    cmp ax, IBM_INT8_HANDLER_CS     ; if the segment pointer == f000, we're set
    je .set_int08_chain_ptr

    mov [dos_ptr], bx               ; if segment isn't f000 save the
    mov [dos_ptr+2], ax             ; pointer to the DOS handler

    push es
    mov es, ax                      ; and get a pointer to the BIOS handler
    mov ax, es:[bx+2]               ; all the DOS handler does is
    mov bx, es:[bx]                 ; set aside some extra stack space
                                    ; but we don't need extra stack space
    pop es

.set_int08_chain_ptr:
    mov [int_08_handler.chain_ptr], bx
    mov [int_08_handler.chain_ptr+2], ax

    ; establish ourselves as the int08 handler
    cli
    mov word es:[TIMER_INT_IVT],int_08_handler
    mov es:[TIMER_INT_IVT+2],ds
    sti

;modify timer0 countdown
;time ticks
;restore interrupt handler
    mov ax, [dos_ptr+2]
    and ax,ax
    jz .save_bios_ptr
    mov bx, [dos_ptr]
    jmp .restore_handler

.save_bios_ptr:
    mov ax, [int_08_handler.chain_ptr]
    mov bx, [int_08_handler.chain_ptr+2]

.restore_handler:
    xor cx,cx
    mov es, cx
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
    call .handler
    .chain_ptr dd 1

.handler:
    push bx
    mov bx, sp
    mov bx, [bx+2]
    call [bx]


    .msg    db "Tick", CR_LF, EOL
    mov dx, .msg
    mov ah, PRINT_LINE
    int DOS_INT

.return:
    pop bx
    add sp, byte 2
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
    dos_ptr         dd 0

;uninitialized data
segment .bss
    start_time      resw 1
    stop_time       resw 1