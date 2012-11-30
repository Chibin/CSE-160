#ifndef CONNECTION_BUFFER_H
#define CONNECTION_BUFFER_H

#include "transport.h"


#ifndef MAX_CONNECTION
#define MAX_CONNECTION 10
#endif

typedef struct connectionBuffer{
	pack connection[MAX_CONNECTION];
	uint8_t limit;
	uint8_t numValues;
}connectionBuffer;

bool connectionBufferPushBack(connectionBuffer* cur, pack newVal){
	if(cur->numValues <= cur->limit-1){
		cur->connection[cur->numValues] = newVal;
		++cur->numValues;
		return TRUE;
	}else return FALSE;
}

bool pendingConnectionCheck(connectionBuffer* cur, pack newVal){
 uint8_t i;
 transport temp2, temp1;
  memcpy(&temp1,(transport*)&newVal.payload,sizeof(transport));
	for(i = 0; i < cur->numValues; i++){
		memcpy(&temp2,(transport*)&cur->connection[i],sizeof(transport));
		dbg("Project3Manager","packInfo: srcPort:%d %d src:%d %d\n",temp2.srcPort, temp1.srcPort, cur->connection[i].src, newVal.src);
		if(cur->connection[i].src == newVal.src && temp1.srcPort == temp2.srcPort);
			return TRUE;
	}
	return FALSE;
}

int connectionBufferSize(connectionBuffer* cur){
	return cur->numValues;
}

void connectionBufferInit(connectionBuffer* cur, uint8_t limiter){;
	cur->numValues = 0;
	cur->limit = limiter;
}

pack getconnectionBuff(connectionBuffer* cur, int i){
	return cur->connection[i];
}

pack connectionBufferPopFront(connectionBuffer* cur){
	pack returnVal;
	nx_uint8_t i;
	returnVal = cur->connection[0];
	for(i = 0; i < cur->numValues; ++i)
		cur->connection[i-1] = cur->connection[i];
	--cur->numValues;
	return returnVal;
}



#endif /* CONNECTION_BUFFER_H */
