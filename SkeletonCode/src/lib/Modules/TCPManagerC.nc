#include "TCPSocketAL.h"
#include "../packet.h"
#include "transport.h"

#ifndef MAX_SOCKET
#define MAX_SOCKET 20
#endif
module TCPManagerC{
	provides interface TCPManager<TCPSocketAL, pack>;
	uses interface TCPSocket<TCPSocketAL>;	
	uses interface NodeA as node;
	
	uses interface Timer<TMilli> as sendTimer;
	uses interface Timer<TMilli> as waitCloseTimer;
}
implementation{
	int tracker = 0; int socketTrack = 0;
	int RECV_BUFFER_LIMITER = 50;
	uint8_t writeBufferSize = 80, readBufferSize = 60;
	TCPSocketAL socketTracker[MAX_SOCKET];
	bool ConnectionCheck(pack* myMsg, transport* tHeader);
	
	command void TCPManager.init(){
		call TCPManager.socketInit();
		dbg("Project3Manager", "TCPManager initializing \n");
		call sendTimer.startPeriodic(1000);
	}
	
	command void TCPManager.socketInit(){
		int i;
		for(i = 1; i < MAX_SOCKET; i++){
			socketTracker[i].index = i;
			socketTracker[i].isAvailable = TRUE;
			socketTracker[i].lastByteAcked = 0; 
			socketTracker[i].lastByteSent = 0;
			socketTracker[i].lastByteWritten = 0;
			socketTracker[i].lastByteRead = 0;
			socketTracker[i].lastByteReceived = 0;
			socketTracker[i].nextByteExpected = 0;
			socketArrInit(&socketTracker[i].sendBuffer);
			socketArrInit(&socketTracker[i].recvBuffer);
			retransBufferInit(&socketTracker[i].frames);
			retransBufferInit(&socketTracker[i].recvFrames);
			socketArrSetLimit(&socketTracker[i].recvBuffer, RECV_BUFFER_LIMITER);
			bufferInit(&socketTracker[i].writeBuffer, writeBufferSize);
			bufferInit(&socketTracker[i].readBuffer, readBufferSize);
		}
	}
	
	command TCPSocketAL * TCPManager.socket(){
		//dbg("Project3Manager", "Giving a socket \n");
//		if(socketTrack == 0){
//			socketTrack++;
//			return &socketTracker[1];
//		}
//		return &socketTracker[2];	
		return (call TCPManager.findFreeSocket());
	}
	
	command TCPSocketAL * TCPManager.findFreeSocket(){
		int i;
		for(i = 1; i < 20; i++)
			if(socketTracker[i].isAvailable){
					socketTracker[i].isAvailable = FALSE;
				return &socketTracker[i];
			}
		return NULL; //this is equivalent to an error, cannot find a socket;
	}
	
	command TCPSocketAL * TCPManager.getSocketfd(uint8_t portdest){
		int i;
		for(i = 1; i < MAX_SOCKET; i++){
		//	dbg("Project3Manager","Checking ports index:%d destport:%d srcPort:%d destAddr:%d \n", i, socketTracker[i].destPort, socketTracker[i].srcPort, socketTracker[i].destAddr);
			if(socketTracker[i].destPort == portdest)
				return &socketTracker[i];
		}
		return NULL;
	}
	
	command TCPSocketAL * TCPManager.getSocket(uint8_t portNum, uint8_t dest){
		int i;
		for(i = 1; i < MAX_SOCKET; i++){
		//	dbg("Project3Manager","Checking ports index:%d destport:%d srcPort:%d destAddr:%d \n", i, socketTracker[i].destPort, socketTracker[i].srcPort, socketTracker[i].destAddr);
			if((socketTracker[i].destPort == portNum) && (socketTracker[i].srcAddr == dest))
				return &socketTracker[i];
		}
		return NULL;	
	}
	
	command void TCPManager.handlePacket(void *payload){
		pack myMsg;
		uint8_t payload2[TRANSPORT_MAX_PAYLOAD_SIZE];
		uint8_t bytesToWrite = 0, sizeOfBuffer = 0;
		TCPSocketAL *temp = call node.getSocket();
		transport tHeader,tHeader2, framedtcpHeader;
		TCPSocketAL *temp2, *temp3;socketData temporary;
		uint16_t windowCheck = 0;
		uint8_t i;
		memcpy(&myMsg,(pack*)payload,sizeof(pack));
		memcpy(&tHeader,(transport *)myMsg.payload, sizeof(transport));
		dbg("Project3Manager", "------HANDLE PACKET BEGIN------ \n");
		printTransport(&tHeader);
		//dbg("Project3Node", "destPort:%d  derp derp\n",tHeader.destPort);
		switch(tHeader.type){
			case TRANSPORT_SYN:
				dbg("Project3Manager", "Received a SYN packet \n");
				if(call TCPSocket.isListening(temp)){
				//check if it's already party of the pendingConnections
					if(!pendingConnectionCheck(&temp->pendingConnections,myMsg)){
						//check if it's already connected, if already connected, don't add into the pendingConnectionsl
						if(ConnectionCheck(&myMsg,&tHeader)){
							dbg("Project3Manager","SENT ANOTHER SYNACK PACKET!!! \n");
						}
						else
							if(connectionBufferPushBack(&temp->pendingConnections, myMsg))
								dbg("Project3Manager","Put into the pending connections\n");
					}
					else
						dbg("Project3Manager","already in the pendingConnections. \n");
	
				dbg("Project3Node", "I am listening \n");
				}
			break;
			case TRANSPORT_SYNACK:
				temp->destPort = tHeader.srcPort;
				temp = call TCPManager.getSocketfd(tHeader.srcPort);
				if(temp->socketState == SYN_SENT){
					dbg("Project3Node", "I got the SYNACK seq:%d index:%d \n", tHeader.seq, temp->index);
					if(retransBufferContains(&temp->frames,tHeader.seq-1, TRANSPORT_SYN)){
						tHeader2 = retransBufferRemove(&temp->frames,tHeader.seq-1, TRANSPORT_SYN);
						dbg("Project3Manager","Removing something with type:%d and seq:%d \n", tHeader2.type, tHeader2.seq);
					}
					tHeader2.destPort = temp->destPort; tHeader2.len = 0; tHeader2.seq = tHeader.seq; tHeader2.srcPort = temp->srcPort; tHeader2.type = TRANSPORT_ACK;
					tHeader2.window = RECV_BUFFER_LIMITER-socketArrSize(&temp->recvBuffer);
					temp->windowCheck = tHeader.window;
					call node.sendTransport(&tHeader2,myMsg.src);
					dbg("Project3Manager","Sending ACK \n");
					temp->socketState = ESTABLISHED;
				}
			break;
			case TRANSPORT_ACK:
			temp3 = call TCPManager.getSocketfd(tHeader.srcPort);
				if(temp->socketState == ESTABLISHED || temp->socketState == FIN_SENT){
					//now I can remove it from the buffer
					//gotta do some buffer checks to remove properly the right datas
					dbg("Project3Manager", "Got the ACK for the sent packet \n");
					
					temporary = getSockData(&temp->sendBuffer, 0);
					dbg("Project3Manager","byte:%d seq:%d type:%d len:%d \n",temporary.byte, temporary.seq,temporary.type,temporary.len);
					dbg("genDebug", "%d %d\n", tHeader.seq, temp->lastByteAcked);
				
					retransBufferLBA(&temp->frames, tHeader.seq, &temp->lastByteAcked);
					
					//----sending portion
					sizeOfBuffer = bufferSize(&temp->writeBuffer);
					if(sizeOfBuffer > 0){
						windowCheck = 0;
						windowCheck = tHeader.window;
						dbg("Project3Manager","SIZE OF WINDOW IS: %d sizeofBuffer is: %d \n", windowCheck,sizeOfBuffer);
						while(windowCheck != 0 && sizeOfBuffer > 0 ){
							if(sizeOfBuffer < windowCheck)
									windowCheck = sizeOfBuffer;
									
							if(windowCheck < TRANSPORT_MAX_PAYLOAD_SIZE){
								if(sizeOfBuffer < windowCheck)
									windowCheck = sizeOfBuffer;
								bufferCopy(&temp->writeBuffer,&payload2, bytesToWrite, windowCheck);
								createTransport(&framedtcpHeader, temp->srcPort, temp->destPort, TRANSPORT_DATA, 0, temp->lastByteSent+windowCheck, &payload2, windowCheck);
								printTransport(&framedtcpHeader);
								retransBufferPushBack(&temp->frames,framedtcpHeader);
								temp->lastByteSent+= windowCheck;
								bytesToWrite += windowCheck;
								sizeOfBuffer = 0;
								windowCheck = 0;
							}
							else{								
								bufferCopy(&temp->writeBuffer,&payload2,bytesToWrite, TRANSPORT_MAX_PAYLOAD_SIZE);
								createTransport(&framedtcpHeader, temp->srcPort, temp->destPort, TRANSPORT_DATA, 0, temp->lastByteSent+TRANSPORT_MAX_PAYLOAD_SIZE ,&payload2, TRANSPORT_MAX_PAYLOAD_SIZE);
								printTransport(&framedtcpHeader);
								retransBufferPushBack(&temp->frames,framedtcpHeader);
								temp->lastByteSent+= TRANSPORT_MAX_PAYLOAD_SIZE;
								windowCheck -= TRANSPORT_MAX_PAYLOAD_SIZE;
								bytesToWrite += TRANSPORT_MAX_PAYLOAD_SIZE;
								sizeOfBuffer -= TRANSPORT_MAX_PAYLOAD_SIZE;
							}
						}
						while(bytesToWrite != 0){
							bufferPopFront(&temp->writeBuffer);
							bytesToWrite--;	
						}
					}
				}else{
					//find the right socket that will need to have connection established with the socket
					if(temp3 == NULL){
						dbg("Project3Manager", "Got the ACK, connection being established index:%d \n",temp->index);
						if(retransBufferContains(&temp->frames,tHeader.seq, TRANSPORT_SYNACK)){
							tHeader2 = retransBufferRemove(&temp->frames,tHeader.seq, TRANSPORT_SYNACK);
							dbg("Project3Manager","Removing something with type:%d and seq:%d \n", tHeader2.type, tHeader2.seq);
						}			
						temp->socketState = ESTABLISHED;
					}
					else{
						dbg("Project3Manager", "Got the ACK, connection being established index:%d \n",temp3->index);
						if(retransBufferContains(&temp3->frames,tHeader.seq, TRANSPORT_SYNACK)){
							tHeader2 = retransBufferRemove(&temp3->frames,tHeader.seq, TRANSPORT_SYNACK);
							dbg("Project3Manager","Removing something with type:%d and seq:%d \n", tHeader2.type, tHeader2.seq);
						}				
						 temp3->socketState = ESTABLISHED;
					}
				}
			break;
			case TRANSPORT_DATA:
				temp3 = call TCPManager.getSocketfd(tHeader.srcPort);
			if(temp3->socketState == SYN_RECEIVED || temp3->socketState == ESTABLISHED){
//					if(temp3->frames.numValues > 0)
//						retransBufferPopFront(&temp3->frames); 
//						temp3->socketState = ESTABLISHED;
//				}
				if((tHeader.seq-tHeader.len <= temp3->lastByteReceived) && (temp3->lastByteReceived <= tHeader.seq) && (temp3->lastByteRead != tHeader.seq)){
					if(temp3->lastByteReceived == tHeader.seq-tHeader.len){
						//dbg("Project3Manager","I GOT A DUPLICATE!! \n");
						retransBufferPushBack(&temp3->recvFrames,tHeader);
						temp3->lastByteReceived = tHeader.seq;
					}
					else{
						dbg("Project3Manager","Putting something into the recvr frame!! \n");
						retransBufferPushBack(&temp3->recvFrames,tHeader);
						temp3->lastByteReceived = tHeader.seq;
					}
				}
				dbg("Project3Manager", "Packet delivered successfully. index:%d seq:%d dest:%d src:%d packsrc:%d window:%d \n", temp3->index, tHeader.seq,temp3->destAddr, temp3->srcAddr, myMsg.src, (socketArrSize(&temp3->recvBuffer)));
				// uint8_t srcPort, uint8_t destPort, uint8_t type, uint16_t window, int16_t seq, uint8_t *payload, uint8_t packetLength
				createTransport(&tHeader2, temp3->srcPort,temp3->destPort,TRANSPORT_ACK,RECV_BUFFER_LIMITER-retransBufferSize(&temp3->recvFrames),temp3->lastByteReceived+1, tHeader.payload,tHeader.len);
				printTransport(&tHeader2);
				call node.sendTransport(&tHeader2, temp3->destAddr);
				}
			break;
			case TRANSPORT_FIN:
				temp3 = call TCPManager.getSocketfd(tHeader.srcPort);
				dbg("Project3Manager","Getting FINS! lastByteReceived:%d \n", temp3->lastByteReceived);
				if(tHeader.seq == temp3->lastByteReceived+1){
					temp3->socketState = TIME_WAIT;
					//FIRE A TIMER FOR TIME WAIT...
					call waitCloseTimer.startOneShot(1200);
					//call waitCloseTimer.startPeriodic(12000);
					
					createTransport(&tHeader2, temp3->srcPort,temp3->destPort,TRANSPORT_FINACK,RECV_BUFFER_LIMITER-retransBufferSize(&temp3->recvFrames),temp3->lastByteReceived+1, tHeader.payload,tHeader.len);
					printTransport(&tHeader2);
					call node.sendTransport(&tHeader2, temp3->destAddr);
				}
			break;
			case TRANSPORT_FINACK:
				temp3 = call TCPManager.getSocketfd(tHeader.srcPort);
				dbg("Project3Manager","SeqNum:%d lastByteAcked:%d state:%d \n",tHeader.seq,temp3->lastByteAcked, temp3->socketState);
				if(tHeader.seq-1 == temp3->lastByteAcked && temp3->socketState == FIN_SENT){
					retransBufferPopFront(&temp3->frames);
					dbg("Project3Manager","GOT THE FIN ACK \n");
					retransBufferInit(&temp3->frames);
					temp3->socketState = CLOSED; temp3->isAvailable = TRUE;
				}
				temp3->socketState = CLOSED; temp3->isAvailable = TRUE;
			break;
			default:
				dbg("Project3Manager", "I'm here \n");
			break;
		}
				dbg("Project3Manager", "------HANDLE PACKET END------ \n\n");
	}
	
	command void TCPManager.freeSocket(TCPSocketAL *input){
		//dbg("Project3Manager","DO I get CALLED?! \n");
	}

	event void sendTimer.fired(){
		// TODO Auto-generated method stub
		int i, numOfFrames = 0;
		transport tcpHeader; socketData temp;
		transport framedtcpHeader;
		uint8_t len = 0; uint8_t window = 1;
		//dbg_clear("Project3Manager","\n");
		//dbg("Project3Manager","----SENDING----\n");
		for(i = 1; i < MAX_SOCKET; i++){
			if(retransBufferSize(&socketTracker[i].frames) >= 1 && (&socketTracker[i].socketState != CLOSED ) && retransBufferSize(&socketTracker[i].frames) < 31 && socketTracker[i].socketState != CLOSED){
				numOfFrames = 0;
				dbg_clear("Project3Manager","\n");
				dbg("Project3Manager","----SENDING----\n");
				dbg("genDebug", "%d\n", socketTracker[i].frames.numValues);
				dbg("Project3Manager","Checking the ports srcPort:%d srcAddr:%d destPort:%d destAddr:%d size:%d index:%d \n",socketTracker[i].srcPort,socketTracker[i].srcAddr,socketTracker[i].destPort,socketTracker[i].destAddr, socketArrSize(&socketTracker[i].sendBuffer), i);
				while(numOfFrames < retransBufferSize(&socketTracker[i].frames)){
					framedtcpHeader = getTransport(&socketTracker[i].frames, numOfFrames);
					printTransport(&framedtcpHeader);
					call node.sendTransport(&framedtcpHeader,socketTracker[i].destAddr);
					numOfFrames++;
				}
				dbg("Project3Manager", "----END---- \n\n");
			}
			if(retransBufferSize(&socketTracker[i].frames) > 31)
				dbg("Project3Manager","------------sSOMETHING WENT WRONG!!--------\n\n");
	  	}
	 	 //bg("Project3Manager", "----END---- \n\n");
	 }
	 
	 event void waitCloseTimer.fired(){
	 	int i;
	 		for(i = 1; i < MAX_SOCKET; i++){
	 			if((&socketTracker[i].socketState == TIME_WAIT)){
	 				dbg("Project3Manager","TERMINATING!!!! ");
	 				socketTracker[i].socketState = CLOSED;
	 				socketTracker[i].isAvailable = TRUE; 
	 			}
	 		}
	 	call waitCloseTimer.stop();
	 }
	 
	 bool ConnectionCheck(pack* myMsg, transport* tHeader){
//	 	createTransport(&framedtcpHeader, output->srcPort, output->destPort,TRANSPORT_SYNACK, 5, tcpHeader.seq+1,(uint8_t*)"",0);
//			printTransport(&framedtcpHeader);
//			call node.sendTransport(&framedtcpHeader,output->destAddr);
		uint8_t i; transport framedtcpHeader;
		for(i = 1; i < MAX_SOCKET; i++){
			if(tHeader->srcPort != 0 )
				if(socketTracker[i].destAddr == myMsg->src && socketTracker[i].destPort == tHeader->srcPort){
					createTransport(&framedtcpHeader, socketTracker[i].srcPort, socketTracker[i].destPort,TRANSPORT_SYNACK, 5, tHeader->seq+1,(uint8_t*)"",0);
					dbg("Project3Manager","Print check src:%d dest:%d", socketTracker[i].srcPort, socketTracker[i].destPort);
					printTransport(&framedtcpHeader);
					call node.sendTransport(&framedtcpHeader,socketTracker[i].destAddr);
					dbg("Project3Manager","I am already connected!!!!!!!!!! index:%d \n\n", i);
					return TRUE;
				}
		}
	 	return FALSE;	
	 }
}
