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

#include "me.h"

void me_commencer(ME * me)
{
	bzero(me->marqueurs, (strlen(me->masque) + 1) * sizeof(me->marqueurs[0]));
	me->dernierMarqueur = -1;
	me->nMarqueurs = 0;
	me_marquer(me, 0);
}

void me_passer(ME * me, int pos)
{
	if(me->marqueurs[pos])
	{
		switch(me->masque[pos])
		{
			case ME_FIN:
				me_demarquer(me, pos);
				break;
			case ME_NORMAL:
				me_demarquer(me, pos);
				me_marquer(me, pos + 1);
				break;
			case ME_PLUS:
			case ME_ETOILE:
				me_marquer(me, pos + 1);
				break;
		}
	}
}

void me_marquer(ME * me, int pos)
{
	++me->marqueurs[pos];
	++me->nMarqueurs;
	if(me->masque[pos] == ME_ETOILE)
		me_marquer(me, pos + 1);
	if(pos > me->dernierMarqueur)
		me->dernierMarqueur = pos;
}

void me_demarquer(ME * me, int pos)
{
	--me->marqueurs[pos];
	--me->nMarqueurs;
	if(!me->marqueurs[pos] && me->nMarqueurs && pos == me->dernierMarqueur)
	{
		while(!me->marqueurs[--pos]) {}
		me->dernierMarqueur = pos;
	}
}
