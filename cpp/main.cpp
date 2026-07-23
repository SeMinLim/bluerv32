#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <vector>

using namespace std;


#define INSTRUCTION_MEMORY_SIZE 4096
#define DATA_MEMORY_SIZE 4096
#define BINARY_SIZE (INSTRUCTION_MEMORY_SIZE + DATA_MEMORY_SIZE)


vector<uint8_t> gInputStream;
bool gInitialized = false;
uint8_t gOutputIdx = 0xff;
uint8_t gInputIdx = 0xff;
size_t gInputOffset = 0;


void initialize() {
	if ( gInitialized ) return;

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
	if ( binarySize != BINARY_SIZE ) {
		printf( "Expected an %d-byte binary, received %ld bytes: %s\n",
			BINARY_SIZE, binarySize, binaryPath );
		fflush( stdout );
		exit(1);
	}
	rewind(binaryFile);

	printf( "---------------------------------------------------------------------\n" );
	printf( "[STEP 1] Loading RV32I bare-metal binary started.\n" );
	printf( "---------------------------------------------------------------------\n" );
	fflush( stdout );

	gInputStream.reserve(BINARY_SIZE * 2 + 2);
	for ( int byteIdx = 0; byteIdx < BINARY_SIZE; byteIdx ++ ) {
		uint8_t data = 0;
		if ( fread(&data, 1, 1, binaryFile) != 1 ) {
			printf( "Failed to read byte %d from %s\n", byteIdx, binaryPath );
			fflush( stdout );
			exit(1);
		}

		if ( byteIdx < INSTRUCTION_MEMORY_SIZE ) {
			gInputStream.push_back(0);
		} else {
			gInputStream.push_back(2);
		}
		gInputStream.push_back(data);
	}
	fclose(binaryFile);

	gInputStream.push_back(1);
	gInputStream.push_back(1);
	gInitialized = true;

	printf( "[STEP 1] Loading RV32I bare-metal binary finished.\n" );
	printf( "---------------------------------------------------------------------\n" );
	printf( "[STEP 2] Starting the processor.\n" );
	printf( "---------------------------------------------------------------------\n" );
	fflush( stdout );
}


extern "C" uint32_t bdpiUartGet(uint8_t idx) {
	initialize();

	uint32_t result = 0xffffffff;
	if ( idx != gOutputIdx && gInputOffset < gInputStream.size() ) {
		result = gInputStream[gInputOffset];
		gInputOffset ++;
		gOutputIdx = idx;
	}
	return result;
}


extern "C" void bdpiUartPut(uint32_t value) {
	uint8_t idx = (value >> 8) & 0xff;
	uint8_t data = value & 0xff;
	if ( idx != gInputIdx ) {
		gInputIdx = idx;
		fprintf(stderr, "%c", data);
		fflush(stderr);
	}
}
