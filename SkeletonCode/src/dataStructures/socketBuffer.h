#ifndef SOCKET_BUFFER_H
#define SOCKET_BUFFER_H
#include "transport.h"

#ifndef SOCKET_BUFFER_SIZE
#define SOCKET_BUFFER_SIZE 30
#endif

#ifndef MAX_BUFFER_SIZE
#define MAX_BUFFER_SIZE 100
#endif
/**
 * byte, seq, type, len
 */
typedef struct socketData{
	//uint8_t byte;//[TRANSPORT_MAX_PAYLOAD_SIZE];
	uint8_t byte;
	uint16_t seq;
	uint8_t type;
	uint8_t len;
	//uint8_t byte;//[TRANSPORT_MAX_PAYLOAD_SIZE];
}socketData;

typedef struct transportData{
	
}transportData;

typedef struct socketArr{
	socketData values[SOCKET_BUFFER_SIZE];
	uint16_t numValues;
	uint8_t limit;
}socketArr;

typedef struct bufferz{
	uint8_t byte[MAX_BUFFER_SIZE];
	uint16_t numValues;
	uint8_t limit;
}bufferz;

void bufferInit(bufferz* cur, uint8_t limiter){
	cur->numValues = 0;
	cur->limit = limiter;
}

bool bufferPushBack(bufferz* cur, uint8_t newVal){
	if(cur->numValues <= cur->limit-1){
		cur->byte[cur->numValues] = newVal;
		++cur->numValues;
		return TRUE;
	}else return FALSE;
}

uint8_t bufferPopFront(bufferz* cur){
	uint8_t returnVal;
	nx_uint8_t i;
	returnVal = cur->byte[0];
	for(i = 1; i < cur->numValues; ++i)
		cur->byte[i-1] = cur->byte[i];
	--cur->numValues;
	return returnVal;
}

int bufferSize(bufferz* cur){
	return cur->numValues;
}

void socketArrInit(socketArr* cur){
	int i;
	cur->numValues = 0;
	cur->limit = SOCKET_BUFFER_SIZE;
	for(i = 0; i < SOCKET_BUFFER_SIZE; i++)
		cur->values[i].type = 100;
}

void socketArrSetLimit(socketArr* cur, uint8_t limiter){
	cur->limit = (limiter > SOCKET_BUFFER_SIZE)?SOCKET_BUFFER_SIZE:limiter;
}

uint8_t socketArrSize(socketArr* cur){
	return cur->numValues;
}

bool isSocketArrEmpty(socketArr* cur){
	if(cur->numValues == 0)
		return TRUE;
	return FALSE;
}
bool isSocketArrFull(socketArr* cur){
	if(cur->numValues == cur->limit-1)
		return TRUE;
	return FALSE;	
}
bool sockPushBack(socketArr* cur, socketData newVal){
	if(cur->numValues <= cur->limit-1){
		cur->values[cur->numValues] = newVal;
		++cur->numValues;
		return TRUE;
	}else return FALSE;
}

socketData getSockData(socketArr* cur, int index){
	return cur->values[index];
}

socketData sockPopFront(socketArr* cur){
	socketData returnVal;
	nx_uint8_t i;
	returnVal = cur->values[0];
	for(i = 0; i < cur->numValues; ++i)
	{
		cur->values[i-1] = cur->values[i];
	}
	--cur->numValues;
	return returnVal;
}

bool socketArrContains(socketArr* cur, int seq, int type){
	uint8_t i;
	for(i = 0; i<=cur->numValues; i++){
		if(cur->values[i].seq == seq && cur->values[i].type == type)
				return TRUE;
	}
	return FALSE;
}

socketData socketArrRemove(socketArr* cur, int seq, int type){
	uint8_t i;
	socketData temp;
	for(i = 0; i<=cur->numValues; i++){
		if(cur->values[i].seq == seq && cur->values[i].type == type){
			if(cur->numValues > 1){
				temp = cur->values[i];
				cur->values[i] = cur->values[cur->numValues-1];		
				cur->numValues--;
				i--;
				return temp;
			}
			else{
				cur->numValues = 0;
				return cur->values[0];
			}
		}
	}
	return temp;
}

//---BUFFER
void bufferCopy(bufferz* cur, uint8_t* to, uint8_t pos, uint8_t len){
	int i;
	memcpy(to,&cur->byte[pos],len);
}

void toBufferCopy(bufferz* cur, uint8_t* to, uint8_t pos, uint8_t len){
	int i;
	memcpy(&cur->byte[pos],to,len);
	dbg("Project4Client","BUFFERCOPY CHECK: %s", cur->byte);

}
//---------------------------------
typedef struct retransBuffer{
	uint16_t lastTimeSent;
	uint8_t numValues;
	uint8_t limit;
	transport values[SOCKET_BUFFER_SIZE];
}retransBuffer;

void retransBufferInit(retransBuffer* cur){
	cur-> numValues = 0;
	cur->limit = SOCKET_BUFFER_SIZE;
}

transport retransBufferPopFront(retransBuffer* cur){
	transport returnVal;
	nx_uint8_t i;
	returnVal = cur->values[0];
	for(i = 1; i < cur->numValues; ++i)
	{
		cur->values[i-1] = cur->values[i];
	}
	--cur->numValues;
	return returnVal;
}

bool retransBufferPushBack(retransBuffer* cur, transport newVal){
	if(cur->numValues <= cur->limit-1){
		cur->values[cur->numValues] = newVal;
		++cur->numValues;
		return TRUE;
	}else return FALSE;
}

bool retransBufferContains(retransBuffer* cur, int seq, int type){
	uint8_t i;
	for(i = 0; i<=cur->numValues; i++){
		if(cur->values[i].seq == seq && cur->values[i].type == type)
				return TRUE;
	}
	return FALSE;
}

bool retransBufferContainsInRange(retransBuffer* cur, int seq, int type){
	uint8_t i;
	for(i = 0; i <=cur->numValues; i++){
		if((cur->values[i].seq-cur->values[i].len <= seq && seq  <= cur->values[i].seq) && cur->values[i].type == type)
			return TRUE;	
	}
	return FALSE;
}

bool retransBufferContainsSeqNum(retransBuffer* cur, int seq, int type){
	uint8_t i;
	for(i = 0; i <=cur->numValues; i++){
		//dbg("Project3Socket", "values are! seq:%d len:%d payload:%d \n",cur->values[i].seq,cur->values[i].len);
		if((cur->values[i].seq-cur->values[i].len == seq && cur->values[i].type == type))
			return TRUE;	
	}
	return FALSE;
}

int retransBufferSize(retransBuffer* cur){
	return cur->numValues;	
}
transport getTransport(retransBuffer* cur, int i){
	return cur->values[i];
}

transport retransBufferSeqNumRemove(retransBuffer* cur, int seq, int type){
	uint8_t i;
	transport temp;
	for(i = 0; i<=cur->numValues; i++){
		if(cur->values[i].seq-cur->values[i].len == seq && cur->values[i].type == type){
			if(cur->numValues > 1){
				temp = cur->values[i];
				cur->values[i] = cur->values[cur->numValues-1];		
				cur->numValues--;
				i--;
				return temp;
			}
			else{
				cur->numValues = 0;
				return cur->values[0];
			}
		}
	}
}

transport retransBufferRemove(retransBuffer* cur, int seq, int type){
	uint8_t i;
	transport temp;
	for(i = 0; i<=cur->numValues; i++){
		if(cur->values[i].seq == seq && cur->values[i].type == type){
			if(cur->numValues > 1){
				temp = cur->values[i];
				cur->values[i] = cur->values[cur->numValues-1];		
				cur->numValues--;
				i--;
				return temp;
			}
			else{
				cur->numValues = 0;
				return cur->values[0];
			}
		}
	}
	return temp;
}

bool retransBufferLBA(retransBuffer *curr, int16_t seq, uint16_t * lastByteAcked) {
	uint8_t counterrr;
	transport temp;
	while(*lastByteAcked < seq-1) {
		if(curr->numValues != 0){
			temp = retransBufferPopFront(curr);
			*lastByteAcked = temp.seq;
			dbg("genDebug", "removed seq%d\n", temp.seq);
		}else
			break;
	}
	return TRUE;
}

#endif /* SOCKET_BUFFER_H */