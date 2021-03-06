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
/* Suis Intéressé par le Dézingage des Obstructions, Négatives, Interdictions et Empêchements */
/* Simple Outil à Détricoter les Obstacles dans ma Marche Inéluctable vers la Suprématie/Supervision/Souveraineté sur les Exécutables */
/* À FAIRE: syslog systématique */
/* À FAIRE: validation via PCRE. Oui, ça ouvre une faille par rapport à du tout compilé statiquement, mais ça ferme celle due à ce que, fatigués de taper l'ensemble des combinaisons possibles, les sudoers finissent bourrés d'étoiles (ex.: systemctl * nginx). */
/* À FAIRE: env (HOME, etc.) */
/* À FAIRE: multi-ligne: www: /sbin/service restart nginx\n\t/sbin/service restart php-fpm */
/* À FAIRE: affectations: OPS_SERVICE = (start|restart|stop) */
/* À FAIRE: include. ATTENTION: il faut faire un fseek sur le fichier pour ne pas perdre ce que g_tampon possède de la suite. */
/* À FAIRE: gestion des groupes à la sudo (%groupe). Bien utiliser les groupes secondaires (les entreposer quelque part). */

#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <limits.h>
#include <stdlib.h>
#include <errno.h>
#include <grp.h>

#include "crible.h"
#include "glob.h"
#include "lecture.h"
#include "auto.h"
#include "env.h"
#include "chemin.h"

extern char ** environ;

AutoContexte g_contexte;
#define UTILISE_ARGV 1
#define UTILISE_SPECIAL 2
#define UTILISE_DEF 3
char g_utilises[' ']; /* Caractères spéciaux utilisés par notre argv, que nous ne pourrons donc pas utiliser comme séparateurs. */
char g_flemmard = 0; /* Fait-on vraiment, ou se contente-t-on de dire? */

#define E_PASIMPL -2

/*- Utilitaires --------------------------------------------------------------*/

int lancer(const char * chemin, char * const argv[], char * const envp[])
{
	return execve(chemin, argv, envp);
}

/*- Exécution ----------------------------------------------------------------*/

void basculerCompte(AutoContexte * contexte)
{
	gid_t groupes[NGROUPS_MAX + 1];
	int nGroupes = -1;
	struct group * pGroupe;
	char ** pMembre;
	
	groupes[++nGroupes] = contexte->execute.pw_gid;
	while((pGroupe = getgrent()))
	{
		if(pGroupe->gr_gid == contexte->execute.pw_gid) continue; /* Celui-là a déjà été fait. */
		
		for(pMembre = pGroupe->gr_mem; *pMembre; ++pMembre)
			if(0 == strcmp(*pMembre, contexte->execute.pw_name))
			{
				if(++nGroupes >= NGROUPS_MAX)
				{
					fprintf(stderr, "# getgrent(%d): trop de groupes; %s ignoré\n", contexte->execute.pw_uid, pGroupe->gr_name);
					--nGroupes;
					break;
				}
				groupes[nGroupes] = pGroupe->gr_gid;
				break;
			}
	}
	endgrent();
	++nGroupes;
	
	if(setgid(contexte->execute.pw_gid)) { fprintf(stderr, "# setgid(%d): %s\n", contexte->execute.pw_gid, strerror(errno)); exit(1); }
	if(setgroups(nGroupes, groupes)) { fprintf(stderr, "# setgroups(%d): %s\n", nGroupes, strerror(errno)); exit(1); }
	if(setuid(contexte->execute.pw_uid)) { fprintf(stderr, "# setuid(%d): %s\n", contexte->execute.pw_uid, strerror(errno)); exit(1); }
}

/*- Vérification -------------------------------------------------------------*/

/*--- Définitions ---*/

int glob_verifier(Glob * g, char ** commande);

/*--- Lecture des cribles ---*/

#define DECALER { if(!debutProchainMemMove) e = l; else if((t = l - debutProchainMemMove) > 0) { if(e > source) memmove(e, debutProchainMemMove, t); debutProchainMemMove = l; e += t; } }

char * preparer(Crible * crible, char * source, int honorerGuillemets)
{
	char * l; /* Pointeur en lecture. */
	char * e; /* Pointeur d'écriture. */
	char * p;
	char * debutProchainMemMove = NULL;
	char * pPrecedentSpe = source - 1;
	char nouveauSpe;
	char precedentSpe;
	int numSpe, special;
	int t;
	char * speciaux = CribleSpeciaux(crible);
	char guillemet = 0;
	
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
			++special;
		}
	}
	
	/* Parcours */
	
	for(l = e = source; *l; ++l)
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
		else if((*l == '"' || *l == '\'') && honorerGuillemets && (!guillemet || guillemet == *l))
		{
			DECALER;
			debutProchainMemMove = l + 1;
			
			guillemet = guillemet ? 0 : *l; /* Indication sur le guillemet fermant. */
		}
		else if(crible->c->carSpeciaux[*l] && !guillemet)
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
		/* À FAIRE: traiter les $, pour effectuer des remplacements. */
	DECALER;
	*e = 0;
	
	return source;
}

/*--- Vérification des cribles ---*/

const char * verifier(AutoContexte * contexte)
{
	/* Idéalement la résolution de binaire (recherche dans le $PATH) se fait en tant que l'utilisateur cible (1), cependant nous avons besoin par la suite d'être root pour pouvoir lire les fichiers de config (2). Donc idéalement, on ferait un setuid(compte); résolution(); setuid(0); vérif(); setuid(compte);, cependant on optera pour la solution plus simple setuid(0); résolution(); vérif(); setuid(compte);.
	 * 1. pour ne pas trouver en root un binaire auquel le compte n'aura pas accès.
	 * 2. la résolution précède nécessairement la lecture de la config: cette dernière contient des références au chemin absolu résolu, donc si on veut pouvoir faire dans la même passe lecture de config et son application (pour pouvoir s'arrêter à la première correspondance trouvée), la résolution doit avoir été faite au moment où on rentre dans la lecture de config.
	 *    Notons qu'on ne peut "simplement" ouvrir le descripteur de fichier en root préalablement, car on sera amenés à ouvrir dynamiquement (directives include) d'autres fichiers durant la lecture du fichier principal.
	 */
	
	char * ptr;
	
	/* Changement d'utilisateur. Nous avons besoin d'être root pour lire le fichier de conf. */
	
	if(setuid(0)) { fprintf(stderr, "# setuid(%d): %s\n", 0, strerror(errno)); exit(1); }
	
	/* On passe tous les arguments d'affectation d'environnement. */
	
	while(contexte->argv[0])
	{
		for(ptr = contexte->argv[0]; (*ptr >= 'A' && *ptr <= 'Z') || *ptr == '_' || (*ptr >= '0' && *ptr <= '9') || (*ptr >= 'a' && *ptr <= 'z'); ++ptr) {}
		if(*ptr != '=')
			break;
		++contexte->argv;
	}
	
	/* L'exécutable doit être référencé par chemin absolu. Résolvons-le ici. */
	
	const char * chemin = cheminComplet(contexte->argv[0]);
	if(!chemin)
	{
		fprintf(stderr, "# %s: %s\n", contexte->argv[0], strerror(errno));
		return NULL;
	}
	
	/* Vérification. */
	
	char * argv0Original = contexte->argv[0];
	contexte->argv[0] = (char *)chemin;
	if(autorise(contexte) != AUTO_OUI) goto eAuto;
	contexte->argv[0] = argv0Original;
	
	/* Retour! */
	
	return chemin;
	
	contexte->argv[0] = argv0Original;
	eAuto:
	return NULL;
}

int quePuisJeFaire(AutoContexte * contexte)
{
	fprintf(stderr, "# Le listage des opérations autorisées n'est pas implémenté.\n");
	return E_PASIMPL;
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

static void securiser(char ** pChaine)
{
	char * bis;
	if(!(bis = (char *)malloc(strlen(*pChaine) + 1))) { fprintf(stderr, "# Impossible d'allouer pour sécuriser une chaîne de caractères."); exit(-1); }
	strcpy(bis, *pChaine);
	*pChaine = bis;
}

void analyserParametres(char *** pargv)
{
	char ** argv = *pargv;
	char aChoisiSonCompte = 0;
	char * ptr;
	struct passwd * pInfosCompte;
	
	if(!(pInfosCompte = getpwuid(getuid()))) { fprintf(stderr, "# getpwuid(%d): mon propre compte n'est pas référencé dans le système. Bien dommage!\n", getuid()); exit(1); }
	memcpy(&g_contexte.executant, pInfosCompte, sizeof(struct passwd));
	/* Les chaînes de caractères doivent être sécurisées, car elles seront écrasées par le getpwuid suivant. */
	securiser(&g_contexte.executant.pw_name);
	securiser(&g_contexte.executant.pw_dir);
	securiser(&g_contexte.executant.pw_shell);
	
	while(*argv)
	{
		if(0 == strcmp(*argv, "-u"))
		{
			if(!argv[1]) { fprintf(stderr, "# -u <compte>: <compte> non renseigné.\n"); exit(1); }
			for(ptr = argv[1]; *ptr && *ptr >= '0' && *ptr <= '9'; ++ptr) {}
			if(*ptr)
				pInfosCompte = getpwnam(argv[1]);
			else
				pInfosCompte = getpwuid(atoi(argv[1]));
			if(!pInfosCompte) { fprintf(stderr, "# -u %s: compte inexistant.\n", argv[1]); exit(1); }
			aChoisiSonCompte = 1;
			++argv;
		}
		else if(0 == strcmp(*argv, "-n"))
		{
			/* À FAIRE: gérer, le jour où on gérera la saisie de mot de passe. */
		}
		else if(0 == strcmp(*argv, "-l"))
			g_flemmard = 1;
		else
			break;
		++argv;
	}
	
	if(!aChoisiSonCompte)
	{
		pInfosCompte = getpwuid(0);
		if(!pInfosCompte) { fprintf(stderr, "# uid %d: compte inexistant.\n", 0); exit(1); }
	}
	memcpy(&g_contexte.execute, pInfosCompte, sizeof(struct passwd));
	
	*pargv = argv;
}

/*- Ordonnancement -----------------------------------------------------------*/

#ifndef TEST

int main(int argc, char * argv[])
{
	++argv;
	const char * chemin;
	
	initialiserUtilises(argv);
	initialiserEnv();
	initialiserLire();
	GlobClasseInitialiser();
	
	analyserParametres(&argv);
	
	if(!argv[0])
	{
		if(g_flemmard)
			return quePuisJeFaire(&g_contexte);
		fprintf(stderr, "# Mais je lance quoi, moi?\n");
		return -1;
	}
	g_contexte.argv = argv;
	if((chemin = verifier(&g_contexte)))
	{
		if(g_flemmard)
			return 0;
		basculerCompte(&g_contexte);
		char ** env = environner(chemin, argv, &g_contexte);
		return lancer(chemin, g_contexte.argv, env);
	}
	if(!g_flemmard)
	fprintf(stderr, "# On ne vous trouve pas les droits pour %s.\n", g_contexte.argv[0]);
	return -1;
}

#endif
