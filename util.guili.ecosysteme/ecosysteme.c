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
#include <signal.h>

#include "U.h"
#include "L.h"
#include "E.h"
#include "Prerequis.h"

int g_trace = 0;

/*- Chaînes de prérequis -----------------------------------------------------*/

void pousserPrerequis(char * ptrL, int tL, char * ptrO, int tO, char * ptrV, int tV, L * resultatAgrege)
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
	
	if((p = (Prerequis *)L_chercherN(resultatAgrege, ptrL, tL)))
		Prerequis_fusionnerN(p, ptrO, tO, ptrV, tV);
	else
	{
		p = Prerequis_creerN(ptrL, tL, ptrO, tO, ptrV, tV);
		L_placer(resultatAgrege, p->logiciel, p);
	}
}

void decouperPrerequis(char * chaine, L * resultatAgrege)
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

void afficherPrerequis(L * t)
{
	int i;
	for(i = -1; ++i < t->n;)
		Prerequis_afficher((Prerequis *)t->vals[i]);
}

/*- Travail ------------------------------------------------------------------*/

void boum(int signal)
{
	int i, n = 0;
	for(i = -1; ++i < E_taches->n;)
		if(((E *)E_taches->vals[i])->etat != E_FINI)
			++n;
	if(n > 0)
	{
		fprintf(stderr, "# Attente de %d processus fils\n", n);
		E_attendreFinLances(E_taches);
		exit(3);
	}
}

#define MODE_TOUT 0
#define MODE_DECOUPE 1

int main(int argc, char ** argv)
{
	struct sigaction accrocheBoum;
	accrocheBoum.sa_handler = &boum;
	accrocheBoum.sa_flags = SA_RESTART;
	sigfillset(&accrocheBoum.sa_mask);
	sigaction(SIGINT, &accrocheBoum, NULL);
	
	L * prerequis = L_creer();
	int mode = MODE_TOUT;
	
	int i = 0;
	while(++i < argc)
	{
		if(0 == strcmp(argv[i], "-d"))
			mode = MODE_DECOUPE;
		else if(0 == strcmp(argv[i], "-v"))
			++g_trace;
		else
		decouperPrerequis(argv[i], prerequis);
	}
	switch(mode)
	{
		case MODE_DECOUPE:
	afficherPrerequis(prerequis);
			break;
	}
}
