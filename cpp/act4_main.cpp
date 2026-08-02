#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <vector>

using namespace std;


#define ACT4_MEMORY_SIZE 1048576


vector<uint8_t> gAct4Memory;
bool gAct4MemoryInitialized = false;


// ACT4 unified memory initialization
void initializeAct4Memory() {
	if ( gAct4MemoryInitialized ) return;

	const char *binaryPath = getenv("BLUERV32_BIN");
	if ( binaryPath == NULL ) {
		printf( "BLUERV32_BIN is not set.\n" );
		fflush( stdout );
		exit(1);
	}

	FILE *binaryFile = fopen(binaryPath, "rb");
	if ( binaryFile == NULL ) {
		printf( "Binary file not found: %s\n", binaryPath );
		fflush( stdout );
		exit(1);
	}

	if ( fseek(binaryFile, 0, SEEK_END) != 0 ) {
		printf( "Failed to seek binary file: %s\n", binaryPath );
		fflush( stdout );
		exit(1);
	}

	long binarySize = ftell(binaryFile);
	if ( binarySize != ACT4_MEMORY_SIZE ) {
		printf( "Expected a %d-byte ACT4 binary, received %ld bytes: %s\n",
			ACT4_MEMORY_SIZE, binarySize, binaryPath );
		fflush( stdout );
		exit(1);
	}
	rewind(binaryFile);

	gAct4Memory.resize(ACT4_MEMORY_SIZE, 0);
	if ( fread(gAct4Memory.data(), 1, ACT4_MEMORY_SIZE, binaryFile) !=
			ACT4_MEMORY_SIZE ) {
		printf( "Failed to read ACT4 binary: %s\n", binaryPath );
		fflush( stdout );
		exit(1);
	}
	fclose(binaryFile);
	gAct4MemoryInitialized = true;
}


// ACT4 unified memory word read
extern "C" uint32_t bdpiAct4Read(uint32_t addr) {
	initializeAct4Memory();

	uint32_t wordAddr = addr & 0xfffffffc;
	if ( wordAddr > ACT4_MEMORY_SIZE - sizeof(uint32_t) ) {
		printf( "ACT4 memory read is out of range: 0x%08x\n", addr );
		fflush( stdout );
		exit(1);
	}

	uint32_t data = 0;
	for ( uint32_t byteIdx = 0; byteIdx < sizeof(uint32_t); byteIdx ++ ) {
		data |= ((uint32_t)gAct4Memory[wordAddr + byteIdx]) << (byteIdx * 8);
	}
	return data >> ((addr & 0x3) * 8);
}


// ACT4 unified memory subword write
extern "C" void bdpiAct4Write(uint32_t addr, uint32_t data, uint8_t size) {
	initializeAct4Memory();

	uint32_t numBytes = 0;
	if ( size == 0 ) numBytes = 1;
	else if ( size == 1 ) numBytes = 2;
	else if ( size == 2 ) numBytes = 4;
	else {
		printf( "Unsupported ACT4 memory access size: %u\n", size );
		fflush( stdout );
		exit(1);
	}

	if ( addr > ACT4_MEMORY_SIZE - numBytes ) {
		printf( "ACT4 memory write is out of range: 0x%08x\n", addr );
		fflush( stdout );
		exit(1);
	}

	for ( uint32_t byteIdx = 0; byteIdx < numBytes; byteIdx ++ ) {
		gAct4Memory[addr + byteIdx] = (data >> (byteIdx * 8)) & 0xff;
	}
}


// ACT4 UART output
extern "C" void bdpiAct4PutChar(uint8_t data) {
	fputc(data, stderr);
	fflush(stderr);
}
