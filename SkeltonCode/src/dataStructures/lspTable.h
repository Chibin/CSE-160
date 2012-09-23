#ifndef LSP_TABLE_H
#define LSP_TABLE_H


typedef struct lspTable{

	uint8_t dest;
	uint8_t nodeNcost;	
	uint8_t nextHop;

}lspTable;

//Creates a Map of all the Nodes
typedef struct lspMap{
	
	//nx_int16_t neighbor[20];
	uint8_t cost[20];

}lspMap;


#endif /* LSP_TABLE_H */