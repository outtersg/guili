#include <string.h>
#include <stdlib.h>
#include <unistd.h>

const char * oeufs[] =
{
	"PATH",
	"LD_LIBRARY_PATH",
	"PYTHONPATH",
	NULL
};

const char * durs[] =
{
	"$PATH",
	"$LD_LIBRARY_PATH",
	"$PYTHONPATH",
	NULL
};

const char precuisson[] =
{
	0,
	/* Précuisson pour le $LD_LIBRARY_PATH: celui provenant de l'environnement de l'appelant précède celui codé en dur dans notre binaire. */
	/* À FAIRE: en réalité il faudrait scinder: sur un chemin en durs ~/local/python+curl+ossl36+sqlite+xz-3.14.6/lib:~/local/lib64:~/local/lib, la première partie (Python lui-même) pourrait être en post-cuisson (Python puis seulement l'environnement de l'appelant), pour avoir l'ordre suivant résultant: ~/local/python+curl+ossl36+sqlite+xz-3.14.6/lib:$LD_LIBRARY_PATH:~/local/lib64:~/local/lib */
	1,
	1,
	-1
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
		if(val && precuisson[i])
		{
			strcat(nouvelle, val);
			strcat(nouvelle, ":");
		}
		strcat(nouvelle, durs[i]);
		if(val && !precuisson[i])
		{
			strcat(nouvelle, ":");
			strcat(nouvelle, val);
		}
		putenv(nouvelle);
	}
	return execv("$bin", argv);
}
