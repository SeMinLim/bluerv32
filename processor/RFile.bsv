import Vector::*;

import Defines::*;

interface RFile2R1W;
	method Word rd1(RIndx index);
	method Word rd2(RIndx index);
	method Action wr(RIndx index, Word data);
endinterface

module mkRFile2R1W(RFile2R1W);
	Vector#(32, Reg#(Word)) registerFile <- replicateM(mkReg(0));

	method Word rd1(RIndx index);
		return registerFile[index];
	endmethod

	method Word rd2(RIndx index);
		return registerFile[index];
	endmethod

	method Action wr(RIndx index, Word data);
		if ( index != 0 ) begin
			registerFile[index] <= data;
		end
	endmethod
endmodule
