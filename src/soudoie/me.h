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

#ifndef _SOUDOIE_ME_H_
#define _SOUDOIE_ME_H_

/*- Machine à États ----------------------------------------------------------*/
/* Cf. exemple d'utilisation dans testerME() (test.c). */

/* Machine à États atomiques: l'avancée dans le crible et le criblé se fait au même rythme: à chaque état passé, on avance d'un élément dans le criblé. */
/* /!\ Cela signifie qu'il est impossible d'avoir des états dont la "barrière" mange plusieurs éléments de l'entrée, ex. des parenthèses groupantes /a(li)+(ba)*$/.
 * Bon, en vrai, cet exemple-ci pourrait marcher, en découpant la chaîne en blocs (a, li, et ba), car il n'y a pas d'empiètement possible entre ces blocs.
 * Mais un /^(ab)*(aba)/, lui, poserait problème, car la lecture d'"aba" pourrait soit donner lieu à des marqueurs après avoir consommé "ab" ou "aba". */
typedef struct
{
	const char * masque;
	int * marqueurs;
	int dernierMarqueur;
	int nMarqueurs;
	char dames; /* Si 0, il ne peut y avoir qu'un seul marqueur sur chaque état; si 1, ils sont empilables (comme au jeu de dames). Ceci pourra servir par exemple pour une implémentation consommant des segments de tailles différentes (charge à l'implémentatin de retenir à part les pointeurs de consommation correspondant à chaque marqueur). */
}
ME;

#define ME_FIN    0
#define ME_NORMAL '.'
#define ME_PLUS   '+'
#define ME_ETOILE '*'

#define FOR_ME(me, pos) \
	for(int nRestant = (me)->nMarqueurs, pos = (me)->dernierMarqueur; nRestant > 0; --pos) \
		for(int nOccurrencesIci = (me)->marqueurs[pos]; --nOccurrencesIci >= 0; --nRestant)

void me_commencer(ME * me);
void me_passer(ME * me, int pos);
void me_marquer(ME * me, int pos);
void me_demarquer(ME * me, int pos);

#endif
