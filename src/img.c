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

#ifndef DEDI
void expandtex_gl(int *iw, int *ih);
#endif

uint32_t img_convert_color_to_32(uint32_t v, int bits)
{
	switch(bits)
	{
		case 16:
			return 0xFF000000*((v>>15)&1)
				+ ((v&0x001F)<<3)
				+ ((v&0x03E0)<<6)
				+ ((v&0x7C00)<<9);
		case 24:
			return 0xFF000000 + (v&0x00FFFFFF);
		case 32:
			return v;
		default:
			// not supported, just return 0xFF000000
			return 0xFF000000;
	}
}

void img_free(img_t *img)
{
	/*
#ifndef DEDI
	if(img->tex != 0)
		glDeleteTextures(1, &(img->tex));
#endif
	*/

	//free(img);
}

int img_gc_lua(lua_State *L)
{
	//img_t **img_ud = (img_t **)lua_touserdata(L, 1);
	//img_t *img = *img_ud;
	img_t *img = lua_touserdata(L, 1);
	if(img != NULL)
	{
#ifdef ALLOW_EXPLICIT_FREE
		printf("Freeing img @ %p\n", img);
#endif
#ifndef DEDI
		if(img->tex != 0)
			glDeleteTextures(1, &(img->tex));
#endif
	}

	return 0;
}

void img_gc_set(lua_State *L)
{
	lua_newtable(L);
	lua_pushcfunction(L, img_gc_lua);
	lua_setfield(L, -2, "__gc");
	lua_setmetatable(L, -2);
}

img_t *img_parse_tga(int len, const char *data, lua_State *L)
{
	// TODO: make this routine safer
	// it's possible to crash this in a whole bunch of ways

	const char *p = data;
	const char *dend = data+len;
	int x,y,i;
	img_tgahead_t head;

	// read header
	assert((unsigned long)len >= (unsigned long)sizeof(img_tgahead_t));
	//memcpy(&head, p, sizeof(img_tgahead_t));
	//p += sizeof(img_tgahead_t);
	// header has to be read semiproperly because gcc has no idea what packed means since 4.7
	memcpy(&head.idlen,   p +  0, 1);
	memcpy(&head.cmtype,  p +  1, 1);
	memcpy(&head.imgtype, p +  2, 1);
	memcpy(&head.cmoffs,  p +  3, 2);
	memcpy(&head.cmlen,   p +  5, 2);
	memcpy(&head.cmbpp,   p +  7, 1);
	memcpy(&head.xstart,  p +  8, 2);
	memcpy(&head.ystart,  p + 10, 2);
	memcpy(&head.width,   p + 12, 2);
	memcpy(&head.height,  p + 14, 2);
	memcpy(&head.bpp,     p + 16, 1);
	memcpy(&head.flags,   p + 17, 1);
	p += 18;

	int bplen = ((head.bpp-1)>>3)+1;
	assert((unsigned long)len >= (unsigned long)(sizeof(img_tgahead_t) + head.idlen));

	// skip ID field
	p += head.idlen;

	// jump to palette

	// load palette if necessary
	uint32_t *palette = (head.cmtype == 1 ? (uint32_t*)malloc(head.cmlen*4) : NULL);

	if(palette != NULL)
	{
		int tclen = ((head.cmbpp-1)>>3)+1;
		assert((unsigned long)len >= (unsigned long)(sizeof(img_tgahead_t) + head.idlen
			+ head.cmlen*tclen));

		memset(palette, 0, 4*head.cmlen);
		for(i = 0; i < head.cmlen; i++)
		{
			// TODO check what happens when the offset is different
			uint32_t tmp_col = 0;
			memcpy(&tmp_col, p, tclen);
			p += tclen;
			palette[i] = img_convert_color_to_32(tmp_col, head.cmbpp);
			//printf("%6i %08X\n", i, palette[i]);
		}
	}

	// allocate + stash
	int iw, ih;
	iw = head.width;
	ih = head.height;
#ifndef DEDI
	expandtex_gl(&iw, &ih);
#endif
	//printf("TEX: %i %i\n", iw, ih);
	img_t *img = (img_t*)(
		L != NULL
		? lua_newuserdata(L, sizeof(img_t)+4*iw*ih)
		: malloc(sizeof(img_t)+4*iw*ih));
	if(img == NULL)
	{
		// this is very much fatal. if we don't crash now, it'll crash later anyway.
		fprintf(stderr, "img_parse_tga: *** COULD NOT ALLOCATE IMAGE! CHECK IF YOU HAVE ENOUGH RAM! ***\n");
		fflush(stderr);
		fflush(stdout);
		abort();
	}

	memset(img, 0, sizeof(img_t) + 4*iw*ih);

	img->head = head;
	img->udtype = UD_IMG;
#ifndef DEDI
	img->tex = 0;
	img->tex_dirty = 1;
#endif

	// copy stuff
	int idx = (head.flags & 32 ? 0 : head.height-1)*iw;
	assert(iw >= head.width);
	assert(ih >= head.height);

	for(i = 0; i < iw*ih; i++)
		img->pixels[i] = 0;

	printf("%i %i %i %i\n", iw, ih, head.width, head.height);

	for(y = 0; y < head.height; y++)
	{
		if(head.imgtype & 8)
		{
			// RLE
			x = 0;
			uint32_t tmp_col = 0;
			while(x < head.width)
			{
				int rle = (int)(uint8_t)(*p++);
				if(rle & 0x80)
				{
					rle &= 0x7F;

					memcpy(&tmp_col, p, bplen);
					p += bplen;

					for(i = 0; i <= rle && x < head.width && p < dend; i++, x++)
						img->pixels[idx++] = tmp_col;
				} else {
					for(i = 0; i <= rle && x < head.width && p < dend; i++, x++)
					{
						memcpy(&tmp_col, p, bplen);
						p += bplen;

						img->pixels[idx++] = tmp_col;
					}
				}
			}
		} else {
			// raw
			uint32_t tmp_col;
			for(x = 0; x < head.width && p < dend; x++)
			{
				memcpy(&tmp_col, p, bplen);
				p += bplen;
				img->pixels[idx++] = tmp_col;
			}
		}

		if(iw > head.width)
			memset(img->pixels+idx, 0, 4*(iw-head.width));

		idx += iw-head.width;

		if(!(head.flags & 32))
			idx -= 2*iw;
	}

	assert(p-data <= len);

	if(ih > head.height)
		memset(img->pixels+iw*head.height, 0, 4*iw*(ih-head.height));

	// convert pixels
	if((head.imgtype&7) == 1 && palette != NULL)
	{
		for(i = 0; i < iw*ih; i++)
		{
			uint32_t offs = (img->pixels[i] + head.cmoffs) % head.cmlen;
			assert(offs >= 0 && offs < head.cmlen);
			img->pixels[i] = palette[offs];
		}

		//printf("cm %i %i\n", head.cmoffs, head.cmlen);
	} else {
		for(i = 0; i < iw*ih; i++)
			img->pixels[i] = img_convert_color_to_32(img->pixels[i], head.bpp);
	}

	// free palette
	free(palette);

	// now return!
	return img;
}

img_t *img_load_tga(const char *fname, lua_State *L)
{
	int flen;
	char *buf = net_fetch_file(fname, &flen);
	if(buf == NULL)
		return NULL;
	img_t *ret = img_parse_tga(flen, buf, L);
	free(buf);
	return ret;
}

void img_write_tga(const char *fname, img_t *img)
{
	FILE *fp = fopen(fname, "wb");
	if(fp == NULL) {
		perror("img_write_tga");
		return;
	}
	
	size_t img_size = img->head.width * img->head.height;
	fwrite(&img->head, sizeof(img_tgahead_t), 1, fp);
	fwrite(img->pixels, sizeof(uint8_t) * 3, img_size, fp);
	fclose(fp);
}
