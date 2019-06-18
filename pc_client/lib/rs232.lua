
--rs232 serial communication library for LuaJIT.
--Written by Cosmin Apreutesei. Public Domain.

local ffi = require'ffi'
local fs = require'lib.fs'
local C = ffi.C

local rs = {}

rs.default_baud_rate = 9600

if jit.os == 'Windows' then

	ffi.cdef[[
	uint32_t GetLastError(void);

	typedef struct _COMMTIMEOUTS {
		 uint32_t ReadIntervalTimeout;
		 uint32_t ReadTotalTimeoutMultiplier;
		 uint32_t ReadTotalTimeoutConstant;
		 uint32_t WriteTotalTimeoutMultiplier;
		 uint32_t WriteTotalTimeoutConstant;
	} COMMTIMEOUTS;

	typedef struct _DCB {
		 uint32_t DCBlength;
		 uint32_t BaudRate;
		 uint32_t fBinary  :1;
		 uint32_t fParity  :1;
		 uint32_t fOutxCtsFlow  :1;
		 uint32_t fOutxDsrFlow  :1;
		 uint32_t fDtrControl  :2;
		 uint32_t fDsrSensitivity  :1;
		 uint32_t fTXContinueOnXoff  :1;
		 uint32_t fOutX  :1;
		 uint32_t fInX  :1;
		 uint32_t fErrorChar  :1;
		 uint32_t fNull  :1;
		 uint32_t fRtsControl  :2;
		 uint32_t fAbortOnError  :1;
		 uint32_t fDummy2  :17;
		 uint16_t wReserved;
		 uint16_t XonLim;
		 uint16_t XoffLim;
		 uint8_t  ByteSize;
		 uint8_t  Parity;
		 uint8_t  StopBits;
		 int8_t  XonChar;
		 int8_t  XoffChar;
		 int8_t  ErrorChar;
		 int8_t  EofChar;
		 int8_t  EvtChar;
		 uint16_t wReserved1;
	} DCB;

	uint32_t QueryDosDeviceA(
		const char *lpDeviceName,
		char       *lpTargetPath,
		uint32_t    ucchMax);

	int GetCommState(void *hFile, DCB *lpDCB);
	int GetCommTimeouts(void *hFile, COMMTIMEOUTS *lpCommTimeouts);
	int SetCommState(void *hFile, DCB *lpDCB);
	int SetCommTimeouts(void *hFile, COMMTIMEOUTS *lpCommTimeouts);
	int SetupComm(void * hFile, uint32_t dwInQueue, uint32_t dwOutQueue);
	]]

	local ERROR_INSUFFICIENT_BUFFER   = 122

	local INVALID_HANDLE_VALUE        = -1
	local GENERIC_READ                = 0x80000000
	local GENERIC_WRITE               = 0x40000000
	local OPEN_EXISTING               = 3
	local MAX_DWORD                   = 0xFFFFFFFF

	function rs.ports()
		local sz = 1024 * 16
		local buf = ffi.new('uint8_t[?]', sz)
		local n = C.QueryDosDeviceA(nil, buf, sz)
		while(n == 0 and C.GetLastError() == ERROR_INSUFFICIENT_BUFFER) do
			sz = sz * 2
			buf = ffi.new('uint8_t[?]', sz)
			n = C.QueryDosDeviceA(nil, buf, sz)
		end
		if n == 0 then
			local err = C.GetLastError()
			return nil, 'QueryDosDevice() error '.. err, err
		end
		local t = {}
		for s in ffi.string(buf, n):gmatch'(COM[^%z]+)' do
			t[#t+1] = s
		end
		return t
	end

	function rs.open(devname, baud_rate)
		baud_rate = baud_rate or rs.default_baud_rate

		local f, err, errcode = fs.open('//./'..devname, 'r+')
		if not f then return nil, err, errcode end

		C.SetupComm(f.handle, 1200, 1200)

		local timeouts = ffi.new'COMMTIMEOUTS'
		timeouts.ReadIntervalTimeout = 0xffffffff
		C.SetCommTimeouts(f.handle, timeouts)

		local config = ffi.new'DCB'
		C.GetCommState(f.handle, config)
		config.BaudRate = baud_rate
		config.fBinary = -1
		config.fParity = 0
		config.fErrorChar = 0
		config.fNull = 0
		config.fAbortOnError = 0
		config.ByteSize = 8
		config.Parity = 0
		config.StopBits = 0
		config.EvtChar = 10

		if C.SetCommState(f.handle, config) == 0 then
			f:close()
			local err = C.GetLastError()
			return nil, 'SetCommState() error '.. err, err
		end

		return f
	end

elseif jit.os == 'Linux' then

	local names = {'^ttyACM', '^ttyUSB', '^rfcomm'}
	local function iscom(name)
		for _,s in ipairs(names) do
			if name:find(s) then
				return true
			end
		end
	end

	function rs.ports()
		local t = {}
		for name, d in fs.dir'/dev' do
			if iscom(name) then
				t[#t+1] = name
			end
		end
		return t
	end

	ffi.cdef[[
	typedef unsigned char cc_t;
	typedef unsigned int speed_t;
	typedef unsigned int tcflag_t;
	struct termios {
		tcflag_t c_iflag;
		tcflag_t c_oflag;
		tcflag_t c_cflag;
		tcflag_t c_lflag;
		cc_t c_line;
		cc_t c_cc[32];
		speed_t c_ispeed;
		speed_t c_ospeed;
	};

	int tcgetattr (int fd, struct termios *);
	int tcsetattr (int fd, int optional_actions, const struct termios *);
	int cfsetospeed (struct termios*, speed_t);
	int cfsetispeed (struct termios*, speed_t);
	]]

	local function oct(s)
		return assert(tonumber(s, 8))
	end

	local baud_flags = {
		[0      ] = oct'0000000',
		[50     ] = oct'0000001',
		[75     ] = oct'0000002',
		[110    ] = oct'0000003',
		[134    ] = oct'0000004',
		[150    ] = oct'0000005',
		[200    ] = oct'0000006',
		[300    ] = oct'0000007',
		[600    ] = oct'0000010',
		[1200   ] = oct'0000011',
		[1800   ] = oct'0000012',
		[2400   ] = oct'0000013',
		[4800   ] = oct'0000014',
		[9600   ] = oct'0000015',
		[19200  ] = oct'0000016',
		[38400  ] = oct'0000017',
		[57600  ] = oct'0010001',
		[115200 ] = oct'0010002',
		[230400 ] = oct'0010003',
		[460800 ] = oct'0010004',
		[500000 ] = oct'0010005',
		[576000 ] = oct'0010006',
		[921600 ] = oct'0010007',
		[1000000] = oct'0010010',
		[1152000] = oct'0010011',
		[1500000] = oct'0010012',
		[2000000] = oct'0010013',
		[2500000] = oct'0010014',
		[3000000] = oct'0010015',
		[3500000] = oct'0010016',
		[4000000] = oct'0010017',
	}

	local INLCR   = oct'0000100'
	local ICRNL   = oct'0000400'
	local IGNPAR  = oct'0000004'
	local IGNBRK  = oct'0000001'
	local OPOST   = oct'0000001'
	local ONLCR   = oct'0000004'
	local OCRNL   = oct'0000010'
	local PARENB  = oct'0000400'
	local PARODD  = oct'0001000'
	local CSTOPB  = oct'0000100'
	local CSIZE   = oct'0000060'
	local CRTSCTS = oct'020000000000'
	local CLOCAL  = oct'0004000'
	local CREAD   = oct'0000200'
	local CS8     = oct'0000060'
	local ICANON  = oct'0000002'
	local ISIG    = oct'0000001'
	local ECHO    = oct'0000010'
	local VTIME   = 5
	local VMIN    = 6
	local TCSANOW = 0

	function rs.open(devname, baud_rate)
		baud_rate = baud_rate or rs.default_baud_rate

		local f, err, errcode = fs.open('/dev/'..devname,
			{flags='rdwr noctty ndelay'})
		if not f then return nil, err, errcode end

		local config = ffi.new'struct termios'
		C.tcgetattr(f.fd, config)

		local iflag = bit.bor(
			bit.bnot(bit.bor(INLCR, ICRNL)),
			IGNPAR, IGNBRK
		)
		local oflag = bit.bnot(bit.bor(OPOST, ONLCR, OCRNL))
		local cflag = bit.bor(
			bit.bnot(bit.bor(PARENB, CSTOPB, CSIZE, CRTSCTS)),
			CLOCAL, CREAD, CS8
		)
		local lflag = bit.bnot(bit.bor(ICANON, ISIG, ECHO))

		config.c_iflag = iflag
		config.c_oflag = oflag
		config.c_cflag = cflag
		config.c_lflag = lflag
		config.c_cc[VTIME] = 1
		config.c_cc[VMIN]  = 1

		local speed = assert(baud_flags[baud_rate], 'invalid baud rate')
		C.cfsetospeed(config, speed)
		C.cfsetispeed(config, speed)

		if C.tcsetattr(f.fd, TCSANOW, config) < 0 then
			f:close()
			return nil, 'tcsetattr() error'
		end

		return f
	end

elseif jit.os == 'OSX' then

	local names = {'^cu.'}
	local function iscom(name)
		for _,s in ipairs(names) do
			if name:find(s) then
				return true
			end
		end
	end

	function rs.ports()
		local t = {}
		for name, d in fs.dir'/dev' do
			if iscom(name) then
				t[#t+1] = name
			end
		end
		return t
	end

	ffi.cdef[[
	typedef unsigned long	tcflag_t;
	typedef unsigned char	cc_t;
	typedef unsigned long	speed_t;

	struct termios {
		tcflag_t	c_iflag;	/* input flags */
		tcflag_t	c_oflag;	/* output flags */
		tcflag_t	c_cflag;	/* control flags */
		tcflag_t	c_lflag;	/* local flags */
		cc_t		c_cc[20];	/* control chars */
		speed_t		c_ispeed;	/* input speed */
		speed_t		c_ospeed;	/* output speed */
	};

	int tcgetattr (int fd, struct termios *);
	int tcsetattr (int fd, int optional_actions, const struct termios *);
	int cfsetospeed (struct termios*, speed_t);
	int cfsetispeed (struct termios*, speed_t);
	]]

	local function oct(s)
		return assert(tonumber(s, 8))
	end

	local baud_flags = {
		[0      ] = 0,
		[50     ] = 50,
		[75     ] = 75,
		[110    ] = 110,
		[134    ] = 134,
		[150    ] = 150,
		[200    ] = 200,
		[300    ] = 300,
		[600    ] = 600,
		[1200   ] = 1200,
		[1800   ] = 1800,
		[2400   ] = 2400,
		[4800   ] = 4800,
		[9600   ] = 9600,
		[19200  ] = 19200,
		[38400  ] = 38400,
		[57600  ] = 57600,
		[115200 ] = 115200,
		[230400 ] = 230400,
		[460800 ] = 460800,
		[500000 ] = 500000,
		[576000 ] = 576000,
		[921600 ] = 921600,
		[1000000] = 1000000,
		[1152000] = 1152000,
		[1500000] = 1500000,
		[2000000] = 2000000,
		[2500000] = 2500000,
		[3000000] = 3000000,
		[3500000] = 3500000,
		[4000000] = 4000000,
	}

	local BRKINT	= 0x00000002
	local PARMRK	= 0x00000008
	local ISTRIP	=	0x00000020
	local IGNCR		= 0x00000080
	local IXON		= 0x00000200
	local IEXTEN 	= 0x00000400

	local ECHONL	= 0x00000010

	local INLCR   = 0x00000040
	local ICRNL   = 0x00000100
	local IGNPAR  = 0x00000004
	local IGNBRK  = 0x00000001
	local OPOST   = 0x00000001
	local ONLCR   = 0x00000002
	local OCRNL   = 0x00000010
	local PARENB  = 0x00001000
	local PARODD  = 0x00002000
	local CSTOPB  = 0x00000400
	local CSIZE   = 0x00000300
	local CCTS_OFLOW = 0x00010000
	local CRTS_IFLOW = 0x00020000
	local CRTSCTS =  bit.bor(CCTS_OFLOW, CRTS_IFLOW)
	local CLOCAL  = 0x00008000
	local CREAD   = 0x00000800
	local CS8     = 0x00000300
	local ICANON  = 0x00000100
	local ISIG    = 0x00000080
	local ECHO    = 0x00000008
	local VTIME   = 17
	local VMIN    = 16
	local TCSANOW = 0

	function rs.open(devname, baud_rate)
		baud_rate = baud_rate or rs.default_baud_rate

		local f, err, errcode = fs.open('/dev/'..devname,
			{flags='rdwr noctty sync nonblock'})
		if not f then return nil, err, errcode end

		local config = ffi.new'struct termios'
		C.tcgetattr(f.fd, config)

		local iflag = bit.band(
			bit.bnot(
				bit.bor(IGNBRK, BRKINT, PARMRK, ISTRIP, INLCR, IGNCR, ICRNL, IXON)
			),
			tonumber(config.c_iflag)
		)

		local lflag = bit.band(
			bit.bnot(
				bit.bor(ECHO, ECHONL, ICANON, ISIG, IEXTEN)
			),
			tonumber(config.c_lflag)
		)

		local oflag = bit.band(
			bit.bnot(OPOST),
			tonumber(config.c_oflag)
		)

		local oflag = bit.band(
			bit.bnot(OPOST),
			tonumber(config.c_oflag)
		)

		local cflag = bit.band(
			bit.bnot(bit.bor(PARENB, CSTOPB, CSIZE, CRTSCTS)),
			tonumber(config.c_cflag)
		)

		local cflag = bit.bor(
			bit.bor(CLOCAL, CREAD, CS8),
			cflag
		)

		local oflag = bit.band(
			bit.bnot(OPOST),
			tonumber(config.c_oflag)
		)

		config.c_iflag = iflag
		config.c_oflag = oflag
		config.c_cflag = cflag
		config.c_lflag = lflag
		config.c_cc[VTIME] = 1
		config.c_cc[VMIN]  = 1

		-- print(config.c_cflag, config.c_iflag, config.c_lflag, config.c_oflag);

		-- config.c_iflag = 0
		-- config.c_oflag = 0
		-- config.c_cflag = 51200
		-- config.c_lflag = 0


		local speed = assert(baud_flags[baud_rate], 'invalid baud rate')
		C.cfsetospeed(config, speed)
		C.cfsetispeed(config, speed)

		if C.tcsetattr(f.fd, TCSANOW, config) < 0 then
			print("error")
			f:close()
			return nil, 'tcsetattr() error'
		end
		return f
	end
end


if not ... then
	require'pp'(rs.ports())
	local dev = ffi.abi'win' and 'COM4' or 'ttyUSB0'
	local f = assert(rs.open(dev))
	print('opened '..dev)
	f:close()
end


return rs
