import FIFO::*;

import Defines::*;
import Decode::*;
import Execute::*;
import RFile::*;

typedef struct {
	Word pc;
	Word instruction;
	Word nextPc;
	Word addr;
	RIndx dst;
	Bool writeDst;
	Bool load;
	AccessSize accessSize;
	Bool extendSigned;
} PendingMemory deriving (Bits, Eq, FShow);

typedef struct {
	Word pc;
	Word instruction;
	Word nextPc;
	RIndx dst;
	Bool writeDst;
	Word data;
} WritebackInfo deriving (Bits, Eq, FShow);

interface ProcessorIfc;
	method ActionValue#(MemReq) iMemReq;
	method Action iMemResp(MemResp response);
	method ActionValue#(MemReq) dMemReq;
	method Action dMemResp(MemResp response);
	method ActionValue#(TrapInfo) trap;
endinterface

function PendingMemory defaultPendingMemory();
	return PendingMemory {
		pc: 0,
		instruction: 0,
		nextPc: 0,
		addr: 0,
		dst: 0,
		writeDst: False,
		load: False,
		accessSize: WordAccess,
		extendSigned: False
	};
endfunction

function WritebackInfo defaultWritebackInfo();
	return WritebackInfo {
		pc: 0,
		instruction: 0,
		nextPc: 0,
		dst: 0,
		writeDst: False,
		data: 0
	};
endfunction

function TrapInfo makeTrap(Word pc, TrapCause cause, Word value);
	return TrapInfo {
		pc: pc,
		cause: cause,
		value: value
	};
endfunction

(* synthesize *)
module mkProcessor(ProcessorIfc);
	Reg#(Word) pc <- mkReg(0);
	Reg#(ProcessorState) state <- mkReg(FetchRequest);
	RFile2R1W registerFile <- mkRFile2R1W;

	Reg#(Word) instructionR <- mkReg(0);
	Reg#(DecodedInst) decodedR <- mkReg(defaultDecodedInst());
	Reg#(Word) src1R <- mkReg(0);
	Reg#(Word) src2R <- mkReg(0);
	Reg#(PendingMemory) pendingMemoryR <- mkReg(defaultPendingMemory());
	Reg#(WritebackInfo) writebackR <- mkReg(defaultWritebackInfo());

	FIFO#(MemReq) iMemReqQ <- mkFIFO;
	FIFO#(MemResp) iMemRespQ <- mkFIFO;
	FIFO#(MemReq) dMemReqQ <- mkFIFO;
	FIFO#(MemResp) dMemRespQ <- mkFIFO;
	FIFO#(TrapInfo) trapQ <- mkFIFO;

	Reg#(Bit#(64)) cycleCnt <- mkReg(0);
	Reg#(Bit#(64)) instructionCnt <- mkReg(0);

	rule countCycle ( state != Trapped );
		cycleCnt <= cycleCnt + 1;
	endrule

	//------------------------------------------------------------------------------------
	// [FETCH]
	// Request and receive one aligned 32-bit instruction
	//------------------------------------------------------------------------------------
	rule fetchRequest ( state == FetchRequest );
		if ( pc[1:0] != 0 ) begin
			trapQ.enq(makeTrap(pc, InstructionAddressMisaligned, pc));
			state <= Trapped;
		end else begin
			iMemReqQ.enq(MemReq {
				addr: pc,
				data: 0,
				size: WordAccess,
				write: False
			});
			state <= FetchResponse;
		end
	endrule

	rule fetchResponse ( state == FetchResponse );
		let response = iMemRespQ.first;
		iMemRespQ.deq;

		if ( response.fault ) begin
			trapQ.enq(makeTrap(pc, InstructionAccessFault, pc));
			state <= Trapped;
		end else begin
			instructionR <= response.data;
			state <= DecodeStage;
		end
	endrule

	//------------------------------------------------------------------------------------
	// [DECODE]
	// Validate the complete RV32I encoding and read architectural registers
	//------------------------------------------------------------------------------------
	rule decodeInstruction ( state == DecodeStage );
		DecodedInst decoded = decode(instructionR);

		if ( !decoded.valid ) begin
			trapQ.enq(makeTrap(pc, IllegalInstruction, instructionR));
			state <= Trapped;
		end else begin
			decodedR <= decoded;
			src1R <= registerFile.rd1(decoded.src1);
			src2R <= registerFile.rd2(decoded.src2);
			state <= ExecuteStage;
		end
	endrule

	//------------------------------------------------------------------------------------
	// [EXECUTE]
	// Execute arithmetic and control operations or issue one data-memory request
	//------------------------------------------------------------------------------------
	rule executeInstruction ( state == ExecuteStage );
		ExecInst executed = execute(decodedR, src1R, src2R, pc);

		if ( decodedR.instructionType == EnvironmentCallInst ) begin
			trapQ.enq(makeTrap(pc, EnvironmentCall, 0));
			state <= Trapped;
		end else if ( decodedR.instructionType == BreakpointInst ) begin
			trapQ.enq(makeTrap(pc, Breakpoint, pc));
			state <= Trapped;
		end else if ( executed.controlTransfer && executed.nextPc[1:0] != 0 ) begin
			trapQ.enq(makeTrap(pc, InstructionAddressMisaligned, executed.nextPc));
			state <= Trapped;
		end else if ( decodedR.instructionType == Load ||
				decodedR.instructionType == Store ) begin
			Bool aligned = isAddressAligned(executed.addr, decodedR.accessSize);

			if ( !aligned ) begin
				TrapCause cause = (decodedR.instructionType == Load) ?
					LoadAddressMisaligned : StoreAddressMisaligned;
				trapQ.enq(makeTrap(pc, cause, executed.addr));
				state <= Trapped;
			end else begin
				dMemReqQ.enq(MemReq {
					addr: executed.addr,
					data: executed.data,
					size: decodedR.accessSize,
					write: (decodedR.instructionType == Store)
				});
				pendingMemoryR <= PendingMemory {
					pc: pc,
					instruction: instructionR,
					nextPc: executed.nextPc,
					addr: executed.addr,
					dst: decodedR.dst,
					writeDst: decodedR.writeDst,
					load: (decodedR.instructionType == Load),
					accessSize: decodedR.accessSize,
					extendSigned: decodedR.extendSigned
				};
				state <= DataResponse;
			end
		end else begin
			writebackR <= WritebackInfo {
				pc: pc,
				instruction: instructionR,
				nextPc: executed.nextPc,
				dst: executed.dst,
				writeDst: executed.writeDst,
				data: executed.data
			};
			state <= WritebackStage;
		end
	endrule

	//------------------------------------------------------------------------------------
	// [MEMORY]
	// Complete a load or store only after the memory system reports success
	//------------------------------------------------------------------------------------
	rule receiveDataResponse ( state == DataResponse );
		let response = dMemRespQ.first;
		dMemRespQ.deq;
		PendingMemory pending = pendingMemoryR;

		if ( response.fault ) begin
			TrapCause cause = pending.load ? LoadAccessFault : StoreAccessFault;
			trapQ.enq(makeTrap(pending.pc, cause, pending.addr));
			state <= Trapped;
		end else begin
			Word data = 0;
			if ( pending.load ) begin
				case ( pending.accessSize )
					ByteAccess: begin
						if ( pending.extendSigned ) begin
							Int#(8) signedData = unpack(response.data[7:0]);
							data = pack(signExtend(signedData));
						end else begin
							data = zeroExtend(response.data[7:0]);
						end
					end
					HalfAccess: begin
						if ( pending.extendSigned ) begin
							Int#(16) signedData = unpack(response.data[15:0]);
							data = pack(signExtend(signedData));
						end else begin
							data = zeroExtend(response.data[15:0]);
						end
					end
					WordAccess: begin data = response.data; end
				endcase
			end

			writebackR <= WritebackInfo {
				pc: pending.pc,
				instruction: pending.instruction,
				nextPc: pending.nextPc,
				dst: pending.dst,
				writeDst: pending.writeDst,
				data: data
			};
			state <= WritebackStage;
		end
	endrule

	//------------------------------------------------------------------------------------
	// [WRITEBACK]
	// Commit exactly one successfully completed instruction
	//------------------------------------------------------------------------------------
	rule writebackInstruction ( state == WritebackStage );
		WritebackInfo info = writebackR;

		if ( info.writeDst ) begin
			registerFile.wr(info.dst, info.data);
		end
		pc <= info.nextPc;
		instructionCnt <= instructionCnt + 1;
		state <= FetchRequest;

`ifdef RV32_TRACE
		$display("RV32_COMMIT pc=%08x inst=%08x rd=%0d data=%08x write=%0d cycle=%0d instret=%0d",
			info.pc, info.instruction, info.dst, info.data,
			info.writeDst, cycleCnt, instructionCnt + 1);
`endif
	endrule

	method ActionValue#(MemReq) iMemReq;
		let request = iMemReqQ.first;
		iMemReqQ.deq;
		return request;
	endmethod

	method Action iMemResp(MemResp response);
		iMemRespQ.enq(response);
	endmethod

	method ActionValue#(MemReq) dMemReq;
		let request = dMemReqQ.first;
		dMemReqQ.deq;
		return request;
	endmethod

	method Action dMemResp(MemResp response);
		dMemRespQ.enq(response);
	endmethod

	method ActionValue#(TrapInfo) trap;
		let info = trapQ.first;
		trapQ.deq;
		return info;
	endmethod
endmodule
