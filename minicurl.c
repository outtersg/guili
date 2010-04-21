/*
 * Copyright (c) 2008 Guillaume Outters
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

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <stdlib.h>
#include <strings.h>
#include <fcntl.h>

#define FINI -3

struct bloc
{
	char * mem;
	int physique;
	int logique;
	int pos;
};

int engranger(int f, struct bloc * b, int quoiEncore)
{
	int t;
	if(b->logique + quoiEncore > b->physique)
	{
		b->mem = b->mem ? realloc(b->mem, b->physique + quoiEncore) : malloc(quoiEncore);
		b->physique += quoiEncore;
	}
	t = read(f, &b->mem[b->logique], quoiEncore);
	b->logique += t;
	return t;
}

int lire(int f, struct bloc * b, int quoi)
{
	int p;
	
	/* On vire les données lues auparavant. */
	
	if(b->pos > 0)
	{
		memmove(&b->mem[0], &b->mem[b->pos], b->logique - b->pos);
		b->logique -= b->pos;
		b->pos = 0;
	}
	
	/* Lecture. */
	
	if(quoi == -1) /* On cherche un \r\n. */
	{
		p = 0;
		while(1)
		{
			for(; p < b->logique - 2; ++p)
				if(b->mem[p] == '\r' && b->mem[p + 1] == '\n')
					return (b->pos = p + 2) - 2;
			if(engranger(f, b, 0x10000) == 0)
				return (b->pos = p) ? p : FINI;
		}
	}
	else if(quoi > 0) /* Un bête bloc mémoire. */
	{
		if(b->logique < quoi)
			engranger(f, b, quoi - b->logique);
		if(b->logique == 0)
			return FINI;
		else
			return (b->pos = b->logique > quoi ? quoi : b->logique);
	}
}

void obtenir(char * url, int mode)
{
	int moi, sortie;
	int z, t;
	char * debut, * fin, * requete;
	struct hostent * infos;
	struct sockaddr_in adresse;
	struct bloc b;
	
	/* Chaussette. */
	
	moi = socket(AF_INET, SOCK_STREAM, 0);
	
	/* Adresse. */
	
	for(fin = url, z = 3; z > 0; ++fin)
		if(*fin == '/')
			if(--z == 1)
				debut = fin + 1;
	--fin;
	*fin = 0;
	infos = gethostbyname(debut);
	adresse.sin_family = infos->h_addrtype;
	bcopy(infos->h_addr_list[0], &adresse.sin_addr, infos->h_length);
	
	adresse.sin_port = htons(80);
	
	/* Connexion. */
	
	connect(moi, (struct sockaddr *)&adresse, sizeof(adresse));
	
	/* Demande. */
	
	requete = alloca(strlen(fin + 1) + 5 + 11 + 6 + strlen(debut) + 2 + 13 + 2);
	strcpy(requete, "GET /");
	strcat(requete, fin + 1);
	strcat(requete, " HTTP/1.1\r\n");
	strcat(requete, "Host: ");
	strcat(requete, debut);
	strcat(requete, "\r\n");
	strcat(requete, "Accept: */*\r\n\r\n");
	write(moi, requete, strlen(requete));
	
	*fin = '/';
	
	/* Lecture. */
	
	b.mem = NULL;
	b.physique = 0;
	b.logique = 0;
	b.pos = 0;
	
	while((t = lire(moi, &b, -1)) >= 0)
	{
		write(2, "\n", 1);
		write(2, &b.mem[0], t);
		if(t == 0) break;
		if(strncmp(&b.mem[0], "Location: ", 10) == 0)
		{
			b.mem[t] = 0;
			obtenir(b.mem, mode);
			break;
		}
	}
	
	if(t == 0) /* Si on est sorti pour cause ligne vide (on en est venu à bout des en-têtes), on va pouvoir lire le vrai contenu. */
	{
		for(fin = url; *fin;)
			if(*++fin == '/')
				debut = fin;
		
		write(2, debut + 1, strlen(debut + 1));
		write(2, "\n", 1);
		if(mode == 0)
			sortie = 1;
		else if((sortie = open(debut + 1, O_WRONLY|O_CREAT, 0700)) < 0)
			perror("open");
		if(sortie >= 0)
		{
			while((t = lire(moi, &b, 0x10000)) >= 0)
				write(sortie, &b.mem[0], t);
			if(sortie > 1) close(sortie);
		}
	}
	
	/* Fermeture. */
	
	if(b.mem)
		free(b.mem);
	close(moi);
}

int main(int argc, char ** argv)
{
	int mode = 0;
	while(*++argv)
		if(strcmp(*argv, "-O") == 0)
			mode = 1;
		else if(strcmp(*argv, "-s") != 0 && strcmp(*argv, "-L") != 0)
			break;
		
	obtenir(&argv[0][0], mode);
	
	return 0;
}
