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

/*- Prérequis ----------------------------------------------------------------*/

typedef struct
{
	char * logiciel;
	char * options;
	char * version;
}
Prerequis;

Prerequis * Prerequis_creerN(char * ptrL, int tL, char * ptrO, int tO, char * ptrV, int tV);
void Prerequis_fusionnerN(Prerequis * p, char * ptrO, int tO, char * ptrV, int tV);
void Prerequis_afficher(Prerequis * p);

/*- Implémentation -----------------------------------------------------------*/

typedef struct
{
	int (*prerequis)(Prerequis * p);
	int (*lancer)(Prerequis * p);
}
PrerequisImpl;

extern PrerequisImpl Prerequis_impl;
