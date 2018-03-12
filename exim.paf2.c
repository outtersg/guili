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

#include "version.h"
#include "local_scan.h"

static char * g_rejets = NULL;

#endif /* TEST */

static char * g_formule = NULL;

typedef struct Expr Expr;

static Expr * g_calcul = NULL;

Expr * expr_compiler(char * formule);
float expr_calculer(Expr * expr, float points);

float secondes(float points)
{
	if(!g_calcul)
	{
		if(!g_formule) g_formule = "p>=15?10+(p-15)*3:0";
		g_calcul = expr_compiler(g_formule);
	}
	return expr_calculer(g_calcul, points);
}

#ifndef TEST

/* ATTENTION: comme il est bien précisé dans la doc, les options doivent être en ORDRE ALPHABÉTIQUE */
optionlist local_scan_options[] = {
	{ "formule", opt_stringptr, &g_formule },
	{ "rejets", opt_stringptr, &g_rejets }
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
		#if (EXIM_MAJOR_VERSION == 4 && EXIM_MINOR_VERSION >= 90) || EXIM_MAJOR_VERSION >= 5
		smtp_printf("451- %s: %d\r\n", 0, "Attendez, je patine dans la choucroute", (int)ceil(points));
		#else
		smtp_printf("451- %s: %d\r\n", "Attendez, je patine dans la choucroute", (int)ceil(points));
		#endif
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
	float p = 0.0f;
	float ici;
	
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
	
	if(secondes(p) > 0.1)
	{
		int r;
		entreposerMessageAnalyse(bloc, t, fd);
		r = poireauter(p, return_text);
		return r;
	}
	
	return LOCAL_SCAN_ACCEPT;
}

/*- Expr ---------------------------------------------------------------------*/

struct Expr
{
	char type;
	union
	{
		struct { char * c; int t; } chaine;
		float n;
	} val;
	Expr * suite; // Élément suivant dans une chaîne en cours de découpe (avant assemblage), ou élément suivant dans une liste de paramètres.
	Expr * gauche; // EXPR_DECOUPE durant la phase de découpe.
	Expr * droite;
};

#define EXPR_ERREUR ((Expr *)-1)
#define EXPR_DECOUPE ((Expr *)-2)

#ifdef TEST

static char g_exprIndentation[256];

void expr__afficher(Expr * e, char * placeIndentation, char * monIndentation, char * indentationFils)
{
	if(!e || e == EXPR_DECOUPE)
		return;
	fprintf(stderr, "%s%s. [", g_exprIndentation, monIndentation);
	if(e == EXPR_ERREUR)
	{
		fprintf(stderr, "#ERR]\n");
		return;
	}
	switch(e->type)
	{
		case '<':
		case '>':
			fwrite(e->val.chaine.c, e->val.chaine.t, 1, stderr);
			fwrite("]", 1, 1, stderr);
			break;
		default:
			fprintf(stderr, "%c]", e->type);
			break;
	}
	switch(e->type)
	{
		case 'a':
			fwrite(" ", 1, 1, stderr);
			fwrite(e->val.chaine.c, e->val.chaine.t, 1, stderr);
			break;
		case 'f':
			fprintf(stderr, " %f", e->val.n);
			break;
	}
	fwrite("\n", 1, 1, stderr);
	int n = sprintf(placeIndentation, "%s%c  ", indentationFils, e->suite ? '|' : ' ');
	if(e->gauche)
		expr__afficher(e->gauche, placeIndentation + n, "/", "|");
	if(e->droite)
		expr__afficher(e->droite, placeIndentation + n, "\\", " ");
	*placeIndentation = 0;
	if(e->suite)
		expr__afficher(e->suite, placeIndentation, indentationFils, indentationFils);
}

void expr_afficher(Expr * e)
{
	g_exprIndentation[0] = 0;
	expr__afficher(e, g_exprIndentation, "", "");
}

void expr_afficherEntre(Expr * debut, Expr * fin)
{
	Expr ** ptrExpr;
	Expr * ptr;
	
	for(ptrExpr = &debut; *ptrExpr && *ptrExpr != EXPR_ERREUR && *ptrExpr != fin; ptrExpr = &(*ptrExpr)->suite) {}
	ptr = *ptrExpr;
	*ptrExpr = NULL;
	expr_afficher(debut);
	*ptrExpr = ptr;
}

#endif

Expr * nexpr(char type)
{
	Expr * expr = (Expr *)malloc(sizeof(Expr));
	expr->type = type;
	expr->suite = NULL;
	expr->gauche = NULL;
	expr->droite = NULL;
	return expr;
}

Expr * nexprDecoupe(char type, Expr *** ptrPtrExpr)
{
	Expr * expr;
	expr = **ptrPtrExpr = nexpr(type);
	*ptrPtrExpr = &expr->suite;
	expr->gauche = EXPR_DECOUPE;
	return expr;
}

Expr * expr_decouper(char * formule)
{
	Expr * debut = NULL;
	Expr ** ptrExpr = &debut;
	Expr * expr;
	char * ptr = formule;
	
	while(*ptr)
	{
		switch(*ptr)
		{
			case '?':
			case ':':
			case '(':
			case ')':
				expr = nexprDecoupe(*ptr, &ptrExpr);
				expr->val.chaine.c = ptr;
				expr->val.chaine.t = 1;
				++ptr;
				break;
			case '>':
			case '<':
				expr = nexprDecoupe(*ptr, &ptrExpr);
				expr->val.chaine.c = ptr;
				if(*++ptr == '=')
					++ptr;
				expr->val.chaine.t = ptr - expr->val.chaine.c;
				break;
			case '+':
			case '-':
			case '*':
			case '/':
				expr = nexprDecoupe(*ptr, &ptrExpr);
				expr->val.chaine.c = ptr;
				expr->val.chaine.t = 1;
				++ptr;
				break;
			default:
				if((*ptr >= '0' && *ptr <= '9') || *ptr == '.')
				{
					expr = nexprDecoupe('f', &ptrExpr);
					expr->val.n = strtof(ptr, &ptr);
				}
				else if(*ptr >= 'a' && *ptr <= 'z')
				{
					expr = nexprDecoupe('a', &ptrExpr);
					expr->val.chaine.c = ptr;
					while(*++ptr >= 'a' && *ptr <= 'z') {}
					expr->val.chaine.t = ptr - expr->val.chaine.c;
				}
				else
				{
					fprintf(stderr, "# Expression inconnue '%c' en position %d de %s\n", *ptr, (int)(ptr - formule), formule);
					/* À FAIRE: libérer la mémoire. */
					return NULL;
				}
				break;
		}
	}
	
	return debut;
}

static char g_prios[256];
static char g_fermantes[256];

Expr * expr_assemblerEntre(Expr * debut, Expr * fin)
{
	Expr * ptr;
	Expr * ptrMax;
	Expr * gauche;
	Expr * droite;
	Expr ** ptrExpr;
	char max;
	
	// S'il n'y rien.
	if(debut == fin)
		return NULL;
	// Ou qu'on est un seul élément déjà assemblé (le critère "un seul élément" ne suffit pas, car une parenthèse seule doit être assemblée pour au moins pouvoir passer par ses contrôles "ah tiens je n'ai personne à ma droite?).
	if(debut->suite == fin && debut->gauche != EXPR_DECOUPE)
		return debut;
	
	recherche:

	// Recherche du premier "opérateur" de plus forte priorité.
	
	ptrMax = NULL;
	max = -1;
	
	for(ptr = debut; ptr != fin; ptr = ptr->suite)
	{
		if(g_prios[ptr->type] > max)
		{
			ptrMax = ptr;
			max = g_prios[ptr->type];
			// Cas particulier: pour les machins ouvrants, on traite en priorité le dernier, donc celui qui vient d'être lu perd artificiellement un point (pour que l'éventuel suivant le remplace).
			if(g_fermantes[ptr->type])
				--max;
		}
	}
	
	// Euh, mais nous a-t-on donné à traiter quelque chose, déjà?
	
	if(!ptrMax)
		return NULL;
	
	// Et on traite.
	
	ptr = ptrMax; // Plus simple pour la suite.
	
	// Cas des parenthèses.
	
	if(g_fermantes[ptr->type])
	{
		// À la recherche de la fermante. Du fait de la bidouille "perd articiellement un point", on est certain qu'aucune autre ouvrante ne s'intercalera entre nous et notre fermante.
		for(ptrMax = ptr; ptrMax != fin; ptrMax = ptrMax->suite)
			if(ptrMax->type == g_fermantes[ptr->type])
			{
				if((droite = expr_assemblerEntre(ptr->suite, ptrMax)) == EXPR_ERREUR)
					return EXPR_ERREUR;
				
				ptr->type = '.';
				ptr->gauche = NULL;
				ptr->droite = droite;
				ptr->suite = ptrMax->suite;
				free(ptrMax);
				
				// Hop, une de réduite, on repart dans un vrai découpage!
				goto recherche;
			}
		fprintf(stderr, "# Élément %c en position %d de %s: impossible de trouver l'élément fermant avant le caractère %ld.\n", ptr->type, (int)(ptr->val.chaine.c - g_formule), g_formule, ptrMax ? (int)(ptrMax->val.chaine.c - g_formule) : strlen(g_formule));
		return EXPR_ERREUR;
	}
	
	// Cas des opérateurs.
	
	gauche = expr_assemblerEntre(debut, ptr);
	if(gauche && gauche->suite == ptr)
		gauche->suite = NULL;
	droite = expr_assemblerEntre(ptr->suite, fin);
	if(droite && droite->suite == fin)
		droite->suite = NULL;
	
	char attenduGauche = 0;
	char attenduDroite = 0;
	switch(ptr->type)
	{
		case '?':
			attenduGauche = 1;
			attenduDroite = ':';
			// À FAIRE: le cas a ? b ? c : d : e (un ? est suivi non de son :, mais d'un nouveau ?).
			break;
		case ':':
		case '>':
		case '<':
		case '+':
		case '-': // À FAIRE: le cas particulier de (- n).
		case '*':
		case '/':
			attenduGauche = attenduDroite = 1;
			break;
		default:
			// Nombre ou identifiant. On ne veut pas de feuille.
			attenduGauche = attenduDroite = 0;
			break;
	}
	if(!attenduGauche && gauche)
	{
		fprintf(stderr, "# Élément %c en position %d de %s: n'accepte pas d'élément à gauche.\n", ptr->type, (int)(ptr->val.chaine.c - g_formule), g_formule);
		return EXPR_ERREUR;
	}
	if(!attenduDroite && droite)
	{
		fprintf(stderr, "# Élément %c en position %d de %s: n'accepte pas d'élément à droite.\n", ptr->type, (int)(ptr->val.chaine.c - g_formule), g_formule);
		return EXPR_ERREUR;
	}
	if(attenduGauche && !gauche)
	{
		fprintf(stderr, "# Élément %c en position %d de %s: attend un élément à gauche.\n", ptr->type, (int)(ptr->val.chaine.c - g_formule), g_formule);
		return EXPR_ERREUR;
	}
	if(attenduDroite && !droite)
	{
		fprintf(stderr, "# Élément %c en position %d de %s: attend un élément à droite.\n", ptr->type, (int)(ptr->val.chaine.c - g_formule), g_formule);
		return EXPR_ERREUR;
	}
	if(attenduDroite > 1 && droite && droite->type != attenduDroite)
	{
		fprintf(stderr, "# Élément %c en position %d de %s: attend un élément %c à droite.\n", ptr->type, (int)(ptr->val.chaine.c - g_formule), g_formule, attenduDroite);
		return EXPR_ERREUR;
	}
	ptr->gauche = gauche;
	ptr->droite = droite;
	ptr->suite = NULL;
	
	return ptr;
}

Expr * expr_assembler(Expr * premiere)
{
	bzero(g_prios, 256);
	bzero(g_fermantes, 256);
	char c;
	g_fermantes['('] = ')';
	g_prios['*'] = g_prios['/'] = 0x10;
	g_prios['+'] = g_prios['-'] = 0x20;
	g_prios['<'] = g_prios['>'] = 0x30;
	g_prios['?'] = g_prios[':'] = 0x50;
	g_prios['('] = 0x70;
	
	for(c = 0; c < 0x7F; ++c)
		if(g_fermantes[c])
			g_prios[g_fermantes[c]] = g_prios[c] - 2; // Le -1 pour l'histoire du "artificiellement" plus loin.
	
	return expr_assemblerEntre(premiere, NULL);
}

Expr * expr_compiler(char * formule)
{
	return expr_assembler(expr_decouper(formule));
}

float expr_calculer(Expr * expr, float p)
{
	float a, b;
	switch(expr->type)
	{
		case '.':
			return expr_calculer(expr->droite, p);
		case 'f':
			return expr->val.n;
		case 'a':
			if(expr->val.chaine.t != 1 || expr->val.chaine.c[0] != 'p')
			{
				fprintf(stderr, "# Variable inconnue ");
				fwrite(expr->val.chaine.c, expr->val.chaine.t, 1, stderr);
				fwrite("\n", 1, 1, stderr);
				return NAN;
			}
			return p;
		case '?':
			expr = expr_calculer(expr->gauche, p) >= 0.1 ? expr->droite->gauche : expr->droite->droite;
			return expr_calculer(expr, p);
		case '+':
			return expr_calculer(expr->gauche, p) + expr_calculer(expr->droite, p);
		case '-':
			return expr_calculer(expr->gauche, p) - expr_calculer(expr->droite, p);
		case '*':
			return expr_calculer(expr->gauche, p) * expr_calculer(expr->droite, p);
		case '/':
			return expr_calculer(expr->gauche, p) / expr_calculer(expr->droite, p);
		case '>':
		case '<':
			a = expr_calculer(expr->gauche, p);
			b = expr_calculer(expr->droite, p);
			if(strncmp(expr->val.chaine.c, "<=", 2) == 0) return a <= b;
			if(strncmp(expr->val.chaine.c, ">=", 2) == 0) return a >= b;
			if(strncmp(expr->val.chaine.c, "<", 1) == 0) return a < b;
			if(strncmp(expr->val.chaine.c, ">", 1) == 0) return a > b;
		default:
			fprintf(stderr, "# Expression inconnue de type %c\n", expr->type);
			return NAN;
	}
}

/*- Test ---------------------------------------------------------------------*/

#ifdef TEST

void auSecours()
{
	fprintf(stderr, "# paf2 [-f <formule>] <fichier RFC 822> …\n");
	fprintf(stderr, "# Simule le passage d'un message dans un exim + paf2 (affiche le temps de blocage éventuel).\n");
	fprintf(stderr, "    -f <formule>\n");
	fprintf(stderr, "        Formule à appliquer au nombre de points pour obtenir le blocage en secondes.\n");
	exit(1);
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
			if(strcmp(*argv, "-f") == 0 && argv[1]) { g_formule = argv[1]; ++argv; continue; }
			
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
