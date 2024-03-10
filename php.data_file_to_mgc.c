#include <fcntl.h>
#include <unistd.h>

#include "data_file.c"

int main(int argc, char ** argv)
{
	int out = open("magic.mgc", O_WRONLY|O_CREAT|O_TRUNC, 0644);
	write(out, php_magic_database, sizeof(php_magic_database));
	close(out);
	return 0;
}
