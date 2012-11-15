/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   Apr 28 2012
 * 
 */ 

#include "serverAL.h"
#include "TCPSocketAL.h"
#include <Timer.h>
#include "command.h"
#include "packet.h"
#include "dataStructures/list.h"
#include "dataStructures/pair.h"
#include "packBuffer.h"
#include "dataStructures/hashmap.h"
#include "transport.h"
//extra dataStructures
#include "dataStructures/arrTimerList.h"
#include "dataStructures/lspTable.h"

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
	
	uses interface server<TCPSocketAL> as ALServer;
	uses interface TCPSocket<TCPSocketAL> as ALSocket;
	uses interface client<TCPSocketAL> as ALClient;
	uses interface TCPManager<TCPSocketAL, pack> as TCPManager;
//	uses interface Timer<TMilli> as ServerTimer;
//	uses interface Timer<TMilli> as ServerWorkerTimer;
	provides{
		interface NodeA;
	}
	
}
implementation{
	
	uint16_t sequenceNum = 0;
	uint16_t neighborSequenceNum = 0;
	uint16_t tcpSequenceNum = 0;
	uint16_t tcpDataSequenceNum = 0;
	int totalNodes = 7;
	
	//---- PROJECT 2 VARIABLES -----
	//We're keeping track of each node with the index. Assume that the index is the name of the node.
	//note: We need to shift the nodes by 1 so that index 0 is keeping track of node 1. (May be reconsidered)
	uint16_t linkSequenceNum = 0;
	lspTable confirmedList;
	lspTable tentativeList;
	lspMap lspMAP[20];
	arrlist lspTracker;
	float cost[20];
	int lastSequenceTracker[20] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
	float totalAverageEMA[20] =  {0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215};
	
	//------------------------------
	//Project 3 variables
	TCPSocketAL *mSocket;
	
	//-----
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
	
	//project 1
	void arrPrintList(arrlist *list);
	bool arrListRemove(arrlist *list, uint32_t iTimer);
	void neighborDiscoveryPacket();
	task void sendBufferTask();
	
	//project 2
	void printlspMap(lspMap *list);
	void lspNeighborDiscoveryPacket();
	void dijkstra();
	int forwardPacketTo(lspTable* list, int dest);
	void printCostList(lspMap *list, uint8_t nodeID);
	float EMA(float prevEMA, float now,float weight);
	
	//project 3
	
	//---- project 3
	async command void NodeA.test(){
	
		dbg("Project3C", "TESTING STUFF \n\n");	
	}
	async command TCPSocketAL * NodeA.getSocket(){
		return mSocket;	
	}
	
	async command void NodeA.sendTransport(transport *tcpHeader, uint16_t destAddr){
		int forwardTo;
		if(tcpHeader->seq == 0)
			tcpHeader->seq = tcpDataSequenceNum;
		dijkstra();
		forwardTo = forwardPacketTo(&confirmedList,destAddr);
		makePack(&sendPackage,TOS_NODE_ID, destAddr,MAX_TTL,PROTOCOL_TCP, tcpDataSequenceNum, tcpHeader,20);
		sendBufferPushBack(&packBuffer, sendPackage, sendPackage.src, forwardTo);
		tcpDataSequenceNum++;
		post sendBufferTask();
	}
	
	async command void NodeA.sendDataPacket(uint8_t srcPort, uint16_t destAddr, uint8_t destPort, uint8_t flagType, uint8_t *payload, uint8_t len){
		int forwardTo;
		transport tcpHeader; 
		dijkstra();
		forwardTo = forwardPacketTo(&confirmedList,destAddr);
		createTransport(&tcpHeader,srcPort,destPort, flagType, 1, tcpDataSequenceNum, payload, len);
	//	tcpHeader.acknowledgment = 0;
		makePack(&sendPackage,TOS_NODE_ID, destAddr,MAX_TTL,PROTOCOL_TCP, tcpDataSequenceNum, &tcpHeader,20);
		sendBufferPushBack(&packBuffer, sendPackage, sendPackage.src, forwardTo);
		tcpDataSequenceNum++;
		post sendBufferTask();
	}
	
	async command void NodeA.sendPacket(uint8_t srcPort, uint16_t destAddr, uint8_t destPort, uint8_t flagType){
		int forwardTo;
		transport tcpHeader; 
		dbg("Project3Node","CHECKING SIZE OF TRANSPORT %d \n\n\n", sizeof(transport));
		dbg("Project3C", "Sending a packet from TCP \n");
		dijkstra();
		forwardTo = forwardPacketTo(&confirmedList,destAddr);
		dbg("Project3Node","Forwarding to %d and src is %d \n", forwardTo, TOS_NODE_ID);
		
		createTransport(&tcpHeader,srcPort,destPort, flagType, 1, tcpSequenceNum,"", TRANSPORT_MAX_PAYLOAD_SIZE);
		//tcpHeader.acknowledgment = 0;
		printTransport(&tcpHeader);
		dbg("Project3Node", "destPort:%d!!!!!! \n",tcpHeader.destPort);
		makePack(&sendPackage,TOS_NODE_ID, destAddr,MAX_TTL,PROTOCOL_TCP, tcpSequenceNum, &tcpHeader,20);
		sendBufferPushBack(&packBuffer, sendPackage, sendPackage.src, forwardTo);
		tcpSequenceNum++;
		post sendBufferTask();
	}
	
	//--- project 3 END
	
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
		checkTimes(&pings, call pingTimeoutTimer.getNow());
	}

	//checks who are the neighbors
	event void neighborDiscoveryTimer.fired(){
		if(isActive)neighborDiscoveryPacket();
	}
		
	//checks if the time is still valid to be in the list
	event void neighborUpdateTimer.fired(){
		uint32_t timerCheck = call neighborUpdateTimer.getNow(); //give the node a 50 second margin from the current time.
			//dbg("Project2test", "Checking the neighbor %d \n", timerCheck);
			if(arrListRemove(&friendList, timerCheck)){
				//lspNeighborDiscoveryPacket();
				dbg("Project2test", "Removed something \n");
				arrPrintList(&friendList);
			}
		dbg("Project1N", "Done checking \n\n");
	}
	
	event void lspTimer.fired(){
		if(isActive)lspNeighborDiscoveryPacket();
	}

	event void AMSend.sendDone(message_t* msg, error_t error){
		//Clear Flag, we can send again.
		if(&pkt == msg){
			//dbg("genDebug", "Packet Sent\n");
			busy = FALSE;
			post sendBufferTask();
		}
	}


	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
		if(!isActive){
			//dbg("genDebug", "The Node is inactive, packet will not be read.\n");
			return msg;
		}
		if(len==sizeof(pack)){
			pack* myMsg=(pack*) payload;
			pair temp1;
			pair temp2;
			pair temporary;
			uint8_t srcPort, destPort, destAddr;
			int incrementor = PING_CMD_LENGTH, i, j, check;
			transport tHeader;
			bool derping;
			if(myMsg->protocol == PROTOCOL_TCP){
				//DEBUG CHECKS
				//dbg("Project3Node","Checking stuff \n\n");
				
			}
			if(TOS_NODE_ID==myMsg->dest){
				//dbg("genDebug", "Packet from %d has arrived! Msg: %s\n", myMsg->src, myMsg->payload);
				switch(myMsg->protocol){
					uint8_t createMsg[PACKET_MAX_PAYLOAD_SIZE];
					uint8_t temporary[PACKET_MAX_PAYLOAD_SIZE];
					uint16_t dest;
					int forwardTo;
					case PROTOCOL_PING:
					dbg("genDebug", "Sending Ping Reply to %d! \n\n", myMsg->src);
					dbg("Project2D","Running dijkstra\n");
					dijkstra();
					dbg("Project2D","END\n\n"); 
					forwardTo = forwardPacketTo(&confirmedList,myMsg->src);
					dbg("Project2F","Forwarding to %d and src is %d \n", forwardTo, TOS_NODE_ID);
					makePack(&sendPackage, TOS_NODE_ID, myMsg->src, MAX_TTL, PROTOCOL_PINGREPLY, sequenceNum++, (uint8_t *) myMsg->payload, sizeof(myMsg->payload));					
					sendBufferPushBack(&packBuffer, sendPackage, sendPackage.src,forwardTo);
					post sendBufferTask();
					break;
					case PROTOCOL_PINGREPLY:
					if(!arrListContains(&Received, myMsg->src, myMsg->seq)){
						dbg("Project1F", "--------------PING REPLY SRC:%d DEST:%d SEQ:%d--------------\n", myMsg->src, myMsg->dest, myMsg->seq);
						dbg("genDebug", "Received a Ping Reply from %d!\n\n", myMsg->src);
						temp1.seq = myMsg->seq;
						temp1.src = myMsg->src;
						arrListPushBack(&Received,temp1);
					}
					else
						dbg("Project1F", "Ping reply duplicate, dropping\n\n");
	
					break;
					case PROTOCOL_TCP:
						call TCPManager.handlePacket(myMsg);
					break;
					case PROTOCOL_CMD:
					switch(getCMD((uint8_t *) &myMsg->payload, sizeof(myMsg->payload))){
						uint32_t temp=0;
						case CMD_PING:
							dbg("genDebug", "Ping packet received: %d \n", myMsg->seq);
							dbg("genDebug", "Sending Ping Reply to %d! \n\n", myMsg->src);
							dbg("Project2D","Running dijkstra\n");
							dijkstra();
							dbg("Project2D","END\n\n"); 
							memcpy(&createMsg, (myMsg->payload) + PING_CMD_LENGTH, sizeof(myMsg->payload) - PING_CMD_LENGTH);
							memcpy(&dest, (myMsg->payload)+ PING_CMD_LENGTH-2, sizeof(uint8_t));
							makePack(&sendPackage, TOS_NODE_ID, (dest-48)&(0x00FF), MAX_TTL, PROTOCOL_PING, sequenceNum++, (uint8_t *)createMsg,
									sizeof(createMsg));	
							dbg("genDebug", "%d %d %s \n", sendPackage.src, sendPackage.dest, sendPackage.payload);
							//Place in Send Buffer
							forwardTo = forwardPacketTo(&confirmedList,sendPackage.dest);
							dbg("Project2F","Forwarding to %d and src is %d \n", forwardTo, TOS_NODE_ID);				
							sendBufferPushBack(&packBuffer, sendPackage, sendPackage.src,forwardTo);
							dbg("Project1F", "BroadCasting from %d SEQ#:%d DEST:%d \n", TOS_NODE_ID, myMsg->seq, sendPackage.dest);
							post sendBufferTask();
						break;
						case CMD_KILL:
							isActive = FALSE;
						break;
						case CMD_ERROR:
						break;
						case CMD_TEST_CLIENT:
							j = 0, check = 0;
							//parsing
							dbg("Project3C", "Testing Client CMD \n");
							memcpy(&createMsg, (myMsg->payload) + PING_CMD_LENGTH, sizeof(myMsg->payload) - PING_CMD_LENGTH);
							for(i = 0; i < 20; i++){
								if(createMsg[i] == ' ' && check == 0){
									memcpy(&temporary, (myMsg->payload) + PING_CMD_LENGTH, j);
									srcPort = atoi(temporary);
									dbg("Project3C", "testing parsing %d \n", srcPort);
									j = 0; check++;
								}
								else if(createMsg[i] == ' ' && check == 1){
									memcpy(&temporary, (myMsg->payload) + PING_CMD_LENGTH+j-1, j);
									destPort = atoi(temporary);
									dbg("Project3C", "testing parsing %d \n", destPort);
									memcpy(&temporary, (myMsg->payload) + PING_CMD_LENGTH+i+1,20);
									destAddr = atoi(temporary);
									dbg("Project3C", "testing parsing %d \n", destAddr);
								}
								j++;
							}
							//starting client
							call TCPManager.init();
							mSocket = (call TCPManager.socket());
							call ALSocket.bind(mSocket, srcPort, TOS_NODE_ID);
							call ALSocket.connect(mSocket, destAddr, destPort);
							call ALClient.init(mSocket);
							dbg("Project3C", "checking state: %d \n", mSocket->socketState);
						break;
						case CMD_TEST_SERVER:
							//parsing the cmd
							dbg("Project3S", "Testing Server CMD \n");
							memcpy(&createMsg, (myMsg->payload) + PING_CMD_LENGTH, sizeof(myMsg->payload) - PING_CMD_LENGTH);
							srcPort = atoi(createMsg);
							dbg("Project3S", "testing parsing %d \n", srcPort);
							//starting up the server
							call TCPManager.init();
							mSocket = (call TCPManager.socket());
							call ALSocket.bind(mSocket, srcPort, TOS_NODE_ID);
							call ALSocket.listen(mSocket, 5);
							call ALServer.init(mSocket);
							dbg("Project3S", "checking state: %d \n", mSocket->socketState);
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
			else if(myMsg->dest == discoveryPacket){
				pair friendListInfo;
				uint8_t *tempArray;
				int i, j;
				int difference; 
				switch(myMsg->protocol){
					case PROTOCOL_LINKSTATE:
						if(!arrListContains(&lspTracker, myMsg->src, myMsg->seq)){
							if(arrListSize(&lspTracker) >= 30){
								dbg("Project2L","Popping front\n");
								pop_front(&lspTracker);	
							}
							temp1.seq = myMsg->seq;
							temp1.src = myMsg->src;
							arrListPushBack(&lspTracker,temp1);
							lspMapinitialize(&lspMAP,myMsg->src);
							dbg("Project2L","LINK STATE OF GREATNESS. FLOODING THE NETWORK from %d seq#: %d :< \n", myMsg->src, myMsg->seq);								
							for(i = 0; i < totalNodes; i++){
								lspMAP[myMsg->src].cost[i] = myMsg->payload[i];
								if(myMsg->payload[i] != -1 && myMsg->payload[i] != 0)
									dbg("Project2L", "Printing out src:%d neighbor:%d  cost:%d \n", myMsg->src, i , myMsg->payload[i]);
							}
							makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, myMsg->protocol, myMsg->seq, (uint8_t *) myMsg->payload, 20);
							sendBufferPushBack(&packBuffer, sendPackage, sendPackage.src, AM_BROADCAST_ADDR);
							post sendBufferTask();
						}
						else
							dbg("Project2L", "Already received this packet from %d, will not flood. \n\n", myMsg->src);			
					break;
					case PROTOCOL_PING:
						//we dont' care about the receiving the ping reply when, we just want to send something.				
						dbg("Project2N", "Sending PingReply seq#: %d src: %d \n",myMsg->seq,myMsg->src);
						makePack(&sendPackage, TOS_NODE_ID, discoveryPacket, MAX_TTL, PROTOCOL_PINGREPLY, myMsg->seq, (uint8_t *) myMsg->payload, sizeof(myMsg->payload));
						sendBufferPushBack(&packBuffer, sendPackage, TOS_NODE_ID, myMsg->src);
						dbg("Project1N", "Ping Received: I am ignoring you %d. \n", myMsg->src);
						post sendBufferTask();
					break;
					case PROTOCOL_PINGREPLY:
						difference = 0;
						//The packet drops usually happen in the pingreply section
						dbg("Project1N", "PingReply Received: That's mean :< %d. \n", myMsg->src);
						dbg("Project2N", "Received Ping reply seq#: %d \n", myMsg->seq);
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
							//project 2 portion
							if(lastSequenceTracker[myMsg->src] < myMsg->seq){
								//calculate the cost of the link in here						
								difference =  myMsg->seq -lastSequenceTracker[myMsg->src];
								lastSequenceTracker[myMsg->src] = myMsg->seq;
								if(myMsg->seq <= 1)
									totalAverageEMA[myMsg->src] = EMA(1.0,1.0,1.0);		
								else							
									totalAverageEMA[myMsg->src] = EMA(totalAverageEMA[myMsg->src],1,1/difference);			
							}
						}
						else{
							dbg("Project1N", "Oh you're already in my FriendList? :D");
						}
					break;
					default:
						dbg("Project1N", "I should never get here, I hope. \n");
					break;	
				}
			}
			else{
				int forwardTo;
				//dbg("Project3Node", "I GOT HERE\n");
				dbg("Project2D","Running dijkstra\n");
				dijkstra();
				dbg("Project2D","END\n\n"); 
				forwardTo = forwardPacketTo(&confirmedList,myMsg->dest);
				dbg("Project2F","Forwarding to %d and src is %d \n", forwardTo, myMsg->src);
				if(forwardTo == 0) printCostList(&lspMAP, TOS_NODE_ID);
				if(forwardTo == -1){
					dbg("Project2F", "rechecking \n");
					dijkstra();
					forwardTo = forwardPacketTo(&confirmedList,myMsg->dest);
					if(forwardTo == -1)
						dbg("Project2F", "Dropping for reals\n");
					else{
						makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, myMsg->protocol, myMsg->seq, (uint8_t *) myMsg->payload, sizeof(myMsg->payload));
						sendBufferPushBack(&packBuffer, sendPackage, sendPackage.src, forwardTo);
						post sendBufferTask();
					}
				}
				else{
					makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, myMsg->protocol, myMsg->seq, (uint8_t *) myMsg->payload, sizeof(myMsg->payload));
					sendBufferPushBack(&packBuffer, sendPackage, sendPackage.src, forwardTo);
					post sendBufferTask();
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


	//---- additional functions
	//---- Project 1 Implementations

	void neighborDiscoveryPacket(){
		pack discoveryPackage;
		uint8_t createMsg[PACKET_MAX_PAYLOAD_SIZE];
		uint16_t dest;
		memcpy(&createMsg, "", sizeof(PACKET_MAX_PAYLOAD_SIZE));
		memcpy(&dest, "", sizeof(uint8_t));
		dbg("Project2N", "Sending seq#: %d\n", neighborSequenceNum);
		makePack(&sendPackage, TOS_NODE_ID, discoveryPacket, MAX_TTL, PROTOCOL_PING, neighborSequenceNum++, (uint8_t *)createMsg,
				sizeof(createMsg));	
		dbg("Project1N", "Hi, is anyone there? :D \n");
		sendBufferPushBack(&packBuffer, sendPackage, sendPackage.src, discoveryPacket);
		post sendBufferTask();	
	}	

	//Checks for the node time out
	bool arrListRemove(arrlist *list, uint32_t iTimer){
		uint8_t i;
		uint8_t j;
		double timeOut;
		bool success = FALSE;
		for(i = 0; i <list->numValues; i++){
			timeOut = iTimer - list->values[i].timer;
			if(list->values[i].timer + 50000 < iTimer ){
				dbg("Project2test","Removing %d from friendList, last seen at time %d. Time removed: %d \n", list->values[i].src, list->values[i].timer, iTimer);	
				list->values[i] = list->values[list->numValues-1];
				list->numValues--;
				i--;
				success =  TRUE;
			}
		}
		return success;
	}
	
	void arrPrintList(arrlist* list){
		uint8_t i;
		for(i = 0; i<list->numValues; i++){
			dbg("Project2test","I think I am friends with %d and the last time we met was %d \n", list->values[i].src, list->values[i].timer);
		}	
	}
	//---- END OF PROJECT 1 IMPLEMENTATIONS

	//---- PROJECT 2 IMPLEMENTATIONS
	void printlspMap(lspMap *list){
		int i,j;
		for(i = 0; i < totalNodes; i++){
			for(j = 0; j < totalNodes; j++){
				if(list[i].cost[j] != 0 && list[i].cost[j] != -1)
					dbg("Project2L", "src: %d  neighbor: %d cost: %d \n", i, j, list[i].cost[j]);
			}	
		}
		dbg("Project2L", "END \n\n");
	}
	
	void printCostList(lspMap *list, uint8_t nodeID) {
		uint8_t i;
		for(i = 0; i < totalNodes; i++) {
			dbg("genDebug", "From %d To %d Costs %d", nodeID, i, list[nodeID].cost[i]);
		}
	}

	void lspNeighborDiscoveryPacket(){
		uint16_t dest;
		int i;
		uint8_t lspCostList[20] = {-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1};	
		lspMapinitialize(&lspMAP,TOS_NODE_ID);
		for(i = 0; i < friendList.numValues; i++){
			if(1/totalAverageEMA[friendList.values[i].src]*10 < 255){
				lspCostList[friendList.values[i].src] = 1/totalAverageEMA[friendList.values[i].src]*10;
				dbg("Project2test", "Cost to %d is %d %f %f\n", friendList.values[i].src, lspCostList[friendList.values[i].src], 1/totalAverageEMA[friendList.values[i].src]*10,totalAverageEMA[friendList.values[i].src]);
				//puts the neighbor into the MAP
				lspMAP[TOS_NODE_ID].cost[friendList.values[i].src] = 1/totalAverageEMA[friendList.values[i].src]*10;
				dbg("Project2L", "Priting neighbors: %d %d\n",friendList.values[i].src, lspCostList[friendList.values[i].src]);
			}
			else
				dbg("Project2test", "Cost is too big, %d is not my neighbor yet. \n", friendList.values[i].src);
		}
		memcpy(&dest, "", sizeof(uint8_t));	
		makePack(&sendPackage, TOS_NODE_ID, discoveryPacket, MAX_TTL, PROTOCOL_LINKSTATE, linkSequenceNum++, (uint8_t *)lspCostList, 20);	
		sendBufferPushBack(&packBuffer, sendPackage, sendPackage.src, discoveryPacket);	
		post sendBufferTask();
		dbg("Project2L", "Sending LSPs EVERYWHERE \n");	
		dbg("Project2L", "END \n\n");
	}	
		
	/**The pseudo code:
	 * 		M = {s}
	 * 		for each n in N - {s}
	 * 			C(n) = l(s,n)
	 * 		while(N != M)
	 * 			M = M union {w} such that C(w) is the minimum for all w in (N-M)
	 * 			for each n in (N-M)
	 * 				C(n) = MIN(C(n), C(w)+l(w,n))
	 * 
	 * 		• N: Set of all nodes
	 *		• M: Set of nodes for which we think we have a shortest path
	 * 		• M is our confirmed?
	 *		• s: The node executing the algorithm
	 *		• L(i,j): cost of edge (i,j) (inf if no edge connects)
	 *		• C(i): Cost of the path from s to i.
	 */
	 
	 void dijkstra(){
		int i;	
		lspTuple lspTup, temp;
		lspTableinit(&tentativeList); lspTableinit(&confirmedList);
		dbg("Project2D","start of dijkstra \n");
		lspTablePushBack(&tentativeList, temp = (lspTuple){TOS_NODE_ID,0,TOS_NODE_ID});
		dbg("Project2D","PushBack from tentativeList dest:%d cost:%d nextHop:%d \n", temp.dest, temp.nodeNcost, temp.nextHop);
		while(!lspTableIsEmpty(&tentativeList)){
			if(!lspTableContains(&confirmedList,lspTup = lspTupleRemoveMinCost(&tentativeList))) //gets the minCost node from the tentative and removes it, then checks if it's in the confirmed list.
				if(lspTablePushBack(&confirmedList,lspTup))
					dbg("Project2D","PushBack from confirmedList dest:%d cost:%d nextHop:%d \n", lspTup.dest,lspTup.nodeNcost, lspTup.nextHop);
			for(i = 1; i < totalNodes; i++){
				temp = (lspTuple){i,lspMAP[lspTup.dest].cost[i]+lspTup.nodeNcost,(lspTup.nextHop == TOS_NODE_ID)?i:lspTup.nextHop};
				if(!lspTableContainsDest(&confirmedList, i) && lspMAP[lspTup.dest].cost[i] != 255 && lspMAP[i].cost[lspTup.dest] != 255 && lspTupleReplace(&tentativeList,temp,temp.nodeNcost))
						dbg("Project2D","Replace from tentativeList dest:%d cost:%d nextHop:%d\n", temp.dest, temp.nodeNcost, temp.nextHop);
				else if(!lspTableContainsDest(&confirmedList, i) && lspMAP[lspTup.dest].cost[i] != 255 && lspMAP[i].cost[lspTup.dest] != 255 && lspTablePushBack(&tentativeList, temp))
						dbg("Project2D","PushBack from tentativeList dest:%d cost:%d nextHop:%d \n", temp.dest, temp.nodeNcost, temp.nextHop);
			}
		}
		dbg("Project2D", "Printing the routing table! \n");
		for(i = 0; i < confirmedList.numValues; i++)
			dbg("Project2D", "dest:%d cost:%d nextHop:%d \n",confirmedList.lspTuples[i].dest,confirmedList.lspTuples[i].nodeNcost,confirmedList.lspTuples[i].nextHop);
		dbg("Project2D", "End of dijkstra! \n");
	}

	int forwardPacketTo(lspTable* list, int dest){	
		return lspTableLookUp(list,dest);
	}
	
	void costCalculator(int lastSequence, int currentSequence){
	}
	/**
	 * let S_1 = Y_1
	 * Exponential Moving Average
	 * S_t = alpha*Y_t + (1-alpha)*S_(t-1)
	 */	
	float EMA(float prevEMA, float now,float weight){
		float alpha = 0.5*weight;
		float averageEMA = alpha*now + (1-alpha)*prevEMA;
		return averageEMA;
	}
	
}
