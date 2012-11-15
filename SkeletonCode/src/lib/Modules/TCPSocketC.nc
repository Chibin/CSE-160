#include "TCPSocketAL.h"
#include "../packet.h"
#include "transport.h"
#include "socketBuffer.h"
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
	socketArr sendBuffer;
	socketArr recvBuffer;
	int queueSize = 0, currentlyConnected = 0;
	int internalPort = 0;
	
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
		input->socketState = LISTEN;
		//max of backlog for the queue
		return 0;
	}
	
	async command uint8_t TCPSocket.accept(TCPSocketAL *input, TCPSocketAL *output){
		//send SYNACK?
	//	output = call TCPManager.socket();
	//	call TCPSocket.bind(output, input->srcPort, input->srcAddr);
			output->srcPort = input->srcPort; output->srcAddr = input->srcAddr;
			output->destPort = input->destPort; output->destAddr = input->destAddr;
			output->socketState = SYN_RECEIVED;
			currentlyConnected++;
			return 0;
	}

	async command uint8_t TCPSocket.connect(TCPSocketAL *input, uint16_t destAddr, uint8_t destPort){
		call node.test();
		input->destAddr = destAddr;
		input->destPort = destPort;
		if(sockPushBack(&input->sendBuffer,(socketData){0,0,TRANSPORT_SYN,0})){
			call node.sendPacket(input->srcPort, destAddr, destPort, TRANSPORT_SYN);
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
		input->socketState = CLOSED;
		input->isAvailable = TRUE;
		return 0;
	}

	async command uint8_t TCPSocket.release(TCPSocketAL *input){
		input->socketState = CLOSED;
		input->isAvailable = TRUE;
		return 0;
	}
	
	async command int16_t TCPSocket.send(TCPSocketAL *input, uint8_t *writeSocketBuffer){
		nx_uint8_t payload[TRANSPORT_MAX_PAYLOAD_SIZE];
		uint8_t bytesStoredInBuffer = 0;
		uint8_t bytesWritten = 0;
		transport tcpHeader;
		// last acknowledged received
		//last frame sent
		//sws = send window size; is this basically the window size that will be given?
		//LFS-LAR <= SWS
		
		//sender should retransmit every so often.... 
		
		//num of window size is in bytes
		//dbg("Project3Socket", "Sending something? pos:%d len:%d \n", pos, len);
		
		/*
		 *
		while(len != 0){
			if(len < TRANSPORT_MAX_PAYLOAD_SIZE){
				memcpy(&payload, (writeBuffer) + bytesWritten, len);
				dbg("Project3Socket", "Checking payload: %s \n", payload);
				createTransport(&tcpHeader, input->srcPort, input->destPort, TRANSPORT_DATA, window, seq , &payload, len);
				printTransport(&tcpHeader);
				call node.sendTransport(&tcpHeader, input->destAddr);
				bytesWritten += len;
				len = 0;
			}
			else{
				memcpy(&payload, (writeBuffer) + bytesWritten, TRANSPORT_MAX_PAYLOAD_SIZE);
				dbg("Project3Socket", "Checking payload: %s \n", payload);
				createTransport(&tcpHeader, input->srcPort, input->destPort, TRANSPORT_DATA, window, seq , &payload, TRANSPORT_MAX_PAYLOAD_SIZE);
				printTransport(&tcpHeader);
				call node.sendTransport(&tcpHeader, input->destAddr);
				len -= TRANSPORT_MAX_PAYLOAD_SIZE;
				bytesWritten += TRANSPORT_MAX_PAYLOAD_SIZE;
			}
		}
		*/
		return bytesStoredInBuffer;
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
	
	async command int16_t TCPSocket.read(TCPSocketAL *input, uint8_t *readBuffer, uint16_t pos, uint16_t len){
		
		//call receive
		uint8_t bytesRead = 0;
		//dbg("Project3Socket", "Receiving something? pos:%d len:%d dest:%d readbuffer:%s \n", pos, len, input->destAddr, readBuffer);
		
		return 20;
	}

	async command int16_t TCPSocket.write(TCPSocketAL *input, uint8_t *writeBuffer, uint16_t pos, uint16_t len){
		nx_uint8_t payload[TRANSPORT_MAX_PAYLOAD_SIZE];
		uint8_t bytesStoredInBuffer = 0;
		uint8_t bytesWritten = 0;
		transport tcpHeader;
		
		//num of window size is in bytes
		dbg("Project3Socket", "Sending something? pos:%d len:%d \n", pos, len);
		
		while(sockPushBack(&input->sendBuffer,(socketData){TRANSPORT_DATA,writeBuffer[pos+bytesStoredInBuffer],pos+bytesStoredInBuffer})){
			dbg("Project3Socket","I can still store stuff %d \n", pos+bytesStoredInBuffer);
			bytesStoredInBuffer++;
		}
		return bytesStoredInBuffer;
		/*
		 * 
		while(len != 0){
			if(len < TRANSPORT_MAX_PAYLOAD_SIZE){
				memcpy(&payload, (writeBuffer) + bytesWritten, len);
				dbg("Project3Socket", "Checking payload: %s \n", payload);
				createTransport(&tcpHeader, input->srcPort, input->destPort, TRANSPORT_DATA, window, seq , &payload, len);
				printTransport(&tcpHeader);
				call node.sendTransport(&tcpHeader, input->destAddr);
				bytesWritten += len;
				len = 0;
			}
			else{
				memcpy(&payload, (writeBuffer) + bytesWritten, TRANSPORT_MAX_PAYLOAD_SIZE);
				dbg("Project3Socket", "Checking payload: %s \n", payload);
				createTransport(&tcpHeader, input->srcPort, input->destPort, TRANSPORT_DATA, window, seq , &payload, TRANSPORT_MAX_PAYLOAD_SIZE);
				printTransport(&tcpHeader);
				call node.sendTransport(&tcpHeader, input->destAddr);
				len -= TRANSPORT_MAX_PAYLOAD_SIZE;
				bytesWritten += TRANSPORT_MAX_PAYLOAD_SIZE;
			}
		}
		*/
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
		if(input->socketState == CLOSING) return TRUE;
		else return FALSE;
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
	}
}
