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

map_t *map_load_aos(const char *fname)
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
	if(map == NULL)
	{
		error_perror("map_load_aos: malloc(map)");
		fclose(fp);
		return NULL;
	}
	map->udtype = UD_MAP;
	map->xlen = 512;
	map->ylen = 64;
	map->zlen = 512;
	map->pillars = malloc(512*512*sizeof(uint8_t *));
	if(map->pillars == NULL)
	{
		error_perror("map_load_aos: malloc(map->pillars)");
		map_free(map);
		fclose(fp);
		return NULL;
	}
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
		
		pillar_temp[0] = (ti>>2)-2;
		map->pillars[pi] = malloc(ti);
		// TODO: check if NULL
		memcpy(map->pillars[pi], pillar_temp, ti);
	}
	
	fclose(fp);
	
	return map;
}

map_t *map_load_icemap(const char *fname)
{
	uint8_t pillar_temp[(256+1)*4];
	int x,z,pi;
	int i;
	
	FILE *fp = fopen(fname, "rb");
	if(fp == NULL)
	{
		error_perror("map_load_icemap");
		return NULL;
	}
	
	uint8_t tag[8];
	tag[7] = 0;
	
	fread(tag, 8, 1, fp);
	if(memcmp(tag, "IceMap\x1A\x01", 8))
	{
		// don't spew an error, this is useful for autodetection mode
		//fprintf(stderr, "map_load_icemap: not an IceMap v1 file\n");
		fclose(fp);
		return NULL;
	}
	
	map_t *map = malloc(sizeof(map_t));
	if(map == NULL)
	{
		error_perror("map_load_icemap: malloc(map)");
		fclose(fp);
		return NULL;
	}
	map->udtype = UD_MAP;
	map->pillars = NULL;
	
	int taglen;
	for(;;)
	{
		tag[7] = '\0';
		fread(tag, 7, 1, fp);
		
		if(!memcmp(tag,"       ",7))
			break;
		
		taglen = fgetc(fp);
		if(taglen == -1)
		{
			fprintf(stderr, "map_load_icemap: premature end!\n");
			map_free(map);
			fclose(fp);
			return NULL;
		} else if(taglen == 255) {
			if(fread(&taglen, 4, 1, fp) != 1)
			{
				fprintf(stderr, "map_load_icemap: premature end!\n");
				map_free(map);
				fclose(fp);
				return NULL;
			}
		}
		
		if(!memcmp(tag,"MapData",7))
		{
			if(map->pillars != NULL)
			{
				fprintf(stderr, "map_load_icemap: more than one MapData!\n");
				map_free(map);
				fclose(fp);
				return NULL;
			}
			
			fread(&(map->xlen), 2, 1, fp);
			fread(&(map->ylen), 2, 1, fp);
			fread(&(map->zlen), 2, 1, fp);
			map->pillars = malloc(map->xlen*map->zlen*sizeof(uint8_t *));
			if(map->pillars == NULL)
			{
				error_perror("map_load_icemap: malloc(map->pillars)");
				map_free(map);
				fclose(fp);
				return NULL;
			}
			
			printf("mapdata %i %ix%ix%i\n"
				,taglen
				,map->xlen,map->ylen,map->zlen);
			
			// load data
			for(z = 0, pi = 0; z < map->zlen; z++)
			for(x = 0; x < map->xlen; x++, pi++)
			{
				int ti = 4;
				
				// TODO: check if someone's trying to blow the size
				for(;;)
				{
					uint8_t n = fgetc(fp);
					uint8_t s = fgetc(fp);
					uint8_t e = fgetc(fp);
					uint8_t a = fgetc(fp);
					
					uint8_t qlen = (n == 0 ? e-s+1 : n-1);
					
					pillar_temp[ti++] = n;
					pillar_temp[ti++] = s;
					pillar_temp[ti++] = e;
					pillar_temp[ti++] = a;
					
					for(i = 0; i < qlen; i++)
					{
						uint8_t b = fgetc(fp);
						uint8_t g = fgetc(fp);
						uint8_t r = fgetc(fp);
						uint8_t t = fgetc(fp);
						
						pillar_temp[ti++] = b;
						pillar_temp[ti++] = g;
						pillar_temp[ti++] = r;
						pillar_temp[ti++] = t;
					}
					
					if(n == 0)
						break;
				}
				
				pillar_temp[0] = (ti>>2)-2;
				map->pillars[pi] = malloc(ti);
				// TODO: check if NULL
				memcpy(map->pillars[pi], pillar_temp, ti);
			}
			
			
		} else if(!memcmp(tag,"MetaInf",7)) {
			// TODO!
			if(taglen > 0)
				fseek(fp, taglen, SEEK_CUR);
		} else {
			if(taglen > 0)
				fseek(fp, taglen, SEEK_CUR);
		}
	}
	
	if(map->pillars == NULL)
	{
		fprintf(stderr, "map_load_icemap: MapData missing!\n");
		map_free(map);
		fclose(fp);
		return NULL;
	}
	
	fclose(fp);
	
	return map;
}

int map_save_icemap(map_t *map, const char *fname)
{
	int x,z,pi;
	int i;
	
	FILE *fp = fopen(fname, "wb");
	if(fp == NULL)
	{
		error_perror("map_save_icemap");
		return 1;
	}
	
	fwrite("IceMap\x1A\x01", 8, 1, fp);
	
	// TODO: meta info
	
	fwrite("MapData\xFF", 8, 1, fp);
	
	// calculate map length
	int32_t maplen = 6;
	for(z = 0, pi = 0; z < map->zlen; z++)
	for(x = 0; x < map->xlen; x++, pi++)
	{
		uint8_t *p = map->pillars[pi];
		
		p += 4;
		
		for(;;)
		{
			int n = (int)p[0];
			
			if(n == 0)
			{
				maplen += 4*((((int)p[2])-(int)p[1])+1);
				maplen += 4;
				break;
			} else {
				maplen += 4*n;
				p += 4*n;
			}
		}
	}
	
	// write map data
	uint16_t xlen = map->xlen;
	uint16_t ylen = map->ylen;
	uint16_t zlen = map->zlen;
	fwrite(&maplen, 4, 1, fp);
	fwrite(&xlen, 2, 1, fp);
	fwrite(&ylen, 2, 1, fp);
	fwrite(&zlen, 2, 1, fp);
	for(z = 0, pi = 0; z < map->zlen; z++)
	for(x = 0; x < map->xlen; x++, pi++)
	{
		uint8_t *pb = (map->pillars[pi])+4;
		uint8_t *p = pb;
		
		for(;;)
		{
			int n = (int)p[0];
			
			if(n == 0)
			{
				p += 4*(((int)p[2])-((int)p[1])+1);
				p += 4;
				break;
			} else {
				p += 4*n;
			}
		}
		
		fwrite(pb, p-pb, 1, fp);
	}
	
	// write end
	fwrite("       \x00", 8, 1, fp);
	
	// close
	fclose(fp);
	
	return 0;
}

void map_free(map_t *map)
{
	if(map == NULL)
		return;
	
	if(map->pillars != NULL)
		free(map->pillars);
	
	free(map);
}
