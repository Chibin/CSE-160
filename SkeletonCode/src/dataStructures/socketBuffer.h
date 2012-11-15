#ifndef SOCKET_BUFFER_H
#define SOCKET_BUFFER_H
#include "transport.h"

#ifndef SOCKET_BUFFER_SIZE
#define SOCKET_BUFFER_SIZE 30
#endif
/**
 * byte, seq, type, len
 */
typedef struct socketData{
	uint8_t byte;
	uint16_t seq;
	uint8_t type;
	uint8_t len;
}socketData;

typedef struct socketArr{
	socketData values[SOCKET_BUFFER_SIZE];
	uint16_t numValues;
	uint8_t limit;
}socketArr;

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
}
#endif /* SOCKET_BUFFER_H */
