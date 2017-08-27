; ==========================================
; pmtest5.asm
; 编译方法：nasm pmtest5.asm -o pmtest5.com
; ==========================================

%include	"pm.inc"	; 常量, 宏, 以及一些说明

org	0100h
	jmp	LABEL_BEGIN

[SECTION .gdt]
; GDT
;                                         段基址,         段界限     , 属性
LABEL_GDT:		Descriptor	       0,                   0, 0			; 空描述符
LABEL_DESC_NORMAL:	Descriptor	       0,              0ffffh, DA_DRW			; Normal 描述符
LABEL_DESC_CODE32:	Descriptor	       0,    SegCode32Len - 1, DA_C + DA_32		; 非一致代码段, 32
LABEL_DESC_CODE16:	Descriptor	       0,              0ffffh, DA_C			; 非一致代码段, 16
LABEL_DESC_CODE_DEST:	Descriptor	       0,  SegCodeDestLen - 1, DA_C + DA_32		; 非一致代码段, 32
LABEL_DESC_CODE_RING3:	Descriptor	       0, SegCodeRing3Len - 1, DA_C + DA_32 + DA_DPL3	; 非一致代码段, 32
LABEL_DESC_DATA:	Descriptor	       0,	  DataLen - 1, DA_DRW			; Data
LABEL_DESC_STACK:	Descriptor	       0,          TopOfStack, DA_DRWA + DA_32		; Stack, 32 位
LABEL_DESC_STACK3:	Descriptor	       0,         TopOfStack3, DA_DRWA + DA_32 + DA_DPL3; Stack, 32 位
LABEL_DESC_LDT:		Descriptor	       0,          LDTLen - 1, DA_LDT			; LDT
LABEL_DESC_TSS:		Descriptor	       0,          TSSLen - 1, DA_386TSS		; TSS
LABEL_DESC_VIDEO:	Descriptor	 0B8000h,              0ffffh, DA_DRW + DA_DPL3		; 显存首地址

; 门                                            目标选择子,       偏移, DCount, 属性
LABEL_CALL_GATE_TEST:	Gate		  SelectorCodeDest,          0,      0, DA_386CGate + DA_DPL3
; GDT 结束

GdtLen		equ	$ - LABEL_GDT	; GDT长度
GdtPtr		dw	GdtLen - 1	; GDT界限
		dd	0		; GDT基地址

; GDT 选择子
SelectorNormal		equ	LABEL_DESC_NORMAL	- LABEL_GDT
SelectorCode32		equ	LABEL_DESC_CODE32	- LABEL_GDT
SelectorCode16		equ	LABEL_DESC_CODE16	- LABEL_GDT
SelectorCodeDest	equ	LABEL_DESC_CODE_DEST	- LABEL_GDT
SelectorCodeRing3	equ	LABEL_DESC_CODE_RING3	- LABEL_GDT + SA_RPL3
SelectorData		equ	LABEL_DESC_DATA		- LABEL_GDT
SelectorStack		equ	LABEL_DESC_STACK	- LABEL_GDT
SelectorStack3		equ	LABEL_DESC_STACK3	- LABEL_GDT + SA_RPL3
SelectorLDT		equ	LABEL_DESC_LDT		- LABEL_GDT
SelectorTSS		equ	LABEL_DESC_TSS		- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	- LABEL_GDT  ; 门描述符放在GDT里面，作为GDT的一项，选择子的定义方式也是跟段选择子差不多。但是门描述符不直接对应一个段，门描述符里面有一个段选择子和一个offset，这个选择子和offset是用来指定这个门对应的位置的。
    ; 所以可以把门看成是普通的代码段，这个代码段在内存段的某个位置，用门描述符来定义的时候要指定好这个代码段放在哪个段的哪个位置(selector和offset)，然后把这个门描述符也像正常的段描述符一样放在GDT里面。这样访问这个门时就是用门描述符在内存中找到对应的代码再进一步的操作。

SelectorCallGateTest	equ	LABEL_CALL_GATE_TEST	- LABEL_GDT + SA_RPL3
; END of [SECTION .gdt]

[SECTION .data1]	 ; 数据段
ALIGN	32
[BITS	32]
LABEL_DATA:
SPValueInRealMode	dw	0
; 字符串
PMMessage:		db	"In Protect Mode now. ^-^", 0	; 进入保护模式后显示此字符串
OffsetPMMessage		equ	PMMessage - $$
StrTest:		db	"ABCDEFGHIJKLMNOPQRSTUVWXYZ", 0
OffsetStrTest		equ	StrTest - $$
DataLen			equ	$ - LABEL_DATA
; END of [SECTION .data1]


; 全局堆栈段
[SECTION .gs]
ALIGN	32
[BITS	32]
LABEL_STACK:
	times 512 db 0
TopOfStack	equ	$ - LABEL_STACK - 1
; END of [SECTION .gs]


; 堆栈段ring3
[SECTION .s3]
ALIGN	32
[BITS	32]
LABEL_STACK3:
	times 512 db 0
TopOfStack3	equ	$ - LABEL_STACK3 - 1
; END of [SECTION .s3]


; TSS ---------------------------------------------------------------------------------------------
[SECTION .tss]
ALIGN	32
[BITS	32]
LABEL_TSS:   		DD	0			; Back
		DD	TopOfStack		; 0 级堆栈
		DD	SelectorStack		; 
		DD	0			; 1 级堆栈
		DD	0			; 
		DD	0			; 2 级堆栈
		DD	0			; 
		DD	0			; CR3
		DD	0			; EIP
		DD	0			; EFLAGS
		DD	0			; EAX
		DD	0			; ECX
		DD	0			; EDX
		DD	0			; EBX
		DD	0			; ESP
		DD	0			; EBP
		DD	0			; ESI
		DD	0			; EDI
		DD	0			; ES
		DD	0			; CS
		DD	0			; SS
		DD	0			; DS
		DD	0			; FS
		DD	0			; GS
		DD	0			; LDT
		DW	0			; 调试陷阱标志
		DW	$ - LABEL_TSS + 2	; I/O位图基址
		DB	0ffh			; I/O位图结束标志
TSSLen		equ	$ - LABEL_TSS
; TSS ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


[SECTION .s16]
[BITS	16]
LABEL_BEGIN:   ; 程序的入口，一开始实模式的时候运行的代码
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, 0100h

	mov	[LABEL_GO_BACK_TO_REAL+3], ax  ; 这个其实也可以在数据区 dd一个变量realcs dd 0 存储实模式下的cs值，然后回到实模式后用jmp [realcs]:label跳回来，都是一样的。 

	mov	[SPValueInRealMode], sp

    ; 下面是修改一下上面定义的段描述符的基址，这样得到的描述符对应的就是真正的段了。但是这种可以在实模式下用cs和label修改的段描述符对应的段其实完全可以直接在实模式下寻址到。所以真正要发挥1M以上的寻址能力的话，这种方法其实不是特别有用。


	; 初始化 16 位代码段描述符
	mov	ax, cs
	movzx	eax, ax
	shl	eax, 4
	add	eax, LABEL_SEG_CODE16
	mov	word [LABEL_DESC_CODE16 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE16 + 4], al
	mov	byte [LABEL_DESC_CODE16 + 7], ah

	; 初始化 32 位代码段描述符
	xor	eax, eax
	mov	ax, cs
	shl	eax, 4
	add	eax, LABEL_SEG_CODE32
    ; 到这，eax里面的值就是LABEL_SEG_CODE32的物理地址
    ; 下面修改了LABEL_DESC_CODE32这个段描述符的基地址，把这个地址改成了eax里面的LABEL_SEG_CODE32的地址值，也就是说前面那么定义仅仅是占一个地方，具体多少值都是在这个里面重新赋值的。
    ; 这个套路在实际使用时不一定适用，因为这里面可以这样改的基地址都是可以在实模式下寻址到的地址，所以没有发挥出保护模式更大的寻址能力。实际使用时，还是应该在定义时就确定好分段的基地址和段界限，就算后面要改也不 是像这样就实模式下的label地址来改。
	mov	word [LABEL_DESC_CODE32 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE32 + 4], al
	mov	byte [LABEL_DESC_CODE32 + 7], ah

	; 初始化测试调用门的代码段描述符
	xor	eax, eax
	mov	ax, cs
	shl	eax, 4
	add	eax, LABEL_SEG_CODE_DEST
	mov	word [LABEL_DESC_CODE_DEST + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE_DEST + 4], al
	mov	byte [LABEL_DESC_CODE_DEST + 7], ah

	; 初始化数据段描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_DATA
	mov	word [LABEL_DESC_DATA + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_DATA + 4], al
	mov	byte [LABEL_DESC_DATA + 7], ah

	; 初始化堆栈段描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_STACK
	mov	word [LABEL_DESC_STACK + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_STACK + 4], al
	mov	byte [LABEL_DESC_STACK + 7], ah

	; 初始化堆栈段描述符(ring3)
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_STACK3
	mov	word [LABEL_DESC_STACK3 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_STACK3 + 4], al
	mov	byte [LABEL_DESC_STACK3 + 7], ah

	; 初始化 LDT 在 GDT 中的描述符
    ; 这个是用来存放LDT的段的描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_LDT
	mov	word [LABEL_DESC_LDT + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_LDT + 4], al
	mov	byte [LABEL_DESC_LDT + 7], ah

	; 初始化 LDT 中的描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_CODE_A
	mov	word [LABEL_LDT_DESC_CODEA + 2], ax
	shr	eax, 16
	mov	byte [LABEL_LDT_DESC_CODEA + 4], al
	mov	byte [LABEL_LDT_DESC_CODEA + 7], ah

	; 初始化Ring3描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_CODE_RING3
	mov	word [LABEL_DESC_CODE_RING3 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE_RING3 + 4], al
	mov	byte [LABEL_DESC_CODE_RING3 + 7], ah

	; 初始化 TSS 描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_TSS
	mov	word [LABEL_DESC_TSS + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_TSS + 4], al
	mov	byte [LABEL_DESC_TSS + 7], ah

	; 为加载 GDTR 作准备
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_GDT		; 到这，eax里面的值是label_gdt的物理地址

	mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

	; 加载 GDTR
	lgdt	[GdtPtr]

	; 关中断
	cli

	; 打开地址线A20
	in	al, 92h
	or	al, 00000010b
	out	92h, al

	; 准备切换到保护模式
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax  ; 置位cr0的最低位pe后，就是保护模式了，开始使用逻辑地址寻址了。下面为了代码逻辑清楚，再跳到另一个段里面去执行保护模式下的代码


	; 真正进入保护模式
	jmp	dword SelectorCode32:0	; 执行这一句会把 SelectorCode32 装入 cs, 并跳转到 Code32Selector:0  处

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LABEL_REAL_ENTRY:		; 从保护模式跳回到实模式就到了这里
	mov	ax, cs ; 跳到这了之后，cs的值就是原来一开始进入保护模式之前的值了，用这个值初始化一下其他的段寄存器就好了。
    ; 最开始修改跳回来时的段地址用的也是这个cs。

	mov	ds, ax
	mov	es, ax
	mov	ss, ax

	mov	sp, [SPValueInRealMode]

	in	al, 92h		; ┓
	and	al, 11111101b	; ┣ 关闭 A20 地址线
	out	92h, al		; ┛

	sti			; 开中断

	mov	ax, 4c00h	; ┓
	int	21h		; ┛回到 DOS
; END of [SECTION .s16]


[SECTION .s32]; 32 位代码段. 由实模式跳入.
[BITS	32]

LABEL_SEG_CODE32: ; 刚进入保护模式
	mov	ax, SelectorData
	mov	ds, ax			; 数据段选择子
	mov	ax, SelectorVideo
	mov	gs, ax			; 视频段选择子

	mov	ax, SelectorStack
	mov	ss, ax			; 堆栈段选择子

	mov	esp, TopOfStack


	; 下面显示一个字符串
	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	xor	esi, esi
	xor	edi, edi
	mov	esi, OffsetPMMessage	; 源数据偏移
	mov	edi, (80 * 10 + 0) * 2	; 目的数据偏移。屏幕第 10 行, 第 0 列。
	cld
.1:
	lodsb
	test	al, al
	jz	.2
	mov	[gs:edi], ax
	add	edi, 2
	jmp	.1
.2:	; 显示完毕

	call	DispReturn

	; Load TSS   
    ; TSS需要作为一个段用段描述符来描述，并且需要用ltr selector来加载使用
	mov	ax, SelectorTSS
	ltr	ax	; 在任务内发生特权级变换时要切换堆栈，而内层堆栈的指针存放在当前任务的TSS中，所以要设置任务状态段寄存器 TR。

    ; 下面是把 ring3的ss sp cs 和 ip压栈
    ; call 的话会把ss esp cs eip什么的入栈，然后ret的时候，再自动出栈以恢复原来的堆栈，这里面因为之前没有call，所以堆栈里面原本没有要跳转的堆栈的信息，所以需要手动把要跳到的段的堆栈信息入栈，这样一个ret之后，就会按栈里面的信息修改堆栈并且跳转了。
	push	SelectorStack3  ; 因为有特权级变化，所以要切换堆栈，需要在当前堆栈里面装上要跳转到的堆栈的信息。
	push	TopOfStack3
	push	SelectorCodeRing3
	push	0
	retf	; 这里其实没有用到TSS，因为从ring0到ring3，是降级了。只有在ring3的代码中需要访问高特权级的时候，才会用到TSS里面的堆栈信息。
    ; Ring0 -> Ring3，历史性转移！将打印数字 '3'。

; ------------------------------------------------------------------------
DispReturn:
	push	eax
	push	ebx
	mov	eax, edi
	mov	bl, 160
	div	bl
	and	eax, 0FFh
	inc	eax
	mov	bl, 160
	mul	bl
	mov	edi, eax
	pop	ebx
	pop	eax

	ret
; DispReturn 结束---------------------------------------------------------

SegCode32Len	equ	$ - LABEL_SEG_CODE32
; END of [SECTION .s32]


[SECTION .sdest]; 调用门目标段
[BITS	32]

LABEL_SEG_CODE_DEST:
	mov	ax, SelectorVideo
	mov	gs, ax			; 视频段选择子(目的)

	mov	edi, (80 * 12 + 0) * 2	; 屏幕第 12 行, 第 0 列。
	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	mov	al, 'C'
	mov	[gs:edi], ax

	; Load LDT
	mov	ax, SelectorLDT
	lldt	ax

	jmp	SelectorLDTCodeA:0	; 跳入局部任务，将打印字母 'L'。

	;retf

SegCodeDestLen	equ	$ - LABEL_SEG_CODE_DEST
; END of [SECTION .sdest]


; 16 位代码段. 由 32 位代码段跳入, 跳出后到实模式
[SECTION .s16code]
ALIGN	32
[BITS	16]
LABEL_SEG_CODE16:
	; 到这里还是保护模式，下面跳回实模式:
	mov	ax, SelectorNormal  ; 这个段定义是0-0ffffh的，而且没有被修改过，因为回到实模式的时候需要给各个段寄存器的高速缓冲寄存器赋上一个合适的值才行，所以要定义一个这样的段然后在回实模式之前把各寄存器都给赋上相关的值。
    ;另外，不能用32位的代码修改高速缓冲器，所以要把修改的这些代码写到16位的代码里面。
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax
; 在这之前的cs是保护模式下的cs，之后就是实模式下的cs了，但是有可能跟跳入保护模式代码前的cs不同，是一个跟当前代码段有关的值，为了让cs跟之前的实模式代码一致，需要再跳回原来实模式代码段label_real_entry
	mov	eax, cr0
	and	al, 11111110b
	mov	cr0, eax  ; 从修改cr0之后，就是回到实模式了


LABEL_GO_BACK_TO_REAL:
	jmp	0:LABEL_REAL_ENTRY	; 段地址会在程序开始处被设置成正确的值

Code16Len	equ	$ - LABEL_SEG_CODE16

; END of [SECTION .s16code]


; LDT
[SECTION .ldt]
ALIGN	32
LABEL_LDT:
;                                         段基址       段界限     ,   属性
LABEL_LDT_DESC_CODEA:	Descriptor	       0,     CodeALen - 1,   DA_C + DA_32	; Code, 32 位

LDTLen		equ	$ - LABEL_LDT

; LDT 选择子
SelectorLDTCodeA	equ	LABEL_LDT_DESC_CODEA	- LABEL_LDT + SA_TIL
; END of [SECTION .ldt]


; CodeA (LDT, 32 位代码段)
[SECTION .la]
ALIGN	32
[BITS	32]
LABEL_CODE_A:
	mov	ax, SelectorVideo
	mov	gs, ax			; 视频段选择子(目的)

	mov	edi, (80 * 13 + 0) * 2	; 屏幕第 13 行, 第 0 列。
	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	mov	al, 'L'
	mov	[gs:edi], ax

	; 准备经由16位代码段跳回实模式
	jmp	SelectorCode16:0
CodeALen	equ	$ - LABEL_CODE_A
; END of [SECTION .la]


; CodeRing3
[SECTION .ring3]  ; 最低特权级Ring3的代码
ALIGN	32
[BITS	32]
LABEL_CODE_RING3:
	mov	ax, SelectorVideo
	mov	gs, ax			; 视频段选择子(目的)

	mov	edi, (80 * 14 + 0) * 2	; 屏幕第 14 行, 第 0 列。
	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	mov	al, '3'
	mov	[gs:edi], ax

	call	SelectorCallGateTest:0	; 这里从ring3的代码跳到ring0的代码特权级发生了变化，所以要从TSS里面加载新的堆栈ss0 esp0啥的。这里才是用到TSS的地方。
    ; 测试调用门（有特权级变换），将打印字母 'C'。
	jmp	$
SegCodeRing3Len	equ	$ - LABEL_CODE_RING3
; END of [SECTION .ring3]
