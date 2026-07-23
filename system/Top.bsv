import Clocks::*;
import FIFO::*;
import FIFOF::*;

import Defines::*;
import Processor::*;
import BRAMSubWord::*;
import Uart::*;

Word instructionBase = 32'h00000000;
Word instructionLimit = 32'h00001000;
Word dataBase = 32'h00001000;
Word dataLimit = 32'h00002000;
Word uartTxAddr = 32'h10000000;

function Bit#(8) nextMemoryLfsr(Bit#(8) value);
	Bit#(1) feedback = value[7] ^ value[5] ^ value[4] ^ value[3];
	return {value[6:0], feedback};
endfunction

function Bool memoryRequestReady(Bit#(8) value);
`ifdef RV32_RANDOM_MEMORY
	return value[0] == 1;
`else
	return True;
`endif
endfunction

function Bit#(3) memoryResponseDelay(Bit#(8) value);
`ifdef RV32_RANDOM_MEMORY
	return value[3:1];
`else
	return 0;
`endif
endfunction

function Bool accessInRange(Word addr, Word base, Word limit, AccessSize size);
	Word bytes = accessSizeBytes(size);
	Word lastAddr = addr + bytes - 1;
	return (addr >= base) && (lastAddr >= addr) && (lastAddr < limit);
endfunction

interface HwMainIfc;
	method ActionValue#(Bit#(8)) serialTx;
	method Action serialRx(Bit#(8) data);
endinterface

module mkHwMain(HwMainIfc);
	ProcessorIfc processor <- mkProcessor;
	BRAMSubWordIfc#(12) instructionMemory <- mkBRAMSubWord;
	BRAMSubWordIfc#(12) dataMemory <- mkBRAMSubWord;

	Reg#(Bool) processorOn <- mkReg(False);
	Reg#(Bit#(13)) instructionLoadCnt <- mkReg(0);
	Reg#(Bit#(13)) dataLoadCnt <- mkReg(0);
	Reg#(Maybe#(Bit#(8))) serialCommand <- mkReg(tagged Invalid);
	Reg#(Maybe#(TrapInfo)) trapR <- mkReg(tagged Invalid);
	Reg#(Bit#(8)) memoryLfsr <- mkReg(8'h1);
	Reg#(Maybe#(Word)) instructionResponseR <- mkReg(tagged Invalid);
	Reg#(Bit#(3)) instructionDelayCnt <- mkReg(0);
	Reg#(Maybe#(Word)) dataResponseR <- mkReg(tagged Invalid);
	Reg#(Bit#(3)) dataDelayCnt <- mkReg(0);

	FIFO#(Bit#(8)) serialRxQ <- mkFIFO;
	FIFOF#(Bit#(8)) serialTxQ <- mkFIFOF;

	rule advanceMemoryLfsr ( processorOn );
		memoryLfsr <= nextMemoryLfsr(memoryLfsr);
	endrule

	//------------------------------------------------------------------------------------
	// [PROCESSOR MEMORY]
	// Decode the 32-bit processor address space into instruction BRAM, data BRAM, and UART
	//------------------------------------------------------------------------------------
	rule relayInstructionRequest ( processorOn && memoryRequestReady(memoryLfsr) );
		let request <- processor.iMemReq;
		Bool valid = !request.write && request.size == WordAccess &&
			accessInRange(request.addr, instructionBase, instructionLimit, WordAccess);

		if ( valid ) begin
			instructionMemory.req(truncate(request.addr - instructionBase),
				0, WordAccess, False);
		end else begin
			processor.iMemResp(MemResp {data: 0, fault: True});
		end
	endrule

	rule captureInstructionResponse ( processorOn && !isValid(instructionResponseR) );
		let data <- instructionMemory.resp;
		instructionResponseR <= tagged Valid data;
		instructionDelayCnt <= memoryResponseDelay(memoryLfsr);
	endrule

	rule relayInstructionResponse ( processorOn && isValid(instructionResponseR) );
		if ( instructionDelayCnt == 0 ) begin
			Word data = fromMaybe(0, instructionResponseR);
			processor.iMemResp(MemResp {data: data, fault: False});
			instructionResponseR <= tagged Invalid;
		end else begin
			instructionDelayCnt <= instructionDelayCnt - 1;
		end
	endrule

	rule relayDataRequest ( processorOn && memoryRequestReady({memoryLfsr[0], memoryLfsr[7:1]}) );
		let request <- processor.dMemReq;
		Bool inDataMemory = accessInRange(request.addr, dataBase, dataLimit,
			request.size);

		if ( inDataMemory ) begin
			dataMemory.req(truncate(request.addr - dataBase), request.data,
				request.size, request.write);
		end else if ( request.write && request.size == ByteAccess &&
				request.addr == uartTxAddr ) begin
			Bit#(8) uartData = truncate(request.data);
			serialTxQ.enq(uartData);
			processor.dMemResp(MemResp {data: 0, fault: False});
`ifdef BSIM
			$display("RV32_UART data=%02x", uartData);
`endif
		end else begin
			processor.dMemResp(MemResp {data: 0, fault: True});
		end
	endrule

	rule captureDataResponse ( processorOn && !isValid(dataResponseR) );
		let data <- dataMemory.resp;
		dataResponseR <= tagged Valid data;
		dataDelayCnt <= memoryResponseDelay({memoryLfsr[4:0], memoryLfsr[7:5]});
	endrule

	rule relayDataResponse ( processorOn && isValid(dataResponseR) );
		if ( dataDelayCnt == 0 ) begin
			Word data = fromMaybe(0, dataResponseR);
			processor.dMemResp(MemResp {data: data, fault: False});
			dataResponseR <= tagged Invalid;
		end else begin
			dataDelayCnt <= dataDelayCnt - 1;
		end
	endrule

	//------------------------------------------------------------------------------------
	// [BOOT LOADER]
	// Command 0 writes instruction memory, command 2 writes data memory, command 1 starts
	//------------------------------------------------------------------------------------
	rule processSerialInput ( !processorOn && !isValid(trapR) );
		Bit#(8) data = serialRxQ.first;
		serialRxQ.deq;

		if ( !isValid(serialCommand) ) begin
			serialCommand <= tagged Valid data;
		end else begin
			Bit#(8) command = fromMaybe(0, serialCommand);
			serialCommand <= tagged Invalid;

			case ( command )
				0: begin
					if ( instructionLoadCnt < fromInteger(4096) ) begin
						instructionMemory.loadByte(truncate(instructionLoadCnt), data);
						instructionLoadCnt <= instructionLoadCnt + 1;
					end
				end
				2: begin
					if ( dataLoadCnt < fromInteger(4096) ) begin
						dataMemory.loadByte(truncate(dataLoadCnt), data);
						dataLoadCnt <= dataLoadCnt + 1;
					end
				end
				1: begin
					processorOn <= True;
				end
				default: begin end
			endcase
		end
	endrule

	//------------------------------------------------------------------------------------
	// [TRAP]
	// Stop the current program and report the external execution-environment trap
	//------------------------------------------------------------------------------------
	rule captureTrap ( processorOn );
		let info <- processor.trap;
		processorOn <= False;
		trapR <= tagged Valid info;
		serialTxQ.enq(8'h21);

`ifdef BSIM
		$display("RV32_TRAP pc=%08x cause=%0d value=%08x",
			info.pc, pack(info.cause), info.value);
`endif
	endrule

`ifdef BSIM
	rule finishSimulation ( isValid(trapR) && !serialTxQ.notEmpty );
		$finish;
	endrule
`endif

	method ActionValue#(Bit#(8)) serialTx;
		let data = serialTxQ.first;
		serialTxQ.deq;
		return data;
	endmethod

	method Action serialRx(Bit#(8) data);
		serialRxQ.enq(data);
	endmethod
endmodule

interface TopIfc;
	(* always_ready *)
	method Bit#(1) ftdi_txd;
	(* always_enabled, always_ready, prefix = "", result = "serial_rxd" *)
	method Action ftdi_rx(Bit#(1) ftdi_rxd);
endinterface

(* no_default_clock, no_default_reset *)
module mkTop#(Clock clk_25mhz)(TopIfc);
	Reset resetNull = noReset();
	UartIfc uart <- mkUart(2604, clocked_by clk_25mhz, reset_by resetNull);
	HwMainIfc main <- mkHwMain(clocked_by clk_25mhz, reset_by resetNull);

	rule relayUartInput;
		let data <- uart.user.get;
		main.serialRx(data);
	endrule

	rule relayUartOutput;
		let data <- main.serialTx;
		uart.user.send(data);
	endrule

	method Bit#(1) ftdi_txd;
		return uart.serial_txd;
	endmethod

	method Action ftdi_rx(Bit#(1) ftdi_rxd);
		uart.serial_rx(ftdi_rxd);
	endmethod
endmodule

module mkTop_bsim(Empty);
	HwMainIfc main <- mkHwMain;
	UartUserIfc uart <- mkUart_bsim;

	rule relayUartInput;
		let data <- uart.get;
		main.serialRx(data);
	endrule

	rule relayUartOutput;
		let data <- main.serialTx;
		uart.send(data);
	endrule
endmodule
