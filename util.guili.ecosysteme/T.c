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

#include "U.h"
#include "T.h"

/*- Table --------------------------------------------------------------------*/

#define T_ALLOC_MIN 4

T * T_creer()
{
	T * t = (T *)malloc(sizeof(T));
	t->n = 0;
	t->nAlloc = T_ALLOC_MIN;
	t->vals = (void **)malloc(t->nAlloc * sizeof(void *));
	t->liberer = NULL;
	return t;
}

void T_ajouter(T * t, void * val)
{
	/* Assez de mémoire pour entreposer? */
	
	if(t->n >= t->nAlloc)
	{
		int nouvelleAlloc = t->nAlloc; // On double.
		if(nouvelleAlloc < T_ALLOC_MIN) nouvelleAlloc = T_ALLOC_MIN;
		t->nAlloc += nouvelleAlloc;
		t->vals = (void **)realloc(t->vals, t->nAlloc * sizeof(void *));
		if(!t->vals) errmem(t->nAlloc * sizeof(void *));
	}
	
	/* Au boulot! */
	
	t->vals[t->n] = val;
	++t->n;
}
