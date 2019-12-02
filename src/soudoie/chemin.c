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

#include <string.h>

#define TASSE \
	{ \
		if(lf > ld) \
		{ \
			if(e < ld) \
				memmove(e, ld, lf - ld); \
			e += lf - ld; \
		} \
		ld = lf; \
	}

void semirealpath(char * chemin)
{
	char * ld, * lf, * e, *ptr;
	
	/* Calage sur le premier / */
	for(lf = chemin - 1; *++lf && *lf != '/';) {}
	
	e = ld = lf;
	while(*ld)
	{
		while(*++lf && *lf != '/') {}
		if(lf == ld + 1)
		{
			if(*lf == '/') /* Deux / d'affilée. */
				++ld;
			else /* / final */
				TASSE;
			continue;
		}
		else if(ld[1] == '.')
		{
			if(ld[2] == '.' && lf == ld + 3) /* /.. */
			{
				/* Peut-on manger le dernier dossier écrit? */
				for(ptr = e; --ptr >= chemin && *ptr != '/';) {}
				if(ptr < chemin || (ptr[1] == '.' && (e == ptr + 2 || (e == ptr + 3 && ptr[2] == '.')))) /* Rien à manger, ou seulement des ./ ou ../ initiaux qu'on ne pourra remonter. */
				{
					TASSE; /* On pousse tel quel notre /.. */
				}
				else
				{
					e = ptr;
					ld = lf;
				}
			}
			else if(lf == ld + 2) /* /. */
			{
				ld = lf;
				continue;
			}
		}
		TASSE;
	}
	*e = 0;
}
