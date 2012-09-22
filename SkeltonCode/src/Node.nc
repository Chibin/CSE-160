/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   Apr 28 2012
 * 
 */ 
#include <Timer.h>
#include "command.h"
#include "packet.h"
#include "dataStructures/list.h"
#include "dataStructures/pair.h"
#include "packBuffer.h"
#include "dataStructures/hashmap.h"
#include "dataStructures/arrTimerList.h"
#include "dataStructures/linkstatetest.h"

//Ping Includes
#include "dataStructures/pingList.h"
#include "ping.h"




module Node{
	uses interface Boot;
	uses interface Timer<TMilli> as pingTimeoutTimer;
	
	uses interface Random as Random;
	
	uses interface Packet;
	uses interface AMPacket;
	uses interface AMSend;
	uses interface SplitControl as AMControl;
	uses interface Receive;
	uses interface Timer<TMilli> as neighborDiscoveryTimer; // Add the line here.
	uses interface Timer<TMilli> as neighborUpdateTimer;
	uses interface Timer<TMilli> as lspTimer;
	
	
}

implementation{
	uint16_t sequenceNum = 0;

	uint16_t neighborSequenceNum = 0;	
	uint16_t linkSequenceNum = 0;	

	nx_int8_t lspCostList[20] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
	//nx_int8_t linkCost[20];
		
	bool busy = FALSE;
	
	message_t pkt;
	pack sendPackage;

	sendBuffer packBuffer;
	arrlist Received;
	
	arrlist friendList;
	
	bool isActive = TRUE;
	
	int discoveryPacket = AM_BROADCAST_ADDR;

	//Ping/PingReply Variables
	pingList pings;

	error_t send(uint16_t src, uint16_t dest, pack *message);
	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
	void arrPrintList(arrlist *list);
	void arrListRemove(arrlist *list,uint32_t iTimer);
	task void sendBufferTask();
			
	
	event void Boot.booted(){
		call AMControl.start();
		arrListInit(&Received);
		dbg("genDebug", "Booted\n");
	}

	event void AMControl.startDone(error_t err){
		if(err == SUCCESS){
			call pingTimeoutTimer.startPeriodic(PING_TIMER_PERIOD + (uint16_t) ((call Random.rand16())%200));
			call neighborDiscoveryTimer.startPeriodic(PING_TIMER_PERIOD + (uint16_t) ((call Random.rand16())%200));
			call neighborUpdateTimer.startPeriodic(PING_TIMER_PERIOD + (uint16_t)((call Random.rand16())%200));
			call lspTimer.startPeriodic(PING_TIMER_PERIOD + (uint16_t)((call Random.rand16())%200));
		}else{
			//Retry until successful
			call AMControl.start();
		}
	}

	event void AMControl.stopDone(error_t err){}

	event void pingTimeoutTimer.fired(){
		//dbg("Project1N", "Checking ping timme out... \n");
		checkTimes(&pings, call pingTimeoutTimer.getNow());
	}
	
	event void neighborDiscoveryTimer.fired(){
		pack discoveryPackage;
		uint8_t createMsg[PACKET_MAX_PAYLOAD_SIZE];
		uint16_t dest;
		
		memcpy(&createMsg, "", sizeof(PACKET_MAX_PAYLOAD_SIZE));
		memcpy(&dest, "", sizeof(uint8_t));
		makePack(&sendPackage, TOS_NODE_ID, discoveryPacket, MAX_TTL, PROTOCOL_PING, neighborSequenceNum++, (uint8_t *)createMsg,
		sizeof(createMsg));	
		
		dbg("Project1N", "Hi, is anyone there? :D \n");
		sendBufferPushBack(&packBuffer, sendPackage, sendPackage.src, discoveryPacket);
		
		post sendBufferTask();
	}
	
	event void neighborUpdateTimer.fired(){
		uint32_t timerCheck = call neighborUpdateTimer.getNow()-10000; //give the node a 10 second margin from the current time.
		dbg("Project1N", "Checking the neighbor %d \n", timerCheck);
		arrListRemove(&friendList, timerCheck);
		arrPrintList(&friendList);
		dbg("Project1N", "Done checking \n\n");
	}
	
	event void lspTimer.fired(){
		
		pack discoveryPackage;
		uint8_t createMsg[PACKET_MAX_PAYLOAD_SIZE];
		uint16_t dest;
		
		dbg("Project2L","%d \n", sizeof(PACKET_MAX_PAYLOAD_SIZE));
		memcpy(&createMsg, &lspCostList[20], 20);
		dbg("Project2L", "%d \n", lspCostList[0]);
		memcpy(&dest, "", sizeof(uint8_t));
		makePack(&sendPackage, TOS_NODE_ID, discoveryPacket, MAX_TTL, PROTOCOL_LINKSTATE, linkSequenceNum++, (uint8_t *)createMsg,
		sizeof(createMsg));	
		sendBufferPushBack(&packBuffer, sendPackage, sendPackage.src, discoveryPacket);
		
		post sendBufferTask();
		dbg("Project2L", "Sending LSPs EVERYWHERE \n");
			
	}
	
	
	event void AMSend.sendDone(message_t* msg, error_t error){
		//Clear Flag, we can send again.
		if(&pkt == msg){
			//dbg("genDebug", "Packet Sent\n");
			busy = FALSE;
			//dbg("Project1F", "Broadcasted\n\n");
			post sendBufferTask();
		}
	}


	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
		if(!isActive){
			dbg("genDebug", "The Node is inactive, packet will not be read.");
			return msg;
		}
		if(len==sizeof(pack)){
			pack* myMsg=(pack*) payload;
			pair temp1;
			pair temp2;

			if(TOS_NODE_ID==myMsg->dest){
				dbg("genDebug", "Packet from %d has arrived! Msg: %s\n", myMsg->src, myMsg->payload);
				//dbg("genDebug", "message from %d, MSG: %s\n\n", myMsg->src, myMsg->payload);
				switch(myMsg->protocol){
					uint8_t createMsg[PACKET_MAX_PAYLOAD_SIZE];
					uint16_t dest;
					case PROTOCOL_PING:
						//if(!arrListContains(&Received, myMsg->src, sendPackage.seq)){
						dbg("genDebug", "Sending Ping Reply to %d! \n\n", myMsg->src);
						makePack(&sendPackage, TOS_NODE_ID, myMsg->src, MAX_TTL, PROTOCOL_PINGREPLY, sequenceNum++, (uint8_t *) myMsg->payload, sizeof(myMsg->payload));
						sendBufferPushBack(&packBuffer, sendPackage, sendPackage.src, AM_BROADCAST_ADDR);
						//temp1.seq = myMsg->seq;
						//temp1.src = myMsg->src;
						//arrListPushBack(&Received,temp1);
						post sendBufferTask();
						//}
						break;
					case PROTOCOL_PINGREPLY:
						if(!arrListContains(&Received, myMsg->src, myMsg->seq)){
						//dbg("Project1F", "%d", );
						dbg("Project1F", "--------------PING REPLY SRC:%d DEST:%d SEQ:%d--------------\n", myMsg->src, myMsg->dest, myMsg->seq);
						dbg("genDebug", "Received a Ping Reply from %d!\n\n", myMsg->src);
						temp1.seq = myMsg->seq;
						temp1.src = myMsg->src;
						arrListPushBack(&Received,temp1);
						}
						else
							dbg("Project1F", "Ping reply duplicate, dropping\n\n");
						
						break;
					case PROTOCOL_CMD:
							switch(getCMD((uint8_t *) &myMsg->payload, sizeof(myMsg->payload))){
								uint32_t temp=0;
								case CMD_PING:
								    dbg("genDebug", "Ping packet received: %d \n", myMsg->seq);
									memcpy(&createMsg, (myMsg->payload) + PING_CMD_LENGTH, sizeof(myMsg->payload) - PING_CMD_LENGTH);
									memcpy(&dest, (myMsg->payload)+ PING_CMD_LENGTH-2, sizeof(uint8_t));
									makePack(&sendPackage, TOS_NODE_ID, (dest-48)&(0x00FF), MAX_TTL, PROTOCOL_PING, sequenceNum++, (uint8_t *)createMsg,
									sizeof(createMsg));	
									
									dbg("genDebug", "%d %d %s \n", sendPackage.src, sendPackage.dest, sendPackage.payload);
									//Place in Send Buffer
									sendBufferPushBack(&packBuffer, sendPackage, sendPackage.src,AM_BROADCAST_ADDR);
									dbg("Project1F", "BroadCasting from %d SEQ#:%d DEST:%d \n", TOS_NODE_ID, myMsg->seq, sendPackage.dest);
									post sendBufferTask();
									break;
								case CMD_KILL:
									isActive = FALSE;
									break;
								case CMD_ERROR:
									break;
								default:
									break;
							}
						break;
					default:
						break;
				}
			}else if(TOS_NODE_ID==myMsg->src){
				//dbg("cmdDebug", "Source is this node: %s\n", myMsg->payload);
				dbg("Project1F", "THIS IS THE SOURCE? SRC:%d dest:%d seq:%d \n\n", myMsg->src, myMsg->dest, myMsg->seq);
				return msg;
			}
			else if(myMsg->dest == discoveryPacket ){
				pair friendListInfo;
				nx_int8_t *tempArray;
				switch(myMsg->protocol){
					case PROTOCOL_LINKSTATE:
						dbg("Project2L","LINK STATE OF GREATNESS. I DON'T DO ANYTHING ELSE :<  \n");
						tempArray = myMsg->payload;
						dbg("Project2L", "Printing out the first element of the list: %d \n", tempArray[0]);
						
						break;	
					case PROTOCOL_PING:
							makePack(&sendPackage, TOS_NODE_ID, discoveryPacket, MAX_TTL, PROTOCOL_PINGREPLY, neighborSequenceNum++, (uint8_t *) myMsg->payload, sizeof(myMsg->payload));
							sendBufferPushBack(&packBuffer, sendPackage, TOS_NODE_ID, myMsg->src);
							dbg("Project1N", "Ping Received: I am ignoring you %d. \n", myMsg->src);
							post sendBufferTask();
						break;
					case PROTOCOL_PINGREPLY:
						dbg("Project1N", "PingReply Received: That's mean :< %d. \n", myMsg->src);
						if(!arrListContains(&friendList, myMsg->src, myMsg->seq)){
							friendListInfo.seq = myMsg->seq;
							friendListInfo.src = myMsg->src;
							friendListInfo.timer = call neighborDiscoveryTimer.getNow();
							if(arrListContainsKey(&friendList, myMsg->src)){
								arrListReplace(&friendList,myMsg->src, myMsg->seq, friendListInfo.timer); //updates the current time of the node
								dbg("Project1N", "---------------Updating my friendList---------------\n\n");
							}
							else
								arrListPushBack(&friendList,friendListInfo);
							
							dbg("Project1N", "NOT IN THE LIST, ADDING: Adding to my FriendList anyways T_T \n\n");
						}
						else{
							dbg("Project1N", "Oh you're already in my FriendList? :D");
						}
						//arrPrintList(&friendList);
						break;
					default:
						dbg("Project1N", "I should never get here, I hope. \n");
						break;	
				}
				 
			}
			else{
				//Changing the flooding mechanism for it to use link state packets
				//broadcast the info
				
				/*if(myMsg->protocol == PROTOCOL_LINKSTATE){
					dbg("Project2L", "I am a link state packet");
				}*/
				
				//checks whether the packet has already been stored in the current list.
				dbg("Project1F","I AM A PACKET FOR BROADCASTING \n");
				if(!arrListContains(&Received, myMsg->src, myMsg->seq)){
					if(arrListSize(&Received) >= 29){
						dbg("Project1F","Popping front");
						pop_front(&Received);	
					}
					
					makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, myMsg->protocol, myMsg->seq, (uint8_t *) myMsg->payload, sizeof(myMsg->payload));
					sendBufferPushBack(&packBuffer, sendPackage, sendPackage.src, AM_BROADCAST_ADDR);
					
					temp1.seq = myMsg->seq;
					temp1.src = myMsg->src;
					arrListPushBack(&Received,temp1);
					dbg("Project1F", "BroadCasting from %d SEQ#:%d DEST:%d \n", TOS_NODE_ID, myMsg->seq, sendPackage.dest);
					post sendBufferTask();
					dbg("Project1F", "Broadcasting\n\n");
				}
				else{
					
					dbg("Project1F", "DROPPING packets with src:%d seq:%d \n", myMsg->src, myMsg->seq);
					temp1 = back(&Received);
					dbg("Project1F", "Size is %d seq# of last is %d\n\n",arrListSize(&Received), temp2.seq);
					}
				
			}		
			return msg;
		}

		dbg("genDebug", "Unknown Packet Type\n");
		return msg;
	}
	
	task void sendBufferTask(){
		if(packBuffer.size !=0 && !busy){
			sendInfo info;
			info = sendBufferPopFront(&packBuffer);
			send(info.src,info.dest, &(info.packet));
		}
		
		if(packBuffer.size !=0 && !busy){
			post sendBufferTask();
		}
	}

	/*
	* Send a packet
	*
	*@param
	*	src - source address
	*	dest - destination address
	*	msg - payload to be sent
	*
	*@return
	*	error_t - Returns SUCCESS, EBUSY when the system is too busy using the radio, or FAIL.
	*/
	
	// use this function for broadcasting?
	
	error_t send(uint16_t src, uint16_t dest, pack *message){
		
		//dbg("Project1F","USING SEND \n");
		
		if(!busy && isActive){
			pack* msg = (pack *)(call Packet.getPayload(&pkt, sizeof(pack) ));			
			*msg = *message;

			//TTL Check
			if(msg->TTL >0)msg->TTL--;
			else return FAIL;

			if(call AMSend.send(dest, &pkt, sizeof(pack)) ==SUCCESS){
				busy = TRUE;
				return SUCCESS;
			}else{
				dbg("genDebug","The radio is busy, or something\n");
				return FAIL;
			}
		}else{
			return EBUSY;
		}
		dbg("genDebug", "FAILED!?");
		return FAIL;
	}	

	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
		Package->src = src;
		Package->dest = dest;
		Package->TTL = TTL;
		Package->seq = seq;
		Package->protocol = protocol;
		memcpy(Package->payload, payload, length);
	}
	
	void arrPrintList(arrlist* list){
		uint8_t i;
		for(i = 0; i<list->numValues; i++){
			dbg("Project1N","I think I am friends with %d and the last time we met was %d \n", list->values[i].src, list->values[i].timer);
		}	
	}
	
	
//Checks for the node time out
	void arrListRemove(arrlist *list,uint32_t iTimer){
		uint8_t i;
		uint8_t j;
		for(i = 0; i<=list->numValues; i++){
			//printf("%d > %d \n", iTimer, list->values[i].timer);
			if(iTimer >= list->values[i].timer && list->values[i].timer != 0){
				dbg("Project1N","Removing %d from friendList, last seen at time %d. Time removed: %d \n", list->values[i].src, list->values[i].timer, iTimer);
				
				if(list->numValues > 1){
					list->values[i] = list->values[list->numValues-1];		
					list->numValues--;
					i--;
				}
				else
					list->numValues = 0;
				}
			}
	
	}	
	
}
