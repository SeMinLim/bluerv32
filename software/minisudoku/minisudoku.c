#include <stdbool.h>
#include <stdint.h>


volatile char * const printChar = (volatile char *)0x10000000;
char setIn[16] = {0, 3, 0, 4, 0, 0, 2, 0, 4, 0, 3, 0, 0, 0, 0, 2};


bool check(char *set, int idx) {
	int row = idx / 4;
	int col = idx % 4;
	int block = ((idx / 8) * 8) + (col / 2) * 2;
	bool unique[12];

	for ( int i = 0; i < 12; i ++ ) {
		unique[i] = false;
	}

	bool valid = true;
	for ( int i = 0; i < 4; i ++ ) {
		char rowValue = set[row * 4 + i];
		char colValue = set[i * 4 + col];
		char blockValue = set[block + (i / 2) * 4 + (i % 2)];

		if ( rowValue > 0 ) {
			if ( unique[rowValue - 1] ) valid = false;
			unique[rowValue - 1] = true;
		}
		if ( colValue > 0 ) {
			if ( unique[colValue + 4 - 1] ) valid = false;
			unique[colValue + 4 - 1] = true;
		}
		if ( blockValue > 0 ) {
			if ( unique[blockValue + 8 - 1] ) valid = false;
			unique[blockValue + 8 - 1] = true;
		}
	}

	return valid;
}

bool solve(char *set, int idx) {
	if ( idx >= 16 ) return true;

	if ( set[idx] > 0 ) {
		return solve(set, idx + 1);
	}

	for ( int i = 0; i < 4; i ++ ) {
		set[idx] = i + 1;
		if ( check(set, idx) && solve(set, idx + 1) ) return true;
	}

	set[idx] = 0;
	return false;
}

void printSet(char *set) {
	for ( int i = 0; i < 16; i ++ ) {
		(*printChar) = set[i] + 0x30;
		if ( i % 4 == 3 ) (*printChar) = 0x0a;
	}
	(*printChar) = 0x0a;
}

int main() {
	printSet(setIn);

	if ( solve(setIn, 0) ) {
		printSet(setIn);
	} else {
		(*printChar) = 'x';
		(*printChar) = 0x0a;
	}

	return 0;
}
