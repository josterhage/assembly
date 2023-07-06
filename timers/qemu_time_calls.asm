;f000:7047
x7047:
    test ecx,ecx                    ;f000:7047
    jz .7054                        ;f000:704a
    dec ecx                         ;f000:704c
    mov [eax+ecx],dl                ;f000:704e
    jmp x7047                       ;f000:7052
.x7054:
    ret                             ;opcode appears to be for a 16-bit ret?

xf7a07:
    push edi
    push esi
    push ebx
    mov bx, ss
    movzx ebx, bx
    cmp ebx, 0x0000d980
    jnz xf7a5a          ; from observation this will likely always be nonzero

xf7a5a:
    pop ebx
    pop esi
    jmp ecx
xf7a63:
    mov edx, 0x00000040
    mov es, dx
    mov dx, es:[0x0013]
    mov [eax+0x1c], dx
    ret

;f000:7fcd
x7fcd:
    mov [eax+0x20], dx              ;f000:7fcd
    mov dx, cs                      ;f000:7fd1
    mov [eax+0x22],dx               ;f000:7fd3
    mov dx, ss                      ;f000:7fd7
    movzx edx, dx                   ;f000:7fd9
    jmp .x7f82                      ;f000:7fdd

.x7f82:
    push edi                        ;f000:7f82
    push esi                        ;f000:7f84
    push ebx                        ;f000:7f86
    push esi                        ;f000:7f88
    mov ebx, eax                    ;f000:7f8a
    mov [esp], edx                  ;f000;7f8d
    call 0x00006bed                 ;f000:7f92
    test eax, eax                   ;f000:7f98
    mov edx, [esp]                  ;f000:7f9b
    jz .x7fba                       ;f000:7fa0
    movzx edx,dx                    ;f000:7fa2
    mov ecx, 0x00007f82             ;f000:7fa6
    mov eax, ebx                    ;f000:7fac
    pop ebx                         ;f000:7faf
    pop ebx                         ;f000:7fb1
    pop esi                         ;f000:7fb3
    pop edi                         ;f000:7fb5
    jmp .x7a07                      ;f000:7fb7
.x7fba:
    mov eax, ebx                    ;f000:7fba
    call 0x0000cfd3                 ;f000:7fbd
    pop eax                         ;f000:7fc3
    pop ebx                         ;f000:7fc5
    pop esi                         ;f000:7fc7
    pop edi                         ;f000:7fc9
    ret                             ;f000:7fcb  (o16 ret)

x6bed:
    mov ax, ss                      ;f000:6bed
    movzx eax, ax                   ;f000:6bef
    xor edx, edx                    ;f000:6bf3
    cmp eax, 0x0000d980             ;f000:6bf6
    jnz .x6c0d                      ;f000:6bfc
    mov eax, esp                    ;f000:6cbfe
    xor edx, edx                    ;f000:6c01
    cmp eax, 0x0000f558             ;f000:6c04
    seta dl                         ;f000:6c0a
.x6c0d:
    mov eax, edx                    ;f000:6c0d
    ret                             ;f000:6c10 (o16 ret)

xcfd3:                              ; stack: 7fbd
    push ebp                        ; stack: 7fbdxxxxxxxx
    push eax                        ; stack: 7fbdxxxxxxxxxxxxxxxx
    push edx                        ; stack: 7fbdxxxxxxxxxxxxxxxxxxxxxxxx
    mov ds, dx
    push cs                         ; stack: 7fbdxxxxxxxxxxxxxxxxxxxxxxxxf000
    push 0xd015                     ; stack: 7fbdxxxxxxxxxxxxxxxxxxxxxxxxf000d015
    push word [eax+0x24]            ; stack: 7fbdxxxxxxxxxxxxxxxxxxxxxxxxf000d015xxxx
    push dword [eax+0x20]           ; stack: 7fbdxxxxxxxxxxxxxxxxxxxxxxxxf000d015xxxxxxxxxxxx
    mov edi, [eax+4]
    mov esi, [eax+0x08]
    mov ebp, [eax+0x0c]
    mov ebx, [eax+0x10]
    mov edx, [eax+0x14]
    mov ecx, [eax+0x18]
    mov word es, [eax+2]
    push dword [eax+0x1c]           ; stack: 7fbdxxxxxxxxxxxxxxxxxxxxxxxxf000d015xxxxxxxxxxxxxxxxxxxx
    mov word ds, [eax]
    pop eax
    iret

;f000:72f5
x72f5:
    mov ecx, 0x0000d980
    mov es, cx
    mov cl, es:[0xf4e0]
    not eax
    and eax, ecx
    or eax, edx
    mov edx, 0x000003f2
    out dx, al
    umov es:[f4e0],al
    ret ;(o16?) f15c (opt1)

;f000:84b3
x84b3:
    push edi                    ;f000:b4b3
    push esi                    ;f000:f4b5
    push ebx                    ;f000:
    mov bl, al
    xor esi, esi
    movzx edi, dl
    test bl, bl
    jz 0x8500
    movzex eax, bl
    mov ecx, esi
    sar eax, cl
    test al, 01
    jz 0x84fc
