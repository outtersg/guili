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

#include "E.h"
#include "Prerequis.h"

int PrerequisImplGuili_lancer(Prerequis * p)
{
	int nParams = 1;
	
	if(p->options && p->options[0])
		++nParams;
	
	if(p->version && p->version[0])
		++nParams;
	
	char ** params = (char **)malloc((nParams + 1) * sizeof(char *));
	params[nParams = 0] = (char *)malloc(2 + strlen(p->logiciel) + 1);
	strcpy(params[nParams], "./");
	strcat(params[nParams], p->logiciel);
	
	if(p->options && p->options[0])
		params[++nParams] = p->options;
	
	if(p->version && p->version[0])
		params[++nParams] = p->version;
	
	params[++nParams] = NULL;
	
	E * tache = E_lancer(params);
	
	T_ajouter(E_taches, tache);
	
	return tache ? 0 : -1;
}

int PrerequisImplGuili_prerequis(Prerequis * p)
{
	setenv("PREREQUIS_THEORIQUES", ".", 0);
	
	return PrerequisImplGuili_lancer(p);
}

PrerequisImpl Prerequis_impl =
{
	PrerequisImplGuili_prerequis,
	PrerequisImplGuili_lancer
};
