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
#include "clientAL.h"
#include "serverWorkerList.h"
#include <Timer.h>
#include "packet.h"

configuration NodeC{
}
implementation {
	components MainC;
	components Node;
	components RandomC as Random;
	
	components new TimerMilliC() as pingTimeoutTimer;
	components new TimerMilliC() as neighborDiscoveryTimer;
	components new TimerMilliC() as neighborUpdateTimer;
	components new TimerMilliC() as lspTimer;
	
	components ActiveMessageC;
	components new AMSenderC(6);
	components new AMReceiverC(6);
	
	// The main component
	components serverC as ALServer;
	components clientC as ALClient;
	components new TimerMilliC() as ServerTimer;
	components new TimerMilliC() as ServerWorkerTimer;
	
	components new TimerMilliC() as ClientTimer;
	components new TimerMilliC() as ClientWorkerTimer;
	
	components new TimerMilliC() as sendTimer;
	components new TimerMilliC() as waitCloseTimer;
	//components RandomC as Random;
	components TCPManagerC as TCPManager;
	components TCPSocketC as ALSocket;
	
	Node -> MainC.Boot;
	//Timers
	Node.pingTimeoutTimer->pingTimeoutTimer;
	
	Node.Random -> Random;
	Node.Packet -> AMSenderC;
	Node.AMPacket -> AMSenderC;
	Node.AMSend -> AMSenderC;
	Node.AMControl -> ActiveMessageC;
	Node.neighborDiscoveryTimer-> neighborDiscoveryTimer; // Add this line here.
	Node.neighborUpdateTimer-> neighborUpdateTimer;
	Node.lspTimer->lspTimer;
	Node.Receive -> AMReceiverC;
	Node.TCPManager -> TCPManager;
	Node.ALSocket -> ALSocket;
	
	Node.ALServer -> ALServer;
	Node.ALClient -> ALClient;
	
	//Wire everything used in the Server Module to the components declared above
	ALServer.ServerTimer -> ServerTimer;
	ALServer.WorkerTimer -> ServerWorkerTimer;
	ALServer.TCPSocket -> ALSocket;
	ALServer.Random -> Random;
	ALServer.TCPManager -> TCPManager;
	
	ALClient.TCPSocket -> ALSocket;
	ALClient.TCPManager -> TCPManager;
	ALClient.Random -> Random;
	ALClient.ClientTimer -> ClientTimer;
	ALSocket.node -> Node;
	TCPManager.node -> Node;
	TCPManager.TCPSocket -> ALSocket;
	ALSocket.TCPManager -> TCPManager;
	TCPManager.sendTimer -> sendTimer;
	TCPManager.waitCloseTimer -> waitCloseTimer;

}
