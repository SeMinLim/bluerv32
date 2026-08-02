import FIFO::*;

import Defines::*;
import Processor::*;

import "BDPI" function ActionValue#(Bit#(32)) bdpiAct4Read(Bit#(32) addr);
import "BDPI" function Action bdpiAct4Write(Bit#(32) addr, Bit#(32) data,
	Bit#(2) size);
import "BDPI" function Action bdpiAct4PutChar(Bit#(8) data);

Word act4MemoryBase = 32'h00000000;
Word act4MemoryLimit = 32'h00100000;
Word uartTxAddr = 32'h10000000;

function Bool accessInAct4Memory(Word addr, AccessSize size);
	Word bytes = accessSizeBytes(size);
	Word lastAddr = addr + bytes - 1;
	return (addr >= act4MemoryBase) && (lastAddr >= addr) &&
		(lastAddr < act4MemoryLimit);
endfunction

module mkTop_act4(Empty);
	ProcessorIfc processor <- mkProcessor;

	FIFO#(MemResp) instructionResponseQ <- mkFIFO;
	FIFO#(MemResp) dataResponseQ <- mkFIFO;

	//------------------------------------------------------------------------------------
	// [INSTRUCTION MEMORY]
	// Serve instruction fetches from the ACT4 unified simulation memory
	//------------------------------------------------------------------------------------
	rule relayInstructionRequest;
		let request <- processor.iMemReq;
		Bool validRequest = !request.write && request.size == WordAccess &&
			accessInAct4Memory(request.addr, WordAccess);
		MemResp response = MemResp {data: 0, fault: !validRequest};

		if ( validRequest ) begin
			let data <- bdpiAct4Read(request.addr);
			response.data = data;
		end
		instructionResponseQ.enq(response);
	endrule

	rule relayInstructionResponse;
		MemResp response = instructionResponseQ.first;
		instructionResponseQ.deq;
		processor.iMemResp(response);
	endrule

	//------------------------------------------------------------------------------------
	// [DATA MEMORY]
	// Serve loads and stores from the same ACT4 memory image and preserve the UART MMIO
	//------------------------------------------------------------------------------------
	rule relayDataRequest;
		let request <- processor.dMemReq;
		Bool inMemory = accessInAct4Memory(request.addr, request.size);
		Bool uartWrite = request.write && request.size == ByteAccess &&
			request.addr == uartTxAddr;
		MemResp response = MemResp {data: 0, fault: False};

		if ( inMemory ) begin
			if ( request.write ) begin
				bdpiAct4Write(request.addr, request.data, pack(request.size));
			end else begin
				let data <- bdpiAct4Read(request.addr);
				response.data = data;
			end
		end else if ( uartWrite ) begin
			bdpiAct4PutChar(truncate(request.data));
		end else begin
			response.fault = True;
		end
		dataResponseQ.enq(response);
	endrule

	rule relayDataResponse;
		MemResp response = dataResponseQ.first;
		dataResponseQ.deq;
		processor.dMemResp(response);
	endrule

	//------------------------------------------------------------------------------------
	// [TERMINATION]
	// ACT4 self-checking tests terminate with EBREAK after printing RVCP-SUMMARY
	//------------------------------------------------------------------------------------
	rule finishSimulation;
		let info <- processor.trap;
		$display("RV32_TRAP pc=%08x cause=%0d value=%08x",
			info.pc, pack(info.cause), info.value);
		$finish;
	endrule
endmodule
