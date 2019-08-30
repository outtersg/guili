/*
 * Copyright (c) 2019 Guillaume Outters
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include <string.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
//#include <limits.h>
//#include <stdlib.h>
//#include <sys/stat.h>
////#include <stdarg.h>
#include <errno.h>
//#include <pwd.h>
//#include <grp.h>

#include "crible.h"
#include "glob.h"
#include "lecture.h"
#include "auto.h"

char g_aff[0x4000];
char * affSpeciaux(Crible * crible, const char * source)
{
	char * ptr;
	for(--source, ptr = g_aff; *++source;)
		if(*source >= ' ')
			*ptr++ = *source;
		else
		{
			strcpy(ptr, "[33m");
			while(*++ptr) {}
			if(*source == CribleSpeciaux(crible)[0])
			{
				strcpy(ptr, " | ");
				while(*++ptr) {}
			}
			else
			{
				*ptr++ = '\\';
				int i;
				char c;
				for(i = 3, c = *source; --i >= 0; c /= 8)
					ptr[i] = '0' + c % 8;
				*(ptr += 3) = 0;
			}
			strcpy(ptr, "[0m");
			while(*++ptr) {}
		}
	*ptr = 0;
	return g_aff;
}

#ifdef TEST

int testerPreparer(const char * source, const char * attendu)
{
	Glob g;
	char preparation[0x4000];
	char spe[2];
	strcpy(preparation, source);
	if(!glob_init(&g, preparation, 0))
	{
		fprintf(stderr, "# Impossible de préparer \"%s\".", source);
		return -1;
	}
	if(strcmp(g.crible, attendu) != 0)
	{
		fprintf(stderr, "# Résultat inattendu pour la préparation de \"%s\":\n", source);
		fprintf(stderr, "\t%s\t(attendu)\n", affSpeciaux((Crible *)&g, attendu));
		fprintf(stderr, "\t%s\t(obtenu)\n", affSpeciaux((Crible *)&g, g.crible));
		return -1;
	}
	return 0;
}

int testerLire(char * source, char * attendu)
{
	Glob g;
	char rien[] = "";
	if(!glob_init(&g, rien, 0))
	{
		fprintf(stderr, "# Impossible de préparer \"%s\".", source);
		return -1;
	}
	
	char * l;
	char contenu[0x1000];
	contenu[0] = 0;
	
	int config;
	if((config = open(CHEMIN_CONFIG, O_WRONLY|O_CREAT, 0700)) < 0) { fprintf(stderr, "# Impossible d'ouvrir %s en écriture: %s\n", CHEMIN_CONFIG, strerror(errno)); return -1; }
	if(write(config, source, strlen(source)) < strlen(source)) { fprintf(stderr, "# Impossible d'écrire %s: %s\n", CHEMIN_CONFIG, strerror(errno)); return -1; }
	close(config);
	
	if((config = open(CHEMIN_CONFIG, O_RDONLY)) < 0) { fprintf(stderr, "# Impossible d'ouvrir %s en lecture: %s\n", CHEMIN_CONFIG, strerror(errno)); return -1; }
	while((l = lireLigne(config)))
	{
		strcat(contenu, l);
		strcat(contenu, "\001");
	}
	close(config);
	
	if(strcmp(contenu, attendu) != 0)
	{
		fprintf(stderr, "[31m# Résultat inattendu[0m pour la lecture de \"%s\":\n", affSpeciaux((Crible *)&g, source));
		fprintf(stderr, "\t%s\t(attendu)\n", affSpeciaux((Crible *)&g, attendu));
		fprintf(stderr, "\t%s\t(obtenu)\n", affSpeciaux((Crible *)&g, contenu));
		return -1;
	}
	
	return 0;
}

void initialiserUtilises(char * argv[]);

int main(int argc, char * argv[])
{
	initialiserUtilises(argv);
	initialiserLire();
	GlobClasseInitialiser();
	
	int r = 0;
	
	#ifdef TEST_PREPARER_0
	if(testerPreparer("/bin/truc premier coucou\\ ah  b  c  d\\ \\ e", "/bin/truc\003premier\003coucou ah\003b\003c\003d  e") < 0) r = -1;
	if(testerPreparer("/bin/truc pre\004ier coucou\\ ah  \003  c  d\\ \\ e", "/bin/truc\005pre\004ier\005coucou ah\005\003\005c\005d  e") < 0) r = -1;
	#endif
	
	#ifdef TEST_LIRE_0
	/* TEST_LIRE_0=1, TEST_LIRE_0=2, TEST_LIRE_0=64 */
	if(testerLire("  ligne:\n  suite\n suite\n   fin\nautre: ligne\nnouvelle:\n ligne bloc", "ligne:\nsuite\nsuite\nfin\001autre: ligne\001nouvelle:\nligne bloc\001") < 0) r = -1;
	#endif
	
	return r;
}

#endif