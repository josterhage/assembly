; print hello message
; hook INT 08h
; start counting
; finish counting
; restore tick vector
; find quotient
; return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
; TIMER.ASM                                                                    ;
;   FIND THE AVERAGE TIME IN ms BETWEEN TWO TIMER TICKS AFTER 128 TICKS        ;
;                                                                              ;
;   Modifies the PIT Timer 0 interval, multiplying the default ticks/second    ;
;   by an integer multiple N and hooks INT 0x08, calling the system handler    ;
;   once every N ticks to ensure time of day functioning                       ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MACROS                                ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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

%define CR_LF           0x0d, 0x0a
%define EOL             '$'

%define TIMER_INTERRUPT 0x08

%define GET_CHAR        0x01
%define PRINT_LINE      0x09
%define GET_TIME        0x2c
%define TERMINATE       0x4c

%define DOS_INT         0x21

%define TIMER0          0x40
%define TIMER_CTL       0x43

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CODE SECTION                          ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

bits 16
org 0x0100

segment .text

start:
; print hello message
    mov dx, hello_message
    mov ah, PRINT_LINE
    int DOS_INT

    call set_int08_handler

    hlt

    call restore_int08_handler

    mov ah, TERMINATE
    int DOS_INT
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Interrupt handlers                                                           ;
;   This program defines a handler for int 0x08                                ;
;   The handler calls the system handler every N ticks and an internal handler ;
;   every single tick                                                          ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; interrupt 0x08 handler                ;
;   assumes that CS is the same as the  ;
;   program's DS, but that DS, ES, and  ;
;   SS have been modified by other code ;
;                                       ;
;   calls the system handler every N    ;
;   ticks, calls a local handler every  ;
;   single tick                         ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

int_08_handler:
    call NEAR .handler
    .chain_pointer      dd 0
    .callback_pointer   dw 0

.handler:
    push bx
    mov bx, sp
    mov bx, [ss:bx+2]   ;120
    test bx, bx          ; check for a null pointer
    jz .return

    ; call the handler chain if necessary
;    dec WORD [ticks_remaining]
;    jnz .callbacks
    call FAR [bx]
;    push ax
;    mov ax,[clock_divisor]
;    mov [ticks_remaining],ax
;    pop ax
;
;    ; iterate through the internal callbacks
;.callbacks:
;    mov bx, sp
;    mov bx, [ss:bx+6]
;    test bx,bx
;    jz .return
;
;.callback_loop:
;    mov bx, [bx]    ; get first callback function pointer
;    test bx, bx     ; check for null
;    jz .return
;    call NEAR [bx]  ; call the pointed function
;    mov bx, [bx+2]  ; get the pointer to the next node
;    test bx, bx     ; check for null
;    jnz .callback_loop
;
.return:
    pop bx
    add sp, BYTE 2
    iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; PROCEDURES                                                                   ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

set_int08_handler:
    push es
    push ax
    push bx
    xor ax, ax
    mov es, ax
    mov bx, 8
    shl bx, 1
    shl bx, 1
    mov ax, bx
    mov bx, [es:bx]
    mov [int_08_handler.chain_pointer], bx
    mov bx, ax
    mov bx, [es:bx+2]
    mov [int_08_handler.chain_pointer+2],bx
    mov bx, ax
    xor ax,ax
    mov [int_08_handler.callback_pointer], ax
    cli
    mov WORD [es:bx], int_08_handler
    mov [es:bx+2], cs
    sti
    pop bx
    pop ax
    pop es
    ret

restore_int08_handler:
    push es
    push ax
    push bx
    xor ax, ax
    mov es, ax
    mov bx, 8
    shl bx, 1
    shl bx, 1
    cli
    mov ax, [int_08_handler.chain_pointer]
    mov [es:bx], ax
    mov ax, [int_08_handler.chain_pointer+2]
    mov [es:bx+2], ax
    sti
    pop bx
    pop ax
    pop es
    ret

tick_handler:
    dec BYTE [ticks]
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; hook_vector                           ;
;   replaces a pointer in the IVT and   ;
;   returns the old pinter              ;
;                                       ;
;   PARAMETERS:                         ;
;       BL - Vector to hook             ;
;       ES:DX - pointer to new handler  ;
;                                       ;
;   RETURNS:                            ;
;       ES:DX - pointer to old handler  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

hook_vector:
    push ax                 ; save ax
    push ds                 ; save data segment
    xor ax,ax               ; ax = 0
    mov ds,ax               ; look to 0 for vectors
    xor bh,bh               ; ensure bh is zeroed
    shl_n 2, bx             ; vector * 4 = base address of far pointer
    cli
    xchg ds:[bx],dx         ; 0:[vector] = new ip, dx = old ip
    mov ax, es              ; ax = new segment
    xchg ds:[bx+2],ax       ; 0:[vector+2] = new segment, ax = old seg
    mov es, ax              ; es = old segment
    sti
    pop ds                  ; restore data segment
    pop ax                  ; restore ax
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Global variables                      ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .data
; vectors

    hello_message       db "Find the average time for a tick in ms.", CR_LF, EOL
    clock_divisor_q     db "What divisor shall we use? ", EOL
    end_msg_begin       db "The system averaged "
    avg_fmt             dd 0
    end_msg_fin         db " ms per tick", CR_LF, EOL
    clock_divisor       dw 1
    ticks_remaining     dw 1

section .bss
; vectors
    int_08_ip                   resw 1
    int_08_segment              resw 1

; time data
    divisor         resb 1
    ticks           resb 1
    start_time      resw 1
    stop_time       resw 1