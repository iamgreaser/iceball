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

img_t *img_load_tga(char *fname)
{
	// TODO: make this routine safer
	// it's possible to crash this in a whole bunch of ways
	
	int x,y,i;
	img_tgahead_t head;
	
	FILE *fp = fopen(fname, "rb");
	if(fp == NULL)
	{
		perror("img_load_tga");
		return NULL;
	}
	
	// read header
	fread(&head, sizeof(img_tgahead_t), 1, fp);
	
	// skip ID field
	fseek(fp, head.idlen, SEEK_CUR);
	
	// jump to palette
	
	// load palette if necessary
	uint32_t *palette = (head.cmtype == 1 ? malloc(head.cmlen*4) : NULL);
	
	if(palette != NULL)
	for(i = 0; i < head.cmlen; i++)
	{
		// TODO check what happens when the offset is different
		uint32_t tmp_col;
		fread(&tmp_col, ((head.cmbpp-1)&~7)*8+1, 1, fp);
		palette[i] = img_convert_color_to_32(tmp_col, head.cmbpp);
	}
	
	// allocate + stash
	img_t *img = malloc(sizeof(img_t)+4*head.width*head.height);
	// TODO: check if NULL
	img->head = head;
	
	// copy stuff
	int idx = (head.flags & 32 ? 0 : head.height-1)*head.width;
	for(y = 0; y < head.height; y++)
	{
		if(head.imgtype & 8)
		{
			// RLE
			x = 0;
			while(x < head.width)
			{
				int rle = fgetc(fp);
				if(rle & 0x80)
				{
					rle &= 0x7F;
					
					uint32_t tmp_col;
					fread(&tmp_col, ((head.bpp-1)&~7)*8+1, 1, fp);
					// TODO: clip at width
					for(i = 0; i <= rle; i++, x++)
						img->pixels[idx++] = tmp_col;
				} else {
					// TODO: clip at width
					for(i = 0; i <= rle; i++, x++)
					{
						uint32_t tmp_col;
						fread(&tmp_col, ((head.bpp-1)&~7)*8+1, 1, fp);
						img->pixels[idx++] = tmp_col;
					}
				}
			}
		} else {
			// raw
			uint32_t tmp_col;
			for(x = 0; x < head.width; x++)
			{
				fread(&tmp_col, ((head.bpp-1)&~7)*8+1, 1, fp);
				img->pixels[idx++] = tmp_col;
			}
		}
		
		if(!(head.flags & 32))
			idx -= 2*head.width;
	}
	
	// convert pixels
	if((head.imgtype&7) == 0)
	{
		for(i = head.width*head.height-1; i >= 0; i--)
			img->pixels[i] = palette[(img->pixels[i] % head.cmlen) + head.cmoffs];
	} else {
		for(i = head.width*head.height-1; i >= 0; i--)
			img->pixels[i] = img_convert_color_to_32(img->pixels[i], head.bpp);
	}
	
	// close and return!
	fclose(fp);
	return img;
}
