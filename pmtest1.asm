; pmtest1.asm

 %include "pm.inc"

org 0100h
    jmp LABEL_BEGIN

[SECTION .gdt]; GDT
    LABEL_GDT: Descriptor 0,0,0
    LABEL_DESC_CODE32: Descriptor 0,SegCode32Len-1, DA_C + DA_32
    LABEL_DESC_VIDEO: Descriptor 0b800h, 0ffffh, DA_DRW

    GdtLen equ $ - LABEL_GDT
    GdtPtr dw GdtLen
           dd 0

    ; GDT 选择子
    SelectorCode32 equ LABEL_DESC_CODE32 - LABEL_GDT
    SelectorVideo equ LABEL_DESC_VIDEO - LABEL_GDT
    
[section .s16]
[bits 16]
LABEL_BEGIN:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0100h

    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_SEG_CODE32
    mov word [LABEL_DESC_CODE32 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE32 + 4 ], al
    mov byte [LABEL_DESC_CODE32 + 7], ah

    ; 准备加载gdtr
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_GDT
    mov dword [GdtPtr + 2], eax

    ; 加载 gdtr
    lgdt [GdtPtr]

    ; 关中断
    cli

    ; 打开地址线A20
    in al, 92h
    or al, 00D00010b
    out 92h, al

    ; 准备切换到保护模式
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; 进入保护方式
    jmp dword SelectorCode32:0

[SECTION .s32]
[bits 32]

LABEL_SEG_CODE32:
    mov ax, SelectorVideo
    mov gs, ax

    mov edi, (80 * 10 + 0) *2
    mov ah, 0ch
    mov al, 'P'
    mov [gs:edi], ax

jmp $

SegCode32Len equ $ - LABEL_SEG_CODE32
