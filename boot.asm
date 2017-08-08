
;%define	_BOOT_DEBUG_	; 做 Boot Sector 时一定将此行注释掉!将此行打开后用 nasm Boot.asm -o Boot.com 做成一个.COM文件易于调试

%ifdef	_BOOT_DEBUG_
	org  0100h			; 调试状态, 做成 .COM 文件, 可调试
%else
	org  07c00h			; Boot 状态, Bios 将把 Boot Sector 加载到 0:7C00 处并开始执行
%endif

;================================================================================================
%ifdef	_BOOT_DEBUG_
BaseOfStack		equ	0100h	; 调试状态下堆栈基地址(栈底, 从这个位置向低地址生长)
%else
BaseOfStack		equ	07c00h	; Boot状态下堆栈基地址(栈底, 从这个位置向低地址生长)
%endif

BaseOfLoader		equ	09000h	; LOADER.BIN 被加载到的位置 ----  段地址
OffsetOfLoader		equ	0100h	; LOADER.BIN 被加载到的位置 ---- 偏移地址
RootDirSectors		equ	14	; 根目录占用空间
SectorNoOfRootDirectory	equ	19	; Root Directory 的第一个扇区号

SectorNoOfFAT1		equ	1	; FAT1 的第一个扇区号	= BPB_RsvdSecCnt
DeltaSectorNo		equ	17	; DeltaSectorNo = BPB_RsvdSecCnt + (BPB_NumFATs * FATSz) - 2
					; 文件的开始Sector号 = DirEntry中的开始Sector号 + 根目录占用Sector数目 + DeltaSectorNo
;================================================================================================
; 上面的这些全是宏定义，编译后不占空间，实际上下面的命令就是程序空间的起始位置
; cs默认值是0, 也下面的这个jmp的位置，但是因为有org，所以每个地址都偏移7c00h

	jmp short LABEL_START		; Start to boot.
	nop				; 这个 nop 不可少

	; 下面是 FAT12 磁盘的头
	BS_OEMName	DB 'ForrestY'	; OEM String, 必须 8 个字节
	BPB_BytsPerSec	DW 512		; 每扇区字节数
	BPB_SecPerClus	DB 1		; 每簇多少扇区
	BPB_RsvdSecCnt	DW 1		; Boot 记录占用多少扇区
	BPB_NumFATs	DB 2		; 共有多少 FAT 表
	BPB_RootEntCnt	DW 224		; 根目录文件数最大值
	BPB_TotSec16	DW 2880		; 逻辑扇区总数
	BPB_Media	DB 0xF0		; 媒体描述符
	BPB_FATSz16	DW 9		; 每FAT扇区数
	BPB_SecPerTrk	DW 18		; 每磁道扇区数
	BPB_NumHeads	DW 2		; 磁头数(面数)
	BPB_HiddSec	DD 0		; 隐藏扇区数
	BPB_TotSec32	DD 0		; 如果 wTotalSectorCount 是 0 由这个值记录扇区数
	BS_DrvNum	DB 0		; 中断 13 的驱动器号
	BS_Reserved1	DB 0		; 未使用
	BS_BootSig	DB 29h		; 扩展引导标记 (29h)
	BS_VolID	DD 0		; 卷序列号
	BS_VolLab	DB 'Tinix0.01  '; 卷标, 必须 11 个字节
	BS_FileSysType	DB 'FAT12   '	; 文件系统类型, 必须 8个字节  


LABEL_START:	
	mov	ax, cs  ; cs 的值是0，此时ip的值是0x7c3e
	mov	ds, ax  ; 给ds es赋值的做法只是一种写法，有没有这两句都行
	mov	es, ax
	mov	ss, ax  ; ss 的值是0
	mov	sp, BaseOfStack   ; sp的值是0x7c00， 栈是由sp向ss 生长，ss 不变，sp每次push减小2


	; 清屏 10h中断 al = 0
	mov	ax, 0600h		; AH = 6,  AL = 0h
	mov	bx, 0700h		; 黑底白字(BL = 07h)
	mov	cx, 0			; 左上角: (0, 0)
	mov	dx, 0184fh		; 右下角: (80, 50)
	int	10h			; int 10h
    ; 显示字符串"booting"
	mov	dh, 0			; "Booting  "
	call	DispStr			; 显示字符串


; 下面三句是用int 13h中断让软盘复位	
	xor	ah, ah	; ┓
	xor	dl, dl	; ┣ 软驱复位，ah = 0表示复位操作，dl = 0表示操作的磁盘号
	int	13h	;     ┛
	
; 下面在 A 盘的根目录区寻找文件名是 LOADER.BIN的条目，根目录区从19扇区开始
	mov	word [wSectorNo], SectorNoOfRootDirectory ; 当前要读的扇区号[wSectorNo]初始值是零 SectorNoOfRootDirectory=19根目录区第一个扇区的扇区号
LABEL_SEARCH_IN_ROOT_DIR_BEGIN:
	cmp	word [wRootDirSizeForLoop], 0 ; 如果[wRootDirSizeForLoop]从19减小到零，表示整个根目录区的19个扇区里面都没有Loader.bin的文件条目	
	jz	LABEL_NO_LOADERBIN		; 如果读完表示没有找到 LOADER.BIN，就跳过去执行找不到时的操作。
	dec	word [wRootDirSizeForLoop]	; 遍历下一个扇区，没遍历的扇区数减一

; 下面是把软盘上根目录区的一个[wSectorNo]扇区读到baseofloader:offsetofloader的内存位置
	mov	ax, BaseOfLoader ; [baseofloader:offsetofloader]是loader.bin被加载到的内存位置
	mov	es, ax			; es <- BaseOfLoader
	mov	bx, OffsetOfLoader	; bx <- OffsetOfLoader	于是, es:bx = BaseOfLoader:OffsetOfLoader
	mov	ax, [wSectorNo]	; ax <- Root Directory 中的某 Sector 号
	mov	cl, 1
	call	ReadSector ; 从ax起读cl个sector到es:bx

	mov	si, LoaderFileName	; 让ds:si 指向字符串"LOADER  BIN"的地址
	mov	di, OffsetOfLoader	; es:di指向刚读出来的那个扇区开始处 di = offsetlofloader 前面的 bx = offsetofloader BaseOfLoader:0100 = BaseOfLoader*10h+100
	cld

; 下面是从这个扇区中找是否有loader.bin文件的条目
	mov	dx, 10h ; 十进制的16，一个扇区512 = 16 × 32，一个文件条目32个字节，所以一个扇区最多可以有16个条目，找完16个条目还没找到loader.bin文件的话就要找下一个扇区了
LABEL_SEARCH_FOR_LOADERBIN:
	cmp	dx, 0										; ┓循环次数控制,
	jz	LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR	; ┣如果已经读完了一个 Sector,
	dec	dx											; ┛就跳到下一个 Sector
	mov	cx, 11  ; 文件名一共11个字节，有11个字节要比较
LABEL_CMP_FILENAME:
	cmp	cx, 0  ; 看是否遍历了11个字节
	jz	LABEL_FILENAME_FOUND	; 如果比较了 11 个字符都相等, 表示找到
    dec	cx
	lodsb				; 从ds:si读一个字节到al
	cmp	al, byte [es:di]
	jz	LABEL_GO_ON
	jmp	LABEL_DIFFERENT		; 只要发现不一样的字符就表明本 DirectoryEntry 不是我们要找的 LOADER.BIN
LABEL_GO_ON:
	inc	di ; es:di 是文件名字符串变量的地址
	jmp	LABEL_CMP_FILENAME	;	继续循环

LABEL_DIFFERENT:
	and	di, 0FFE0h ; 为了让它指向本条目开头，一个条目32字节，进行di &= E0后，di 就指向本条目的开头了 
	add	di, 20h	; 也就是十进制的32，表示向后移动一个条目的字节数    
	mov	si, LoaderFileName ; 恢复ds:si 指向文件名字符串的第一个字节
	jmp	LABEL_SEARCH_FOR_LOADERBIN;    ┛

LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
	add	word [wSectorNo], 1 ; 加1是下一个扇区的扇区号
	jmp	LABEL_SEARCH_IN_ROOT_DIR_BEGIN

LABEL_NO_LOADERBIN:
	mov	dh, 2			; 打印第二个字符串"No LOADER."
	call	DispStr			; 显示字符串
%ifdef	_BOOT_DEBUG_
	mov	ax, 4c00h		; ┓
	int	21h			; ┛没有找到 LOADER.BIN, 回到 DOS
%else
	jmp	$			; 没有找到 LOADER.BIN, 死循环在这里
%endif

LABEL_FILENAME_FOUND:			; 找到 LOADER.BIN 后便来到这里继续
	mov	ax, RootDirSectors  ; 根目录区总共占的扇区数，值是14
	and	di, 0FFE0h		; 一个条目32字节，占5位，末5位置零就是当前条目的开头 
	add	di, 01Ah		; 一个条目的0x1a处开始的两个字节是这个条目对应的文件的开始簇的簇号
	mov	cx, word [es:di] ; cx 是这个文件的第一个簇的簇号，这里一个簇只有一个sector
	push	cx			; 保存此 Sector 在 FAT 中的序号
	add	cx, ax ; ax 是根目录区占用的扇区数14，加上这个再加上下一句就得到这个扇区在磁盘中实际的扇区号
	add	cx, DeltaSectorNo	; 这句完成时 cl 里面变成 LOADER.BIN 的起始扇区号 (从 0 开始数的序号)，DeltaSectorNo是2x9-1=17，也就是2个fat表总共的扇区数(2*9)减去数据区从2开始计数引起的一个偏移，这个数再加上上面的根目录区总扇区数14就是这个数据区的扇区在整个磁盘的扇区号
	mov	ax, BaseOfLoader ; loader.bin被加载到内存的段地址
	mov	es, ax			; es <- BaseOfLoader
	mov	bx, OffsetOfLoader	; loader.bin被加载到内存段内的偏移地址。 实模式下20位地址总线有4位是段内偏移，16位是段地址，所以每段10h的空间，loader.bin被加载到内存的物理地址就变成了es:bx = BaseOfLoader:OffsetOfLoader = BaseOfLoader * 10h + OffsetOfLoader
	mov	ax, cx			; 到这里，es:bx指向了loader.bin要被加载到内存的物理地址，ax是要从磁盘中读出的loader.bin的实际起始簇号

LABEL_GOON_LOADING_FILE:
	push	ax			; 
	push	bx			; 现在stack里面除了ax bx之外，在前面还有cx也就是loader.bin的起始扇区在数据区的扇区号(从2开始)

	mov	ah, 0Eh			;  每读一个扇区就在 "Booting  " 后面打一个点
	mov	al, '.'			;  ah 是10h中断的服务号，ah=0eh是teletype模式下显示字符, al是显示的字符，bl是前景色
	mov	bl, 0Fh			;  Booting ......
	int	10h			; ┃
	pop	bx			; ┃
	pop	ax			; ┛

	mov	cl, 1
	call	ReadSector ; cl = 1，读一个扇区出来 
	pop	ax			; 取出此 Sector 在 FAT 中的序号，上面的cx
	call	GetFATEntry ; 从fat表中取出ax指定的fatentry，并保存到ax的低12位，高12位都是0
	cmp	ax, 0FFFh ; 看是否是最后一个扇区
	jz	LABEL_FILE_LOADED ; 如果是最后一个扇区，就加载完成
	push	ax			; 读出来的fatentry号，也就是这个文件的下一个簇的簇号，由于一个簇是一个扇区，这个号码也是这个文件的下一个扇区在数据区的扇区编号(从2开始算起)
	mov	dx, RootDirSectors
	add	ax, dx
	add	ax, DeltaSectorNo ; 使ax变成该文件下一个扇区在磁盘中的实际扇区号
	add	bx, [BPB_BytsPerSec]  ; es:bx是下一个要读出的扇区被加载到内存中的起始位置。因为已经读出一个扇区了，把要读到内存中的的位置向后移动一个扇区的位置，指向下一个扇区要被读到内存中的位置
	jmp	LABEL_GOON_LOADING_FILE ; 继续读下一个扇区然后找对应的fat表中的fatentry

LABEL_FILE_LOADED: ; 加载完成

	mov	dh, 1			; "Ready."
	call	DispStr			; 显示字符串

; *****************************************************************************************************
	jmp	BaseOfLoader:OffsetOfLoader	; 这一句正式跳转到已加载到内存中的 LOADER.BIN 的开始处
						; 开始执行 LOADER.BIN 的代码
						; Boot Sector 的使命到此结束
                        ; 仍然是在实模式下，找到loader.bin之后，把这个文件加载到BaseOfLoader:OffsetOfLoader内存位置处，然后跳到这个位置，这样就开始执行loader.bin里面的内容了。
; *****************************************************************************************************




; 下面是变量字符串还有一些前面调用过的函数
;============================================================================
;变量
;----------------------------------------------------------------------------
wRootDirSizeForLoop	dw	RootDirSectors	; Root Directory 占用的扇区数, 在循环中会递减至零.
wSectorNo		dw	0		; 要读取的扇区号
bOdd			db	0		; 奇数还是偶数

;============================================================================
;字符串
;----------------------------------------------------------------------------
LoaderFileName		db	"LOADER  BIN", 0	; LOADER.BIN 之文件名，8字节文件名加上3字节扩展名
; 为简化代码, 下面每个字符串的长度均为 MessageLength
MessageLength		equ	9
BootMessage:		db	"Booting  "; 9字节, 不够则用空格补齐. 序号 0
Message1		db	"Ready.   "; 9字节, 不够则用空格补齐. 序号 1
Message2		db	"No LOADER"; 9字节, 不够则用空格补齐. 序号 2
;============================================================================


;----------------------------------------------------------------------------
; 函数名: DispStr
;----------------------------------------------------------------------------
; 作用:
;	显示一个字符串, 函数开始时 dh 中应该是字符串序号(0-based)
DispStr:
	mov	ax, MessageLength
	mul	dh
	add	ax, BootMessage
	mov	bp, ax			; ┓
	mov	ax, ds			; ┣ ES:BP = 串地址，int 10h ah=13时，es:bp指向字符的首地址
	mov	es, ax			; ┛
	mov	cx, MessageLength	; 对于int 10h ah=13来说CX是显示字符串的长度 
	mov	ax, 01301h		; AH = 13 在teletype模式下显示字符串,  AL = 01h al是显示输出的方式
	mov	bx, 0007h		; bh是页号(BH = 0) bl是属性,黑底白字(BL = 07h)
	mov	dl, 0           ; dh dl 是显示的坐标
	int	10h			; 设置完成后进入中断int 10h
	ret


;----------------------------------------------------------------------------
; 函数名: ReadSector
;----------------------------------------------------------------------------
; 作用:
;	从第 ax 个 Sector 开始, 将 cl 个 Sector 读入 es:bx 中
ReadSector:
	; -----------------------------------------------------------------------
	; 怎样由扇区号求扇区在磁盘中的位置 (扇区号 -> 柱面号, 起始扇区, 磁头号)
	; -----------------------------------------------------------------------
	; 设扇区号为 x
	;                           ┌ 柱面号 = y >> 1
	;       x           ┌ 商 y ┤
	; -------------- => ┤      └ 磁头号 = y & 1
	;  每磁道扇区数     │
	;                   └ 余 z => 起始扇区号 = z + 1

	push	bp ; 保存原来的bp里面的值
	mov	bp, sp ; 让bp为栈底，这样esp-2后就空出两个字节，这两个字节就可以用[bp - 2]来访问，原来的栈正常使用
	sub	esp, 2			; 辟出两个字节的堆栈区域保存要读的扇区数: byte [bp-2]

	mov	byte [bp-2], cl ;cl是要读的扇区数
	push	bx			; 保存 bx
    ;下面是按上面注释里面的公式计算的，把各结果放到相应的寄存器里面
	mov	bl, [BPB_SecPerTrk]	; bl: 除数
	div	bl			; y 在 al 中, z 在 ah 中
	inc	ah			; z ++
	mov	cl, ah			; cl <- 起始扇区号
	mov	dh, al			; dh <- y
	shr	al, 1			; y >> 1 (其实是 y/BPB_NumHeads, 这里BPB_NumHeads=2)
	mov	ch, al			; ch <- 柱面号
	and	dh, 1			; dh & 1 = 磁头号
	pop	bx			; 恢复 bx, bx是读出数据保存的位置[es:bx]
	; 至此, "柱面号, 起始扇区, 磁头号" 全部得到 ^^^^^^^^^^^^^^^^^^^^^^^^
	mov	dl, [BS_DrvNum]		; dl是驱动器号 (0 表示 A 盘)，在第0扇区里面定义的
    
.GoOnReading:
	mov	ah, 2			; 02h表示读的操作，00h表示复位磁盘
	mov	al, byte [bp-2]		; 读 al 个扇区
	int	13h
	jc	.GoOnReading		; 如果读取错误 CF 会被置为 1, 这时就不停地读, 直到正确为止

	add	esp, 2 ; 读完之后要恢复堆栈，把那两个保留的字节还了
	pop	bp ; 恢复bp寄存器的值

	ret


;----------------------------------------------------------------------------
; 函数名: GetFATEntry
;----------------------------------------------------------------------------
; 作用:
;	找到序号为 ax 的 Sector 在 FAT 中的条目, 结果放在 ax 中
;	需要注意的是, 中间需要读 FAT 的扇区到 es:bx 处, 所以函数一开始保存了 es 和 bx
GetFATEntry:
	push	es
	push	bx
	push	ax  ; ax是要读的扇区在数据区的扇区号，也就是fat表中的表项号
    ;腾出4k的空间来
	mov	ax, BaseOfLoader	; ┓
	sub	ax, 0100h		; BaseOfLoader左移4k大小，空出4k空间使用
	mov	es, ax			; 
	pop	ax
    ; 找出fat表中的位置
	mov	byte [bOdd], 0  ; 先暂时当成ax是偶数fat表项
	mov	bx, 3    ; 每个表项占1.5个字节，也就是3/2，所以要乘3再除以2
	mul	bx			; dx:ax = ax * 3
	mov	bx, 2
	div	bx			; dx:ax / 2  ==>  ax <- 商, dx <- 余数
	cmp	dx, 0   ; ax*3/2 余数是零表示原ax是偶数，也就是偶数项表项
	jz	LABEL_EVEN   
	mov	byte [bOdd], 1  ; 1表示是ax是奇数，也就是奇数表项

LABEL_EVEN:     ; 如果是偶数表项的话，ax*3/2就是这个表项的头字节在fat表中的的字节偏移量
	xor	dx, dx			; 现在 ax 中是 FATEntry 在 FAT 中的偏移量. 下面来计算 FATEntry 在哪个扇区中(FAT占用不止一个扇区)
	mov	bx, [BPB_BytsPerSec]
	div	bx			; dx:ax / BPB_BytsPerSec = ax/512 这一除，得到的商ax是FATEntry 所在的扇区在fat表中的扇区号(从0开始)，得到的余数dx就是FATEntry 在扇区内的偏移
	push	dx
	mov	bx, 0			; bx <- 0	于是, es:bx = (BaseOfLoader - 100):00 = (BaseOfLoader - 100) * 10h
	add	ax, SectorNoOfFAT1	; 此句执行之后的 ax 就是 FATEntry 所在的扇区号, SectorNoOfFAT1就是Fat表1的起始扇区的实际扇区号
	mov	cl, 2
	call	ReadSector		; 读取 FATEntry 所在的扇区, 一次读两个, 避免在边界发生错误, 因为一个 FATEntry 可能跨越两个扇区
	pop	dx
	add	bx, dx ; es:bx是读出扇区在内存中存储的位置，dx是fat entry在扇区内有偏移量
	mov	ax, [es:bx]  ; 读出fatentry 的两个字节
	cmp	byte [bOdd], 1 ; 根据条目的奇偶不同调整这两个字节，使ax这个两字节寄存器里面的值就是这个文件的条目
	jnz	LABEL_EVEN_2
	shr	ax, 4 ; 如果是奇数项的话，读出的高字节8位就是fatentry的高8位，低字节的8位中的高4位是fatentry的低4位，也就是说ax的高12位是fatentry。所以要右移4位，加上下面这句，取出ax的高12位
LABEL_EVEN_2:
	and	ax, 0FFFh ; 如果是偶数项条目，读出的低字节8位就是条目的低8位，高字节(8位)的低4位就是文件条目的8-11位，也就是说ax的低12位就是fatentry，高4位是下一个fatentry(奇数项)的低4位。所以要and运算去掉高4位，得到纯粹的fatentry

LABEL_GET_FAT_ENRY_OK: ; 恢复一开始的es 和 bx的值，有没有这个label都一样

	pop	bx
	pop	es
	ret


;----------------------------------------------------------------------------
times 	510-($-$$)	db	0	; 填充剩下的空间，使生成的二进制代码恰好为512字节
dw 	0xaa55				; 结束标志
