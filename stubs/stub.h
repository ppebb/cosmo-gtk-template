#define LEN(X) sizeof(X) / sizeof(X[0])

void *try_find_lib(char **candidates, int len);
void *try_find_sym(void *lib_ptr, const char *name);
