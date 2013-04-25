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

#ifdef USE_OPENGL
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
	free(img);
}

img_t *img_parse_tga(int len, const char *data)
{
	// TODO: make this routine safer
	// it's possible to crash this in a whole bunch of ways
	
	const char *p = data;
	const char *dend = data+len;
	int x,y,i;
	img_tgahead_t head;
	
	// read header
	memcpy(&head, p, sizeof(img_tgahead_t));
	p += sizeof(img_tgahead_t);
	
	// skip ID field
	p += head.idlen;
	
	// jump to palette
	
	// load palette if necessary
	uint32_t *palette = (head.cmtype == 1 ? (uint32_t*)malloc(head.cmlen*4) : NULL);
	
	if(palette != NULL)
	for(i = 0; i < head.cmlen; i++)
	{
		// TODO check what happens when the offset is different
		uint32_t tmp_col;
		int tclen = ((head.cmbpp-1)>>3)+1;
		memcpy(&tmp_col, p, tclen);
		p += tclen;
		palette[i] = img_convert_color_to_32(tmp_col, head.cmbpp);
		//printf("%6i %08X\n", i, palette[i]);
	}
	
	// allocate + stash
	int iw, ih;
	iw = head.width;
	ih = head.height;
#ifdef USE_OPENGL
	expandtex_gl(&iw, &ih);
#endif
	printf("TEX: %i %i\n", iw, ih);
	img_t *img = (img_t*)malloc(sizeof(img_t)+4*iw*ih);
	// TODO: check if NULL
	img->head = head;
	img->udtype = UD_IMG;
#ifdef USE_OPENGL
	img->tex = 0;
	img->tex_dirty = 1;
#endif
	
	// copy stuff
	int bplen = ((head.bpp-1)>>3)+1;
	int idx = (head.flags & 32 ? 0 : head.height-1)*iw;
	for(y = 0; y < head.height; y++)
	{
		if(head.imgtype & 8)
		{
			// RLE
			x = 0;
			uint32_t tmp_col;
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
		
		idx += iw-head.width;
		if(!(head.flags & 32))
			idx -= 2*iw;
	}
	
	// convert pixels
	if((head.imgtype&7) == 1)
	{
		for(i = iw*ih-1; i >= 0; i--)
			img->pixels[i] = palette[(img->pixels[i] + head.cmoffs) % head.cmlen];
		//printf("cm %i %i\n", head.cmoffs, head.cmlen);
	} else {
		for(i = iw*ih-1; i >= 0; i--)
			img->pixels[i] = img_convert_color_to_32(img->pixels[i], head.bpp);
	}
	
	// free palette
	free(palette);
	
	// now return!
	return img;
}

img_t *img_load_tga(const char *fname)
{
	int flen;
	char *buf = net_fetch_file(fname, &flen);
	if(buf == NULL)
		return NULL;
	img_t *ret = img_parse_tga(flen, buf);
	free(buf);
	return ret;
}
