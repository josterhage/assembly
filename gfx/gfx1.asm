%define VIDEO_MEMORY_SEGMENT 0xA000

bits 16
org 0x0100

section .text

start:
; setup the graphics mode
	mov ax, 0x000d
	int 0x10
; call the drawing function
	push ds
	mov ax, VIDEO_MEMORY_SEGMENT
	mov ds, ax
	xor bx, bx
	add bx, 400
	mov al, [bx] 
	mov dx, 0x03CE
	mov ax, 0x0205
	out dx, ax
	mov ax, 0x0003
	out dx, ax
	mov ax, 0xff08
	out dx, ax
	mov al, 0xff
	mov [bx], al
	mov [bx+1], al
	mov [bx+2],al


	pop ds
	mov dx, press_any_key_message
	mov ah, 0x09
	int 0x21 
; wait for a key
	call wait_for_key
; return to text mode
	mov ax, 0x0002
	int 0x10
; exit
	int 0x20
	ret

wait_for_key:
	mov ah, 0x0b
	int 0x21
	and al, al
	jz wait_for_key
	ret

section .data
	press_any_key_message db "Press any key to continue...", 0x0d, 0x0a, '$'

