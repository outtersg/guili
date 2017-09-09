/* Petit Anti-Fâcheux: une sorte de spamd minimaliste. */
// Pour tester le temps que serait bloqué un message:
// cc -DTEST -o /tmp/paf2 exim.paf2.c && /tmp/paf2 <fichier RFC 822>

#include <stdio.h>
#include <fcntl.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <ctype.h>
#include <sys/stat.h>
#include <sys/types.h>

#ifndef TEST

#include "local_scan.h"

static char * g_rejets = NULL;

#endif /* TEST */

static int g_facteurPoireautage = 0; // 1 s de poireautage par tranche de g_facteurPoireautage points-poubelle.

float secondes(float points)
{
	if(!g_facteurPoireautage) g_facteurPoireautage = 2000;
	
	return points * g_facteurPoireautage / 1000;
}

#ifndef TEST

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
	
	// Exim, ne nous interromps pas, s'il-te-plaît.
	alarm(0);

	for (temps = 0; temps < secondes(points); temps += intervalle)
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

#else /* TEST */

#include <errno.h>
#include <sys/mman.h>

#define LOCAL_SCAN_ACCEPT 0

typedef struct header_line
{
	int slen;
	const char * text;
	struct header_line * next;
} header_line;

header_line * header_list;

char * g_cheminCourant;

typedef char uschar;

void entreposerMessageAnalyse(char * blocDebut, int tailleDebut, int fd)
{
	
}

int poireauter(float points, uschar ** return_text)
{
	char sansZero[31];
	char * ptr;
	for(ptr = &sansZero[snprintf(sansZero, 31, "%.3f", points)]; --ptr > sansZero && *ptr == '0';)
		if(*ptr == '.')
		{
			// Sortie forcée, de peur qu'avant le . on trouve des 0 que l'on fasse sauter.
			--ptr;
			break;
		}
	*(++ptr) = 0;
	fprintf(stdout, "%s: %s points-poubelle -> %.0f s\n", g_cheminCourant, sansZero, secondes(points));
	return 0;
}

#endif /* TEST */

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
		if(0 == strncmp("X-Spam-Status: Yes\n", (const char *)enTete->text, 19))
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

#ifdef TEST

void auSecours()
{
}

int main(int argc, char ** argv)
{
	int causant = 0;
	int f;
	int e;
	char * contenu;
	char * ptr;
	char * debut;
	char * fin;
	struct stat infos;
	header_line ** prochainEnTete;
	header_line * enTete, * suivant;
	
	if(argc > 1)
	{
		header_list = NULL;
		while(*++argv)
		{
			if(strcmp(*argv, "-h") == 0) { auSecours(); return(-1); }
			if(strcmp(*argv, "-v") == 0) { causant = 1; continue; }
			
			if((f = open(g_cheminCourant = *argv, O_RDONLY)) < 0)
			{
				fprintf(stderr, "# fopen(%s): %s\n", *argv, strerror(errno));
				continue;
			}
			
			if((e = fstat(f, &infos)) < 0)
			{
				fprintf(stderr, "# fstat(%s): %s\n", *argv, strerror(errno));
				close(f);
				continue;
			}
			contenu = mmap(NULL, infos.st_size, PROT_READ, MAP_PRIVATE, f, 0);
			fin = &contenu[infos.st_size];
			
			debut = contenu;
			prochainEnTete = &header_list;
			for(ptr = contenu; ptr < fin; ++ptr)
			{
				if(*ptr == '\n')
				{
					if(ptr == debut) // Deux d'affilée: fin des en-têtes.
						break;
					enTete = *prochainEnTete = (header_line *)malloc(sizeof(header_line));
					enTete->text = debut;
					enTete->slen = ptr - debut + 1;
					enTete->next = NULL;
					prochainEnTete = &enTete->next;
					debut = ptr + 1;
				}
			}
			
			lseek(f, 0, SEEK_SET);
			local_scan(f, NULL);
			
			for(enTete = header_list; enTete; enTete = suivant)
			{
				suivant = enTete->next;
				free(enTete);
			}
			munmap(contenu, infos.st_size);
			close(f);
		}
	}
	else
		auSecours();
}

#endif /* TEST */
