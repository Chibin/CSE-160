interface client<val_t>{
	command void init(val_t *);
	command void msg(void* myMsg);
}
