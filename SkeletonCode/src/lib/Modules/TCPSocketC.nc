#include "TCPSocketAL.h"
#include "../packet.h"
#include "transport.h"
#include "socketBuffer.h"
#include "connectionBuffer.h"
module TCPSocketC{
	provides{
		interface TCPSocket<TCPSocketAL>;
	}
	uses interface NodeA as node;
	uses interface TCPManager<TCPSocketAL, pack> as TCPManager;
}
implementation{	

    /** 
	 * need to make a send and recv function.
	 * write only puts it in the writeBuffer
	 * recv should put it into the readBuffer, while read should transfer the data to the application
	 **/
	//make a list of ports being used
	int portTracker[20];
	//socketArr sendBuffer;
	//socketArr recvBuffer;
	int queueSize = 0, currentlyConnected = 0;
	int internalPort = 0;
	int firstTime = 0;
	
	async command void TCPSocket.init(TCPSocketAL *input){
		dbg("Project3Socket", "Initializing \n");
		input->socketState = CLOSED;
	}
	
	async command uint8_t TCPSocket.bind(TCPSocketAL *input, uint8_t localPort, uint16_t address){
		int i;
		dbg("Project3Socket", "Binding \n");
		//make a function that checks if that port is already being used
		for(i = 0; i < 20; i++)
			if(portTracker[i] == localPort){
				return -1;
			}
		portTracker[internalPort] = localPort;
		internalPort++;
		input->isAvailable = FALSE;
		input->socketState = CLOSED;
		input->srcPort = localPort;
		input->srcAddr = address;
		return 0;
	}
	
	async command uint8_t TCPSocket.listen(TCPSocketAL *input, uint8_t backlog){
		dbg("Project3Socket", "Listening...\n");
		queueSize = backlog;
		connectionBufferInit(&input->pendingConnections, backlog);
		input->socketState = LISTEN;
		//max of backlog for the queue
		return 0;
	}
	
	async command uint8_t TCPSocket.accept(TCPSocketAL *input, TCPSocketAL *output){
		//send SYNACK?
	//	output = call TCPManager.socket();
	//	call TCPSocket.bind(output, input->srcPort, input->srcAddr);
		pack msg; transport tcpHeader;
		transport framedtcpHeader;
		if( (connectionBufferSize(&input->pendingConnections) > 0) && currentlyConnected < 5){
			msg = connectionBufferPopFront(&input->pendingConnections);
			memcpy(&tcpHeader,(transport*)&msg.payload,sizeof(transport));
			output->srcPort = rand()%255; 
			output->srcAddr = input->srcAddr;
			output->destPort = tcpHeader.srcPort; 
			output->destAddr = msg.src;
			output->socketState = SYN_RECEIVED;
			retransBufferInit(&output->frames);
			retransBufferInit(&output->recvFrames);
			socketArrInit(&output->sendBuffer);
			socketArrInit(&output->recvBuffer);
			bufferInit(&output->writeBuffer,50);
			
			//transport *output, uint8_t srcPort, uint8_t destPort, uint8_t type, uint16_t window, int16_t seq, uint8_t *payload, uint8_t packetLength
			createTransport(&framedtcpHeader, output->srcPort, output->destPort,TRANSPORT_SYNACK, 5, tcpHeader.seq+1,(uint8_t*)"",0);
			printTransport(&framedtcpHeader);
			call node.sendTransport(&framedtcpHeader,output->destAddr);
		//	retransBufferPushBack(&output->frames,framedtcpHeader);
		//	sockPushBack(&output->sendBuffer, (socketData){0,tcpHeader.seq+1,TRANSPORT_SYNACK,0});
			currentlyConnected++;
			return 0;
		}
		return -1;
	}

	async command uint8_t TCPSocket.connect(TCPSocketAL *input, uint16_t destAddr, uint8_t destPort){
		transport framedtcpHeader;
		input->destAddr = destAddr;
		input->destPort = destPort;
		createTransport(&framedtcpHeader, input->srcPort, input->destPort, TRANSPORT_SYN,1,0,(uint8_t*)"",0);
		if(retransBufferPushBack(&input->frames,framedtcpHeader)){
			input->socketState = SYN_SENT;
			dbg("Project3Socket", "Connecting \n");
			return 0;
		}
		return -1;
	}

	async command uint8_t TCPSocket.close(TCPSocketAL *input){
		//make sure that all the packets are sent first and is received by the other side
		//which will then be in "is closing" state
		// should send a FIN packet
		// should be in closing state
		transport finPack;
		dbg("Project3Socket","-----------CALLED CLOSE----------------- \n");
		//transport *output, uint8_t srcPort, uint8_t destPort, uint8_t type, uint16_t window, int16_t seq, uint8_t *payload, uint8_t packetLength)
		if(input->lastByteSent == input->lastByteWritten){
			if(input->socketState != FIN_SENT && input->socketState != CLOSED){
				input->socketState = FIN_SENT;
				createTransport(&finPack,input->srcPort,input->destPort,TRANSPORT_FIN,0,input->lastByteWritten+1,(uint8_t*)"",0);
				retransBufferPushBack(&input->frames,finPack);
				dbg("Project3Socket","Pushing the FIN packet \n");
				return 0;
			}
			dbg("Project3Socket","Already, in FIN_SENT state \n");
			return -1;
		}else{
			dbg("Project3Socket","Something went wrong \n");
			return -1;
		}
	}

	async command uint8_t TCPSocket.release(TCPSocketAL *input){
		input->socketState = CLOSED;
		input->isAvailable = TRUE;
		return 0;
	}
	
	async command int16_t TCPSocket.receive(TCPSocketAL *input, uint8_t *readSocketBuffer){
		//RWS receive window size; upper bound on the number of out-of-order frames
		//LAF largest acceptable frame
		//LFR last frame received
		//LAF-LFR <= RWS
		
		//frames have seqNums
		//if SeqNum <= LFR or SeqNum > LAF; discard
		//if LFR < SeqNuM <= LAF, accept it
		//seqNumToAck, largest sequence number not yet acknowledged but anything smaller than seqNumToAck has already been received
		// LFR = seqNumToAck and LAF = LFR+RWS
		return 0;
	}
	
	//readBuffer = outputReader, current pos, len
	async command int16_t TCPSocket.read(TCPSocketAL *input, uint8_t *readBuffer, uint16_t pos, uint16_t len){
		uint8_t lengthCheck = 0; transport framedtcpHeader; transport newframedtcpHeader; uint8_t length = 0; uint8_t poppedValue;
		socketData temp; bool splitCheck = FALSE;

		if(retransBufferSize(&input->recvFrames) > 0){
			if(retransBufferContainsSeqNum(&input->recvFrames,input->lastByteRead,TRANSPORT_DATA)){	
				framedtcpHeader = retransBufferSeqNumRemove(&input->recvFrames,input->lastByteRead,TRANSPORT_DATA);
				dbg("Project3Socket", "CHECKINa fasdfadsf ads fadsf adsfG  payload:%d bufferLimit:%d !!!!!! \n",framedtcpHeader.payload[0], input->readBuffer.limit);
				length = framedtcpHeader.len;
				
				if((input->readBuffer.limit - input->readBuffer.numValues) < length){
					retransBufferPushBack(&input->recvFrames,framedtcpHeader);
					return 0;
				}else{
					dbg("Project3Socket","doing a memcopy to the readBuffer!!!!!! \n");
					memcpy(&input->readBuffer.byte[input->readBuffer.numValues],&framedtcpHeader.payload[0],length);
					input->readBuffer.numValues+=length;
					input->lastByteRead +=length;
				}
				if(input->readBuffer.numValues < len)
				len = input->readBuffer.numValues;
				memcpy(&readBuffer[pos],&input->readBuffer.byte[0],len);
				length = len;
			}
		}
		
		while(len != 0 && bufferSize(&input->readBuffer) > 0){
			poppedValue = bufferPopFront(&input->readBuffer);
			dbg("Project3Socket","Popping asd gasdfasdf agafgjasdFLUSDFLSUDFSLDFU!!!! %d %c sizeOfBuffer:%d len:%d \n", poppedValue, poppedValue, bufferSize(&input->readBuffer), len);
			len--;
		}

		//call receive
		//dbg("Project3Socket", "Receiving something? pos:%d len:%d dest:%d readbuffer:%s \n", pos, len, input->destAddr, readBuffer);
		return length;
	}

	async command int16_t TCPSocket.write(TCPSocketAL *input, uint8_t *writeBuffer, uint16_t pos, uint16_t len){
		nx_uint8_t payload[TRANSPORT_MAX_PAYLOAD_SIZE];
		transport framedtcpHeader;
		uint8_t test, testings;
		uint8_t bytesStoredInBuffer = 0;
		uint8_t bytesWritten = 0;
		transport tcpHeader;
		
		//num of window size is in bytes
		dbg("Project3Socket", "Sending something? pos:%d len:%d sizeofBuffer:%d limit:%d\n", pos, len, bufferSize(&input->writeBuffer), input->writeBuffer.limit);
		
		if((input->writeBuffer.limit - bufferSize(&input->writeBuffer))-1 < len)
			len = input->writeBuffer.limit - bufferSize(&input->writeBuffer);
		memcpy(&input->writeBuffer.byte[input->writeBuffer.numValues], &writeBuffer[pos],len);
		input->writeBuffer.numValues+= len;
		
		input->lastByteWritten += len;
		
		
		dbg_clear("Project3Socket", "\n");
		//uint8_t srcPort, uint8_t destPort, uint8_t type, uint16_t window, int16_t seq, uint8_t *payload, uint8_t packetLength
		if(firstTime == 0){
			test = bufferPopFront(&input->writeBuffer);
			dbg("Project3Socket","First send %d \n",test);
			input->lastByteSent++;
			createTransport(&framedtcpHeader, input->srcPort,input->destPort,TRANSPORT_DATA,0,input->lastByteSent,(uint8_t*)&test,1);
			retransBufferPushBack(&input->frames, framedtcpHeader); firstTime++;
		}
		if(retransBufferSize(&input->frames) == 0){
			test = bufferPopFront(&input->writeBuffer);
			dbg("Project3Socket","----------------------------------SENDSSSSSSSSSS----------------------:%d %d\n\n",firstTime+1,test);
			input->lastByteSent++;
			createTransport(&framedtcpHeader, input->srcPort,input->destPort,TRANSPORT_DATA,0,input->lastByteSent,(uint8_t*)&test,1);
			retransBufferPushBack(&input->frames, framedtcpHeader); firstTime++;
		}
		
		for(testings = 0; testings < bufferSize(&input->writeBuffer); testings++) {
			dbg_clear("genDebug", "%d ", input->writeBuffer.byte[testings]);
		}
		dbg_clear("genDebug", "\n %d\n", input->writeBuffer.byte[input->lastByteWritten - (input->lastByteSent + 1)]);
		
		return len;
	}

	async command bool TCPSocket.isListening(TCPSocketAL *input){
		if(input->socketState == LISTEN){
			return TRUE;
		}
		else{
			 return FALSE;
		}
	}

	async command bool TCPSocket.isConnected(TCPSocketAL *input){
		if(input->socketState == ESTABLISHED) return TRUE;
		else return FALSE;
	}	

	async command bool TCPSocket.isClosing(TCPSocketAL *input){
		return (input->socketState == CLOSING || input->socketState == FIN_SENT);
	}

	async command bool TCPSocket.isClosed(TCPSocketAL *input){
		if(input->socketState == CLOSED) return TRUE;
		else return FALSE;
	}

	async command bool TCPSocket.isConnectPending(TCPSocketAL *input){
		if(input->socketState == SYN_SENT) return TRUE;
		else return FALSE;
	}
	
	async command void TCPSocket.copy(TCPSocketAL *input, TCPSocketAL *output){
		output->srcPort = input->srcPort; output->srcAddr = input->srcAddr;
		output->destPort = input->destPort; output->destAddr = input->destAddr;
		output->socketState = input->socketState;
		memcpy(&output->frames,&input->frames,sizeof(retransBuffer));
		memcpy(&output->recvFrames,&input->recvFrames,sizeof(retransBuffer));
		memcpy(&output->sendBuffer,&input->sendBuffer,sizeof(socketArr));
		memcpy(&output->recvBuffer,&input->recvBuffer,sizeof(socketArr));
	}
}
