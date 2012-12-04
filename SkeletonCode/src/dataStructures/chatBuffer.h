#ifndef CHAT_BUFFER_H
#define CHAT_BUFFER_H

#include "socketBuffer.h"

#ifndef CHATBUFFER_SIZE
#define CHATBUFFER_SIZE 20
#endif

typedef struct chatBuffer{
	bufferz msg[CHATBUFFER_SIZE];
	uint8_t numValues;
}chatBuffer;

void chatBufferInit(chatBuffer* cur){
	uint8_t i;	
	cur->numValues = 0;
	for(i = 0; i < CHATBUFFER_SIZE; i++){
		bufferInit(&cur->msg[i],20);
	}
}

bool pushBackChatBuffer(chatBuffer* cur, uint8_t* newVal){
	if(cur->numValues <= CHATBUFFER_SIZE){
		toBufferCopy(&cur->msg[cur->numValues],newVal,0,128);
		++cur->numValues;
		return TRUE;
	}else return FALSE;
	return FALSE;
}

bufferz popFrontChatBuffer(chatBuffer* cur){
	bufferz returnVal;
	nx_uint8_t i;
	returnVal = cur->msg[0];
	for(i = 1; i < cur->numValues; ++i)
	{
		cur->msg[i-1] = cur->msg[i];
	}
	--cur->numValues;
	return returnVal;	
}


#endif /* CHAT_BUFFER_H */
