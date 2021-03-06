/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   October 1 2012
 * 
 */ 

#ifndef SERVER_AL_H
#define SERVER_AL_H
#include "TCPSocketAL.h"
#include "chatBuffer.h"

typedef struct serverAL{
	TCPSocketAL *socket;
	uint8_t numofWorkers;
}serverAL;

enum{
	SERVER_WORKER_BUFFER_SIZE = 128, // 128 bytes
	NEWSERVER_BUFFER_SIZE = 128
};

typedef struct serverWorkerAL{
	TCPSocketAL *socket;
	uint16_t position;
	uint8_t buffer[SERVER_WORKER_BUFFER_SIZE];
	uint8_t currentMsgBuffer[NEWSERVER_BUFFER_SIZE];
	uint8_t currentMsgBufferlen;
	chatBuffer storedMsgs;
	chatBuffer sendMsgs;
	uint8_t currentlySendingMsg[NEWSERVER_BUFFER_SIZE];
	uint8_t currentlySendinglen;
	uint8_t usernameConnected[20];
	uint8_t userportNum[20];
	uint8_t newMsglen;
	uint8_t id;
}serverWorkerAL;

enum{
	SERVER_TIMER_PERIOD=500, //500 ms
	WORKER_TIMER_PERIOD=533 //533 ms
};
#endif /* SERVER_AL_H */
