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

#include <errno.h>
#include <string.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/stat.h>

#include "lecture.h"
#include "auto.h"
#include "glob.h"

/*- Validation ---------------------------------------------------------------*/

int autoValiderLigne(char * ligne, AutoContexte * contexte)
{
	Crible * c;
	
	/* À FAIRE: si commence par un ^, passer par PCRE. */
	if(1)
	{
		Glob g;
		glob_init(&g, ligne);
		c = (Crible *)&g;
	}
	
	if(c->c->fVerif(c, contexte->argv) == 0)
		return AUTO_OUI;
	
	return AUTO_NE_SAIS_PAS;
}

int autoValiderBloc(char * enTete, char * corps, AutoContexte * contexte)
{
	char * ligne;
	char * ptr;
	int r;
	
	/*- En-tête -*/
	
	/* À FAIRE: vérifier le compte de l'exécutant. */
	/* À FAIRE: mot-clé "as", ex.: "me as daemon: commande", et vérifier le compte de l'exécuté. */
	
	/*- Corps -*/
	/* Le corps peut être multi-lignes. */
	
	for(ligne = corps; *ligne;)
	{
		/* À FAIRE: si la ligne contient des $, remplacer par la valeur de la variable (interne).
		 * Pour ce faire il faudra sans doute changer ligne, pour l'allouer dans un espace "à nous" suffisamment spacieux. */
	 	
		for(ptr = ligne - 1; *++ptr && *ptr != '\n';) {}
		*ptr = 0;
		if((r = autoValiderLigne(ligne, contexte)) != AUTO_NE_SAIS_PAS)
			return r; /* À FAIRE: un "reject" dans l'en-tête qui transforme les AUTO_OUI en AUTO_NON. */
		ligne = ++ptr;
	}
	
	return AUTO_NE_SAIS_PAS;
}

/*- Lecture de la config -----------------------------------------------------*/

int autoMangerLigne(char * ligne, AutoContexte * contexte)
{
	char * ptr;
	char * ptrSuite;
	
	/* L'en-tête. */
	
	for(ptr = ligne - 1; *++ptr && *ptr != ':' && *ptr != '\n';) {}
	if(!*ptr && ptr == ligne) return AUTO_NE_SAIS_PAS; /* Ligne vide. */
	for(ptrSuite = ptr; *++ptrSuite && (*ptrSuite == ' ' || *ptrSuite == '\t' || *ptrSuite == '\n');) {}
	switch(*ptr)
	{
		case ':': *ptr = '\0'; return autoValiderBloc(ligne, ptrSuite, contexte);
		/* À FAIRE: affectation de variables avec du =. */
	}
	
	fprintf(stderr, "# Syntaxe incorrecte (manque : ou =):\n\t%s\n", ligne);
	return AUTO_NE_SAIS_PAS;
}

/*- Ordonnancement de la validation ------------------------------------------*/

int autoriseFichierConfig(char * config, AutoContexte * contexte)
{
	struct stat infos;
	char * l;
	
	int r = AUTO_NE_SAIS_PAS;
	int f = open(config, O_RDONLY);
	if(f < 0) { fprintf(stderr, "# Impossible d'ouvrir %s: %s\n", config, strerror(errno)); goto eOpen; }
	if(fstat(f, &infos) != 0) { fprintf(stderr, "# Impossible de vérifier les droits sur %s: %s\n", config, strerror(errno)); goto eStat; }
	if(infos.st_uid != 0) { fprintf(stderr, "# %s doit appartenir à root. Il sera ignoré.\n", config); goto eStat; }
	if(infos.st_mode & 0022) { fprintf(stderr, "# %s ne doit être inscriptible que par root. Il sera ignoré.\n", config); goto eStat; }
	
	while((l = lireLigne(f)))
		if((r = autoMangerLigne(l, contexte)) != AUTO_NE_SAIS_PAS)
			break;
	
	close(f);
	
	return r;
	
	eStat:
	close(f);
	eOpen:
	return r;
}

int autoriseConfig(AutoContexte * contexte)
{
	return autoriseFichierConfig(CHEMIN_CONFIG, contexte);
}

int autorise(AutoContexte * contexte)
{
	/* À FAIRE: implémenter ici d'autres sources de validation: NIS, etc. */
	return autoriseConfig(contexte);
}
