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
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <poll.h>
#include <sys/types.h>
#include <sys/wait.h>

#include "U.h"
#include "E.h"

/*- Exécution ----------------------------------------------------------------*/

T * E_taches = NULL;

void E_fiston(E * e)
{
	if(dup2(e->stdout, 1) < 0) goto eDup;
	close(0);
	
	execvp(e->argv[0], e->argv);
	
	int err = errno;
	int i;
	fprintf(stderr, "# execvp(");
	for(i = -1; e->argv[++i];)
		fprintf(stderr, "%c%s", i ? ' ' : '(', e->argv[i]);
	fprintf(stderr, "): %s\n", strerror(err));
	
	eDup:
	exit(1);
}

E * E_lancer(char ** argv)
{
	int tube[2];
	E * e;
	
	if(g_trace >= 2)
	{
		int i;
		for(i = -1; argv[++i];)
			fprintf(stdout, "%s%c", argv[i], argv[i + 1] ? ' ' : '\n');
	}
	
	/* La tâche est susceptible d'être ajoutée à E_taches. */
	if(!E_taches)
		E_taches = T_creer();
	
	if(!(e = (E *)emalloc(sizeof(E)))) goto eE;
	e->argv = argv;
	e->traiter = NULL;
	
	if(pipe(&tube[0]) < 0) goto eTube;
	e->stdout = tube[0];
	
	switch(e->pid = fork())
	{
		case 0:
			close(tube[0]);
			e->stdout = tube[1];
			E_fiston(e);
		case -1:
			fprintf(stderr, "# fork(): %s\n", strerror(errno));
			goto eFourche;
	}
	
	e->etat = E_EN_COURS;
	
	close(tube[1]);
	
	return e;
	
	eFourche:
	close(tube[0]);
	close(tube[1]);
	eTube:
	free(e);
	eE:
	return NULL;
}

#define E_LECTURE_TAILLE 65536
char E_lecture[E_LECTURE_TAILLE];

int E_recevoir(void ** _es, int ne)
{
	E ** es = (E **)_es;
	
	struct pollfd * fs = (struct pollfd *)alloca(ne * sizeof(struct pollfd));
	int i, n;
	
	for(i = -1; ++i < ne;)
	{
		fs[i].fd = es[i]->stdout;
		fs[i].events = POLLIN|POLLERR|POLLHUP|POLLNVAL;
		fs[i].revents = 0;
	}
	if(poll(fs, ne, 1000) < 0)
		return errerrno("poll");
	for(i = -1; ++i < ne;)
		if(fs[i].revents)
		{
			n = 1;
			if(fs[i].revents & POLLIN)
			{
				if((n = read(fs[i].fd, E_lecture, E_LECTURE_TAILLE)) > 0)
				{
					if(es[i]->traiter)
						es[i]->traiter(E_lecture, n);
					write(1, E_lecture, n);
					continue;
				}
				/* == 0: fermé à l'autre bout; < 0: ça pète, mais on peut considérer que c'est du fermé à l'autre bout aussi. */
			}
			if(n <= 0 || fs[i].revents & (POLLERR|POLLHUP|POLLNVAL))
			{
				es[i]->etat = E_FINI;
			}
		}
	
	return 0;
}

int E_attendre(void ** _es, int ne)
{
	E ** es = (E **)_es;
	int retour;
	int idf;
	int i;
	
	while(1)
	{
		if((idf = wait(&retour)) < 0)
		{
			if(errno == ECHILD)
				break;
			else
				errerrno("wait");
		}
		else
		{
			for(i = -1; ++i < ne;)
				if(es[i]->pid == idf)
				{
					if(retour != 0)
						fprintf(stderr, "# %s: sorti en %d\n", es[i]->argv[0], retour);
					es[i]->etat = E_FINI;
				}
		}
	}
	
	return 0;
}

int E_attendreFinLances(T * t)
{
	int i;
	int encore = 1;
	while(encore)
	{
		encore = 0;
		E_recevoir(t->vals, t->n);
		for(i = -1; ++i < t->n;)
			if(((E *)t->vals[i])->etat != E_FINI)
				encore = 1;
	}
	return E_attendre(t->vals, t->n);
}
