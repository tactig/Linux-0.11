/*
	move self to 0x9000:0x0
	load setup
	显示“Loading system...”
	read system module to 0x1000:0x0
*/
int syssize = 0x3000 	//设置system模块的大小
int setuplen = 4 	//setup程序所需的扇区数
int bootseg = 0x07c0	//bootsect被BIOS加载时的起始地址
int initseg = 0x9000	//移动bootsct的地址
int setupseg = 0x9020	//setup的初始地址
int sysseg = 0x1000	//syetem 模块的起始地址
int endseg = sysseg + syssize	//system 模块的结尾段地址




start()
{
	ds = bootseg;	//0x7c0
	es = initseg;	//0x9000
	cx = 256;
	si = di = 0;
	rep movw;	//复制512字节，即一个扇区
	jmp go(),initseg;	//跳转到go
}

go()
{
	ds = es = ss = 0x9000;
	ss = 0x9000;
	sp = 0xff00;
}

load_setup()		//加载setup程序
{
	dx = 0x0000	//驱动器0，0磁头
	cx = 0x0002	//磁道0,扇区2
	bx = 0x0200	//ES:BX
	ax = 0x0200+setuplen	//ah=0x02 读扇区到es:bx=0x9000:0x200，al=4要读出的扇区数量
	int 0x13;
	/*
		dh = 0x0 drive
		dl = 0x0 表示第一个软盘驱动器A
		ah = 0x2 Read Sectors From Drive
		al = 0x4 read 4 sectors
		ch = 0x0 read from 0 track
		cl = 0x2 read from 2nd sector
		ES:BX    buffer address pointer
		CF	set on error, clear if no error

	*/
	if (CF != 1)
		jmp ok_load_setup;
	dx = ax =0;
	int 0x13;
	/*
		INT 13h AH=00h: Reset Disk Drive
		Parameters:
		AH	00h
		DL	Drive
		Results:
		CF	Set on error

	*/
	jmp load_setup;
}

ok_load_setup()
{
	dl = 0;		//驱动器数量
	ax = 0x0800	//ah = 8获取驱动参数
	int 0x13	//驱动参数输出至es:di,每磁道的扇区数输出至cl
	ch = 0;

	sectors = cx;	//保存每磁道含有的扇区数
	es = 0x9000;

//show "loading system"
	ah = 0x03;
	bh = 0;
	int 0x10;

	cx = 24;
	bx = 0x0007;
	bp = &msg;	//es:bp 指向要显示的字符串
	ax = 0x1301;	//write string, move cursor
	int 0x10;

//Loading system module to 0x10000
	es = 0x1000;
	read_it();
	kill_motor();
/***************************************************/
//检测根设备
	ax = root_dev;
	if (ax != 0)
		jmp root_defined;
	
	bx = sectors;
	ax = 0x0208;
	if(bx == 15 )
		jmp root_defined;
	ax = 0x021c;
	if(bx == 18)
		jmp root_defined;
	undef_root:
	jmp undef_root;
	root_defined:
		root_dev = ax;
	
/***************************************************/
//跳转到setup
	jmp 0x90200;

}

short sread = 5;
short head = 0;
short track = 0;

read_it()
{
	ax = es;
	if (ax & 0x0fff != 0)
		die: jmp die;
	bx = 0;

rp_read:
	ax = es;
	if (ax < endseg)
		jmp ok1_read;
	ret;

ok1_read:
	ax = sectors;		//每磁道含有的扇区数量
	ax -= sread;		//未读的扇区数量
	cx = ax;
	cx = cx << 9 + bx	//cx = cx*512 + 0
	if (CF == 0)
		jmp ok2_read;	//如果剩余的未读的扇区字节数小于64KB，则跳转
	if (ZF == 1)
		jmp ok2_read;
	
	ax = 0;
	ax -= bx;
	ax = ax >> 9;

ok2_read:
	read_track();
	cx = ax; 		//先前未读的扇区数量
	ax += sread;
	if (ax != sectors)
		jmp ok3_read;
	ax = 1;
	ax -= head;
	track++;

ok4_read:
	head = ax;
	ax = 0;

ok3_read:
	sread = ax;
	cx <<= 9;
	bx += cx;
	if (CF == 0)
		jmp rp_read;
	
	ax = es;
	ax += 0x1000;
	es = ax;
	bx = 0;
	jmp rp_read;
}

read_track()
{
	push ax			//先前未读的扇区数量
	push bx			//0x0
	push cx			//未读扇区的总字节数
	push dx
	dx = track;		//dx = 0x0
	cx = sread;		//cx = 0x5
	cx++;			//cx = 0x6
	ch = dl;		//cx = 0x6
	dx = head;		//dx = 0x0
	dh = dl;		//dx = 0x0
	dl = 0;
	dx = 0x0100;		//dx = 0x0100
	ah = 2;
	int 0x13;		//ah = 0x2 Read Sectors From Drive
				//将所在磁道所有未读的扇区全部读入ES:BX(0x1000:0)
	if (CF == 1)
		jmp bad_rt;
	pop dx
	pop cx
	pop bx
	pop ax
	ret
}

bad_rt()
{
	ax = 0;
	dx = 0;
	int 0x13;
	/*
		NT 13h AH=00h: Reset Disk Drive
		Parameters:
		AH	00h
		DL	Drive
		Results:
		CF	Set on error

	*/
	pop dx;
	pop cx;
	pop bx;
	pop ax;
	jmp read_track;
}

kill_motor()
{
	push dx;
	dx = 0x3f2;
	al = 0;
	outb;
	pop dx;
	ret
}

short sectors = 0;	
char *msg = "\n\nLoading system...\n\n\n\n";
short root_dev = 0x306	// 表示第2个硬盘的第1个分区
short boot_flag = 0xaa55;
