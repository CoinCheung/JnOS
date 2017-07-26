; 调用一个程序来在屏幕上显示字符串

    ;org 07c00h ; 从07c00处加载程序
    mov ax,cs
    mov ds,ax
    mov es,ax

    call DispStr ; 调用函数显示字符串
    jmp $

; 显示字符串的函数
DispStr:
    mov ax, BootMessage
    mov bp,ax
    mov cx, 16
    mov ax, 01301h
    mov bx, 000ch
    mov dl, 0
    int 10h
    ret


BootMessage: db "hello from boot"  ; db 伪指令表示定义一个字数据占一字节，dw两字节，dd四字节
times 510 - ($ - $$) db 0 ; 写数据0，重复510 - ($ - $$)次，其中 $ 是当前指令位置，$$是段开始的位置。这一句是将剩下空间都填上0,一直到510字节的位置
dw 0xaa55 ; 将第512个字节填充上结束标志位 aa55

