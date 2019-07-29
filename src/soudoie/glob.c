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

#include "glob.h"

#define IFS 0
#define GLOB_ETOILE 1

int glob_verifier(Glob * g, char ** commande);

CribleClasse ClasseGlob;

void GlobClasseInitialiser()
{
	ClasseGlob.fVerif = (FonctionVerif)glob_verifier;
	ClasseGlob.nSpeciaux = 2;
	ClasseGlob.offsetSpeciaux = (int)&((Glob *)NULL)->speciaux;
	bzero(ClasseGlob.carSpeciaux, 256);
	ClasseGlob.carSpeciaux[' '] = 1 + IFS;
	ClasseGlob.carSpeciaux['\t'] = 1 + IFS;
	ClasseGlob.carSpeciaux['*'] = -1 - GLOB_ETOILE;
}

Glob * glob_init(Glob * c, char * source)
{
	char cree = 0;
	
	if(!c)
	{
		c = (Glob *)malloc(sizeof(Glob));
		cree = 1;
	}
	c->c = &ClasseGlob;
	char ifs;
	if(!preparer((Crible *)c, source))
	{
		if(cree) free(c);
		return NULL;
	}
	c->crible = (char *)malloc(strlen(source) + 1);
	strcpy(c->crible, source);
	return c;
}

int glob_verifier(Glob * g, char ** commande)
{
	return -1;
}
