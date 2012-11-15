interface TCPManager<val_t, val2_t>{
	command void init();
	command void socketInit();
	command val_t *socket();
	command val_t * findFreeSocket();
	command void freeSocket(val_t *);
	command void handlePacket(void *);
	/**
	 * Finds the socket with the same destination port number
	 */
	command val_t *getSocketfd(uint8_t);
	command val_t * getSocket(uint8_t portNum, uint8_t dest);
}
