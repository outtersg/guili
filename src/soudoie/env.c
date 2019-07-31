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

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <strings.h>

#include "env.h"

#define T_BLOC_ENVIRON 0x10
#define T_BLOC_SILO 0x400

typedef struct
{
	char ** environ;
	int tlEnviron;
	int tpEnviron;
	
	char * silo;
	int tlSilo;
	int tpSilo;
}
Env;

Env g_env;

static void ajouter(Env * e, const char * var, const char * val);

void initialiserEnv()
{
	bzero(&g_env, sizeof(g_env));
	ajouter(&g_env, "", "");
	g_env.environ[0] = NULL;
	g_env.tlSilo = 0;
}

static void ajouter(Env * e, const char * var, const char * val)
{
	int tVar = strlen(var);
	char * p;
	if((p = strchr(var, '='))) /* Variables passées directement sous la forme var=val, plutôt qu'en deux paramètres. */
	{
		tVar = p - var;
		if(!val)
			val = p + 1;
	}
	int tAllocSilo = tVar + 1 + strlen(val) + 1;
	char ** pVarEnv;
	
	/* Préparation de la place "contenu". */
	
	if(e->tlSilo + tAllocSilo > e->tpSilo)
	{
		e->tpSilo += T_BLOC_SILO * ((e->tlSilo + tAllocSilo - e->tpSilo + T_BLOC_SILO - 1) / T_BLOC_SILO);
		char * nouveauSilo = e->silo ? realloc(e->silo, e->tpSilo) : malloc(e->tpSilo);
		if(!nouveauSilo)
		{
			fprintf(stderr, "# Impossible d'allouer suffisamment d'espace pour l'environnement.\n");
			exit(-1);
		}
		/* Puisque l'entrepôt change de place, tous les pointeurs doivent suivre. */
		if(e->environ)
			for(pVarEnv = e->environ; *pVarEnv; ++pVarEnv)
				*pVarEnv = nouveauSilo + (*pVarEnv - e->silo);
		e->silo = nouveauSilo;
	}
	
	/* Recherche de l'éventuelle valeur à remplacer, à défaut préparation de la place "pointeur". */
	
	for(pVarEnv = e->environ; pVarEnv && *pVarEnv; ++pVarEnv)
		if(0 == strncmp(*pVarEnv, var, tVar) && (*pVarEnv)[tVar] == '=')
		{
			/* On va écraser l'entrée sans désallouer son contenu. Tant pis, il est plus simple de faire ainsi. */
			/* À FAIRE?: optimiser l'utilisation mémoire en memmovant le silo, et recalant les e->environ correspondants. */
			break;
		}
	if(!pVarEnv || !*pVarEnv)
	{
		if(e->tlEnviron == e->tpEnviron)
		{
			e->tpEnviron += T_BLOC_ENVIRON;
			char ** nouvelEnviron = e->environ ? realloc(e->environ, e->tpEnviron * sizeof(char **)) : malloc(e->tpEnviron * sizeof(char **));
			if(!nouvelEnviron)
			{
				fprintf(stderr, "# Impossible d'allouer suffisamment d'espace pour l'environnement.\n");
				exit(-1);
			}
			e->environ = nouvelEnviron;
			pVarEnv = &e->environ[e->tlEnviron];
		}
		pVarEnv[1] = NULL;
		++e->tlEnviron;
	}
	
	/* Au boulot! */
	
	*pVarEnv = &e->silo[e->tlSilo];
	strcpy(*pVarEnv, var);
	(*pVarEnv)[tVar] = '=';
	strcpy(&(*pVarEnv)[tVar + 1], val);
	e->tlSilo += tAllocSilo;
}

static void ajouterEnv(Env * e, char * nom)
{
	char * ptr;
	if((ptr = getenv(nom)))
		ajouter(e, nom, ptr);
}

char ** environner(const char * chemin, char ** argv, AutoContexte * appel)
{
	Env * e = &g_env;
	char * ptr;
	
	/* On récupère certaines variables de l'environnement. */
	
	ajouterEnv(e, "LANG");
	ajouterEnv(e, "LC_ALL");
	ajouterEnv(e, "LC_COLLATE");
	ajouterEnv(e, "LC_CTYPE");
	ajouterEnv(e, "LC_MESSAGES");
	ajouterEnv(e, "LC_MONETARY");
	ajouterEnv(e, "LC_NUMERIC");
	ajouterEnv(e, "LC_TIME");
	ajouterEnv(e, "DISPLAY");
	ajouterEnv(e, "TERM");
	ajouterEnv(e, "PATH");
	ajouterEnv(e, "LD_LIBRARY_PATH");
	
	/* On prend en compte (en écrasant éventuellement) les variables passées en paramètre. */
	
	/* Les paramètres à prendre en compte sont ceux entre le début des argv et appel->argv (début de la commande). */
	for(; *argv && argv < appel->argv; ++argv)
	{
		for(ptr = *argv; *ptr && *ptr != '='; ++ptr)
			if(!((*ptr >= 'A' && *ptr <= 'Z') || (*ptr >= 'a' && *ptr <= 'z') || (*ptr >= '0' && *ptr <= '9') || (*ptr == '_')))
				break;
		if(*ptr == '=')
			ajouter(e, *argv, NULL);
	}
	
	/* On écrase le tout par les variables "sensibles". */
	
	/*ajouter(e, "MAIL=/var/mail/root");*/
	ajouter(e, "LOGNAME", appel->execute.pw_name);
	ajouter(e, "USER", appel->execute.pw_name);
	ajouter(e, "USERNAME", appel->execute.pw_name);
	ajouter(e, "HOME", appel->execute.pw_dir);
	ajouter(e, "SHELL", appel->execute.pw_shell);
	ajouter(e, "SUDO_COMMAND", chemin);
	/*
	ajouter(e, "SUDO_USER=toto", NULL);
	ajouter(e, "SUDO_UID=999999999", NULL);
	ajouter(e, "SUDO_GID=999999999", NULL);
	 */
	
	/* À FAIRE: pouvoir préciser dans la conf quelles variables sont imposées ou doivent respecter un schéma. */
	
	return e->environ;
}
