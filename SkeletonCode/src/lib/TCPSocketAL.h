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
#include "connectionBuffer.h"

enum TCPSOCKET_STATE{
	CLOSED=0,
	LISTEN=1,
	SYN_SENT=2,
	SYN_RECEIVED=3,
	ESTABLISHED=4,
	SHUTDOWN=5,
	CLOSING=6,
	FIN_SENT=7,
	TIME_WAIT=8
	
};

typedef struct TCPSocketAL{
	/*Insert Variables Here */
	uint8_t index;
	bool isAvailable;
	int socketState;
	uint8_t srcPort, destPort;
	uint16_t srcAddr, destAddr;
	retransBuffer frames;
	retransBuffer recvFrames;
	socketArr sendBuffer;
	socketArr recvBuffer;
	buffer writeBuffer;
	buffer readBuffer;
	connectionBuffer pendingConnections;
	uint8_t windowCheck; //in bytes
	//sender
	//lastByteAcked <= lastByteSent
	//lastByteSent <= lastByteWritten
	//lastByteWritten - lastByteAcked <= maximuReceiverWindowsize;
	//index of x = seqnum of x - (lastByteAcked+1)
	//LastSequenceNum of retransQueue = lastByteSent
	//sequenceNum of index zero of the byteBuffer is lastBytesent+1
	//LastByteWritten - lastbyteSent-1 is the index of the last number of the byteBuffer
	
	// LastByteSent - LastByteAcked <= AdvertisedWindow
	uint16_t lastByteAcked, lastByteSent, lastByteWritten;
	//receiver
	uint16_t lastByteRead, lastByteReceived, nextByteExpected;
	//lastByteRead <= lastByteReceived 
	//lastBytedReceived >= nextByteExpected-1
	//index of lastByte in-order buffer of the receiver, nextByteExpected-1-lastByteRead-1
	//First index  or sequenceNum of the queue is lastByteRead-1
	//receiver window = out of order queue 	
	//AdvertisedWindow = MaxRcvBuff - ( (NextByteExpected - 1) - LastByteRead )
}TCPSocketAL;

#endif /* TCP_SOCKET_AL_H */