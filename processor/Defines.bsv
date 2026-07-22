typedef Bit#(32) Word;
typedef Bit#(5) RIndx;

typedef enum {
	ByteAccess,
	HalfAccess,
	WordAccess
} AccessSize deriving (Bits, Eq, FShow);

typedef enum {
	FetchRequest,
	FetchResponse,
	DecodeStage,
	ExecuteStage,
	DataResponse,
	WritebackStage,
	Trapped
} ProcessorState deriving (Bits, Eq, FShow);

typedef enum {
	InstructionAddressMisaligned,
	InstructionAccessFault,
	IllegalInstruction,
	Breakpoint,
	LoadAddressMisaligned,
	LoadAccessFault,
	StoreAddressMisaligned,
	StoreAccessFault,
	EnvironmentCall
} TrapCause deriving (Bits, Eq, FShow);

typedef struct {
	Word addr;
	Word data;
	AccessSize size;
	Bool write;
} MemReq deriving (Bits, Eq, FShow);

typedef struct {
	Word data;
	Bool fault;
} MemResp deriving (Bits, Eq, FShow);

typedef struct {
	Word pc;
	TrapCause cause;
	Word value;
} TrapInfo deriving (Bits, Eq, FShow);

function Word accessSizeBytes(AccessSize size);
	Word bytes = case ( size )
		ByteAccess: 1;
		HalfAccess: 2;
		WordAccess: 4;
	endcase;
	return bytes;
endfunction

function Bool isAddressAligned(Word addr, AccessSize size);
	Bool aligned = case ( size )
		ByteAccess: True;
		HalfAccess: (addr[0] == 0);
		WordAccess: (addr[1:0] == 0);
	endcase;
	return aligned;
endfunction
