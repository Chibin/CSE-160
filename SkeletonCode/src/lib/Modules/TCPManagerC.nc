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
}
implementation{
	int tracker = 0; int socketTrack = 0;
	int RECV_BUFFER_LIMITER = 5;
	TCPSocketAL socketTracker[MAX_SOCKET];
	
	command void TCPManager.init(){
		call TCPManager.socketInit();
		dbg("Project3Manager", "TCPManager initializing \n");
		call sendTimer.startPeriodic(10000);
	}
	
	command void TCPManager.socketInit(){
		int i;
		for(i = 1; i < MAX_SOCKET; i++){
			socketTracker[i].index = i;
			socketTracker[i].isAvailable = TRUE;
			socketArrInit(&socketTracker[i].sendBuffer);
			socketArrInit(&socketTracker[i].recvBuffer);
			socketArrSetLimit(&socketTracker[i].recvBuffer, RECV_BUFFER_LIMITER);
		}
	}
	
	command TCPSocketAL * TCPManager.socket(){
		//dbg("Project3Manager", "Giving a socket \n");
		if(socketTrack == 0){
			socketTrack++;
			return &socketTracker[1];
		}
		return &socketTracker[2];
		
		//return (call TCPManager.findFreeSocket());
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
		pack *myMsg = (pack*)payload;
		TCPSocketAL *temp = call node.getSocket();
		transport tHeader,tHeader2;
		TCPSocketAL *temp2, *temp3;socketData temporary;
		memcpy(&tHeader,(transport *)myMsg->payload, sizeof(transport));
		//dbg("Project3Node", "destPort:%d  derp derp\n",tHeader.destPort);
		switch(tHeader.type){
			case TRANSPORT_SYN:
				dbg("Project3Manager", "Received a SYN packet \n");
				if(call TCPSocket.isListening(temp)){
					socketTracker[1].destPort = tHeader.srcPort; socketTracker[1].destAddr = myMsg->src;
					//temp->destPort = tHeader.srcPort; temp->destAddr = myMsg->dest;
					temp2 = call TCPManager.socket();
					dbg("Project3Manager", "This is index:%d \n", temp2->index);
					call TCPSocket.accept(temp, &socketTracker[temp2->index]);
					tHeader2.destPort = temp2->destPort; tHeader2.len = 0; tHeader2.seq = tHeader.seq+1; tHeader2.srcPort = temp2->srcPort; 
					memcpy(&tHeader2.payload,"",0);
					tHeader2.type = TRANSPORT_SYNACK; tHeader2.window = RECV_BUFFER_LIMITER-socketArrSize(&socketTracker[temp2->index].recvBuffer);
					dbg("Project3Manager","Sending SYNACK! \n");
					call node.sendTransport(&tHeader2, myMsg->src);
					printTransport(&tHeader2);
					//call node.sendPacket(temp2->srcPort, myMsg->src, tHeader.srcPort, TRANSPORT_SYNACK);
					temporary.byte = 0; temporary.len = 0; temporary.seq = tHeader.seq+1; temporary.type = TRANSPORT_SYNACK;
					if(sockPushBack(&socketTracker[temp2->index].sendBuffer, temporary)){
						//dbg("Project3Node", "put synack to the send buffer \n srcPort:%d destPort%d \n destAddr:%d \n", temp->srcPort, temp->destPort, temp->destAddr);
					}
					dbg("Project3Node", "I am listening \n");
				}
			break;
			case TRANSPORT_SYNACK:
				temp = call TCPManager.getSocketfd(tHeader.srcPort);
				dbg("Project3Node", "I got the SYNACK seq:%d index:%d \n", tHeader.seq, temp->index);
				if(socketArrContains(&temp->sendBuffer,tHeader.seq-1, TRANSPORT_SYN)){
					temporary = socketArrRemove(&temp->sendBuffer,tHeader.seq-1, TRANSPORT_SYN);
					dbg("Project3Manager","Removing something with type:%d and seq:%d", temporary.type, temporary.seq);
				}
				//find the right socket that is going to be in an established state
				call node.sendPacket(temp->srcPort, myMsg->src, tHeader.srcPort, TRANSPORT_ACK);
				dbg("Project3Manager","Sending ACK \n");
				temp->socketState = ESTABLISHED;
			break;
			case TRANSPORT_ACK:
			temp3 = call TCPManager.getSocketfd(tHeader.srcPort);
				if(temp->socketState == ESTABLISHED){
					//now I can remove it from the buffer
					dbg("Project3Manager", "Got the ACK for the sent packet \n");
					// check the sendBuffer and remove the ACK'ed data
					
				}else{
					//find the right socket that will need to have connection established with the socket
					dbg("Project3Manager", "Got the ACK, connection being established \n");
					if(temp3 == NULL)
						temp->socketState = ESTABLISHED;
					else temp3->socketState = ESTABLISHED;
				}
			break;
			case TRANSPORT_DATA:
				//should go here when receiving data
				//should put it into the recvBuffer..
				temp3 = call TCPManager.getSocketfd(tHeader.srcPort);
				sockPushBack(&temp3->recvBuffer,(socketData){tHeader.payload,tHeader.seq,TRANSPORT_DATA,tHeader.len});
				dbg("Project3Manager", "Packet delivered successfully. \n");
				createTransport(&tHeader2, tHeader.destPort, tHeader.srcPort,TRANSPORT_ACK, tHeader.window,tHeader.seq, tHeader.payload,TRANSPORT_MAX_PAYLOAD_SIZE);
				printTransport(&tHeader2);
				call node.sendTransport(&tHeader2, myMsg->src);
			break;
			default:
				dbg("Project3Manager", "I'm here \n");
			break;
		}
	
	}
	
	command void TCPManager.freeSocket(TCPSocketAL *input){
		//dbg("Project3Manager","DO I get CALLED?! \n");
	}

	event void sendTimer.fired(){
		// TODO Auto-generated method stub
		int i;
		transport tcpHeader; socketData temp;
		uint8_t len = 0; uint8_t window = 1;
		dbg("Project3Manager","SENDING PERIOD TIMERS that's suppose to send STUFF \n");
		for(i = 1; i < MAX_SOCKET; i++){
			if(socketArrSize(&socketTracker[i].sendBuffer) >= 1){
				dbg("Project3Manager","Checking the ports srcPort:%d srcAddr:%d destPort:%d destAddr:%d size:%d index:%d \n",socketTracker[i].srcPort,socketTracker[i].srcAddr,socketTracker[i].destPort,socketTracker[i].destAddr, socketArrSize(&socketTracker[i].sendBuffer), socketTracker[i].index);
				temp = getSockData(&socketTracker[i].sendBuffer, 0);
				switch(temp.type){
					case TRANSPORT_SYN:	
					//createTransport(transport *output, uint8_t srcPort, uint8_t destPort, uint8_t type, uint16_t window, int16_t seq, uint8_t *payload, uint8_t packetLength);
						createTransport(&tcpHeader, socketTracker[i].srcPort, socketTracker[i].destPort, temp.type, 1, temp.seq ,(uint8_t*)"",len);
						dbg("Project3Manager", "Index: %d \n", i);
					break;
					case TRANSPORT_SYNACK:
						window = RECV_BUFFER_LIMITER-socketArrSize(&socketTracker[i].recvBuffer);
						createTransport(&tcpHeader, socketTracker[i].srcPort, socketTracker[i].destPort, temp.type, window, temp.seq ,(uint8_t*)"",len);
					break;
					case TRANSPORT_ACK:
					break;
					default:
					break;
				}
				//createTransport(&tcpHeader, socketTracker[i].srcPort, socketTracker[i].destPort, temp.type, 1, temp.seq ,(uint8_t*)"",len);
					printTransport(&tcpHeader);
					call node.sendTransport(&tcpHeader, socketTracker[i].destAddr);
			}
		}
		dbg("Project3Manager", "I CRASH HERE?! \n");
	
	 
	  }
	
}
