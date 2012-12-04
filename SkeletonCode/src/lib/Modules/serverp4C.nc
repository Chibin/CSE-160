/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   October 1 2012
 * 
 */ 

#include "serverAL.h"
#include "TCPSocketAL.h"
#include "serverWorkerList.h"
#include "../packet.h"
#include <stdio.h>

module serverp4C{
	uses{
		interface TCPSocket<TCPSocketAL>;
		interface Timer<TMilli> as ServerTimer;
		interface Timer<TMilli> as WorkerTimer;
		interface Timer<TMilli> as sendMsgTimer;
		interface Random;
		interface TCPManager<TCPSocketAL,pack>;
	}
	provides{
		interface server<TCPSocketAL>;
		interface serverWorker<serverWorkerAL, TCPSocketAL>;
	}
}
implementation{
	//Local Variables Variables
	serverAL mServer;	
	serverWorkerList workers;
	int TCP_ERRMSG_SUCCESS = 0;
	void broadCastMsg(serverWorkerList* worker,uint8_t* msg);
	
	command void server.init(TCPSocketAL *socket){
		mServer.socket = socket;
		mServer.numofWorkers=0;	
		call ServerTimer.startPeriodic(SERVER_TIMER_PERIOD + (uint16_t) ((call Random.rand16())%200));
		call WorkerTimer.startPeriodic(WORKER_TIMER_PERIOD + (uint16_t) ((call Random.rand16())%200));
		call sendMsgTimer.startPeriodic(WORKER_TIMER_PERIOD + (uint16_t) ((call Random.rand16())%200));
	}
	
	event void ServerTimer.fired(){
		if(! call TCPSocket.isClosed(mServer.socket) ){
			TCPSocketAL connectedSock;
			//Attempt to Establish a Connection
			if(call TCPSocket.accept(mServer.socket, &(connectedSock)) == TCP_ERRMSG_SUCCESS){
				serverWorkerAL newWorker;
				dbg("serverAL", "serverAL - Connection Accepted.\n");
				//create a worker.
				call serverWorker.init(&newWorker, &connectedSock);
				newWorker.id= mServer.numofWorkers;
				mServer.numofWorkers++;
				serverWorkerListPushBack(&workers, newWorker);
			}
		}else{ //Shutdown
			//Socket is closed, shutdown
			dbg("serverAL", "serverAL - Server Shutdown\n");
			call TCPSocket.release( mServer.socket );			
			call WorkerTimer.stop();
			call ServerTimer.stop();
			call sendMsgTimer.stop();
		}
	}
	
	event void WorkerTimer.fired(){
		uint16_t i;
		serverWorkerAL *currentWorker;
		
		for(i=0; i<serverWorkerListSize(&workers); i++){
			currentWorker = serverWorkerListGet(&workers, i);
			call serverWorker.execute(currentWorker);
			call serverWorker.sendMsg(currentWorker);
		}		
	}
	
	
	//WORKER
	command void serverWorker.init(serverWorkerAL *worker, TCPSocketAL *inputSocket){
		worker->position = 0;
		worker->socket = call TCPManager.socket();
		worker->currentMsgBufferlen = 0;
		worker->currentlySendinglen = 0;
		chatBufferInit(&worker->sendMsgs);
		chatBufferInit(&worker->storedMsgs);
		call TCPSocket.copy(inputSocket, worker->socket);
		dbg("serverAL", "serverAL - Worker Intilized\n");
	}
	
	command void serverWorker.execute(serverWorkerAL *worker){
		if(!call TCPSocket.isClosed( (worker->socket) ) ){
			uint16_t bufferIndex, length, count;
			uint8_t i; char* pch;
			
			count = call TCPSocket.read( (worker->socket), worker->currentMsgBuffer, worker->currentMsgBufferlen, NEWSERVER_BUFFER_SIZE-worker->currentMsgBufferlen);
			
			if(count == -1){
				// Socket unable to read, release socket
				dbg("serverAL", "serverAL - Releasing socket\n");
				dbg("serverAL", "Position: %lu\n", worker->position);
				return;
			}
			if(count > 0 ){
				dbg("Project4Server","amount data read: %d \n",count);
				for(i = 0; i <= count; i++){
					if(worker->currentMsgBuffer[worker->currentMsgBufferlen-1+i] == '\r' && worker->currentMsgBuffer[worker->currentMsgBufferlen+i] == '\n'){
						dbg("Project4Server","END OF MESSAGE!!!! storing! \n");
						pch = strtok(worker->currentMsgBuffer,"\n");
						strcat(worker->currentMsgBuffer,"\r\n");
						dbg("Project4Server","%s",worker->currentMsgBuffer);
						if(pushBackChatBuffer(&worker->storedMsgs,worker->currentMsgBuffer)){
							//dbg("Project4Server","Pushed into storedMessages! %s \n", worker->storedMsgs.msg[worker->storedMsgs.numValues-1].byte);							
							//dbg("Project4Server","This is what's left %s \n", worker->currentMsgBuffer);
							worker->currentMsgBufferlen = 0;
							return;
						}
					}
				}
				worker->currentMsgBufferlen += count;
				dbg("Project4Server","Total dataread for this msg: %d \n", worker->currentMsgBufferlen);
				return;
			}
		}
	}
	
	event void sendMsgTimer.fired(){
		// TODO Auto-generated method stub
		uint16_t i;
		serverWorkerAL *currentWorker;
		uint8_t tempBuffer[NEWSERVER_BUFFER_SIZE];
		uint8_t newTempBuffer[NEWSERVER_BUFFER_SIZE];
		uint8_t cmd[20];
		char* spliter;
		bufferz tempBufferz;
		for(i = 0; i < mServer.numofWorkers; i++){
			currentWorker = serverWorkerListGet(&workers, i);
			if(currentWorker->storedMsgs.numValues > 0 && currentWorker->currentlySendinglen == 0){
				tempBufferz = popFrontChatBuffer(&currentWorker->storedMsgs);
				sprintf(tempBuffer,"%s",&tempBufferz.byte);
				spliter = strtok((char* )tempBuffer," \r\n");
				if(strcmp(spliter,"hello") == 0){
					dbg("Project4Server", "-------------------HELLO COMMAND------------------- \n");
					strcpy(currentWorker->usernameConnected, spliter = strtok(NULL," "));
					dbg("Project4Server","USERNAME:%s \n", currentWorker->usernameConnected);
					strcpy(currentWorker->userportNum, spliter = strtok(NULL,"\r\n"));
					spliter++;
					currentWorker->currentlySendinglen = sprintf(currentWorker->currentMsgBuffer,"%s",spliter);
					dbg("Project4Server", "USER PORTNUMBER:%s \n", currentWorker->userportNum);
					//currentWorker->currentlySendinglen = 0;
					dbg("Project4Server", "-------------------END COMMAND------------------- \n\n");
				}
				else if(strcmp(spliter,"msg") == 0){
					dbg("Project4Server", "-------------------MSG COMMAND------------------- \n");
					currentWorker->currentlySendinglen = 0;
					strcat(&newTempBuffer,spliter);
					strcat(&newTempBuffer," ");
					strcat(&newTempBuffer,currentWorker->usernameConnected);
					strcat(&newTempBuffer," ");
					spliter = strtok(NULL,"\r\n");
					strcat(&newTempBuffer,spliter);
					strcat(&newTempBuffer,"\r\n");
					dbg("Project4Server","%s \n",newTempBuffer);
					broadCastMsg(&workers,newTempBuffer);
					//pushBackChatBuffer(&currentWorker->sendMsgs,newTempBuffer);
					//spliter++;
					//currentWorker->currentlySendinglen = sprintf(currentWorker->currentMsgBuffer,"%s",spliter);
					dbg("Project4Server", "-------------------END COMMAND------------------- \n\n");
				}else if(strcmp(spliter,"listusr") == 0){
					dbg("Project4Server", "-----------------LISTUSR COMMAND----------------- \n");
					strcat(&newTempBuffer,"listusr");
					for(i = 0; i < mServer.numofWorkers; i++){
						currentWorker = serverWorkerListGet(&workers, i);
						if(i == 0){
							strcat(&newTempBuffer," ");
							strcat(&newTempBuffer,currentWorker->usernameConnected);
						}
						else{
							strcat(&newTempBuffer,", ");
							strcat(&newTempBuffer,currentWorker->usernameConnected);
						}
					}
					strcat(&newTempBuffer,"\r\n");
					dbg("Project4Server","%s \n",newTempBuffer);
					pushBackChatBuffer(&currentWorker->sendMsgs,newTempBuffer);
					dbg("Project4Server", "-----------------END COMMAND----------------- \n");
					
				}	
			}
			
			
		}		
	}
	
	void broadCastMsg(serverWorkerList* worker,uint8_t* msg){
		uint8_t i; serverWorkerAL *currentWorker;
		for(i = 0; i < mServer.numofWorkers; i++){
			currentWorker = serverWorkerListGet(&workers, i);
			pushBackChatBuffer(&currentWorker->sendMsgs,msg);
		}
		
	}


	command void serverWorker.sendMsg(serverWorkerAL *currentWorker){
		// TODO Auto-generated method stub
		uint8_t count; bufferz currentMsg;
		if(currentWorker->currentlySendinglen == 0 && currentWorker->socket->writeBuffer.numValues == 0){
			if(currentWorker->sendMsgs.numValues > 0){
				currentMsg = popFrontChatBuffer(&currentWorker->sendMsgs);
				currentWorker->currentlySendinglen = sprintf(&currentWorker->currentlySendingMsg,"%s",currentMsg.byte);
			}
		}
		if(currentWorker->currentlySendinglen > 0 ){
			count = call TCPSocket.write((currentWorker->socket), currentWorker->currentlySendingMsg, 0, currentWorker->currentlySendinglen);
			dbg("Project4Server", "Checking writeBuffer... size:%d payload:%s index:%d",currentWorker->socket->writeBuffer.numValues,currentWorker->socket->writeBuffer.byte, currentWorker->socket->index);
			memcpy(currentWorker->currentlySendingMsg,currentWorker->currentlySendingMsg+count,currentWorker->currentlySendinglen-count);
			currentWorker->currentlySendinglen -= count;
		}
		if(count > 0)
			dbg("Project4Client", "Amount of bytes sent: %d \n", count);
	}
	
}
