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

#include "me.h"
#include "glob.h"

#define IFS 0
#define GLOB_ETOILE 1
#define ETOILE GLOB_ETOILE

#define GLOB_ERR -1
#define GLOB_OUI 0
#define GLOB_NON 1

/* Que de l'alphabétique */
#define CODE_A 1
/* De l'alphabétique avec du glob (E comme Étoile) au milieu */
#define CODE_AEA 2
/* Début alphabétique terminé par une étoile */
#define CODE_AE 3
/* Une étoile */
#define CODE_E 4
/* Double étoile */
#define CODE_EE 5
/* Montage interdit */
#define CODE_ERR -1
char code(Glob * g, char * segment, char ** premiereEtoile);

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

/**
 * Compare une chaîne à un masque.
 * 
 * @param char * chaine  Chaîne à comparer.
 * @param char * glob    Masque crible.
 * @param char code      Indication du type de masque via une des constantes CODE_…. Les cribles CODE_E (*) ou CODE_AE (truc*) bénéficient d'un traitement rapide (strncmp() de tout ce qui se trouve avant l'* finale).
 * 
 * @return int           Une des constantes GLOB_….
 */
int glob_comparerBout(char * chaine, char * glob, char code)
{
	/* À FAIRE: implémenter (et appeler!) une purge des chemins: les . sont supprimés, et les .. s'annulent avec le membre précédent, pour qu'un gusse ayant le droit de faire du "vi /etc/nginx/nginx.conf.*" ne lance pas un "vi /etc/nginx/nginx.conf.d/../../hosts".
	if(*glob == '/')
	 */
	if(code == CODE_E || code == CODE_AE) /* "truc*", il suffit de comparer le début de chaîne. */
		return strncmp(chaine, glob, strlen(glob) - 1) == 0 ? GLOB_OUI : GLOB_NON;
	
	fprintf(stderr, "# Désolé, l'analyse des * en milieu d'expression n'est pas encore gérée (%s).\n", glob);
	return GLOB_ERR;
}

int glob_verifierParME(Glob * g, char * crible, char ** commande)
{
	int i, numSeg, nEtats;
	char * ptr;
	char ** segments;
	char * codesEtat;
	char * cardinalitesEtat;
	int r;
	
	/* Conversion en états. */
	
	for(nEtats = 1, ptr = crible - 1; *++ptr;)
		if(*ptr == g->speciaux[IFS])
			++nEtats;
	segments = (char **)alloca(nEtats * sizeof(char *));
	codesEtat = (char *)alloca(nEtats * sizeof(char));
	cardinalitesEtat = (char *)alloca((nEtats + 1) * sizeof(char));
	segments[0] = crible;
	for(i = 0, ptr = crible;; ++ptr)
		if((r = *ptr) == g->speciaux[IFS] || !r)
		{
			if(r)
				*ptr = 0;
			switch(codesEtat[i] = code(g, segments[i], NULL))
			{
				case CODE_ERR: return GLOB_ERR; break;
				case CODE_EE: cardinalitesEtat[i] = ME_ETOILE; break;
				default: cardinalitesEtat[i] = ME_NORMAL; break;
			}
			if(!r)
				break;
			segments[++i] = ptr + 1;
		}
	cardinalitesEtat[++i] = ME_FIN;
	
	/* Préparation de la machine à états. */
	
	ME me;
	me.masque = cardinalitesEtat;
	me.marqueurs = (int *)alloca((strlen(me.masque) + 1) * sizeof(me.marqueurs[0]));
	me.dames = 0;
	me_commencer(&me);
	
	/* On déroule! */
	
	for(--commande; *++commande;)
	{
		FOR_ME(&me, numSeg)
		{
			if
			(
				!(r = numSeg >= nEtats) /* Si ce n'est pas un marqueur en position de fin (parce que si ça l'est, poubelle direct, puisqu'il n'était pas censé arriver là avant qu'on ait fini de manger commande). */
				&& !(r = me.marqueurs[numSeg + 1]) /* Et si on n'a pas déjà un marqueur à la position convoitée. */
			)
				switch(codesEtat[numSeg])
				{
					case CODE_EE:
					case CODE_E:
						r = 1;
						break;
					case CODE_AE:
					case CODE_AEA:
						r = glob_comparerBout(*commande, segments[numSeg], codesEtat[numSeg]) == GLOB_OUI;
						break;
					case CODE_A:
						r = strcmp(*commande, segments[numSeg]) == 0;
						break;
				}
			if(r)
				me_passer(&me, numSeg);
			else
				me_demarquer(&me, numSeg);
		}
	}
	
	/* Restauration */
	/* A priori le crible est à usage unique, mais bon, sait-on jamais. On remet les fins de segment qu'on avait remplacés par des fins de chaîne. */
	
	for(i = 0, ptr = crible - 1; ++i < nEtats;)
	{
		while(*++ptr) {}
		*ptr = g->speciaux[IFS];
	}
	
	/* Retour. */
	
	return !*commande && me.marqueurs[nEtats] ? GLOB_OUI : GLOB_NON;
}

int glob_verifier(Glob * g, char ** commande)
{
	char dernier = 0;
	char * debut = g->crible;
	char * fin;
	char * etoile;
	char sep = g->speciaux[IFS];
	int r = GLOB_OUI, rtemp;
	while(*commande && *debut)
	{
		fin = strchr(debut, sep); /* Nos commandes sont représentées sous la forme: <commande><ifs><argv[1]><ifs><argv[n]><\0> */
		if(!fin)
		{
			sep = 0;
			fin = &debut[strlen(debut)];
		}
		*fin = 0;
		switch(code(g, debut, &etoile))
		{
			case CODE_ERR: r = GLOB_ERR; break;
			case CODE_EE:
				*fin = sep;
				/* A-t-on quelque chose derrière notre ** (auquel cas il faut vérifier) ou était-ce le dernier membre (qui valide tout ce qui va derrière)? */
				return sep ? glob_verifierParME(g, debut, commande) : GLOB_OUI;
			case CODE_E:
			case CODE_AE:
			case CODE_AEA:
				if((rtemp = glob_comparerBout(*commande, debut, etoile[1] ? CODE_AEA : CODE_AE)) != GLOB_OUI)
					r = rtemp;
				break;
			case CODE_A: /* Chaîne figée, facile, une simple comparaison. */
			if(strcmp(*commande, debut) != 0)
				r = GLOB_NON;
				break;
		}
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

char code(Glob * g, char * segment, char ** premiereEtoile)
{
	char * etoile;
	char r;
	
	if((etoile = strchr(segment, g->speciaux[ETOILE])))
	{
		if(etoile[1] == g->speciaux[ETOILE]) /* Double étoile. */
		{
			if(etoile > segment || (etoile[2] && etoile[2] != g->speciaux[IFS]))
			{
				fprintf(stderr, "# Les ** doivent constituer un argument à part entière (ici: \"%s\").\n", segment);
				return CODE_ERR;
			}
			r = CODE_EE;
		}
		else /* Étoile simple. */
			r = etoile[1] ? CODE_AEA : (etoile == segment ? CODE_E : CODE_AE);
	}
	else
		r = CODE_A;
	if(premiereEtoile)
		*premiereEtoile = etoile;
	return r;
}
