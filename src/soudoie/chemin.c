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
#include <limits.h>
#include <errno.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/stat.h>

#include "chemin.h"

static char * g_chemin = NULL;
static size_t g_cheminTaille = 0;

char * g_cheminPour(size_t taille);
char * g_cheminCourant();

const char * cheminComplet(const char * truc)
{
	int t;
	const char * ptr;
	
	if((ptr = strchr(truc, '/')))
	{
		if(ptr > truc) /* Chemin relatif, le / n'étant pas au début. */
		{
			if(!g_cheminCourant())
				return NULL;
			if(!g_cheminPour((t = strlen(g_chemin)) + 1))
				return NULL;
			g_chemin[t] = '/';
			++t;
		}
		else /* Chemin absolu, avec son / au départ. */
			t = 0;
		if(!g_cheminPour(t + strlen(truc)))
			return NULL;
		strcpy(&g_chemin[t], truc);
		semirealpath(g_chemin);
		return g_chemin;
	}
	
	const char * chemins = getenv("PATH");
	if(!chemins)
		return NULL;
	int tTruc = strlen(truc);
	struct stat infos;
	while(*chemins)
	{
		ptr = chemins;
		while(*ptr && *ptr != ':')
			++ptr;
		if((t = ptr - chemins) + 1 + tTruc <= PATH_MAX)
		{
			strncpy(g_chemin, chemins, t);
			g_chemin[t] = '/';
			strcpy(&g_chemin[t + 1], truc);
			if(stat(g_chemin, &infos) == 0 && S_ISREG(infos.st_mode) && (infos.st_mode & S_IXUSR))
				return g_chemin;
		}
		chemins = ptr + 1;
	}
	return NULL;
}

#define TASSE \
	{ \
		if(lf > ld) \
		{ \
			if(e < ld) \
				memmove(e, ld, lf - ld); \
			e += lf - ld; \
		} \
		ld = lf; \
	}

void semirealpath(char * chemin)
{
	char * ld, * lf, * e, *ptr;
	
	/* Calage sur le premier / */
	for(lf = chemin - 1; *++lf && *lf != '/';) {}
	
	e = ld = lf;
	while(*ld)
	{
		while(*++lf && *lf != '/') {}
		if(lf == ld + 1)
		{
			if(*lf == '/') /* Deux / d'affilée. */
				++ld;
			else /* / final */
				TASSE;
			continue;
		}
		else if(ld[1] == '.')
		{
			if(ld[2] == '.' && lf == ld + 3) /* /.. */
			{
				/* Peut-on manger le dernier dossier écrit? */
				for(ptr = e; --ptr >= chemin && *ptr != '/';) {}
				if(ptr < chemin || (ptr[1] == '.' && (e == ptr + 2 || (e == ptr + 3 && ptr[2] == '.')))) /* Rien à manger, ou seulement des ./ ou ../ initiaux qu'on ne pourra remonter. */
				{
					TASSE; /* On pousse tel quel notre /.. */
				}
				else
				{
					e = ptr;
					ld = lf;
				}
			}
			else if(lf == ld + 2) /* /. */
			{
				ld = lf;
				continue;
			}
		}
		TASSE;
	}
	*e = 0;
}

char * g_cheminPour(size_t taille)
{
	if(g_cheminTaille >= taille)
		return g_chemin;
	
	char * ptr;
	
	if(!(ptr = (char *)(g_chemin ? malloc(taille + 1) : realloc(g_chemin, taille + 1))))
	{
		fprintf(stderr, "# g_cheminPour(%ld): malloc(): %s\n", taille, strerror(errno));
		free(g_chemin);
		taille = 0;
	}
	
	g_cheminTaille = taille;
	return (g_chemin = ptr);
}

char * g_cheminCourant()
{
	char * ptr;
	
	while(1)
	{
		if(!(ptr = g_cheminPour(g_cheminTaille < PATH_MAX ? PATH_MAX : g_cheminTaille * 3 / 2)))
			return NULL;
		if((ptr = getcwd(ptr, g_cheminTaille)))
			return ptr;
		else if(errno != ERANGE)
		{
			fprintf(stderr, "# getcwd(): %s\n", strerror(errno));
			return NULL;
		}
	}
}
