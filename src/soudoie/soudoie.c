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

/* Super Opérateur Universel, Daignez Ouvrir Immédiatement pour Exécution. */
/* Super Opérateur Universel, Daignez Ouvrir Ultérieurement pour Exécution. */
/* Super Utilisateur Respectable, Daignez Opérer Une Escalade. */
/* Super Utilisateur Ronchon, J'Ordonne Une Escalade. */
/* À FAIRE: syslog systématique */
/* À FAIRE: validation via PCRE. Oui, ça ouvre une faille par rapport à du tout compilé statiquement, mais ça ferme celle due à ce que, fatigués de taper l'ensemble des combinaisons possibles, les sudoers finissent bourrés d'étoiles (ex.: systemctl * nginx). */
/* À FAIRE: vérif simple: à la lecture de /etc/soudure, les ' ' deviennent \003 (sauf si ligne contient un \003) sauf si dans []. * font un seul argument (donnent [^\003]), ** en fin correspondent à tout. Un chemin contenant des .. et . est compacté avant comparaison. */
/* À FAIRE: env (HOME, etc.) */
/* À FAIRE: limitation au compte: gui as www: /bin/vi /etc/nginx.conf */
/* À FAIRE: multi-ligne: www: /sbin/service restart nginx\n\t/sbin/service restart php-fpm */
/* À FAIRE: affectations: OPS_SERVICE = (start|restart|stop) */
/* À FAIRE: include */

#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <limits.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <stdarg.h>
#include <errno.h>
#include <pwd.h>
#include <grp.h>

#include "lecture.h"

extern char ** environ;

char g_chemin[PATH_MAX + 1];
struct passwd g_infosCompte;
#define UTILISE_ARGV 1
#define UTILISE_SPECIAL 2
#define UTILISE_DEF 3
char g_utilises[' ']; /* Caractères spéciaux utilisés par notre argv, que nous ne pourrons donc pas utiliser comme séparateurs. */

/*- Utilitaires --------------------------------------------------------------*/

int lancer(const char * chemin, char * const argv[], char * const envp[])
{
	return execve(chemin, argv, envp);
}

const char * cheminComplet(const char * truc)
{
	if(truc[0] == '/')
		return truc;
	const char * chemins = getenv("PATH");
	if(!chemins)
		return NULL;
	const char * ptr;
	int t;
	int tTruc = strlen(truc);
	struct stat infos;
	while(*chemins)
	{
		ptr = chemins;
		while(*ptr && *ptr != ':')
			++ptr;
		if((t = ptr - chemins) + 1 + tTruc <= PATH_MAX)
		{
			strncpy(g_chemin, chemins, t);
			g_chemin[t] = '/';
			strcpy(&g_chemin[t + 1], truc);
			if(stat(g_chemin, &infos) == 0 && S_ISREG(infos.st_mode) && (infos.st_mode & S_IXUSR))
				return g_chemin;
		}
		chemins = ptr + 1;
	}
	return NULL;
}

/*- Exécution ----------------------------------------------------------------*/

void basculerCompte()
{
	gid_t groupes[NGROUPS_MAX + 1];
	int nGroupes = -1;
	struct group * pGroupe;
	char ** pMembre;
	
	groupes[++nGroupes] = g_infosCompte.pw_gid;
	while((pGroupe = getgrent()))
	{
		if(pGroupe->gr_gid == g_infosCompte.pw_gid) continue; /* Celui-là a déjà été fait. */
		
		for(pMembre = pGroupe->gr_mem; *pMembre; ++pMembre)
			if(0 == strcmp(*pMembre, g_infosCompte.pw_name))
			{
				if(++nGroupes >= NGROUPS_MAX)
				{
					fprintf(stderr, "# getgrent(%d): trop de groupes; %s ignoré\n", g_infosCompte.pw_uid, pGroupe->gr_name);
					--nGroupes;
					break;
				}
				groupes[nGroupes] = pGroupe->gr_gid;
				break;
			}
	}
	endgrent();
	++nGroupes;
	
	if(setgid(g_infosCompte.pw_gid)) { fprintf(stderr, "# setgid(%d): %s\n", g_infosCompte.pw_gid, strerror(errno)); exit(1); }
	if(setgroups(nGroupes, groupes)) { fprintf(stderr, "# setgroups(%d): %s\n", nGroupes, strerror(errno)); exit(1); }
	if(setuid(g_infosCompte.pw_uid)) { fprintf(stderr, "# setuid(%d): %s\n", g_infosCompte.pw_uid, strerror(errno)); exit(1); }
}

/*- Vérification -------------------------------------------------------------*/

/*--- Définitions ---*/

struct Crible;

typedef int (*FonctionVerif)(struct Crible * this, char ** commande);

typedef struct
{
	FonctionVerif fVerif;
	int nSpeciaux; /* Nombre d'octets spéciaux à mettre de côté (ex.: IFS, etc.). */
	int offsetSpeciaux; /* Où dans notre objet se trouve le tableau speciaux? */
	/* char[256] indiquant pour chaque caractère s'il est spécial:
	 *   0: non spécial
	 *   > 0: spécial, combinable (plusieurs occurrences successives sont concaténées); sera remplacé par speciaux[n - 1] dans le source prémâché résultant.
	 *   < 0: spécial, non combinable (plusieurs occurrences seront conservées); sera remplacé par speciaux[1 - n].
	 */
	char carSpeciaux[256];
}
CribleClasse;

typedef struct Crible
{
	CribleClasse * c;
}
Crible;

char * CribleSpeciaux(Crible * c)
{
	return ((char *)c) + c->c->offsetSpeciaux;
}

#define IFS 0
#define GLOB_ETOILE 1

typedef struct
{
	CribleClasse * c;
	char speciaux[2];
	char * crible;
}
Glob;

int glob_verifier(Glob * g, char ** commande);

/*--- Lecture des cribles ---*/

#define DECALER if(debutProchainMemMove && l > debutProchainMemMove) { memmove(debutProchainMemMove - l + e, debutProchainMemMove, l - debutProchainMemMove); debutProchainMemMove = l; }

/* Découpe une ligne de source.
 * Renvoie le caractère utilisé pour IFS, ou -1 en cas d'erreur.
 * Paramètres:
 *   crible
 *     Crible à préparer. Sa classe doit être renseignée (porte les métacaractères, etc.).
 *   source
 *     Chaîne à lire.
 */
char * preparer(Crible * crible, char * source)
{
	char * l; /* Pointeur en lecture. */
	char * e; /* Pointeur d'écriture. */
	char * p;
	char * debutProchainMemMove = NULL;
	char * pPrecedentSpe = source - 1;
	char nouveauSpe;
	char precedentSpe;
	int numSpe, special;
	char * speciaux = CribleSpeciaux(crible);
	
	/* Préparation des caractères spéciaux */
	/* On ne peut les choisir définitivement, car certains sont peut-être déjà pris, et on ne saura lesquels qu'en parcourant (remplacement de variables, etc.). */
	
	for(special = -1; ++special < ' ';)
		if(g_utilises[special] == UTILISE_DEF)
			g_utilises[special] = 0;
	if(crible->c->nSpeciaux)
	{
		for(numSpe = -1, special = '\003'; ++numSpe < crible->c->nSpeciaux;)
		{
			while(g_utilises[special])
				if(++special == ' ')
				{
					/* Ne débordons pas sur les caractères imprimables. */
					fprintf(stderr, "# Trop de caractères spéciaux dans %s.\n", source);
					return NULL;
				}
			speciaux[numSpe] = special;
		}
	}
	
	/* Parcours */
	
	for(l = e = source; *l; ++l, ++e)
		if(*l == '\\')
		{
				if(l[1])
				{
					/* Puisqu'on s'apprête à décaler, on traite l'éventuel précédent décalage en attente. */
					DECALER;
					++l;
					debutProchainMemMove = l;
				}
		}
		else if(crible->c->carSpeciaux[*l])
		{
			special = crible->c->carSpeciaux[*l];
			special = special > 0 ? special - 1 : -1 - special;
			if(crible->c->carSpeciaux[*l] > 0)
			{
				if(precedentSpe == *l && l == pPrecedentSpe + 1) /* Si l'on suit le précédent du même type. */
				{
					DECALER;
					--e; /* … on en est la prolongation, et notre curseur en écriture n'avance pas. */
				}
				pPrecedentSpe = l;
				precedentSpe = *l;
			}
			*l = speciaux[special];
		}
		else if(*l > 0 && *l < ' ' && !g_utilises[*l])
		{
			/* Ouille, un des octets que nous avions choisis pour représenter nos caractères spéciaux est un caractère de la chaîne; changement d'octet à effectuer pour ne pas avoir de conflit sur cet octet. */
			
			/* Lequel est-ce? */
			
			for(numSpe = -1; speciaux[++numSpe] != *l;) {}
			
			/* Celui-ci est grillé. */
			
			g_utilises[*l] = UTILISE_DEF;
			
			/* Recherchons un remplaçant qui ne soit pas déjà utilisé. */
			
			for(nouveauSpe = *l, p = source; p < l && ++nouveauSpe;)
			{
				if(nouveauSpe == ' ')
				{
					/* Ne débordons pas sur les caractères imprimables. */
					fprintf(stderr, "# Trop de caractères spéciaux dans %s.\n", source); /* À FAIRE: aïe, on a travaillé directement sur source; il faudrait en avoir une copie propre pour afficher ce diagnostic. */
					return NULL;
				}
				if(g_utilises[nouveauSpe])
					continue;
				for(p = source - 1; ++p < l;)
					if(*p == nouveauSpe) /* Zut, celui-ci aussi est pris. */
						break;
			}
			
			/* Ouf, un nouveau séparateur non utilisé. */
			
			for(p = source - 1; ++p < l;)
				if(*p == *l)
					*p = nouveauSpe;
			speciaux[numSpe] = nouveauSpe;
		}
		/* À FAIRE: traiter les guillemets. Attention: comment traiter un <espace>""<espace>? Il ne faut pas que les guillemets aient déjà simplifié, sans quoi l'<espace><espace> restant deviendra un seul <espace>. */
		/* À FAIRE: traiter les $, pour effectuer des remplacements. */
	DECALER;
	*e = 0;
	
	return source;
}

CribleClasse ClasseGlob;

void GlobClasseInitialiser()
{
	ClasseGlob.fVerif = (FonctionVerif)glob_verifier;
	ClasseGlob.nSpeciaux = 2;
	ClasseGlob.offsetSpeciaux = (int)&((Glob *)NULL)->speciaux;
	bzero(ClasseGlob.carSpeciaux, 256);
	ClasseGlob.carSpeciaux[' '] = 1 + IFS;
	ClasseGlob.carSpeciaux['\t'] = 1 + IFS;
	ClasseGlob.carSpeciaux['*'] = -1 - GLOB_ETOILE;
}

Glob * glob_init(Glob * c, char * source)
{
	char cree = 0;
	
	if(!c)
	{
		c = (Glob *)malloc(sizeof(Glob));
		cree = 1;
	}
	c->c = &ClasseGlob;
	char ifs;
	if(!preparer((Crible *)c, source))
	{
		if(cree) free(c);
		return NULL;
	}
	c->crible = (char *)malloc(strlen(source) + 1);
	strcpy(c->crible, source);
	return c;
}

/*--- Vérification des cribles ---*/

int glob_verifier(Glob * g, char ** commande)
{
	return -1;
}

/*--- Ordonnancement de la validation ---*/

char ** autorise(char ** argv)
{
	return argv;
}

const char * verifier(char * argv[])
{
	/* Idéalement la résolution de binaire (recherche dans le $PATH) se fait en tant que l'utilisateur cible (1), cependant nous avons besoin par la suite d'être root pour pouvoir lire les fichiers de config (2). Donc idéalement, on ferait un setuid(compte); résolution(); setuid(0); vérif(); setuid(compte);, cependant on optera pour la solution plus simple setuid(0); résolution(); vérif(); setuid(compte);.
	 * 1. pour ne pas trouver en root un binaire auquel le compte n'aura pas accès.
	 * 2. la résolution précède nécessairement la lecture de la config: cette dernière contient des références au chemin absolu résolu, donc si on veut pouvoir faire dans la même passe lecture de config et son application (pour pouvoir s'arrêter à la première correspondance trouvée), la résolution doit avoir été faite au moment où on rentre dans la lecture de config.
	 *    Notons qu'on ne peut "simplement" ouvrir le descripteur de fichier en root préalablement, car on sera amenés à ouvrir dynamiquement (directives include) d'autres fichiers durant la lecture du fichier principal.
	 */
	
	/* Changement d'utilisateur. Nous avons besoin d'être root pour lire le fichier de conf. */
	
	if(setuid(0)) { fprintf(stderr, "# setuid(%d): %s\n", 0, strerror(errno)); exit(1); }
	
	/* L'exécutable doit être référencé par chemin absolu. Résolvons-le ici. */
	
	const char * chemin = cheminComplet(argv[0]);
	if(!chemin)
		return NULL;
	
	/* Vérification. */
	
	char * argv0Original = argv[0];
	argv[0] = (char *)chemin;
	if(!autorise(argv)) goto eAuto;
	argv[0] = argv0Original;
	
	/* Retour! */
	
	return chemin;
	
	argv[0] = argv0Original;
	eAuto:
	return NULL;
}

/*- Initialisation -----------------------------------------------------------*/

void initialiserUtilises(char * argv[])
{
	char * p;
	bzero(g_utilises, ' ');
	while(*++argv)
		for(p = *argv; *p; ++p)
			if(*p > 0 && *p < ' ')
				g_utilises[*p] = UTILISE_ARGV;
	/* Certains caractères sont de toute façon proscrits comme séparateurs: ils pourraient prêter à confusion. */
	g_utilises['\n'] = UTILISE_SPECIAL;
	g_utilises['\r'] = UTILISE_SPECIAL;
	g_utilises['\t'] = UTILISE_SPECIAL;
}

void analyserParametres(char *** pargv)
{
	char ** argv = *pargv;
	char aChoisiSonCompte = 0;
	char * ptr;
	
	while(*argv)
	{
		if(0 == strcmp(*argv, "-u"))
		{
			if(!argv[1]) { fprintf(stderr, "# -u <compte>: <compte> non renseigné.\n"); exit(1); }
			struct passwd * pInfosCompte;
			for(ptr = argv[1]; *ptr && *ptr >= '0' && *ptr <= '9'; ++ptr) {}
			if(*ptr)
				pInfosCompte = getpwnam(argv[1]);
			else
				pInfosCompte = getpwuid(atoi(argv[1]));
			if(!pInfosCompte) { fprintf(stderr, "# -u %s: compte inexistant.\n", argv[1]); exit(1); }
			memcpy(&g_infosCompte, pInfosCompte, sizeof(struct passwd));
			aChoisiSonCompte = 1;
			++argv;
		}
		else
			break;
		++argv;
	}
	
	if(!aChoisiSonCompte)
	{
		struct passwd * pInfosCompte = getpwuid(0);
		if(!pInfosCompte) { fprintf(stderr, "# uid %d: compte inexistant.\n", 0); exit(1); }
		memcpy(&g_infosCompte, pInfosCompte, sizeof(struct passwd));
	}
	
	*pargv = argv;
}

/*- Ordonnancement -----------------------------------------------------------*/

#ifndef TEST

int main(int argc, char * argv[])
{
	++argv;
	const char * chemin;
	
	initialiserUtilises(argv);
	initialiserLire();
	GlobClasseInitialiser();
	
	analyserParametres(&argv);
	
	if(!argv[0])
	{
		fprintf(stderr, "# Mais je lance quoi, moi?\n");
		return -1;
	}
	if((chemin = verifier(argv)))
	{
		basculerCompte();
		return lancer(chemin, argv, environ);
	}
	fprintf(stderr, "# On ne vous trouve pas les droits pour %s.\n", argv[0]);
	return -1;
}

#else

char g_aff[0x4000];
char * affSpeciaux(Crible * crible, const char * source)
{
	char * ptr;
	for(--source, ptr = g_aff; *++source;)
		if(*source >= ' ')
			*ptr++ = *source;
		else
		{
			strcpy(ptr, "[33m");
			while(*++ptr) {}
			if(*source == CribleSpeciaux(crible)[0])
			{
				strcpy(ptr, " | ");
				while(*++ptr) {}
			}
			else
			{
				*ptr++ = '\\';
				int i;
				char c;
				for(i = 3, c = *source; --i >= 0; c /= 8)
					ptr[i] = '0' + c % 8;
				*(ptr += 3) = 0;
			}
			strcpy(ptr, "[0m");
			while(*++ptr) {}
		}
	*ptr = 0;
	return g_aff;
}

int testerPreparer(const char * source, const char * attendu)
{
	Glob g;
	char preparation[0x4000];
	char spe[2];
	strcpy(preparation, source);
	if(!glob_init(&g, preparation))
	{
		fprintf(stderr, "# Impossible de préparer \"%s\".", source);
		return -1;
	}
	if(strcmp(g.crible, attendu) != 0)
	{
		fprintf(stderr, "# Résultat inattendu pour la préparation de \"%s\":\n", source);
		fprintf(stderr, "\t%s\t(attendu)\n", affSpeciaux((Crible *)&g, attendu));
		fprintf(stderr, "\t%s\t(obtenu)\n", affSpeciaux((Crible *)&g, g.crible));
		return -1;
	}
	return 0;
}

int main(int argc, char * argv[])
{
	initialiserUtilises(argv);
	initialiserLire();
	GlobClasseInitialiser();
	
	#ifdef TEST_PREPARER_0
	int r = 0;
	if(testerPreparer("/bin/truc premier coucou\\ ah  b  c  d\\ \\ e", "/bin/truc\003premier\003coucou ah\003b\003c\003d  e") < 0) r = -1;
	if(testerPreparer("/bin/truc pre\004ier coucou\\ ah  \003  c  d\\ \\ e", "/bin/truc\005pre\004ier\005coucou ah\005\003\005c\005d  e") < 0) r = -1;
	return r;
	#endif
}

#endif
