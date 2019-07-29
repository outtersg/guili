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

#ifndef _SOUDOIE_CRIBLE_H
#define _SOUDOIE_CRIBLE_H

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

/* Découpe une ligne de source.
 * Renvoie le caractère utilisé pour IFS, ou -1 en cas d'erreur.
 * Paramètres:
 *   crible
 *     Crible à préparer. Sa classe doit être renseignée (porte les métacaractères, etc.).
 *   source
 *     Chaîne à lire.
 */
char * preparer(Crible * crible, char * source);

#endif
