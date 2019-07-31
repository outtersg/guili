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

#ifndef _SOUDOIE_AUTO_H
#define _SOUDOIE_AUTO_H

#include <pwd.h>

#ifndef CONFIG
#ifdef TEST
#define CONFIG surdoues.test.conf
#else
#define CONFIG /etc/surdoues
#endif
#endif
#define CHAINE(x) #x
#define DECHAINE(x) CHAINE(x)
#define CHEMIN_CONFIG DECHAINE(CONFIG)

#define AUTO_OUI 0
#define AUTO_NON -1
#define AUTO_NE_SAIS_PAS -2

typedef struct
{
	char ** argv;
	struct passwd executant;
	struct passwd execute;
}
AutoContexte;

int autorise(AutoContexte * contexte);

#endif
