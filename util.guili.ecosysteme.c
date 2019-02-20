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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*- Utilitaires --------------------------------------------------------------*/

void errmem(unsigned long taille)
{
	fprintf(stderr, "# Impossible d'allouer %lu octets. Boum.\n", taille);
	exit(126);
}

/*- Table --------------------------------------------------------------------*/

#define T_ALLOC_MIN 4

/* Tableau à clés alphabétiques *non triées*: on y perd en temps de recherche, mais on gagne un mécanisme "premier entré, premier sorti". */
typedef struct
{
	int n;
	int nAlloc;
	char ** cles;
	void ** vals;
	void (*liberer)(void * val);
}
T;

T * T_creer()
{
	T * t = (T *)malloc(sizeof(T));
	t->n = 0;
	t->nAlloc = T_ALLOC_MIN;
	t->cles = (char **)malloc(t->nAlloc * sizeof(char *));
	t->vals = (void **)malloc(t->nAlloc * sizeof(void *));
	t->liberer = NULL;
	return t;
}

void * T_chercherN(T * t, char * cle, int tailleCle)
{
	int i;
	for(i = -1; ++i < t->n;)
		if(0 == strncmp(cle, t->cles[i], tailleCle) && t->cles[i][tailleCle] == 0)
			return t->vals[i];
	return NULL;
}

int T_pos(T * t, char * cle)
{
	int i;
	for(i = -1; ++i < t->n;)
		if(0 == strcmp(cle, t->cles[i]))
			return i;
	return -1;
}

void T_placer(T * t, char * cle, void * val)
{
	int pos;
	
	/* Remplacement? */
	
	if((pos = T_pos(t, cle)) >= 0)
	{
		if(t->liberer)
			(t->liberer)(t->vals[pos]);
		t->vals[pos] = val;
		return;
	}
	
	/* Assez de mémoire pour entreposer? */
	
	if(t->n >= t->nAlloc)
	{
		int nouvelleAlloc = t->nAlloc; // On double.
		if(nouvelleAlloc < T_ALLOC_MIN) nouvelleAlloc = T_ALLOC_MIN;
		t->nAlloc += nouvelleAlloc;
		t->cles = (char **)realloc(t->cles, t->nAlloc * sizeof(char *));
		t->vals = (void **)realloc(t->vals, t->nAlloc * sizeof(void *));
		if(!t->cles || !t->vals) errmem(t->nAlloc * sizeof(char *));
	}
	
	/* Au boulot! */
	
	t->cles[t->n] = cle;
	t->vals[t->n] = val;
	++t->n;
}

/*- Prérequis ----------------------------------------------------------------*/

typedef struct
{
	char * logiciel;
	char * options;
	char * version;
}
Prerequis;

Prerequis * Prerequis_creerN(char * ptrL, int tL, char * ptrO, int tO, char * ptrV, int tV)
{
	Prerequis * p = (Prerequis *)malloc(sizeof(Prerequis));
	p->logiciel = (char *)malloc(tL);
	strncpy(p->logiciel, ptrL, tL);
	p->logiciel[tL] = 0;
	p->options = (char *)malloc(tO);
	strncpy(p->options, ptrO, tO);
	p->options[tO] = 0;
	p->version = (char *)malloc(tV);
	strncpy(p->version, ptrV, tV);
	p->version[tV] = 0;
	return p;
}

void Prerequis_fusionnerN(Prerequis * p, char * ptrO, int tO, char * ptrV, int tV)
{
	if(tO)
	{
		if(!(p->options = (char *)realloc(p->options, sizeof(char) * (strlen(p->options) + tO + 1))))
			errmem(0);
		strncat(p->options, ptrO, tO);
	}
	if(tV)
	{
		int espace = p->version && *p->version ? 1 : 0;
		if(!(p->version = (char *)realloc(p->version, sizeof(char) * (strlen(p->version) + espace + tV + 1))))
			errmem(0);
		if(espace)
			strcat(p->version, " ");
		strncat(p->version, ptrV, tV);
	}
}

/*- Chaînes de prérequis -----------------------------------------------------*/

void pousserPrerequis(char * ptrL, int tL, char * ptrO, int tO, char * ptrV, int tV, T * resultatAgrege)
{
	Prerequis * p;
	
	/* Pas d'espace entre les options. */
	char * ptrO2 = NULL;
	int i, tO2;
	for(i = -1; ++i < tO;)
		if(ptrO[i] == ' ')
		{
			ptrO2 = alloca(tO);
			strncpy(ptrO2, ptrO, i);
			tO2 = i;
			while(++i < tO)
				if(ptrO[i] != ' ')
					ptrO2[tO2++] = ptrO[i];
			ptrO2[tO2] = 0;
			
			ptrO = ptrO2;
			tO = tO2;
			break;
		}
	
	if((p = (Prerequis *)T_chercherN(resultatAgrege, ptrL, tL)))
		Prerequis_fusionnerN(p, ptrO, tO, ptrV, tV);
	else
	{
		p = Prerequis_creerN(ptrL, tL, ptrO, tO, ptrV, tV);
		T_placer(resultatAgrege, p->logiciel, p);
	}
}

void decouperPrerequis(char * chaine, T * resultatAgrege)
{
	char * ptrL; int tL;
	char * ptrO; int tO;
	char * ptrV; int tV;
	while(*chaine == ' ') ++chaine;
	while(*chaine)
	{
		ptrL = chaine;
		while(*chaine && *chaine != '+' && *chaine != ' ' && *chaine != '<' && *chaine != '>' && *chaine != '=' && (*chaine < '0' || *chaine > '9')) ++chaine;
		tL = chaine - ptrL;
		while(*chaine == ' ') ++chaine;
		ptrO = chaine;
		tO = 0;
		while(*chaine == '+')
		{
			while(*chaine && *chaine != ' ' && *chaine != '<' && *chaine != '>' && *chaine != '=') ++chaine;
			tO = chaine - ptrO;
			while(*chaine == ' ') ++chaine;
		}
		ptrV = chaine;
		tV = 0;
		while(*chaine == '<' || *chaine == '>' || *chaine == '=' || (*chaine >= '0' && *chaine <= '9'))
		{
			while(*chaine && *chaine != ' ') ++chaine;
			tV = chaine - ptrV;
			while(*chaine == ' ') ++chaine;
		}
		pousserPrerequis(ptrL, tL, ptrO, tO, ptrV, tV, resultatAgrege);
		while(*chaine == ' ') ++chaine;
	}
}

void afficherPrerequis(T * t)
{
	int i;
	Prerequis * p;
	for(i = -1; ++i < t->n;)
	{
		p = (Prerequis *)t->vals[i];
		fprintf(stdout, "%s", p->logiciel);
		if(p->options && *p->options)
			fprintf(stdout, "%s", p->options);
		if(p->version && *p->version)
			fprintf(stdout, " %s", p->version);
		fprintf(stdout, "\n");
	}
}

/*- Travail ------------------------------------------------------------------*/

#define MODE_TOUT 0
#define MODE_DECOUPE 1

int main(int argc, char ** argv)
{
	T * prerequis = T_creer();
	int mode = MODE_TOUT;
	
	int i = 0;
	if(argc >= 2 && 0 == strcmp(argv[1], "-d"))
	{
		mode = MODE_DECOUPE;
		++i;
	}
	while(++i < argc)
		decouperPrerequis(argv[i], prerequis);
	switch(mode)
	{
		case MODE_DECOUPE:
	afficherPrerequis(prerequis);
			break;
	}
}
