import Defines::*;
import Decode::*;

typedef struct {
	InstructionType instructionType;
	RIndx dst;
	Bool writeDst;
	Word data;
	Word addr;
	Word nextPc;
	Bool controlTransfer;
} ExecInst deriving (Bits, Eq, FShow);

function Word alu(Word a, Word b, AluFunc func);
	Word result = case ( func )
		Add: (a + b);
		Sub: (a - b);
		And: (a & b);
		Or: (a | b);
		Xor: (a ^ b);
		SetLessThan: (signedLT(a, b) ? 1 : 0);
		SetLessThanUnsigned: ((a < b) ? 1 : 0);
		ShiftLeftLogical: (a << b[4:0]);
		ShiftRightLogical: (a >> b[4:0]);
		ShiftRightArithmetic: signedShiftRight(a, b[4:0]);
	endcase;
	return result;
endfunction

function Bool branchCondition(Word a, Word b, BranchFunc func);
	Bool taken = case ( func )
		Equal: (a == b);
		NotEqual: (a != b);
		LessThan: signedLT(a, b);
		LessThanUnsigned: (a < b);
		GreaterEqual: signedGE(a, b);
		GreaterEqualUnsigned: (a >= b);
	endcase;
	return taken;
endfunction

function ExecInst execute(DecodedInst decoded, Word src1, Word src2, Word pc);
	Word data = 0;
	Word addr = 0;
	Word nextPc = pc + 4;
	Bool controlTransfer = False;

	case ( decoded.instructionType )
		AluRegister: begin data = alu(src1, src2, decoded.aluFunc); end
		AluImmediate: begin data = alu(src1, decoded.immediate, decoded.aluFunc); end
		Branch: begin
			Bool taken = branchCondition(src1, src2, decoded.branchFunc);
			if ( taken ) begin
				nextPc = pc + decoded.immediate;
				controlTransfer = True;
			end
		end
		LoadUpperImmediate: begin data = decoded.immediate; end
		AddUpperImmediatePc: begin data = pc + decoded.immediate; end
		JumpAndLink: begin
			data = pc + 4;
			nextPc = pc + decoded.immediate;
			controlTransfer = True;
		end
		JumpAndLinkRegister: begin
			data = pc + 4;
			nextPc = (src1 + decoded.immediate) & 32'hfffffffe;
			controlTransfer = True;
		end
		Load: begin addr = src1 + decoded.immediate; end
		Store: begin
			addr = src1 + decoded.immediate;
			data = src2;
		end
		default: begin end
	endcase

	return ExecInst {
		instructionType: decoded.instructionType,
		dst: decoded.dst,
		writeDst: decoded.writeDst,
		data: data,
		addr: addr,
		nextPc: nextPc,
		controlTransfer: controlTransfer
	};
endfunction
