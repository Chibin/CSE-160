#include "TCPSocketAL.h"
#include "transport.h"
interface NodeA{
	async command void test();
	/**
	 * sendPacket(uint8_t srcPort, uint16_t destAddr, uint8_t destPort, uint8_t flagType)
	 */
	async command void sendPacket(uint8_t srcPort, uint16_t destAddr, uint8_t destPort, uint8_t flagType);
	async command TCPSocketAL * getSocket();
	async command void sendDataPacket(uint8_t srcPort, uint16_t destAddr, uint8_t destPort, uint8_t flagType, uint8_t *payload, uint8_t len);
	async command void sendTransport(transport *tcpHeader, uint16_t destAddr);
}