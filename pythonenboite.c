#include <string.h>
#include <stdlib.h>
#include <unistd.h>

const char * oeufs[] =
{
	"PATH",
	"LD_LIBRARY_PATH",
	NULL
};

const char * durs[] =
{
	"$PATH",
	"$LD_LIBRARY_PATH",
	NULL
};

int main(int argc, char ** argv)
{
	int i;
	char * val;
	char * nouvelle;
	for(i = -1; oeufs[++i];)
	{
		val = getenv(oeufs[i]);
		nouvelle = (char *)malloc((strlen(oeufs[i]) + 1 + strlen(durs[i]) + (val ? 1 + strlen(val) : 0) + 1) * sizeof(char));
		strcpy(nouvelle, oeufs[i]);
		strcat(nouvelle, "=");
		strcat(nouvelle, durs[i]);
		if(val)
		{
			strcat(nouvelle, ":");
			strcat(nouvelle, val);
		}
		putenv(nouvelle);
	}
	return execv("$bin", argv);
}
