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

/* À FAIRE: prérequis optionnels
 * Les logiciels doivent pouvoir préciser les prérequis par lesquels ils seraient *éventuellement* intéressés. Si un de ces prérequis apparaît dans la liste, à la prochaine passe on le placera avant le logiciel.
 */
/* À FAIRE: v 3 && prerequis="$prerequis autre" || true
 * L'accumulation de prérequis est-elle possible? Si on a demandé >= 3 < 4, le v 2 renverra false, donc prerequis n'aura pas été affectée. Il faudrait un double mode à v: première passe "pas plus que", seconde "contrôle strict". v() pourrait définirait $version comme actuellement (avec toutes les contraintes), mais faire son return en fonction des seules contraintes <, <=, et = (ignorant les > ou >=, et transformant les = en <=)
 */
/* À FAIRE: php < 7 >= 5.4
 * Renvoie 7.3.x :-( car ne tient compte que de la dernière contrainte.
 */
/* À FAIRE: version insoluble
 * S'accorder sur un code retour de processus pour signifier "je n'ai aucune version qui réponde à ces contraintes".
 */
/* À FAIRE: options générées
 * Si php détecte un MySQL et décide de se muter en php+mysql, comment récupérer ce résultat pour l'associer à la nouvelle liste de prérequis?
 */
/* À FAIRE: cache
 * Pour pouvoir cacher logiciel par logiciel, il faut que ce dernier puisse nous certifier que "pour telle version des prérequis, et telles contraintes sur ma version, voici la version que je te sortirai systématiquement".
 * On doit donc calculer la version exacte de chaque prérequis avant celle du logiciel.
 * De plus pour pouvoir limiter les changements, chaque logiciel doit pouvoir spécifier les prérequis par lesquels il serait *éventuellement* intéressé. Ainsi on ne lui calculera un nouveau cache que si l'une de ces dépendances potentielles change (et non pas au changement sur n'importe quel autre logiciel).
 * Pour ce qui est des contraintes de version: on doit pouvoir simplifier, pour que par exemple si un premier logiciel a prérequis postgresql >= 9, et qu'un second prérequiert postgresql >= 8, la combinaison postgresql >= 9 >= 8 ne donne pas lieu au calcul d'un nouveau cache mais utilise celui de postgresql >= 9.
 */
/* À FAIRE: gestion du "ou"
 * On peut avoir un | entre versions (1.0.2 | >= 1.1), ou entre logiciels (openssl >= 1 | gnutls >= 1). Attention à ne pas fusionner les logiciels à options différentes (postgresql >= 10 | postgresql+telleextension >= 9).
 */
/* À FAIRE: versions déjà installées
 * Comment faire pour dire "si une version déjà installée répond aux critères, on la prend immédiatement, de préférence à la dernière version théorique"? Peut-être tout simplement les tester avant celles listées par appel à l'installeur.
 */
/* À FAIRE: parcours d'arbre
 * On circule sur un arbre à trous: certains rameaux ne sont pas encore calculés (si on a demandé php >= 4 < 5.6, on a commencé par la dernière 5.5, mais on n'a pas encore peuplé toutes les branches jusqu'à la 4).
 * Si une combinaison échoue, on doit pouvoir essayer la version précédente de la dernière feuille incomplète (si grostruc < 5 échoue à trouver un combinaison avec pour dépendance petit < 2 qui avait été calculé à 1.9.8, on réessaye petit < 2 < 1.9.8); si la feuille est épuisée, son prérequérant joue sur la feuille suivante (en réitérant avec toutes les valeurs de la première feuille; peut-être avoir un mécanisme pour dire quelles feuilles on rétrograde plus volontiers: celles du bout?). Si on a parcouru toutes les combinaisons de feuilles, alors c'est le rameau qui doit essayer une version antérieure, etc.
 */
/* À FAIRE: gère-t-on l'auto-dépendance?
 * Comment réagit-on si clang >= 5 a pour prérequis clang < 5? La fusion des dépendances actuelle va aboutir (au mieux, si on n'a pas précisé >= 5; si on l'a précisé: impossibilité) à un clang 4.x, il faudra donc relancer une seconde fois. Mais dans ce cas il faudra qu'on ait implémenté "versions déjà installées".
 * Même problème avec les options, ex.: freetype a besoin de harfbuzz+ft qui a besoin de freetype. On a résolu via une option +hb, obligatoire pour le premier, et interdite pour le dernier. Cependant ecosysteme ne verra qu'un seul freetype, celui avec +hb.
 * Il nous faut donc un moyen de distinguer prérequis de compil de prérequis d'exécution.
 */
/* À FAIRE: avoir un système de pkg-config?
 * À l'heure actuelle, si je compile ./gcc '< 7.4' en oubliant le +, trouvant une mpfr 3, il va s'y lier.
 * Si plus tard, compilant un ./php +, il trouve le gcc, il va lui demander ses propres dépendances pour que le php s'y lie.
 * Problème: le + passé à ./php va faire dire à gcc qu'il souhaite voir dans le LD_LIBRARY_PATH "du mpfr, version max", ce qui fait mettre dans ce chemin celui de mpfr 4 (compilée entre-temps).
 * Au moment du ld, gcc ne trouvera pas la mpfr 3 avec laquelle il s'était lié (mpfr 3 -> libmpfr.so.4; mpfr 4 -> libmpfr.so.6). Donc pétage (heureusement dans le configure; sinon on se serait tapés toute la compile avant de planter!)
 * Donc on doit avoir moyen de ressortir avec quels prérequis on s'était finalement compilés. pkg-config semble être approprié (si je lui ajoute un Requires.GuiLI, ne va-t-il pas trop gueuler?).
 */

int g_trace = 0;

char estVersion(char * chaine);

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
	{
		Prerequis_fusionnerN(p, ptrO, tO, ptrV, tV);
		// Certains prérequis spéciaux (séparateurs) s'agrègent à la dernière occurrence trouvée plutôt qu'à la première: en ce cas on décale tout le monde.
		if(tL == 1 && *ptrL == '\\')
		{
			i = L_posN(resultatAgrege, ptrL, tL);
			char * cle = resultatAgrege->cles[i];
			char * val = resultatAgrege->vals[i];
			while(++i < resultatAgrege->n)
			{
				resultatAgrege->cles[i - 1] = resultatAgrege->cles[i];
				resultatAgrege->vals[i - 1] = resultatAgrege->vals[i];
			}
			resultatAgrege->cles[i - 1] = cle;
			resultatAgrege->vals[i - 1] = val;
		}
	}
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
		while(*chaine && *chaine != '+' && *chaine != ' ' && *chaine != '<' && *chaine != '>' && *chaine != '=' && *chaine != '(') ++chaine;
		if(*chaine == '(')
			while(*++chaine)
				if(*chaine == ')')
				{
					++chaine;
					break;
				}
				
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

char estVersion(char * chaine)
{
	if(*chaine < '0' || *chaine > '9') return 0;
	while(*++chaine && *chaine != ' ')
		if(*chaine != '.' && (*chaine < '0' || *chaine > '9'))
			return 0;
	return chaine[-1] != '.';
}

void afficherPrerequis(L * t)
{
	int i;
	for(i = -1; ++i < t->n;)
		Prerequis_afficher((Prerequis *)t->vals[i]);
}

int resoudrePrerequis(L * t)
{
	int i;
	Prerequis * p;
	for(i = -1; ++i < t->n;)
	{
		Prerequis_impl.prerequis(t->vals[i]);
	}
	
	return E_attendreFinLances(E_taches);
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
			return 0;
		case MODE_TOUT:
			return resoudrePrerequis(prerequis);
	}
}
