import Defines::*;

typedef enum {
	AluRegister,
	AluImmediate,
	Branch,
	LoadUpperImmediate,
	AddUpperImmediatePc,
	JumpAndLink,
	JumpAndLinkRegister,
	Load,
	Store,
	Fence,
	EnvironmentCallInst,
	BreakpointInst,
	IllegalInst
} InstructionType deriving (Bits, Eq, FShow);

typedef enum {
	Add,
	Sub,
	And,
	Or,
	Xor,
	SetLessThan,
	SetLessThanUnsigned,
	ShiftLeftLogical,
	ShiftRightLogical,
	ShiftRightArithmetic
} AluFunc deriving (Bits, Eq, FShow);

typedef enum {
	Equal,
	NotEqual,
	LessThan,
	LessThanUnsigned,
	GreaterEqual,
	GreaterEqualUnsigned
} BranchFunc deriving (Bits, Eq, FShow);

typedef struct {
	InstructionType instructionType;
	AluFunc aluFunc;
	BranchFunc branchFunc;
	Bool valid;
	Bool writeDst;
	RIndx dst;
	RIndx src1;
	RIndx src2;
	Word immediate;
	AccessSize accessSize;
	Bool extendSigned;
} DecodedInst deriving (Bits, Eq, FShow);

Bit#(7) opLoad = 7'b0000011;
Bit#(7) opMiscMem = 7'b0001111;
Bit#(7) opImmediate = 7'b0010011;
Bit#(7) opAuipc = 7'b0010111;
Bit#(7) opStore = 7'b0100011;
Bit#(7) opRegister = 7'b0110011;
Bit#(7) opLui = 7'b0110111;
Bit#(7) opBranch = 7'b1100011;
Bit#(7) opJalr = 7'b1100111;
Bit#(7) opJal = 7'b1101111;
Bit#(7) opSystem = 7'b1110011;

function DecodedInst defaultDecodedInst();
	return DecodedInst {
		instructionType: IllegalInst,
		aluFunc: Add,
		branchFunc: Equal,
		valid: False,
		writeDst: False,
		dst: 0,
		src1: 0,
		src2: 0,
		immediate: 0,
		accessSize: WordAccess,
		extendSigned: False
	};
endfunction

function DecodedInst decode(Bit#(32) instruction);
	Bit#(7) opcode = instruction[6:0];
	Bit#(3) funct3 = instruction[14:12];
	Bit#(7) funct7 = instruction[31:25];
	RIndx dst = instruction[11:7];
	RIndx src1 = instruction[19:15];
	RIndx src2 = instruction[24:20];

	Word immediateI = signExtend(instruction[31:20]);
	Word immediateS = signExtend({instruction[31:25], instruction[11:7]});
	Word immediateB = signExtend({instruction[31], instruction[7],
		instruction[30:25], instruction[11:8], 1'b0});
	Word immediateU = {instruction[31:12], 12'b0};
	Word immediateJ = signExtend({instruction[31], instruction[19:12],
		instruction[20], instruction[30:21], 1'b0});

	DecodedInst decoded = defaultDecodedInst();

	case ( opcode )
		opRegister: begin
			if ( funct7 == 7'b0000000 ) begin
				case ( funct3 )
					3'b000: begin decoded.valid = True; decoded.aluFunc = Add; end
					3'b001: begin decoded.valid = True; decoded.aluFunc = ShiftLeftLogical; end
					3'b010: begin decoded.valid = True; decoded.aluFunc = SetLessThan; end
					3'b011: begin decoded.valid = True; decoded.aluFunc = SetLessThanUnsigned; end
					3'b100: begin decoded.valid = True; decoded.aluFunc = Xor; end
					3'b101: begin decoded.valid = True; decoded.aluFunc = ShiftRightLogical; end
					3'b110: begin decoded.valid = True; decoded.aluFunc = Or; end
					3'b111: begin decoded.valid = True; decoded.aluFunc = And; end
				endcase
			end else if ( funct7 == 7'b0100000 ) begin
				case ( funct3 )
					3'b000: begin decoded.valid = True; decoded.aluFunc = Sub; end
					3'b101: begin decoded.valid = True; decoded.aluFunc = ShiftRightArithmetic; end
					default: begin end
				endcase
			end
			if ( decoded.valid ) begin
				decoded.instructionType = AluRegister;
				decoded.writeDst = True;
				decoded.dst = dst;
				decoded.src1 = src1;
				decoded.src2 = src2;
			end
		end

		opImmediate: begin
			case ( funct3 )
				3'b000: begin decoded.valid = True; decoded.aluFunc = Add; end
				3'b010: begin decoded.valid = True; decoded.aluFunc = SetLessThan; end
				3'b011: begin decoded.valid = True; decoded.aluFunc = SetLessThanUnsigned; end
				3'b100: begin decoded.valid = True; decoded.aluFunc = Xor; end
				3'b110: begin decoded.valid = True; decoded.aluFunc = Or; end
				3'b111: begin decoded.valid = True; decoded.aluFunc = And; end
				3'b001: begin
					if ( funct7 == 7'b0000000 ) begin
						decoded.valid = True;
						decoded.aluFunc = ShiftLeftLogical;
					end
				end
				3'b101: begin
					if ( funct7 == 7'b0000000 ) begin
						decoded.valid = True;
						decoded.aluFunc = ShiftRightLogical;
					end else if ( funct7 == 7'b0100000 ) begin
						decoded.valid = True;
						decoded.aluFunc = ShiftRightArithmetic;
					end
				end
			endcase
			if ( decoded.valid ) begin
				decoded.instructionType = AluImmediate;
				decoded.writeDst = True;
				decoded.dst = dst;
				decoded.src1 = src1;
				decoded.immediate = immediateI;
			end
		end

		opBranch: begin
			case ( funct3 )
				3'b000: begin decoded.valid = True; decoded.branchFunc = Equal; end
				3'b001: begin decoded.valid = True; decoded.branchFunc = NotEqual; end
				3'b100: begin decoded.valid = True; decoded.branchFunc = LessThan; end
				3'b101: begin decoded.valid = True; decoded.branchFunc = GreaterEqual; end
				3'b110: begin decoded.valid = True; decoded.branchFunc = LessThanUnsigned; end
				3'b111: begin decoded.valid = True; decoded.branchFunc = GreaterEqualUnsigned; end
				default: begin end
			endcase
			if ( decoded.valid ) begin
				decoded.instructionType = Branch;
				decoded.src1 = src1;
				decoded.src2 = src2;
				decoded.immediate = immediateB;
			end
		end

		opLoad: begin
			case ( funct3 )
				3'b000: begin decoded.valid = True; decoded.accessSize = ByteAccess; decoded.extendSigned = True; end
				3'b001: begin decoded.valid = True; decoded.accessSize = HalfAccess; decoded.extendSigned = True; end
				3'b010: begin decoded.valid = True; decoded.accessSize = WordAccess; decoded.extendSigned = False; end
				3'b100: begin decoded.valid = True; decoded.accessSize = ByteAccess; decoded.extendSigned = False; end
				3'b101: begin decoded.valid = True; decoded.accessSize = HalfAccess; decoded.extendSigned = False; end
				default: begin end
			endcase
			if ( decoded.valid ) begin
				decoded.instructionType = Load;
				decoded.writeDst = True;
				decoded.dst = dst;
				decoded.src1 = src1;
				decoded.immediate = immediateI;
			end
		end

		opStore: begin
			case ( funct3 )
				3'b000: begin decoded.valid = True; decoded.accessSize = ByteAccess; end
				3'b001: begin decoded.valid = True; decoded.accessSize = HalfAccess; end
				3'b010: begin decoded.valid = True; decoded.accessSize = WordAccess; end
				default: begin end
			endcase
			if ( decoded.valid ) begin
				decoded.instructionType = Store;
				decoded.src1 = src1;
				decoded.src2 = src2;
				decoded.immediate = immediateS;
			end
		end

		opLui: begin
			decoded.valid = True;
			decoded.instructionType = LoadUpperImmediate;
			decoded.writeDst = True;
			decoded.dst = dst;
			decoded.immediate = immediateU;
		end

		opAuipc: begin
			decoded.valid = True;
			decoded.instructionType = AddUpperImmediatePc;
			decoded.writeDst = True;
			decoded.dst = dst;
			decoded.immediate = immediateU;
		end

		opJal: begin
			decoded.valid = True;
			decoded.instructionType = JumpAndLink;
			decoded.writeDst = True;
			decoded.dst = dst;
			decoded.immediate = immediateJ;
		end

		opJalr: begin
			if ( funct3 == 3'b000 ) begin
				decoded.valid = True;
				decoded.instructionType = JumpAndLinkRegister;
				decoded.writeDst = True;
				decoded.dst = dst;
				decoded.src1 = src1;
				decoded.immediate = immediateI;
			end
		end

		opMiscMem: begin
			if ( funct3 == 3'b000 ) begin
				decoded.valid = True;
				decoded.instructionType = Fence;
			end
		end

		opSystem: begin
			if ( instruction == 32'h00000073 ) begin
				decoded.valid = True;
				decoded.instructionType = EnvironmentCallInst;
			end else if ( instruction == 32'h00100073 ) begin
				decoded.valid = True;
				decoded.instructionType = BreakpointInst;
			end
		end

		default: begin end
	endcase

	return decoded;
endfunction
