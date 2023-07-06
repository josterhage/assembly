; CS = f000
; org: fea5

push 0x0000f0fc     ; pointer to be used later
jmp .d2d2

.d2d2:
    cli                         ;f000:d2d2
    cld                         ;f000:d2d3
    push ds                     ;f000:d2d4      stack: fcf00000DSDS
    push eax                    ;f000:d2d5      stack: fcf00000DS16EAXEAX32
    mov eax, 0x0000d980         ;f000:d2d7
    mov ds, ax                  ;f000:d2dd      ds = 0xd980
    mov eax, [0xf550]           ;f000:d2df      
                                ;values seen: 0x0000fd58
                                ;
    sub eax, 0x28               ;f000:d2e3      eax = 0x0000fd30
    pop dword ptr [eax+0x1c]    ;f000:d2e7      EAXEAX32 => d980:fd4c
    pop word ptr [eax]          ;f000:d2ec      DS16 => d980:fd30      stack: fcf00000
    mov [eax+0x04], edi         ;f000:d2ef
    mov [eax+0x08], esi         ;f000:d2f4
    mov [eax+0x0c], ebp         ;f000:d2f9
    mov [eax+0x10], ebx         ;f000:d2fe
    mov [eax+0x14], edx         ;f000:d303
    mov [eax+0x18], ecx         ;f000:d308
    mov WORD [eax+0x02],es      ;f000:d30d
    pop ecx                     ;f000:d311      ecx = 0000f0fc
    mov [eax+0x20], esp         ;f000:d313
    mov word [eax+0x24], ss     ;f000:d318
    mov dx, ds                  ;f000:d31c      dx = 0xd980
    mov ss, dx                  ;f000:d31e      ss = 0xd980
    mov esp, eax                ;f000:d320      esp = 0xfd30
    call .f0fc                  ;f000:d323

; it looks like the actual clock handler is at f000:f0fc
; the code starting at f000:d2d2:
; saves the processor state in memory starting at d980:fd30
;       including the stack segment and stack pointer
; sets SS:ESP => d980:0000fd30
; calls the real clock handler

; this is a really weird stack frame, all these values are already on the stack
.f0fc:
    push ebp                                ;f000:f0fc      esp = fd2c
    push edi                                ;f000:f0fe      esp = fd28
    push esi                                ;f000:f100      esp = fd24
    push ebx                                ;f000:f102      esp = fd20
    sub esp, 0x38                           ;f000:f104      esp = fce8
    mov eax, 0x00000040                     ;f000:f108
    mov es, ax                              ;f000:f10e      this is the same data segment location as the virtual-box bios
    mov eax, es:[0x006c]                    ;f000:f110      and the same pointer to the seconds DWORD
    inc eax                                 ;f000:f115
    cmp eax, 0x001800af                     ;f000:f117      one tick less than the virtual-box and IBM versions
    jbe .f12c                               ;f000:f11d    
.f11f:
    mov al, es:[0x0070]                     ;f000:f11f
    inc eax                                 ;f000:f123
    mov es:[0x0070], al                     ;f000:f125      increment the day
    xor eax, eax                            ;f000:f129
.f12c:          ; why does this section re establish the extra segment?
    mov edx, 0x00000040                     ;f000:f12c
    mov es, dx                              ;f000:f132
    mov es:[0x006c], eax                    ;f000:f134
    mov es, dx                              ;f000:f139
    mov al, es:[0x0040]                     ;f000:f13b      is 40:40 the drive status byte?
    test al, al                             ;f000:f13f
    jz .f15c                                ;f000:f141

.f15c:
    mov eax, cs:[0x6030]                    ;f000:f15c      *ptr = 0
    mov [esp], eax                          ;f000:f161 
    test eax, eax                           ;f000:f166
    jz .f306                               ;f000:f169

.f306:
    mov esi, cs:[0x602c]                    ;f000:f306      *ptr = 0
    test esi, esi                           ;f000:f30c
    jz .f37f

.f37f:
    mov eax, 0x0000d980                     ;f000:f37f
    mov edi, eax                            ;f000:f385
    mov es, ax                              ;f000:f388
    mov bp, es:[f514]                       ;f000:f38a      *ptr = 0
    test bp, bp
    jz .f4d6

.f4d6:
    mov ecx, 0x00000026                     ;f000:f4d6
    xor edx, edx                            ;f000:f4dc
    lea eax, [esp+0x12]                     ;f000:f4df
    call 0x00007047                         ;f000:f4e5
    mov word [esp+0x32],0x0200              ;f000:f4eb
    mov edx, 0x0000e829                     ;f000:f4f2
    movzx edx, dx                           ;f000:f4f8
    call 0x00007fcd                         ;f000:f4fc
    mov al, 0x20                            ;f000:f502
    out 0x20,al                             ;f000:f504
    add esp, 0x38                           ;f000:f506
    pop ebx                                 ;f000:f50a
    pop esi                                 ;f000:f50c
    pop edi                                 ;f000:f50e
    pop ebp                                 ;f000:f510
    ret                                     ;f000:f512      (o16 ret)

;;;;;;;;;;;;;;;;;;;;;;;
; likely not executed ;
;;;;;;;;;;;;;;;;;;;;;;;
.f143:
    dec eax                                 ;f000:f143
    mov es:[0x0040], al                     ;f000:f145
    test al, al                             ;f000:f149
    jnz .f15c   ;f15c                       ;f000:f14b
.f14d
    xor edx, edx                            ;f000:f14d
    mov eax, 0x000000f0                     ;f000:f150
    call 0x000072f5   ;f000:72f5            ;f000:f156
;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;
; likely not executed ;
;;;;;;;;;;;;;;;;;;;;;;;
.f16d:
    lea edx, [esp+12]                       ;f000:f16d
    mov eax, [esp]                          ;f000:f173
    call 0x00007c1f                         ;f000:f178
    mov edi, eax                            ;f000:f17e
    test eax, eax                           ;f000:f181
    jnz 0xf306                              ;f000:f184
.f188:
    mov dword [esp+4], 0x0000d980           ;f000:f188
    mov es, word [esp+4]                    ;f000:f192
    mov ebp, es:[0xf4e4]                    ;f000:f197
    mov eax, es:[0xf4e8]                    ;f000:f19d
    mov [esp+8], ebp                        ;f000:f1a2
    mov [esp+0x0c],eax                      ;f000:f1a8
    xor esi,esi                             ;f000:f1ae
    mov ebx, 00000001                       ;f000:f1b1
.f1b7:
    mov dl, [esp:ebx+9]                     ;f000:f1b7
    test dl, dl                             ;f000:f1bc
    jz .f22f                                ;f000:f1be
.f1c0:
    xor eax, eax                            ;f000:f1c0
.f1c3:
    cmp dl, [esp:eax+0x14]                  ;f000:f1c3
    jnz .f1e7                               ;f000:f1c8
    mov byte [esp:eax+0x14],0               ;f000:f1ca
    lea eax, [esi+1]                        ;f000:f1d0
    mov [esp:esi+0x0a], dl                  ;f000:f1d5
    inc ebx                                 ;f000:f1da
    cmp ebx, 7                              ;f000:f1dc
    jnz 0xf22a                              ;f000:f1e0
.f1e2:
    mov esi, eax                            ;f000:f1e2
    jmp 0xf22f                              ;f000:f1e5
.f1e7:
    inc eax                                 ;f000:f1e7
    cmp eax, 6                              ;f000:f1e9
    jnc .f1c3                               ;f000:f1ed
.f1ef:
    movzx   byte ecx, [esp+0x12]            ;f000:f1ef
    movzx   eax, dl                         ;f000:f1f6
    mov edx, 0x00000080                     ;f000:f1fa
    call dword 0x0000fa47                   ;f000:f200
    cmp ebx, 6                              ;f000:f206
    jnz 0xf214                              ;f000:f20a
.f20c:
    mov byte [esp+9], 0xff                  ;f000:f20c
    jmp 0xf22f                              ;f000:f212
.f214:
    cmp byte [esp:ebx+0xa],0                ;f000:f214
    lea ebx, [ebx+1]                        ;f000:f21a
    jnz 0xf227                              ;f000:f21f
.f221:
    mov byte [esp+9], 0xff                  ;f000:f221
    mov eax, esi                            ;f000:f227
    mov esi, eax                            ;f000:f22a
    jmp .f1b7                               ;f000:f22d
.f22f:
    mov al, [esp+0x12]                      ;f000:f22f
    not eax                                 ;f000:f234
    and eax, ebp                            ;f000:f237
    movzx eax, al                           ;f000:f23a
    mov edx, 0x00000080                     ;f000:f23e
    call 0x000084b3                         ;f000:f244
    mov eax, ebp                            ;f000:f24a
    not eax                                 ;f000:f24d
    and al, [esp+0x12]                      ;f000:f250
    movzx eax, al                           ;f000:f255
    xor edx, edx                            ;f000:f259
    call dword 0x000084b3                   ;f000:f25c
    mov al, [es]+0x12                       ;f000:f262
    mov [esp+0x08],al                       ;f000:f267
    mov bl, [esp:edi+0x14]                  ;f000:f26c
;;;;;;;;;;;;;;;;;;;;;;;