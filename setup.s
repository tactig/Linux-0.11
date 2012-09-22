!
!	setup.s		(C) 1991 Linus Torvalds
!
! setup.s is responsible for getting the system data from the BIOS,
! and putting them into the appropriate places in system memory.   		
! both setup.s and system has been loaded by the bootblock.        		
! setup.s 用于从BIOS中获取系统数据，并将其放入系统内存的适当的地方。
! setup.s和系统都由bootblock加载
!                                                                  		
! This code asks the bios for memory/disk/other parameters, and    		
! puts them in a "safe" place: 0x90000-0x901FF, ie where the       		
! boot-block used to be. It is then up to the protected mode       		
! system to read them from there before the area is overwritten    		
! for buffer-blocks.                                               		
! 该段代码向BIOS获取 内存/硬盘 或者其他的数据，然后将它们放入一个“安全”
! 地方： 0x90000-0x901FF ，该地址范围为boot-block存在的地方。
!                                                                  		
                                                                   		
! NOTE! These had better be the same as in bootsect.s!             		

INITSEG  = 0x9000	! we move boot here - out of the way
SYSSEG   = 0x1000	! system loaded at 0x10000 (65536).
SETUPSEG = 0x9020	! this is the current segment

.globl begtext, begdata, begbss, endtext, enddata, endbss
.text
begtext:
.data
begdata:
.bss
begbss:
.text

entry start
start:

! ok, the read went well so we get current cursor position and save it for
! posterity.

	mov	ax,#INITSEG	! this is done in bootsect already, but...
	mov	ds,ax
	mov	ah,#0x03	! read cursor pos
	xor	bh,bh
	int	0x10		! save it in known place, con_init fetches
	mov	[0],dx		! it from 0x90000.

! Get memory size (extended mem, kB)

	mov	ah,#0x88
	int	0x15
	mov	[2],ax

! Get video-card data:

	mov	ah,#0x0f
	int	0x10
	mov	[4],bx		! bh = display page
	mov	[6],ax		! al = video mode, ah = window width

! check for EGA/VGA and some config parameters

	mov	ah,#0x12
	mov	bl,#0x10
	int	0x10
	mov	[8],ax
	mov	[10],bx
	mov	[12],cx

! Get hd0 data
! 硬盘参数列表占据10个字节
	mov	ax,#0x0000
	mov	ds,ax
	lds	si,[4*0x41]		//ds:si = [0x41*4]:[0x41*4+2]
	mov	ax,#INITSEG		//0x9000
	mov	es,ax			//es = 0x9000
	mov	di,#0x0080		//di = 0x80;
	mov	cx,#0x10
	rep
	movsb				//move a type form ds:si to es:di for cx times.

! Get hd1 data

	mov	ax,#0x0000
	mov	ds,ax
	lds	si,[4*0x46]		//获取hd1的参数列表
	mov	ax,#INITSEG
	mov	es,ax
	mov	di,#0x0090
	mov	cx,#0x10
	rep
	movsb

! Check that there IS a hd1 :-)

	mov	ax,#0x01500
	mov	dl,#0x81		//检测第二个硬盘
	int	0x13
	jc	no_disk1		//没有所指定的盘CF=1
	cmp	ah,#3			//ah输出表示盘的类型，如果ah=3
	je	is_disk1		//则跳转到is_disk1
no_disk1:				//此处是第二个硬盘不存在
	mov	ax,#INITSEG
	mov	es,ax			//es = 0x9000
	mov	di,#0x0090		//0x9000:0x0 是第二个硬盘参数表的入口地址
	mov	cx,#0x10
	mov	ax,#0x00
	rep
	stosb				//set es:di to al for cx times.
is_disk1:

! now we want to move to protected mode ...

	cli			! no interrupts allowed !
				//禁用中断指令,比如时钟中断

! first we move the system to it's rightful place

	mov	ax,#0x0000
	cld			! 'direction'=0, movs moves forward
				//si、di的值增加
do_move:
	mov	es,ax		! destination segment
				//es = 0x0
	add	ax,#0x1000	//ax = 0x1000
	cmp	ax,#0x9000
	jz	end_move
	mov	ds,ax		! source segment
				//ds = 0x1000
	sub	di,di
	sub	si,si		//di = si =0
	mov 	cx,#0x8000
	rep
	movsw
	jmp	do_move

! then we load the segment descriptors

end_move:
	mov	ax,#SETUPSEG	! right, forgot this at first. didn't work :-)
				//ax = 0x9020
	mov	ds,ax		//ds = 0x9020
	lidt	idt_48		! load idt with 0,0
	lgdt	gdt_48		! load gdt with whatever appropriate

! that was painless, now we enable A20

	call	empty_8042
	mov	al,#0xD1		! command write
	out	#0x64,al
	call	empty_8042
	mov	al,#0xDF		! A20 on
	out	#0x60,al
	call	empty_8042

! well, that went ok, I hope. Now we have to reprogram the interrupts :-(
! we put them right after the intel-reserved hardware interrupts, at
! int 0x20-0x2F. There they won't mess up anything. Sadly IBM really
! messed this up with the original PC, and they haven't been able to
! rectify it afterwards. Thus the bios puts interrupts at 0x08-0x0f,
! which is used for the internal hardware interrupts as well. We just
! have to reprogram the 8259's, and it isn't fun.

	mov	al,#0x11		! initialization sequence
	out	#0x20,al		! send it to 8259A-1
	.word	0x00eb,0x00eb		! jmp $+2, jmp $+2
	out	#0xA0,al		! and to 8259A-2
	.word	0x00eb,0x00eb
	mov	al,#0x20		! start of hardware int's (0x20)
	out	#0x21,al
	.word	0x00eb,0x00eb
	mov	al,#0x28		! start of hardware int's 2 (0x28)
	out	#0xA1,al
	.word	0x00eb,0x00eb
	mov	al,#0x04		! 8259-1 is master
	out	#0x21,al
	.word	0x00eb,0x00eb
	mov	al,#0x02		! 8259-2 is slave
	out	#0xA1,al
	.word	0x00eb,0x00eb
	mov	al,#0x01		! 8086 mode for both
	out	#0x21,al
	.word	0x00eb,0x00eb
	out	#0xA1,al
	.word	0x00eb,0x00eb
	mov	al,#0xFF		! mask off all interrupts for now
	out	#0x21,al
	.word	0x00eb,0x00eb
	out	#0xA1,al

! well, that certainly wasn't fun :-(. Hopefully it works, and we don't
! need no steenking BIOS anyway (except for the initial loading :-).
! The BIOS-routine wants lots of unnecessary data, and it's less
! "interesting" anyway. This is how REAL programmers do it.
!
! Well, now's the time to actually move into protected mode. To make
! things as simple as possible, we do no register set-up or anything,
! we let the gnu-compiled 32-bit programs do that. We just jump to
! absolute address 0x00000, in 32-bit protected mode.

	mov	ax,#0x0001	! protected mode (PE) bit
	lmsw	ax		! This is it!
	jmpi	0,8		! jmp offset 0 of segment 8 (cs)
					!! 8 = 0b1000
					!! 00	表示优先级为0
					!! 0	表示GDT表
					!! 1	表示GDT表的第二项
					!! 

! This routine checks that the keyboard command queue is empty
! No timeout is used - if this hangs there is something wrong with
! the machine, and we probably couldn't proceed anyway.
empty_8042:
	.word	0x00eb,0x00eb
	in	al,#0x64	! 8042 status port
	test	al,#2		! is input buffer full?
	jnz	empty_8042	! yes - loop
	ret

gdt:
	.word	0,0,0,0		! dummy，缺省

	!! 内核代码段选择符
	!! 0x00C0 9A00 0000 07FF
	.word	0x07FF		! 8Mb - limit=2047 (2048*4096=8Mb)
	.word	0x0000		! base address=0
	.word	0x9A00		! code read/exec
	.word	0x00C0		! granularity=4096, 386

	!! 内核数据段
	!! 0x00C0 9200 0000 07FF
	.word	0x07FF		! 8Mb - limit=2047 (2048*4096=8Mb)
	.word	0x0000		! base address=0
	.word	0x9200		! data read/write
	.word	0x00C0		! granularity=4096, 386

idt_48:
	.word	0			! idt limit=0
	.word	0,0			! idt base=0L
			!!将IDT暂时定位在0x0中，长度为0

gdt_48:
	.word	0x800		! gdt limit=2048, 256 GDT entries,一个GDT entry
	.word	512+gdt,0x9	! gdt base = 0X9xxxx
			!! 定位到219
	
.text
endtext:
.data
enddata:
.bss
endbss:
