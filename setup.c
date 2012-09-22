/*
	0x9000:0x0~0x9000:1FF
*/
int initseg = 0x9000;
int sysseg = 0x1000;
int setupseg = 0x9020;

start()
{
	ds = ax = initseg;		//0x9000
	ah = 0x03;			//read cursor pos
	bh = 0;
	int 0x10;
	ds:[0] = dx;			//0x9000:0x0

/***************************************************/
	//get memory size
	ah = 0x88;
	int 0x15;
	ds:[2] = ax;			//0x9000:0x2

	//get video card data

	ah = 0x0f;
	int 0x10;
	ds:[4] = bx;
	ds:[6] = ax;

	//check for EGA/VGA and some config parameters

	ah = 0x12;
	bl = 0x10;
	int 0x10;
	ds:[8] = ax;
	ds:[10] = bx;
	ds:[12] = cx;

	//get hd0 data
	ds = ax = 0;
	lds si, [4*0x41]
	es = ax = initseg;		//0x9000
	di = 0x0080;
	cx = 0x10;
	rep movsb

	//get h1 data
	//check that there IS a hd1
	//move to protected mode
	//move the system to it's 
	// load the segment descriptors
	//enable A20
	//reprogram the interrupts
}
