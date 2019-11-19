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
		glob_init(&g, ligne, 0);
		c = (Crible *)&g;
	}
	
	if(c->c->fVerif(c, contexte->argv) == 0)
		return AUTO_OUI;
	
	return AUTO_NE_SAIS_PAS;
}

int autoValiderEnTete(char * enTete, AutoContexte * contexte)
{
	char * debut;
	char * fin;
	char c;
	int vExecutant = 0;
	int vExecute = 0;
	int mode = 0; /* 0: exécutant; 1: exécuté */
	struct passwd * gusse;
	int * vGusse;
	
	for(fin = enTete; *(debut = fin);)
	{
		/* Recherche du prochain mot. */
		
		for(fin = debut - 1; *++fin && *fin != ' ' && *fin != ',';) {}
		c = *fin;
		*fin = 0;
		
		/* Prise en compte du mot. */
		
		switch(mode)
		{
			case 0:
			case 1:
				if(mode == 0 && 0 == strcmp(debut, "as"))
					mode = 1;
				else
				{
					gusse = mode == 1 ? & contexte->execute : & contexte->executant;
					vGusse = mode == 1 ? & vExecute : & vExecutant;
					if(*debut == '%')
					{
						/* À FAIRE: % pour désigner un groupe autorisé. */
						fprintf(stderr, "# Je ne gère pas les groupes (%s).\n", debut);
					}
					else if(0 == strcmp(debut, "*") || 0 == strcmp(debut, "ALL"))
						*vGusse = 1;
					else if(0 == strcmp(debut, gusse->pw_name))
						*vGusse = 1;
					else if(!*vGusse)
						*vGusse = -1;
				}
		}
		
		/* On restaure et on continue. */
		
		*fin = c;
		while(*fin == ' ') ++fin;
	}
	
	/*- Ménage et retour -*/
	
	return vExecutant > 0 && vExecute >= 0 ? AUTO_OUI : AUTO_NE_SAIS_PAS;
}

int autoValiderBloc(char * enTete, char * corps, AutoContexte * contexte)
{
	char * ligne;
	char * ptr;
	char butee;
	int r;
	
	/*- En-tête -*/
	
	if((r = autoValiderEnTete(enTete, contexte)) != AUTO_OUI)
		return r;
	
	/*- Corps -*/
	/* Le corps peut être multi-lignes. */
	
	for(butee = *(ligne = corps); butee;)
	{
		/* À FAIRE: si la ligne contient des $, remplacer par la valeur de la variable (interne).
		 * Pour ce faire il faudra sans doute changer ligne, pour l'allouer dans un espace "à nous" suffisamment spacieux. */
	 	
		for(ptr = ligne - 1; *++ptr && *ptr != '\n';) {}
		butee = *ptr;
		*ptr = 0;
		if((r = autoValiderLigne(ligne, contexte)) != AUTO_NE_SAIS_PAS)
		{
			*ptr = butee;
			return r; /* À FAIRE: un "reject" dans l'en-tête qui transforme les AUTO_OUI en AUTO_NON. */
		}
		*ptr = butee;
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
