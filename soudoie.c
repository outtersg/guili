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

int main(int argc, char * argv[])
{
	++argv;
	const char * chemin;
	
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

/*
	eval "`sed < soudoie.c -e '1,/^\/\* BUILD/d' -e '/^\*\//,$d'`"
*/
/* BUILD

cc -o soudoie soudoie.c && ( [ `id -u` -eq 0 ] && chmod 4755 soudoie || sudo sh -c 'chown 0:0 soudoie && chmod 4755 soudoie' )

*/
