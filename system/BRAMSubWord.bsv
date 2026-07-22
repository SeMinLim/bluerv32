import FIFO::*;
import BRAM::*;

import Defines::*;

interface BRAMSubWordIfc#(numeric type addrSize);
	method Action req(Bit#(addrSize) addr, Word data, AccessSize size, Bool write);
	method Action loadByte(Bit#(addrSize) addr, Bit#(8) data);
	method ActionValue#(Word) resp;
endinterface

function Word writeMask(Bit#(2) offset, AccessSize size);
	Word baseMask = case ( size )
		ByteAccess: 32'h000000ff;
		HalfAccess: 32'h0000ffff;
		WordAccess: 32'hffffffff;
	endcase;
	Bit#(5) shift = {offset, 3'b000};
	return baseMask << shift;
endfunction

module mkBRAMSubWord(BRAMSubWordIfc#(addrSize))
	provisos(Add#(subAddrSize, 2, addrSize));

	BRAM2Port#(Bit#(subAddrSize), Word) memory <- mkBRAM2Server(defaultValue);
	FIFO#(Tuple5#(Bit#(addrSize), Word, AccessSize, Bool, Bool)) requestQ <- mkFIFO;
	FIFO#(Word) responseQ <- mkFIFO;

	rule processRequest;
		let request = requestQ.first;
		requestQ.deq;
		let oldData <- memory.portA.response.get;

		Bit#(addrSize) addr = tpl_1(request);
		Word data = tpl_2(request);
		AccessSize size = tpl_3(request);
		Bool write = tpl_4(request);
		Bool respond = tpl_5(request);
		Bit#(subAddrSize) wordAddr = truncate(addr >> 2);

		if ( write ) begin
			Bit#(2) offset = truncate(addr);
			Bit#(5) shift = {offset, 3'b000};
			Word mask = writeMask(offset, size);
			Word shiftedData = data << shift;
			Word newData = (oldData & ~mask) | (shiftedData & mask);

			memory.portB.request.put(BRAMRequest {
				write: True,
				responseOnWrite: False,
				address: wordAddr,
				datain: newData
			});
			if ( respond ) begin
				responseQ.enq(0);
			end
		end else begin
			Bit#(2) offset = truncate(addr);
			Bit#(5) shift = {offset, 3'b000};
			responseQ.enq(oldData >> shift);
		end
	endrule

	method Action req(Bit#(addrSize) addr, Word data, AccessSize size, Bool write);
		requestQ.enq(tuple5(addr, data, size, write, True));
		memory.portA.request.put(BRAMRequest {
			write: False,
			responseOnWrite: False,
			address: truncate(addr >> 2),
			datain: 0
		});
	endmethod

	method Action loadByte(Bit#(addrSize) addr, Bit#(8) data);
		requestQ.enq(tuple5(addr, zeroExtend(data), ByteAccess, True, False));
		memory.portA.request.put(BRAMRequest {
			write: False,
			responseOnWrite: False,
			address: truncate(addr >> 2),
			datain: 0
		});
	endmethod

	method ActionValue#(Word) resp;
		let data = responseQ.first;
		responseQ.deq;
		return data;
	endmethod
endmodule
