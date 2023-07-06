;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ASM FLOWERBOX                                                               ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INTERRUPT HANDLER                                                           ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;HANDLER_LABEL:                  ; Entry-point in memory
                                ; this is where the IVT points to
%macro irq_handler 1
    call NEAR .real_handler     ; call to the actual handler code
    .chain_pointer dd %1         ; 16:16 pointer to the original handler
                                ; or to F000:FF53

.real_handler:                  ; Actual code for handling the interrupt
                                ; we call here so that [SP+2] points to
                                ; chain_pointer
    push bx
    mov bx, sp
    mov bx, [ss:bx+2]           ; save chain_pointer in BX
%endmacro

%macro irq_ret 0
    pushf                       ; do we need this?
    call FAR [bx]
    pop bx
    add sp, BYTE 2
    iret
%endmacro

my_irq_handler:
    irq_handler 0
    ; do irq stuff
    irq_ret


; jump table implementation

; code:
; get data that provides offset
mov bx, [data_src]
; adjust bx for address width
; bx <<= 0 for byte width
; bx <<= 1 for word width
; bx <<= 2 for dword width
; bx <<= 3 for qword width
; example uses word
shl bx, 1
add bx, .jump_labels    ; this doesn't have to be  '.jump_labels' but
                        ; it should be local
mov bx, [bx]
jmp bx                  ; for some reason it doesn't seem to work
                        ; if you just jmp [bx] ¯\_(ツ)_/¯

.return_label:
    ;more of the program
    ret

;
; other program code if desired
;

; must have one label for every value you expect
.jump_labels:
    dw .label1
    dw .label2
    times 2 dw .label3  ; fall-through

.label1:
    ; do stuff
    jmp .return_label

.label2:
    ; do stuff
    jmp .return_label

.label3:
    ; do stuff
    jmp .return_label