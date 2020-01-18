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

/*- Liste --------------------------------------------------------------------*/

/* Tableau à clés alphabétiques *non triées*: on y perd en temps de recherche, mais on gagne un mécanisme "premier entré, premier sorti". */
typedef struct
{
	int n;
	int nAlloc;
	char ** cles;
	void ** vals;
	void (*liberer)(void * val);
}
L;

L * L_creer();
void * L_chercherN(L * t, char * cle, int tailleCle);
int L_pos(L * t, char * cle);
int L_posN(L * t, char * cle, int tailleCle);
void L_placer(L * t, char * cle, void * val);
