/* Petit Anti-Fâcheux: une sorte de spamd minimaliste. */

#include <stdio.h>
#include <fcntl.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <ctype.h>
#include <sys/stat.h>
#include <sys/types.h>

#include "local_scan.h"

static char * g_rejets = NULL;
static int g_facteurPoireautage = 0; // 1 s de poireautage par tranche de g_facteurPoireautage points-poubelle.

optionlist local_scan_options[] = {
	{ "rejets", opt_stringptr, &g_rejets },
	{ "tranchePoireautage", opt_fixed, &g_facteurPoireautage }
};

int local_scan_options_count = sizeof(local_scan_options) / sizeof(optionlist);

int poireauter(float points, uschar ** return_text)
{
	int temps;
	char * str;
	int intervalle = 5;
	int ret;
	
	if(!g_facteurPoireautage) g_facteurPoireautage = 2000;
	
	// Exim, ne nous interromps pas, s'il-te-plaît.
	alarm(0);

	for (temps = 0; temps < points * g_facteurPoireautage / 1000; temps += intervalle)
	{
		smtp_printf("451- %s: %d\r\n", "Attendez, je patine dans la choucroute", (int)ceil(points));
		ret = smtp_fflush();
		if (ret != 0)
		{
			log_write(0, LOG_MAIN | LOG_REJECT, "paf: teergrubed sender for %d secs until it closed the connection.", temps);
			/* The other side closed the connection, nothing to print */
			*return_text = (uschar *)"";
			return LOCAL_SCAN_TEMPREJECT;
		}
		sleep(intervalle);
	}

	log_write(0, LOG_MAIN | LOG_REJECT, "paf: teergrubed sender until full configured duration of %d secs.", temps);
	*return_text = string_sprintf("Bravo, vous marquez %f points-poubelle! Retentez votre chance...", points);
	return LOCAL_SCAN_TEMPREJECT;
}

#define T_PAQUET 0x1000

int ouvrirTrace(int fd, char * suffixe, char ** ptrChemin)
{
	if(ptrChemin) *ptrChemin = NULL;
	
	if(!g_rejets)
		return -1;
	
	char id[SPOOL_DATA_START_OFFSET + 1];
	char * ptr;
	int n;
	int sortie;
	
	lseek(fd, 0, SEEK_SET);
	n = read(fd, id, SPOOL_DATA_START_OFFSET);
	for(ptr = &id[n]; --ptr >= id && isspace(*ptr);) {}
	*(++ptr) = 0;
	
	char * chemin = (char *)string_sprintf("%s/%s%s", g_rejets, id, suffixe);
	if((sortie = open(chemin, O_WRONLY|O_CREAT, 0444)) < 0)
	{
		mkdir(g_rejets, 0700);
		if((sortie = open(chemin, O_WRONLY|O_CREAT, 0444)) < 0)
		{
			log_write(0, LOG_MAIN, "paf: error: cannot write %s", chemin);
			return -1;
		}
	}
	
	if(ptrChemin) *ptrChemin = chemin;
	return sortie;
}

void entreposerMessageAnalyse(char * blocDebut, int tailleDebut, int fd)
{
	int sortie;
	
	if((sortie = ouvrirTrace(fd, "", NULL)) < 0)
		return;
	
	char bloc[T_PAQUET];
	int n;
	
	write(sortie, blocDebut, tailleDebut);
	
	while((n = read(fd, bloc, T_PAQUET)) > 0)
		write(sortie, bloc, n);
	
	close(sortie);
}

#define T_BLOC_ENTETES 0x2000

int local_scan(int fd, uschar ** return_text)
{
	float p = 6.0f; // Points-poubelle. On initialise à 6 pour les messages qui auraient un Spam mais pas le Score associé.
	float ici;
	char poubelle = 0;
	
	char bloc[T_BLOC_ENTETES + 2];
	int n = 0, t = 0;
	header_line * enTete;
	header_line * autre;
	
	for(enTete = header_list; enTete; enTete = enTete->next)
	{
		// Nos réécritures semblent dédoubler certains en-têtes, dont les From. C'est un peu gênant de juger double là-dessus.
		for(autre = header_list; autre != enTete; autre = autre->next)
			if(autre->slen == enTete->slen && memcmp(autre->text, enTete->text, autre->slen) == 0)
				break;
		if(autre != enTete)
			continue;
		
		// Repérage des en-têtes nous intéressant.
		if(0 == strcmp("X-Spam-Status: Yes\n", (const char *)enTete->text))
			poubelle = 1;
		if(0 == strncmp("X-Spam-Score: ", (const char *)enTete->text, 14))
		{
			ici = atof((char *)&enTete->text[14]);
			if(ici > p)
				p = ici;
		}
		
		// Copie dans le bloc d'en-têtes, pour pondre en une fois dans le fichier résultant.
		n = enTete->slen;
		if(t + n > T_BLOC_ENTETES)
			n = T_BLOC_ENTETES - t;
		memcpy(&bloc[t], enTete->text, n);
		t += n;
	}
	
	if(bloc[t] != '\n')
		bloc[t++] = '\n';
	bloc[t++] = '\n';
	
	if(poubelle)
	{
		int r;
		entreposerMessageAnalyse(bloc, t, fd);
		r = poireauter(p, return_text);
		return r;
	}
	
	return LOCAL_SCAN_ACCEPT;
}
