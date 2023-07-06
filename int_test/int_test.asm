;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MACROS                                ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%macro shl_n 2
%rep %1
    shl %2, 1
%endrep
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CONSTANTS                             ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%define CR_LF           0x0d, 0x0a
%define EOL             '$'


; DOS Interrupt Functions
%define PRINT_LINE      0x09
%define TERMINATE       0x4c

; INTERRUPTS
%define DOS_INT         0x21
%define CUSTOM_INT      0x50

bits 16
org 0x0100

start:
    mov bx, ds
    mov es, bx ; es should equal ds, but just in case
    mov bl, CUSTOM_INT
    mov dx, custom_handler
    call hook_vector

    int CUSTOM_INT

    mov ah, TERMINATE
    int DOS_INT
    ret

custom_handler:
    nop
    iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; hook_vector                           ;
;   replaces a pointer in the IVT and   ;
;   return the old value                ;
;                                       ;
;   PARAMETERS:                         ;
;       BL - Vector to hook             ;
;       ES:DX - pointer to new handler  ;
;                                       ;
;   RETURNS:                            ;
;       ES:DX - pointer to old handler  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

hook_vector:
    push ax
    push ds
    xor ax,ax
    mov ds,ax           ; read from segment 0000
    and bx, 0x00ff
    shl_n 3, bx         ; vector * 4 = base address of far pointer
    xchg ds:[bx],dx     ; swap the instruction pointer
    mov ax, es
    xchg ds:[bx+2],ax   ; swap the segment pointer
    mov es, ax          ; save the segment pointer to es
    pop ds
    pop ax
    ret