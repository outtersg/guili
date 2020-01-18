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

#include "U.h"
#include "L.h"

/*- Liste --------------------------------------------------------------------*/

#define L_ALLOC_MIN 4

L * L_creer()
{
	L * t = (L *)malloc(sizeof(L));
	t->n = 0;
	t->nAlloc = L_ALLOC_MIN;
	t->cles = (char **)malloc(t->nAlloc * sizeof(char *));
	t->vals = (void **)malloc(t->nAlloc * sizeof(void *));
	t->liberer = NULL;
	return t;
}

void * L_chercherN(L * t, char * cle, int tailleCle)
{
	int i;
	for(i = -1; ++i < t->n;)
		if(0 == strncmp(cle, t->cles[i], tailleCle) && t->cles[i][tailleCle] == 0)
			return t->vals[i];
	return NULL;
}

int L_pos(L * t, char * cle)
{
	int i;
	for(i = -1; ++i < t->n;)
		if(0 == strcmp(cle, t->cles[i]))
			return i;
	return -1;
}

int L_posN(L * t, char * cle, int tailleCle)
{
	int i;
	for(i = -1; ++i < t->n;)
		if(0 == strncmp(cle, t->cles[i], tailleCle) && t->cles[i][tailleCle] == 0)
			return i;
	return -1;
}

void L_placer(L * t, char * cle, void * val)
{
	int pos;
	
	/* Remplacement? */
	
	if((pos = L_pos(t, cle)) >= 0)
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
		if(nouvelleAlloc < L_ALLOC_MIN) nouvelleAlloc = L_ALLOC_MIN;
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
