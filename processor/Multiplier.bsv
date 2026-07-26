import FIFO::*;

import Defines::*;
import Decode::*;

typedef struct {
	MultiplyFunc multiplyFunc;
	Word src1;
	Word src2;
} MultiplyRequest deriving (Bits, Eq, FShow);

interface MultiplierIfc;
	method Action request(MultiplyRequest value);
	method ActionValue#(Word) response;
endinterface

function Word multiplyResult(MultiplyRequest request);
	Bit#(64) product = primMul(request.src1, request.src2);
	Word productHigh = product[63:32];
	Word result = product[31:0];

	case ( request.multiplyFunc )
		MultiplyLow: begin
			result = product[31:0];
		end
		MultiplyHighSigned: begin
			if ( request.src1[31] == 1 ) begin
				productHigh = productHigh - request.src2;
			end
			if ( request.src2[31] == 1 ) begin
				productHigh = productHigh - request.src1;
			end
			result = productHigh;
		end
		MultiplyHighSignedUnsigned: begin
			if ( request.src1[31] == 1 ) begin
				productHigh = productHigh - request.src2;
			end
			result = productHigh;
		end
		MultiplyHighUnsigned: begin
			result = productHigh;
		end
	endcase

	return result;
endfunction

module mkMultiplier(MultiplierIfc);
	FIFO#(MultiplyRequest) requestQ <- mkFIFO;
	FIFO#(Word) responseQ <- mkFIFO;

	rule process1;
		MultiplyRequest request = requestQ.first;
		requestQ.deq;
		responseQ.enq(multiplyResult(request));
	endrule

	method Action request(MultiplyRequest value);
		requestQ.enq(value);
	endmethod

	method ActionValue#(Word) response;
		Word data = responseQ.first;
		responseQ.deq;
		return data;
	endmethod
endmodule
