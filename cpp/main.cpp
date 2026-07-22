#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <queue>

using namespace std;


#define INSTRUCTION_MEMORY_SIZE 4096
#define DATA_MEMORY_SIZE 4096
#define BINARY_SIZE (INSTRUCTION_MEMORY_SIZE + DATA_MEMORY_SIZE)


pthread_mutex_t gMutex;
pthread_t gThread;
queue<uint8_t> swToHwQ;
queue<uint8_t> hwToSwQ;
bool gInitDone = false;
uint8_t gOutputIdx = 0xff;
uint8_t gInputIdx = 0xff;


int softwareMain();
void *softwareThread(void *arg);


void initialize() {
	if ( gInitDone ) return;

	if ( pthread_mutex_init(&gMutex, NULL) != 0 ) {
		printf( "Failed to initialize the UART mutex.\n" );
		fflush( stdout );
		exit(1);
	}

	gInitDone = true;
	if ( pthread_create(&gThread, NULL, softwareThread, NULL) != 0 ) {
		gInitDone = false;
		printf( "Failed to create the UART loader thread.\n" );
		fflush( stdout );
		exit(1);
	}
}

void *softwareThread(void *arg) {
	(void)arg;
	softwareMain();
	return NULL;
}

extern "C" uint32_t bdpiUartGet(uint8_t idx) {
	initialize();

	uint32_t result = 0xffffffff;
	pthread_mutex_lock(&gMutex);
	if ( idx != gOutputIdx && !swToHwQ.empty() ) {
		result = swToHwQ.front();
		swToHwQ.pop();
		gOutputIdx = (gOutputIdx + 1) & 0xff;
	}
	pthread_mutex_unlock(&gMutex);
	return result;
}

extern "C" void bdpiUartPut(uint32_t value) {
	initialize();

	uint8_t idx = (value >> 8) & 0xff;
	uint8_t data = value & 0xff;
	if ( idx != gInputIdx ) {
		gInputIdx = idx;
		pthread_mutex_lock(&gMutex);
		hwToSwQ.push(data);
		pthread_mutex_unlock(&gMutex);
	}
}

uint32_t uartReceive() {
	initialize();

	uint32_t result = 0xffffffff;
	pthread_mutex_lock(&gMutex);
	if ( !hwToSwQ.empty() ) {
		result = hwToSwQ.front();
		hwToSwQ.pop();
	}
	pthread_mutex_unlock(&gMutex);
	return result;
}

void uartSend(uint8_t data) {
	initialize();

	pthread_mutex_lock(&gMutex);
	swToHwQ.push(data);
	pthread_mutex_unlock(&gMutex);
}

int softwareMain() {
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

	for ( int byteIdx = 0; byteIdx < BINARY_SIZE; byteIdx ++ ) {
		uint8_t data = 0;
		if ( fread(&data, 1, 1, binaryFile) != 1 ) {
			printf( "Failed to read byte %d from %s\n", byteIdx, binaryPath );
			fflush( stdout );
			exit(1);
		}

		if ( byteIdx < INSTRUCTION_MEMORY_SIZE ) {
			uartSend(0);
		} else {
			uartSend(2);
		}
		uartSend(data);
	}
	fclose(binaryFile);

	printf( "[STEP 1] Loading RV32I bare-metal binary finished.\n" );
	printf( "---------------------------------------------------------------------\n" );
	printf( "[STEP 2] Starting the processor.\n" );
	printf( "---------------------------------------------------------------------\n" );
	fflush( stdout );

	uartSend(1);
	uartSend(1);

	while ( true ) {
		uint32_t data = uartReceive();
		if ( data <= 0xff ) {
			fprintf(stderr, "%c", static_cast<uint8_t>(data));
			fflush(stderr);
		}
	}

	return 0;
}
