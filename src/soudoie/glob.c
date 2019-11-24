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
#include <strings.h>
#include <string.h>
#include <stdio.h>

#include "glob.h"

#define IFS 0
#define GLOB_ETOILE 1
#define ETOILE GLOB_ETOILE

#define GLOB_ERR -1
#define GLOB_OUI 0
#define GLOB_NON 1

int glob_verifier(Glob * g, char ** commande);

CribleClasse ClasseGlob;

void GlobClasseInitialiser()
{
	ClasseGlob.fVerif = (FonctionVerif)glob_verifier;
	ClasseGlob.nSpeciaux = 2;
	ClasseGlob.offsetSpeciaux = ((char *)&((Glob *)NULL)->speciaux) - (char *)NULL;
	bzero(ClasseGlob.carSpeciaux, 256);
	ClasseGlob.carSpeciaux[' '] = 1 + IFS;
	ClasseGlob.carSpeciaux['\t'] = 1 + IFS;
	ClasseGlob.carSpeciaux['*'] = -1 - GLOB_ETOILE;
}

Glob * glob_init(Glob * c, char * source, char allouer)
{
	char cree = 0;
	
	if(!c)
	{
		c = (Glob *)malloc(sizeof(Glob));
		cree = 1;
	}
	c->c = &ClasseGlob;
	char ifs;
	if(!preparer((Crible *)c, source, 1))
	{
		if(cree) free(c);
		return NULL;
	}
	if(allouer)
	{
	c->crible = (char *)malloc(strlen(source) + 1);
	strcpy(c->crible, source);
	}
	else
		c->crible = source;
	return c;
}

int glob_comparerBout(char * chaine, char * glob)
{
	fprintf(stderr, "# Désolé, l'analyse des * en milieu d'expression n'est pas encore gérée (%s).\n", glob);
	return GLOB_ERR;
}

int glob_verifier(Glob * g, char ** commande)
{
	char dernier = 0;
	char * debut = g->crible;
	char * fin;
	char * etoile;
	char sep = g->speciaux[IFS];
	int r = GLOB_OUI;
	while(*commande && *debut)
	{
		fin = strchr(debut, sep); /* Nos commandes sont représentées sous la forme: <commande><ifs><argv[1]><ifs><argv[n]><\0> */
		if(!fin)
		{
			sep = 0;
			fin = &debut[strlen(debut)];
		}
		*fin = 0;
		if((etoile = strchr(debut, g->speciaux[ETOILE])))
		{
			if(etoile[1] == g->speciaux[ETOILE]) /* Double étoile. */
			{
				if(etoile[2] || etoile > debut)
				{
					fprintf(stderr, "# Les ** doivent constituer un argument à part entière (ici: \"%s\").\n", debut);
					r = GLOB_ERR;
				}
				if(sep) /* Quelque chose suit notre double étoile. */
				{
					fprintf(stderr, "# Désolé, les ** non finaux ne sont pas encore implémentés.\n");
					r = GLOB_ERR;
				}
				/* Après ces vérifications, nous savons que nous avons un "vrai" **, qui correspond à tout et n'importe quoi. */
				*fin = sep;
				return GLOB_OUI;
			}
			else /* Étoile simple. */
			{
				/* À FAIRE: implémenter (et appeler!) une purge des chemins: les . sont supprimés, et les .. s'annulent avec le membre précédent, pour qu'un gusse ayant le droit de faire du "vi /etc/nginx/nginx.conf.*" ne lance pas un "vi /etc/nginx/nginx.conf.d/../../hosts".
				if(*debut == '/')
				 */
				if(!etoile[1]) /* "truc*", il suffit de comparer le début de chaîne. */
				{
					if(strncmp(*commande, debut, etoile - debut) != 0)
						r = GLOB_NON;
				}
				else
					r = glob_comparerBout(*commande, debut);
			}
		}
		else
			/* Chaîne figée, facile, une simple comparaison. */
			if(strcmp(*commande, debut) != 0)
				r = GLOB_NON;
		*fin = sep;
		if(r != GLOB_OUI)
			return r;
		debut = sep ? fin + 1 : fin;
		++commande;
	}
	if(!*commande && !*debut) /* Les deux sont terminées en même temps: comparaison réussie! */
		return GLOB_OUI;
	else if(!*commande && debut[0] == g->speciaux[ETOILE] && debut[1] == g->speciaux[ETOILE] && !debut[2]) /* Commande parcourue entièrement, et dans le crible il ne restait plus qu'un ** final, qui peut tout à fait correspondre à rien. Donc c'est bon. */
		return GLOB_OUI;
	return GLOB_NON;
}
