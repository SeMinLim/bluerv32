#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <queue>


pthread_mutex_t gMutex;
pthread_t gThread;
std::queue<uint8_t> sw2hwQ;
std::queue<uint8_t> hw2swQ;
bool gInitDone = false;
uint8_t gOutIdx = 0xff;
uint8_t gInIdx = 0xff;


void uartSend( uint8_t data );
uint32_t uartRecv( void );
void *softwareMain( void *arg );


void initialize( void ) {
	if ( gInitDone ) return;

	pthread_mutex_init(&gMutex, NULL);
	if ( pthread_create(&gThread, NULL, softwareMain, NULL) != 0 ) {
		printf( "Failed to start the software loader thread.\n" );
		fflush( stdout );
		exit(1);
	}

	gInitDone = true;
}


extern "C" uint32_t bdpiUartGet( uint8_t idx ) {
	initialize();

	uint32_t data = 0xffffffff;
	pthread_mutex_lock(&gMutex);
	if ( idx != gOutIdx && !sw2hwQ.empty() ) {
		data = sw2hwQ.front();
		sw2hwQ.pop();
		gOutIdx = (uint8_t)((gOutIdx + 1) & 0xff);
	}
	pthread_mutex_unlock(&gMutex);
	return data;
}


extern "C" void bdpiUartPut( uint32_t dataIn ) {
	initialize();

	uint8_t idx = (uint8_t)((dataIn >> 8) & 0xff);
	uint8_t data = (uint8_t)(dataIn & 0xff);
	if ( idx != gInIdx ) {
		gInIdx = idx;
		pthread_mutex_lock(&gMutex);
		hw2swQ.push(data);
		pthread_mutex_unlock(&gMutex);
	}
}


uint32_t uartRecv( void ) {
	initialize();

	uint32_t data = 0xffffffff;
	pthread_mutex_lock(&gMutex);
	if ( !hw2swQ.empty() ) {
		data = hw2swQ.front();
		hw2swQ.pop();
	}
	pthread_mutex_unlock(&gMutex);
	return data;
}


void uartSend( uint8_t data ) {
	initialize();

	pthread_mutex_lock(&gMutex);
	sw2hwQ.push(data);
	pthread_mutex_unlock(&gMutex);
}


void *softwareMain( void *arg ) {
	(void)arg;

	const char *binPath = getenv("BLUERV32_BIN");
	if ( binPath == NULL || binPath[0] == '\0' ) {
		binPath = "build/software/minisudoku/minisudoku.bin";
	}

	FILE *binFile = fopen(binPath, "rb");
	if ( binFile == NULL ) {
		printf( "Binary file not found: %s\n", binPath );
		fflush( stdout );
		exit(1);
	}

	uint32_t byteOffset = 0;
	uint8_t data = 0;
	while ( fread(&data, 1, 1, binFile) == 1 ) {
		if ( byteOffset < 4096 ) {
			uartSend(0);
		} else {
			uartSend(2);
		}
		uartSend(data);
		byteOffset ++;
	}
	fclose(binFile);

	printf( "Loaded binary: %s\n", binPath );
	printf( "Loaded bytes : %u\n", byteOffset );
	fflush( stdout );

	uartSend(1);
	uartSend(1);

	while ( true ) {
		uint32_t output = uartRecv();
		if ( output > 0xff ) continue;
		fprintf(stderr, "%c", (uint8_t)output);
		fflush(stderr);
	}

	return NULL;
}
