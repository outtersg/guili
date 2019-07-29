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
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <errno.h>

#if defined(TEST_LIRE_0) && TEST_LIRE_0
#define T_BLOC_TAMPON TEST_LIRE_0
#else
#define T_BLOC_TAMPON 0x400
#endif

struct
{
	char * o; /* Tampon (octets). */
	char * p; /* Pointeur courant. */
	int tp; /* Taille physique. */
	int tl; /* Taille logique. */
} g_tampon;

void initialiserLire()
{
	bzero(&g_tampon, sizeof(g_tampon));
}

char * lireLigne(int f)
{
	int t, n;
	char * p = g_tampon.p;
	char * p0;
	char * fin = &g_tampon.o[g_tampon.tl];
	char finDeFichier = 0;
	char * finDeCeTour;
	char arret;
	char suppressionEspaces = 0;
	int dec;
	
	while(1)
	{
		/* Analyse du dernier bloc lu et recherche d'un retour à la ligne. */
		
		finDeCeTour = finDeFichier || fin <= &g_tampon.o[0] ? fin : fin - 1; /* fin - 1: un retour à la ligne peut être suivi d'un espace ou tabulation, auquel cas la ligne suivante est la prolongation de la nôtre (façon LDIF). Notre butée de recherche du retour à la ligne sera donc fin - 1, pour être sûrs d'avoir l'octet suivant sous la main à inspecter. */
		arret = finDeFichier; /* Si finDeFichier, même si la boucle suivante (recherche d'un retour à la ligne) sort sans avoir trouvé, on clôt la ligne courante. */
		while(p < finDeCeTour)
		{
			/* Commence-t-on le tour avec des espaces parasites? */
			if(suppressionEspaces)
			{
				for(p0 = p, --p; ++p < fin;)
					if(*p != ' ' && *p != '\t')
					{
						suppressionEspaces = 0;
						break;
					}
				if(p > p0)
				{
					if(fin > p)
						memmove(p0, p, fin - p);
					g_tampon.tl -= p - p0;
					finDeCeTour -= p - p0;
					fin -= p - p0;
					p = p0;
				}
			}
			/* Peut-on trouver un retour à la ligne franc dans ce qu'on a déjà lu? */
			for(--p; ++p < finDeCeTour;)
			{
				if(*p == '\n')
				{
					if(p == fin - 1 || (p[1] != ' ' && p[1] != '\t')) /* Soit fin de fichier, soit le caractère suivant n'indique pas une prolongation de ligne. */
					{
						arret = 1;
						goto ligneTrouvee;
					}
					/* Retour suivi d'un prolongateur de ligne. On bouffe ceux-ci. */
					++p;
					suppressionEspaces = 1;
					break;
				}
			}
		}
		
		ligneTrouvee:
		
		/* Une ligne entière est composé, on la renvoie. */
		
		/* Attention: on va devoir caler un '\0' à la fin, on s'assure donc d'avoir la place de le faire.
		 * Dans le cas à la limite où la fin de fichier tient tout juste dans le bloc alloué pour lire, on n'a aucun octet d'alloué en plus pour caser notre '\0'. En ce cas on ne se considère pas en fin de ligne: on repart pour un tour de lecture, qui réservera un bloc de plus même si on sait qu'il n'y lira aucun octet du fichier terminé, mais au moins ça fera de la place pour caler notre '\0' au prochain tour de boucle.
		 */
		if(arret && p < &g_tampon.o[g_tampon.tp])
		{
			finDeCeTour = p;
			*finDeCeTour = 0;
			for(p = g_tampon.p; *p == ' ' || *p == '\t'; ++p) {} /* Inutile de conserver les espaces en début de ligne. */
			g_tampon.p = finDeCeTour + 1; /* Pour pouvoir partir sur la suite au prochain tour. */
			return finDeFichier && p >= fin ? NULL : p;
		}
		
		/* Pas trouvé de caractère retour: besoin de lire un peu plus pour en trouver un. */
		
		t = g_tampon.tp - g_tampon.tl; /* Combien va-t-on lire? */
		if(t < T_BLOC_TAMPON) /* Plus assez de place, il va falloir en faire. */
		{
			/* Commençons par tasser tout en début de bloc. */
			if(g_tampon.p > g_tampon.o)
			{
				g_tampon.tl = &g_tampon.o[g_tampon.tl] - g_tampon.p;
				memmove(g_tampon.o, g_tampon.p, g_tampon.tl);
				dec = g_tampon.p - g_tampon.o;
				p -= dec;
				fin -= dec;
				finDeCeTour -= dec;
				g_tampon.p = g_tampon.o;
				t = g_tampon.tp - g_tampon.tl;
			}
			if(t < T_BLOC_TAMPON) /* Bon, toujours pas assez: on agrandit notre tampon de lecture. */
			{
				char * nouveau;
				g_tampon.tp += T_BLOC_TAMPON;
				if(!(nouveau = g_tampon.o ? realloc(g_tampon.o, g_tampon.tp) : malloc(g_tampon.tp)))
				{
					fprintf(stderr, "# Impossible d'allouer %d octets pour la lecture de la config.\n", g_tampon.tp);
					exit(-1);
				}
				g_tampon.p = &nouveau[g_tampon.p - g_tampon.o];
				fin = &nouveau[fin - g_tampon.o];
				p = &nouveau[p - g_tampon.o];
				g_tampon.o = nouveau;
				t = g_tampon.tp - g_tampon.tl;
			}
		}
		
		/* Lisons! */
		
		if((n = read(f, &g_tampon.o[g_tampon.tl], t)) < 0)
		{
			fprintf(stderr, "# Impossible de lire la config: %s.\n", strerror(errno));
			exit(-1);
		}
		else if(n == 0)
			finDeFichier = 1;
		g_tampon.tl += n;
		fin = &g_tampon.o[g_tampon.tl];
	}
}
