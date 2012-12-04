
#include "TCPSocketAL.h"
#include "clientAL.h"
#include "../packet.h"
#include <stdio.h>

enum{
	BYTES_TO_SEND = 100
};

module clientp4C{
	uses{
		interface TCPSocket<TCPSocketAL>;
		
		interface Timer<TMilli> as ClientTimer;
		interface Random;
		interface TCPManager<TCPSocketAL,pack>;
	}
	provides{
		interface client<TCPSocketAL>;
	}
}
implementation{
	clientAL mClient;
	command void client.init(TCPSocketAL *socket){
		mClient.socket = socket;
		mClient.startTime = 0;
		mClient.position = 0;
		mClient.amount=BYTES_TO_SEND;
		mClient.currentMsglen = 0;
		mClient.receiveBufferlen = 0;
		chatBufferInit(&mClient.clientBuffer);
		call ClientTimer.startPeriodic(CLIENT_TIMER_PERIOD + (uint16_t) ((call Random.rand16())%200));
		dbg("Project4Client", "TESTING!");
	}	
	event void ClientTimer.fired(){
		if(call TCPSocket.isConnectPending( (mClient.socket) )){
			dbg("clientAL", "clientAL - Connection Pending...\n");
		}else if(call TCPSocket.isConnected( (mClient.socket) )){
			uint8_t count; bufferz currentMsg;
			if(mClient.currentMsglen == 0 && mClient.socket->writeBuffer.numValues == 0){
				if(mClient.clientBuffer.numValues > 0){
					currentMsg = popFrontChatBuffer(&mClient.clientBuffer);
					mClient.currentMsglen = sprintf(&mClient.currentMsgBuffer,"%s",currentMsg.byte);
				}
			}
			//dbg("Project4Client", "SIZE OF CLIENTBUFFER: %d",mClient.clientBuffer.numValues);
			//dbg("Project4Client", " I AM CONNECTED!!!!!!!!!!! \n");
			if(mClient.currentMsglen > 0 ){
				count = call TCPSocket.write(mClient.socket, mClient.currentMsgBuffer, 0, mClient.currentMsglen);
				memcpy(mClient.currentMsgBuffer,mClient.currentMsgBuffer+count,mClient.currentMsglen-count);
				mClient.currentMsglen -= count;
			}
			if(count > 0)
				dbg("Project4Client", "Amount of bytes sent: %d \n", count);
		}else if(call TCPSocket.isClosing(mClient.socket)){

		}else if(call TCPSocket.isClosed( (mClient.socket) )){
			
		}
		
		//reading messages!!!!
		if(!call TCPSocket.isClosed( (mClient.socket) ) ){
			uint16_t bufferIndex, length, count;
			uint8_t i; char* pch;
			
			count = call TCPSocket.read( (mClient.socket), mClient.receivedBuffer, mClient.receiveBufferlen, NEWCLIENT_BUFFER_SIZE-mClient.receiveBufferlen);
			
			if(count == -1){
				// Socket unable to read, release socket
				dbg("serverAL", "serverAL - Releasing socket\n");
				dbg("serverAL", "Position: %lu\n", mClient.receiveBufferlen);
				return;
			}
			if(count > 0 ){
				dbg("Project4Server","amount data read: %d \n",count);
				for(i = 0; i <= count; i++){
					if(mClient.receivedBuffer[mClient.receiveBufferlen-1+i] == '\r' && mClient.receivedBuffer[mClient.receiveBufferlen+i] == '\n'){
						dbg("Project4Server","PRINTING OUT SERVER MESSAGE:  %s \n", mClient.receivedBuffer);
						mClient.receiveBufferlen = 0;
						return;
					}
				}
			}
			
				mClient.receiveBufferlen += count;
			if(mClient.receiveBufferlen != 0)dbg("Project4Server","Total dataread for this msg: %d \n", mClient.receiveBufferlen);
				return;
		}
	}
		

	command void client.msg(void* myMsg){
		// TODO Auto-generated method stub
		uint8_t* my = myMsg;
		dbg("Project4Client","PAYLOAD: %s\\r\\n", my);
		pushBackChatBuffer(&mClient.clientBuffer,my);
		
	}
	
}
