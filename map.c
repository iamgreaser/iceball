/*
    This file is part of Iceball.

    Iceball is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Iceball is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Iceball.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "common.h"

map_t *map_load_aos(char *fname)
{
	uint8_t pillar_temp[(256+1)*4];
	int x,z,pi;
	int i;
	
	FILE *fp = fopen(fname, "rb");
	if(fp == NULL)
	{
		error_perror("map_load_aos");
		return NULL;
	}
	
	map_t *map = malloc(sizeof(map_t));
	// TODO: check if NULL
	map->xlen = 512;
	map->ylen = 64;
	map->zlen = 512;
	map->pillars = malloc(512*512*sizeof(uint8_t *));
	// TODO: check if NULL
	
	// load data
	for(z = 0, pi = 0; z < 512; z++)
	for(x = 0; x < 512; x++, pi++)
	{
		int ti = 4;
		
		// TODO: check if someone's trying to blow the size
		for(;;)
		{
			uint8_t n = fgetc(fp);
			uint8_t s = fgetc(fp);
			uint8_t e = fgetc(fp);
			uint8_t a = fgetc(fp);
			
			uint8_t xlen = (n == 0 ? e-s+1 : n-1);
			
			pillar_temp[ti++] = n;
			pillar_temp[ti++] = s;
			pillar_temp[ti++] = e;
			pillar_temp[ti++] = a;
			
			for(i = 0; i < xlen; i++)
			{
				uint8_t b = fgetc(fp);
				uint8_t g = fgetc(fp);
				uint8_t r = fgetc(fp);
				fgetc(fp); // skip lighting
				
				pillar_temp[ti++] = b;
				pillar_temp[ti++] = g;
				pillar_temp[ti++] = r;
				pillar_temp[ti++] = BT_SOLID_BREAKABLE;
			}
			
			if(n == 0)
				break;
		}
		
		pillar_temp[0] = (ti>>2)-1;
		map->pillars[pi] = malloc(ti);
		// TODO: check if NULL
		memcpy(map->pillars[pi], pillar_temp, ti);
	}
	
	fclose(fp);
	
	return map;
}

map_t *map_load_bts(char *fname)
{
	// TODO!
	return NULL;
}

void map_free(map_t *map)
{
	if(map == NULL)
		return;
	
	if(map->pillars != NULL)
		free(map->pillars);
	
	free(map);
}
