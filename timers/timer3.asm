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
CR      equ 0x0d
LF      equ 0x0a
EOL     equ '$'

; interrupt constants
TIMER_INTERRUPT     equ 0x08
TIMER_INT_IVT       equ TIMER_INTERRUPT*4
USER_TIMER_INT      equ 0x1c
USER_TIMER_IVT      equ USER_TIMER_INT*4

; DOS functions
PRINT_LINE      equ 0x09
GET_TIME        equ 0x2c
TERMINATE       equ 0x4c
DOS_INT         equ 0x21

; MMIO ports
INTA00          equ 0x20
TIMER0          equ 0x40
TIMER_CTL       equ 0x43

EOI             equ 0x20

; BIOS stuff
BIOS_DATA_SEG   equ 0x0040
BIOS_SECONDS    equ 0x006c
BIOS_DAYS       equ 0x0070
TICKS_PER_DAY   equ 0x001800b01
MOTOR_COUNT     equ 0x0040
FDC_CTL_PORT    equ 0x03f2

; code

bits 16
org 0x0100

segment .text

start:
    mov ax, cs
    mov bx, USER_TIMER_INT
    mov dx, int_1c_handler
    call hook_handler
    mov [int_1c_ip],dx
    mov [int_1c_cs],ax

    mov ax, cs
    mov bx, TIMER_INTERRUPT
    mov dx, int_08_handler
    call hook_handler
    mov [int_08_ip],dx
    mov [int_08_cs],ax

    mov bx, 2
    call set_ticks_per_tock
    ;cli
    ;mov word [ticks_per_tock],2
    ;mov word [ticks_since_tock],0
    ;xor ax, ax
    ;out TIMER0, al
    ;mov al, 0x80
    ;out TIMER0, al
    ;sti

    mov cx, 100
.halt:
    hlt
    dec cx
    jnz .halt

;    mov bx, 1
    call reset_ticks
    ;cli
    ;mov word [ticks_per_tock],1
    ;mov word [ticks_since_tock],0
    ;xor ax,ax
    ;out TIMER0, al
    ;out TIMER0, al
    ;sti

    mov ax, [int_1c_cs]
    mov bx, USER_TIMER_INT
    mov dx, [int_1c_ip]
    call hook_handler

    mov ax, [int_08_cs]
    mov bx, TIMER_INTERRUPT
    mov dx, [int_08_ip]
    call hook_handler

    mov dx, GOODBYE
    mov ah, PRINT_LINE
    int DOS_INT
    ret

    GOODBYE db "Goodbye!",CR,LF,EOL


;hooks interrupt handler
;   AX - CS
;   BX - interrupt
;   DX - pointer
;   returns: AX:DX -> old handler
hook_handler:
    push es
    push ax
    xor ax, ax              ;  AX = 0
    mov es, ax              ;  ES = 0
    pop ax
    shl_n 2,bx              ;  BX <<= 2
    cli                     ;  HW interrupts off
    xchg es:[bx], dx        ;  ES:BX <==> DX
    xchg es:[bx+2], ax      ;  ES:BX+2 <==> AX
    sti                     ;  HW interrupts on
    pop es
    ret

; modifies the clock divider in the i8253
; bx - new divider
set_ticks_per_tock:
    push dx
    push ax
    mov dx,1
    xor ax,ax
    div bx

    cli
    mov word [ticks_per_tock],bx
    mov word [ticks_since_tock],0
    out TIMER0, al
    mov al, ah
    out TIMER0, al
    sti

    pop ax
    pop dx
    ret

reset_ticks:
    push ax
    xor ax,ax
    cli
    mov word [ticks_per_tock],1
    mov word [ticks_since_tock],0
    out TIMER0, al
    out TIMER0, al
    sti
    pop ax
    ret

int_08_handler:
    push ax
    push dx
    mov ax, [ticks_since_tock]
    inc ax
    cmp ax, [ticks_per_tock]
    jne .internal_handler
    call clock_handler
    xor ax,ax
.internal_handler:
    mov [ticks_since_tock], al
    mov al, INTA00
    out EOI, al
    ;do our thing
    mov dx, TICK
    mov ah, PRINT_LINE
    int DOS_INT
    pop dx
    pop ax
    iret

    TICK    db "TICK!", CR, LF, EOL

int_1c_handler:
    ;assume CS=DS=ES=SS
    push dx
    push ax
    mov dx, TOCK
    mov ah, PRINT_LINE
    int DOS_INT
    pop ax
    pop dx
    iret

    TOCK    db  "TOCK!", CR, LF, EOL

clock_handler:
    ; virtualbox implementation of the int8 clock handler
    ; i took out the disk drive timeout stuff
    ; 1) who has disk drives anymore?
    ; 2) an extant disk drive would be idle anyway
    sti
    push eax
    push ds
    push dx
    mov ax, BIOS_DATA_SEG
    mov ds, ax
    mov eax, [BIOS_SECONDS]
    inc eax
    cmp eax, TICKS_PER_DAY
    jb .a1
    inc byte [BIOS_DAYS]
.a1:
    pop dx  ; popping dx and ds before the call to INT1C so that
    pop ds  ; the DS is my program's DS
    int USER_TIMER_INT
    cli
    pop eax
    ret

segment .data
    ;strings
    hello_msg db "Testing timer routines", CR, LF, EOL

    ;pointers
    int_08_ip   dw  0
    int_08_cs   dw  0
    int_1c_ip   dw  0
    int_1c_cs   dw  0

    ;data
    ticks_per_tock      dw 1
    ticks_since_tock    dw 0