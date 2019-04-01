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

#include "U.h"
#include "Prerequis.h"

Prerequis * Prerequis_creerN(char * ptrL, int tL, char * ptrO, int tO, char * ptrV, int tV)
{
	Prerequis * p = (Prerequis *)malloc(sizeof(Prerequis));
	p->logiciel = (char *)malloc(tL + 1);
	strncpy(p->logiciel, ptrL, tL);
	p->logiciel[tL] = 0;
	p->options = (char *)malloc(tO + 1);
	strncpy(p->options, ptrO, tO);
	p->options[tO] = 0;
	p->version = (char *)malloc(tV + 1);
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

void Prerequis_afficher(Prerequis * p)
{
	fprintf(stdout, "%s", p->logiciel);
	if(p->options && *p->options)
		fprintf(stdout, "%s", p->options);
	if(p->version && *p->version)
		fprintf(stdout, " %s", p->version);
	fprintf(stdout, "\n");
}

