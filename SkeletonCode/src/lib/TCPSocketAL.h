/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   October 1 2012
 * 
 */ 

#ifndef TCP_SOCKET_AL_H
#define TCP_SOCKET_AL_H
#include "socketBuffer.h"

enum TCPSOCKET_STATE{
	CLOSED=0,
	LISTEN=1,
	SYN_SENT=2,
	SYN_RECEIVED=3,
	ESTABLISHED=4,
	SHUTDOWN=5,
	CLOSING=6
};

typedef struct TCPSocketAL{
	/*Insert Variables Here */
	int index;
	bool isAvailable;
	int socketState;
	int srcPort, srcAddr;
	int destPort, destAddr;
	socketArr sendBuffer;
	socketArr recvBuffer;
	
}TCPSocketAL;

#endif /* TCP_SOCKET_AL_H */
