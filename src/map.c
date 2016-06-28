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

#define PILLAR_SIZE 1028 // (256 + 1) * 4

int map_parse_root(map_t *map, const char *dend, const char *data, int xlen, int ylen, int zlen, int wipe_lighting)
{
	// TODO: refactor a bit
	// TODO: Check ylen
	// TODO: Do we need the power of 2 check?

	// (x & (x - 1)) == 0 == power of 2
	if (xlen <= 0 || (xlen & (xlen - 1)) != 0)
	{
		fprintf(stderr, "map_parse_root: Invalid xlen\n");
		return 0;
	}

	if (zlen <= 0 || (zlen & (zlen - 1)) != 0)
	{
		fprintf(stderr, "map_parse_root: Invalid zlen\n");
		return 0;
	}

	if (ylen != -1 && (ylen <= 0 || ylen > 255))
	{
		fprintf(stderr, "map_parse_root: Invalid ylen\n");
		return 0;
	}

	uint8_t pillar_temp[PILLAR_SIZE];
	int i,x,z,pi;

	int taglen = (int)(dend-data);

	map->udtype = UD_MAP;

	map->xlen = xlen;
	map->ylen = ylen;
	map->zlen = zlen;

	int max_y = 0;

	map->pillars = (uint8_t**)calloc(1, map->xlen*map->zlen*sizeof(uint8_t *));
	if(map->pillars == NULL)
	{
		error_perror("map_parse_root: malloc(map->pillars)");
		return 0;
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
			if (ti + 4 >= PILLAR_SIZE)
			{
				fprintf(stderr, "map_parse_root: too many control entries in pillar\n");
				return 0;
			}

			uint8_t n = (uint8_t)*(data++);
			uint8_t s = (uint8_t)*(data++);
			uint8_t e = (uint8_t)*(data++);
			uint8_t a = (uint8_t)*(data++);

			if(e > max_y)
				max_y = e;

			uint8_t qlen = (n == 0 ? e-s+1 : n-1);

			pillar_temp[ti++] = n;
			pillar_temp[ti++] = s;
			pillar_temp[ti++] = e;
			pillar_temp[ti++] = a;

			for(i = 0; i < qlen; i++)
			{
				if (ti + 4 >= PILLAR_SIZE)
				{
					fprintf(stderr, "map_parse_root: too many colour entries in pillar\n");
					return 0;
				}

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
		map->pillars[pi] = (uint8_t*)calloc(1, ti);
		// TODO: check if NULL
		memcpy(map->pillars[pi], pillar_temp, ti);
	}

	if(ylen == -1)
	{
		ylen = max_y+1;

		if(ylen < 64)
			ylen = 64;

		map->ylen = ylen;
	}

	// TODO: check if the Y exceeded the maximum map Y

#ifndef DEDI
	map->visible_chunks_arr = NULL;
	render_init_va_format(map);
#endif

	return 1;
}

map_t *map_parse_aos(int len, const char *data)
{
	if(data == NULL)
		return NULL;

	const char *p = data;
	const char *dend = data + len;

	map_t *map = (map_t*)calloc(1, sizeof(map_t));
	if(map == NULL)
	{
		error_perror("map_parse_aos: malloc");
		return NULL;
	}

	if (!map_parse_root(map, dend, data, 512, -1, 512, 1))
	{
		error_perror("map_parse_aos: bad map data");
		map_free(map);
		return NULL;
	}
	return map;
}

map_t *map_parse_icemap(int len, const char *data)
{
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

	map_t *map = (map_t*)calloc(1, sizeof(map_t));
	if(map == NULL)
	{
		error_perror("map_parse_icemap: malloc");
		return NULL;
	}

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
		
		// Check for derpy chunk len
		if(p + taglen > dend)
		{
			error_perror("map_load_icemap: premature end!");
			map_free(map);
			return NULL;
		}

		if(!memcmp(tag,"MapData",7))
		{
			if(map->pillars != NULL)
			{
				fprintf(stderr, "map_load_icemap: more than one MapData!\n");
				map_free(map);
				return NULL;
			}

			int xlen = ((uint16_t *)p)[0];
			int ylen = ((uint16_t *)p)[1];
			int zlen = ((uint16_t *)p)[2];
			p += 6;

			if (!map_parse_root(map, p+taglen, p, xlen, ylen, zlen, 0))
			{
				error_perror("map_load_icemap: bad MapData");
				map_free(map);
				return NULL;
			}
			p += taglen-6;
		} else if(!memcmp(tag,"MetaInf",7)) {
			// TODO: Store MetaInf
			if(taglen > 0)
				p += taglen;
		} else if(!memcmp(tag,"MapEnts",7)) {
			if (map->entities != NULL)
			{
				fprintf(stderr, "map_load_icemap: more than one MapEnts!\n");
				map_free(map);
				return NULL;
			}
			
			if (!map_set_mapents(map, p, taglen))
			{
				error_perror("map_load_icemap: bad MapEnts");
				map_free(map);
				return NULL;
			}
			
			p += taglen;
		} else {
			if(taglen > 0)
				p += taglen;
		}
	}

	if(map->pillars == NULL)
	{
		fprintf(stderr, "map_load_icemap: MapData missing!\n");
		map_free(map);
		return NULL;
	}

#ifndef DEDI
	map->visible_chunks_arr = NULL;
	render_init_va_format(map);
#endif

	//printf("all good.\n");
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
	// TODO: make this actually save everything (MetaInf, MapEnts)
	int x,z,pi;

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

	// icemap header + chunk header + map size + map + terminator chunk
	int buflen = 8
		+8+4+6+maplen
		+8;
	if (map->entities_size) {
		// chunk header + data
		buflen += 8 + 4 + map->entities_size;
	}

	char *buf = (char*)malloc(buflen);

	if (buf == NULL) {
		fprintf(stderr, "map_serialise_icemap: buf is NULL!\n");
		return NULL;
	}

	// Header and MapData chunk
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

	// MapEnts
	if (map->entities_size) {
		memcpy(zf, "MapEnts\xFF", 8);
		*(uint32_t *)&zf[8] = map->entities_size;
		zf += 12;
		memcpy(zf, map->entities, map->entities_size);
	}

	// MetaInf
	// TODO:

	// Terminator
	memcpy(buf+buflen-8, "       \x00", 8);

	//printf("derp!\n");
	*len = buflen;

	return buf;
}

int map_save_icemap(map_t *map, const char *fname)
{
	FILE *fp = fopen(fname, "wb");
	if(fp == NULL)
	{
		error_perror("map_save_icemap: could not open file");
		return 1;
	}

	int len;
	char *buf = map_serialise_icemap(map, &len);

	// write end
	fwrite(buf, sizeof(char), (size_t)len, fp);

	// close
	fclose(fp);

	return 0;
}

int map_set_mapents(map_t *map, const char *src, size_t size)
{
	// Check for null terminator
	if (src[size - 1] != '\0')
		size++;
	
	if (map->entities == NULL) {
		map->entities = (char*)malloc(size);
	} else {
		map->entities = (char*)realloc(map->entities, size);
	}
	
	if(map->entities == NULL)
	{
		error_perror("map_set_mapents: malloc");
		return 0;
	}
	
	memcpy(map->entities, src, size);
	map->entities_size = size;
	
	// Ensure null terminator
	map->entities[size - 1] = '\0';
	
	return 1;
}

void map_free(map_t *map)
{
	if(map == NULL)
		return;

	if(map->pillars != NULL)
		free(map->pillars);

	if(map->entities != NULL)
		free(map->entities);
#ifndef DEDI
	render_free_visible_chunks(map);
#endif

	free(map);
}

