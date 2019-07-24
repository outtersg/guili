/* Super Opérateur Universel, Daignez Ouvrir Immédiatement pour Exécution. */
/* Super Opérateur Universel, Daignez Ouvrir Ultérieurement pour Exécution. */
/* Super Utilisateur Respectable, Daignez Opérer Une Escalade. */
/* Super Utilisateur Ronchon, J'Ordonne Une Escalade. */
/* À FAIRE: syslog systématique */
/* À FAIRE: validation via PCRE. Oui, ça ouvre une faille par rapport à du tout compilé statiquement, mais ça ferme celle due à ce que, fatigués de taper l'ensemble des combinaisons possibles, les sudoers finissent bourrés d'étoiles (ex.: systemctl * nginx). */

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

extern char ** environ;

char g_chemin[PATH_MAX + 1];
struct passwd g_infosCompte;
#define UTILISE_ARGV 1
#define UTILISE_SPECIAL 2
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

typedef int (*FonctionVerif)(void * crible, char ** commande);

typedef struct
{
	char ifs;
	char * crible;
}
Glob;

typedef struct
{
	FonctionVerif verif;
	union
	{
		Glob glob;
	} d;
}
Crible;

int glob_verifier(Glob * g, char ** commande);

/*--- Lecture des cribles ---*/

#define TAILLE_TAMPON 0x10000

char g_tampon[TAILLE_TAMPON + 1];

#define DECALER if(debutProchainMemMove && l > debutProchainMemMove) { memmove(debutProchainMemMove - l + e, debutProchainMemMove, l - debutProchainMemMove); debutProchainMemMove = l; }

/* Découpe une ligne de source.
 * Renvoie le caractère utilisé pour IFS, ou -1 en cas d'erreur.
 */
char preparer(char * source)
{
	char * l; /* Pointeur en lecture. */
	char * e; /* Pointeur d'écriture. */
	char * p;
	char * debutProchainMemMove = NULL;
	char * pPrecedentIfs = source - 1;
	char ifs = '\003';
	char nouvelIfs;
	int i;
	
	for(l = e = source; *l; ++l, ++e)
		switch(*l)
		{
			case '\\':
				if(l[1])
				{
					/* Puisqu'on s'apprête à décaler, on traite l'éventuel précédent décalage en attente. */
					DECALER;
					++l;
					debutProchainMemMove = l;
				}
				break;
			case ' ':
			case '\t':
				*l = ifs;
				if(l == pPrecedentIfs + 1) /* Si l'on suit le précédent espace… */
				{
					DECALER;
					--e; /* … on en est la prolongation, et notre curseur en écriture n'avance pas. */
				}
				pPrecedentIfs = l;
				break;
			/* À FAIRE: traiter les guillemets. Attention: comment traiter un <espace>""<espace>? Il ne faut pas que les guillemets aient déjà simplifié, sans quoi l'<espace><espace> restant deviendra un seul <espace>. */
			/* À FAIRE: traiter les $, pour effectuer des remplacements. */
			/* Ouille, notre séparateur actuel est un caractère de la chaîne; changement de caractère en vue. */
			default:
				if(*l == ifs)
				{
					for(nouvelIfs = ifs, p = source; p < l && ++nouvelIfs;)
					{
						if(nouvelIfs == ' ')
						{
							/* Ne débordons pas sur les caractères imprimables. */
							fprintf(stderr, "# Trop de caractères spéciaux dans %s.\n", source); /* À FAIRE: aïe, on a modifié la chaîne; il faudrait en avoir une copie propre pour diagnostic. */
							return -1;
						}
						if(g_utilises[nouvelIfs])
							continue;
						for(p = source - 1; ++p < l;)
							if(*p == nouvelIfs) /* Zut, celui-ci aussi est pris. */
								break;
					}
					
					/* Ouf, un nouveau séparateur non utilisé. */
					
					for(p = source - 1; ++p < l;)
						if(*p == ifs)
							*p = nouvelIfs;
					ifs = nouvelIfs;
				}
				break;
		}
	DECALER;
	*e = 0;
	
	return ifs;
}

Crible * glob_init(Crible * c, char * source)
{
	char ifs;
	if((ifs = preparer(source)) == -1)
		return NULL;
	c->d.glob.ifs = ifs;
	c->d.glob.crible = (char *)malloc(strlen(source) + 1);
	strcpy(c->d.glob.crible, source);
	return c;
}

const char * verifier(char * argv[])
{
	/* À FAIRE: vérifier qu'il a vraiment le droit: /etc/soudeurs, par exemple. */
	
	/* Changement d'utilisateur. La vérification aura peut-être à accéder à des fichiers que seul le compte cible peut voir. */
	
	basculerCompte();
	
	const char * chemin = cheminComplet(argv[0]);
	if(!chemin)
		return NULL;
	
	return chemin;
}

/*--- Vérification des cribles ---*/

int glob_verifier(Glob * g, char ** commande)
{
	return -1;
}

/*- Initialisation -----------------------------------------------------------*/

void initialiserUtilises(char * argv[])
{
	char * p;
	bzero(g_utilises, ' ');
	while(*++argv)
		for(p = *argv; *p; ++p)
			if(*p > 0 && *p < ' ')
				g_utilises[(int)p] = UTILISE_ARGV;
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
	analyserParametres(&argv);
	
	if(!argv[0])
	{
		fprintf(stderr, "# Mais je lance quoi, moi?\n");
		return -1;
	}
	if((chemin = verifier(argv)))
		return lancer(chemin, argv, environ);
	fprintf(stderr, "# On ne vous trouve pas les droits pour %s.\n", argv[0]);
	return -1;
}

#else

char g_aff[0x4000];
char * affSpeciaux(const char * source, char ifs)
{
	char * ptr;
	for(--source, ptr = g_aff; *++source;)
		if(*source >= ' ')
			*ptr++ = *source;
		else
		{
			strcpy(ptr, "[33m");
			while(*++ptr) {}
			if(*source == ifs)
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
	char preparation[0x4000];
	char ifs;
	strcpy(preparation, source);
	if((ifs = preparer(preparation)) == -1)
	{
		fprintf(stderr, "# Impossible de préparer \"%s\".", source);
		return -1;
	}
	if(strcmp(preparation, attendu) != 0)
	{
		fprintf(stderr, "# Résultat inattendu pour la préparation de \"%s\":\n", source);
		fprintf(stderr, "\t%s\t(attendu)\n", affSpeciaux(attendu, ifs));
		fprintf(stderr, "\t%s\t(obtenu)\n", affSpeciaux(preparation, ifs));
		return -1;
	}
	return 0;
}

int main(int argc, char * argv[])
{
	initialiserUtilises(argv);
	
	int r = 0;
	if(testerPreparer("/bin/truc premier coucou\\ ah  b  c  d\\ \\ e", "/bin/truc\003premier\003coucou ah\003b\003c\003d  e") < 0) r = -1;
	if(testerPreparer("/bin/truc pre\004ier coucou\\ ah  \003  c  d\\ \\ e", "/bin/truc\005pre\004ier\005coucou ah\005\003\005c\005d  e") < 0) r = -1;
	return r;
}

#endif

/*
	eval "`sed < soudoie.c -e '1,/^\/\* BUILD/d' -e '/^\*\//,$d'`"
*/
/* BUILD

cc -o soudoie soudoie.c && ( [ `id -u` -eq 0 ] && chmod 4755 soudoie || sudo sh -c 'chown 0:0 soudoie && chmod 4755 soudoie' )

*/
/* TEST

cc -g -DTEST -o soudoie soudoie.c && ./soudoie

*/
