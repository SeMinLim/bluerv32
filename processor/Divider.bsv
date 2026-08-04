import FIFO::*;

import Defines::*;
import Decode::*;

typedef struct {
	DivideFunc divideFunc;
	Word dividend;
	Word divisor;
} DivideRequest deriving (Bits, Eq, FShow);

interface DividerIfc;
	method Action request(DivideRequest value);
	method ActionValue#(Word) response;
endinterface

function Word twosComplement(Word value);
	return (~value) + 32'h00000001;
endfunction

function Bool isSignedDivide(DivideFunc divideFunc);
	return divideFunc == DivideSigned ||
		divideFunc == RemainderSigned;
endfunction

function Bool isRemainder(DivideFunc divideFunc);
	return divideFunc == RemainderSigned ||
		divideFunc == RemainderUnsigned;
endfunction

module mkDivider(DividerIfc);
	FIFO#(DivideRequest) requestQ <- mkFIFO;
	FIFO#(Word) responseQ <- mkFIFO;

	Reg#(Bool) divideOn <- mkReg(False);
	Reg#(Bit#(6)) divideCnt <- mkReg(0);
	Reg#(Word) dividendR <- mkReg(0);
	Reg#(Word) divisorR <- mkReg(0);
	Reg#(Word) quotientR <- mkReg(0);
	Reg#(Bit#(33)) remainderR <- mkReg(0);
	Reg#(DivideFunc) divideFuncR <- mkReg(DivideSigned);
	Reg#(Bool) quotientNegativeR <- mkReg(False);
	Reg#(Bool) remainderNegativeR <- mkReg(False);

	//------------------------------------------------------------------------------------
	// [START]
	// Normalize signed operands or complete an architectural special case
	//------------------------------------------------------------------------------------
	rule startDivide ( !divideOn );
		DivideRequest request = requestQ.first;
		requestQ.deq;

		Bool signedOperation = isSignedDivide(request.divideFunc);
		Bool remainderOperation = isRemainder(request.divideFunc);
		Bool dividendNegative = signedOperation && (request.dividend[31] == 1);
		Bool divisorNegative = signedOperation && (request.divisor[31] == 1);
		Bool signedOverflow = signedOperation &&
			request.dividend == 32'h80000000 &&
			request.divisor == 32'hffffffff;
		Word dividendMagnitude = dividendNegative ?
			twosComplement(request.dividend) : request.dividend;
		Word divisorMagnitude = divisorNegative ?
			twosComplement(request.divisor) : request.divisor;

		if ( request.divisor == 0 ) begin
			Word result = remainderOperation ? request.dividend : 32'hffffffff;
			responseQ.enq(result);
		end else if ( signedOverflow ) begin
			Word result = remainderOperation ? 0 : 32'h80000000;
			responseQ.enq(result);
		end else begin
			divideFuncR <= request.divideFunc;
			dividendR <= dividendMagnitude;
			divisorR <= divisorMagnitude;
			quotientR <= 0;
			remainderR <= 0;
			quotientNegativeR <= dividendNegative != divisorNegative;
			remainderNegativeR <= dividendNegative;
			divideCnt <= 0;
			divideOn <= True;
		end
	endrule

	//------------------------------------------------------------------------------------
	// [DIVIDE]
	// Produce one quotient bit per cycle with restoring radix-2 division
	//------------------------------------------------------------------------------------
	rule process1 ( divideOn );
		Bit#(33) shiftedRemainder = {remainderR[31:0], dividendR[31]};
		Word shiftedDividend = {dividendR[30:0], 1'b0};
		Word nextQuotient = {quotientR[30:0], 1'b0};
		Bit#(33) divisorExtended = zeroExtend(divisorR);
		Bit#(33) nextRemainder = shiftedRemainder;

		if ( shiftedRemainder >= divisorExtended ) begin
			nextRemainder = shiftedRemainder - divisorExtended;
			nextQuotient = nextQuotient | 32'h00000001;
		end

		if ( divideCnt == 6'd31 ) begin
			Word quotient = quotientNegativeR ?
				twosComplement(nextQuotient) : nextQuotient;
			Word remainderMagnitude = truncate(nextRemainder);
			Word remainder = remainderNegativeR ?
				twosComplement(remainderMagnitude) : remainderMagnitude;
			Word result = isRemainder(divideFuncR) ? remainder : quotient;

			responseQ.enq(result);
			divideCnt <= 0;
			divideOn <= False;
		end else begin
			dividendR <= shiftedDividend;
			quotientR <= nextQuotient;
			remainderR <= nextRemainder;
			divideCnt <= divideCnt + 6'd1;
		end
	endrule

	method Action request(DivideRequest value);
		requestQ.enq(value);
	endmethod

	method ActionValue#(Word) response;
		Word data = responseQ.first;
		responseQ.deq;
		return data;
	endmethod
endmodule
