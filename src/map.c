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
map_t *map_parse_root(const char *dend, const char *data, int xlen, int ylen, int zlen, int wipe_lighting)
{
	// TODO: refactor a bit
	
	uint8_t pillar_temp[(256+1)*4];
	int i,x,z,pi;
	
	int taglen = (int)(dend-data);
	
	map_t *map = malloc(sizeof(map_t));
	if(map == NULL)
	{
		error_perror("map_parse_root: malloc");
		return NULL;
	}
	
	map->udtype = UD_MAP;
	
	map->xlen = xlen;
	map->ylen = ylen;
	map->zlen = zlen;
	
	map->pillars = malloc(map->xlen*map->zlen*sizeof(uint8_t *));
	if(map->pillars == NULL)
	{
		error_perror("map_parse_root: malloc(map->pillars)");
		map_free(map);
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
			uint8_t n = (uint8_t)*(data++);
			uint8_t s = (uint8_t)*(data++);
			uint8_t e = (uint8_t)*(data++);
			uint8_t a = (uint8_t)*(data++);
			
			uint8_t qlen = (n == 0 ? e-s+1 : n-1);
			
			pillar_temp[ti++] = n;
			pillar_temp[ti++] = s;
			pillar_temp[ti++] = e;
			pillar_temp[ti++] = a;
			
			for(i = 0; i < qlen; i++)
			{
				uint8_t b = (uint8_t)*(data++);
				uint8_t g = (uint8_t)*(data++);
				uint8_t r = (uint8_t)*(data++);
				uint8_t t = (uint8_t)*(data++);
				
				if(wipe_lighting) t = 1;
				
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
	
	return map;
}

map_t *map_parse_aos(int len, const char *data)
{
	int i;
	
	if(data == NULL)
		return NULL;
	
	const char *p = data;
	const char *dend = data + len;
	
	return map_parse_root(dend, data, 512, 64, 512, 1);
}

map_t *map_parse_icemap(int len, const char *data)
{
	int i;
	
	if(data == NULL)
		return NULL;
	
	const char *p = data;
	const char *dend = data + len;
	
	if(memcmp(p, "IceMap\x1A\x01", 8))
	{
		// don't spew an error, this is useful for autodetection mode
		//fprintf(stderr, "map_load_icemap: not an IceMap v1 file\n");
		return NULL;
	}
	p += 8;
	
	map_t *map = NULL;
	
	int taglen;
	for(;;)
	{
		const char *tag = p;
		if(!memcmp(tag,"       ",7))
			break;
		
		p += 7;
		if(p >= dend)
		{
			fprintf(stderr, "map_load_icemap: premature end!\n");
			map_free(map);
			return NULL;
		}
		
		taglen = (uint8_t)*(p++);
		if(taglen == 255) {
			if(p+4 > dend)
			{
				fprintf(stderr, "map_load_icemap: premature end!\n");
				map_free(map);
				return NULL;
			}
			taglen = (int)*(uint32_t *)p;
			p += 4;
		}
		
		if(!memcmp(tag,"MapData",7))
		{
			if(map != NULL && map->pillars != NULL)
			{
				fprintf(stderr, "map_load_icemap: more than one MapData!\n");
				map_free(map);
				return NULL;
			}
			
			int xlen = ((uint16_t *)p)[0];
			int ylen = ((uint16_t *)p)[1];
			int zlen = ((uint16_t *)p)[2];
			p += 6;
			
			map = map_parse_root(p+taglen, p, xlen, ylen, zlen, 0);
			p += taglen-6;
		} else if(!memcmp(tag,"MetaInf",7)) {
			// TODO!
			if(taglen > 0)
				p += taglen;
		} else {
			if(taglen > 0)
				p += taglen;
		}
	}
	
	if(map == NULL || map->pillars == NULL)
	{
		fprintf(stderr, "map_load_icemap: MapData missing!\n");
		map_free(map);
		return NULL;
	}
	
	printf("all good.\n");
	return map;
}

map_t *map_load_aos(const char *fname)
{
	int flen;
	char *data = net_fetch_file(fname, &flen);
	if(data == NULL)
		return NULL;
	
	map_t *ret = map_parse_aos(flen, data);
	free(data);
	return ret;
}

map_t *map_load_icemap(const char *fname)
{
	int flen;
	char *data = net_fetch_file(fname, &flen);
	if(data == NULL)
		return NULL;
	
	map_t *ret = map_parse_icemap(flen, data);
	free(data);
	return ret;
}

char *map_serialise_icemap(map_t *map, int *len)
{
	// TODO: make map_save_icemap rely on this
	int x,z,pi;
	int i;
	
	if(map == NULL)
	{
		fprintf(stderr, "map_serialise_icemap: map is NULL!\n");
		return NULL;
	}
	
	// calculate map length
	int32_t maplen = 0;
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
	
	int buflen = 8
		+8+4+6+maplen
		+8;
	
	char *buf = malloc(buflen);
	// TODO check if NULL
	
	memcpy(buf, "IceMap\x1A\x01MapData\xFF", 16);
	
	*(uint32_t *)&buf[16] = 6+maplen;
	*(uint16_t *)&buf[20] = map->xlen;
	*(uint16_t *)&buf[22] = map->ylen;
	*(uint16_t *)&buf[24] = map->zlen;
	char *zf = &buf[26];
	
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
		
		memcpy(zf, pb, p-pb);
		zf += p-pb;
	}
	memcpy(buf+buflen-8, "       \x00", 8);
	
	//printf("derp!\n");
	*len = buflen;
	
	return buf;
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
