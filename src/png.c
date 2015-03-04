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

typedef struct pngheader {
	uint32_t width, height;
	uint8_t bpc, ctyp, cmpr, filt, inter;
} __attribute__((__packed__)) pngheader_t;

#ifndef DEDI
void expandtex_gl(int *iw, int *ih);
#endif

// TODO: move this out somewhere
// TODO: detect CPU endianness
void eswapbe32(void *pin)
{
	uint8_t *p = pin;
	uint8_t t;

	t = p[1];
	p[1] = p[2];
	p[2] = t;

	t = p[0];
	p[0] = p[3];
	p[3] = t;
}

int png_check_chunk(int len, const char *data, int *rclen)
{
	if(len < 12)
	{
		fprintf(stderr, "png_check_chunk: chunk too small\n");
		return 1;
	}

	int clen =
		(((unsigned int)(unsigned char)data[0])<<24)
		+ (((unsigned int)(unsigned char)data[1])<<16)
		+ (((unsigned int)(unsigned char)data[2])<<8)
		+ (((unsigned int)(unsigned char)data[3]) );

	if(len < 12 + clen)
	{
		fprintf(stderr, "png_check_chunk: chunk too small\n");
		return 1;
	}

	const char *cdata = data + 8 + clen;
	int exp_crc =
		(((unsigned int)(unsigned char)cdata[0])<<24)
		+ (((unsigned int)(unsigned char)cdata[1])<<16)
		+ (((unsigned int)(unsigned char)cdata[2])<<8)
		+ (((unsigned int)(unsigned char)cdata[3]) );
	int act_crc = crc32(crc32(0L, Z_NULL, 0), (void *)(data+4), clen+4);

	if(exp_crc != act_crc)
	{
		fprintf(stderr, "png_check_chunk: CRC32 mismatch\n");
		return 1;
	}

	*rclen = clen;
	return 0;
}

int png_load_IHDR(int *len, const char **data, pngheader_t *ihdr)
{
	int clen = 0;

	if(png_check_chunk(*len, *data, &clen))
		return 1;

	if(memcmp((*data)+4, "IHDR", 4))
	{
		fprintf(stderr, "png_load_IHDR: expected IHDR chunk\n");
		return 1;
	}

	if(clen != sizeof(pngheader_t))
	{
		fprintf(stderr, "png_load_IHDR: chunk size incorrect\n");
		return 1;
	}

	memcpy(ihdr, (*data)+8, sizeof(pngheader_t));

	// endian swap
	eswapbe32(&(ihdr->width));
	eswapbe32(&(ihdr->height));

	*len -= clen+12;
	*data += clen+12;

	return 0;
}

uint8_t png_predict_paeth(uint8_t a, uint8_t b, uint8_t c)
{
	int32_t p = ((int32_t)a) + ((int32_t)b) - ((int32_t)c);

	int32_t pa = (p < ((int32_t)a) ? ((int32_t)a) - p : p - ((int32_t)a));
	int32_t pb = (p < ((int32_t)b) ? ((int32_t)b) - p : p - ((int32_t)b));
	int32_t pc = (p < ((int32_t)c) ? ((int32_t)c) - p : p - ((int32_t)c));

	if(pa <= pb && pa <= pc) return (uint8_t)a;
	else if(pb <= pc) return (uint8_t)b;
	else return (uint8_t)c;
}

img_t *img_parse_png(int len, const char *data, lua_State *L)
{
	pngheader_t ihdr;

	// check header
	if(len < 8 || memcmp(data, "\x89PNG\x0D\x0A\x1A\x0A", 8))
	{
		// not a PNG image
		// don't spew an error, this is useful for autodetection mode
		// FIXME: we're spewing it anyway until we have this loader and autodetection working
		fprintf(stderr, "img_parse_png: not a PNG image\n");
		return NULL;
	}

	// read chunks
	len -= 8;
	data += 8;
	if(png_load_IHDR(&len, &data, &ihdr))
		return NULL;

	if(ihdr.width > 65535 || ihdr.height > 65535)
	{
		fprintf(stderr, "img_parse_png: image dimensions too large\n");
		return NULL;
	}

	// TODO: implement 1,2,4bpc for modes 0 (greyscale) and 3 (indexed)
	//if(((ihdr.ctyp != 3 && ihdr.ctyp != 0) || (ihdr.bpc != 1 && ihdr.bpc != 2 && ihdr.bpc != 4)) && ihdr.bpc != 8)
	if(ihdr.bpc != 8)
	{
		//fprintf(stderr, "img_parse_png: given bits-per-component not supported (16bpc unsupported at the moment)\n");
		fprintf(stderr, "img_parse_png: given bits-per-component not supported (only 8bpc supported at the moment)\n");
		return NULL;
	}

	if(ihdr.ctyp != 0 && ihdr.ctyp != 2 && ihdr.ctyp != 3 && ihdr.ctyp != 4 && ihdr.ctyp != 6)
	{
		fprintf(stderr, "img_parse_png: colour type not supported");
		return NULL;
	}

	if(ihdr.cmpr != 0)
	{
		fprintf(stderr, "img_parse_png: compression type not supported");
		return NULL;
	}

	if(ihdr.filt != 0)
	{
		fprintf(stderr, "img_parse_png: filtering type not supported");
		return NULL;
	}

	if(ihdr.inter != 0)
	{
		fprintf(stderr, "img_parse_png: interlacing not supported yet");
		return NULL;
	}

	uint8_t pal[256*3];
	uint8_t trns[256];
	int pal_len = 0;
	int trns_len = 0;

	char *cbuf = NULL;
	size_t cbuf_len = 0;
	for(;;)
	{
		int clen;

		if(png_check_chunk(len, data, &clen))
		{
			if(cbuf != NULL)
				free(cbuf);
			return NULL;
		}

		const char *tag = data+4;
		if(!memcmp("IDAT", tag, 4))
		{
			cbuf = realloc(cbuf, cbuf_len+clen);
			if(cbuf == NULL)
			{
				// this is very much fatal. if we don't crash now, it'll crash later anyway.
				fprintf(stderr, "img_parse_png: *** COULD NOT REALLOCATE IDAT BUFFER! CHECK IF YOU HAVE ENOUGH RAM! ***\n");
				fflush(stderr);
				fflush(stdout);
				abort();
			}

			memcpy(cbuf+cbuf_len, data+8, clen);
			cbuf_len += clen;
		} else if(!memcmp("IEND", tag, 4)) {
			break;
		} else if(!memcmp("PLTE", tag, 4)) {
			if(ihdr.ctyp != 3)
			{
				// probably best not to spam this stuff.
				//fprintf(stderr, "img_parse_png: PLTE tag for non-indexed image ignored\n");
			} else if((clen % 3) != 0 || clen > (3<<ihdr.bpc) || clen > 256*3) {
				fprintf(stderr, "img_parse_png: invalid PLTE length\n");
				if(cbuf != NULL)
					free(cbuf);
				return NULL;
			} else {
				pal_len = clen / 3;
				memcpy(pal, data+8, clen);
			}
		} else if(!memcmp("tRNS", tag, 4)) {
			// we might as well be better than Internet Explorer
			int explen = -1;
			if(ihdr.ctyp == 0)
				explen = 2;
			else if(ihdr.ctyp == 2)
				explen = 6;
			else if(ihdr.ctyp == 3)
				explen = pal_len;

			if(explen == -1)
			{
				fprintf(stderr, "img_parse_png: warning: tRNS not expected for this image type!\n");
			} else if((ihdr.ctyp == 3 ? clen > explen : explen != clen)) {
				fprintf(stderr, "img_parse_png: warning: tRNS chunk length incorrect; ignored\n");
			} else {
				memset(trns+clen, 0xFF, 256-clen);
				memcpy(trns, data+8, clen);
				trns_len = clen;
			}
		} else if(!(tag[0]&0x20)) {
			fprintf(stderr, "img_parse_png: unexpected compulsory tag %c%c%c%c\n"
				, tag[0], tag[1], tag[2], tag[3]);
			if(cbuf != NULL)
				free(cbuf);
			return NULL;
		}

		data += 12+clen;
	}

	// decompress PNG image
	int bpp = 1;
	if((ihdr.ctyp & 2) && !(ihdr.ctyp & 1)) bpp = 3;
	if(ihdr.ctyp & 4) bpp++;
	bpp *= ihdr.bpc;
	int bypp = (bpp+3)>>3; // note, only relevant for >= 8bpc images
	int ipitch = ((ihdr.width*bpp+7)>>3)+1;
	int iwidth = ihdr.width;
	int iheight = ihdr.height;

	uLongf ubuf_len = ipitch*iheight;
	uint8_t *ubuf = malloc((size_t)ubuf_len);

	if(uncompress((Bytef *)ubuf, &ubuf_len, (const Bytef *)cbuf, cbuf_len) != Z_OK)
	{
		fprintf(stderr, "img_parse_tga: error when uncompressing image\n");
		if(cbuf != NULL)
			free(cbuf);
		if(ubuf != NULL)
			free(ubuf);
		return NULL;
	}

	// we don't need the compressed image anymore
	if(cbuf != NULL)
		free(cbuf);

	// now let's filter each scanline
	int x, y;
	for(y = 0; y < iheight; y++)
	{
		uint8_t *q = ubuf + ipitch*y;
		uint8_t typ = *(q++);

		// NOTE: all inaccessible pixels are treated as 0
		switch(typ)
		{
			case 0:
				// no filtering
				break;
			case 1:
				// sub left
				q += bypp;
				for(x = bypp; x < iwidth*bypp; x++)
				{
					q[0] += q[-bypp];
					q++;
				}
				break;
			case 2:
				// sub up
				if(y != 0)
				{
					for(x = 0; x < iwidth*bypp; x++)
					{
						q[0] += q[-ipitch];
						q++;
					}
				}
				break;
			case 3:
				// sub average
				if(y != 0)
				{
					for(x = 0; x < bypp; x++)
					{
						q[0] += ((int)q[-ipitch])>>1;
						q++;
					}
					for(x = bypp; x < iwidth*bypp; x++)
					{
						q[0] += ((int)q[-bypp] + (int)q[-ipitch])>>1;
						q++;
					}
				} else {
					q += bypp;
					for(x = bypp; x < iwidth*bypp; x++)
					{
						q[0] += ((int)q[-bypp]);
						q++;
					}
				}
				break;
			case 4:
				// Paeth predictor
				if(y != 0)
				{
					for(x = 0; x < bypp; x++)
					{
						q[0] += png_predict_paeth(0, q[-ipitch], 0);
						q++;
					}
					for(x = bypp; x < iwidth*bypp; x++)
					{
						q[0] += png_predict_paeth(q[-bypp], q[-ipitch], q[-bypp-ipitch]);
						q++;
					}
				} else {
					q += bypp;
					for(x = bypp; x < iwidth*bypp; x++)
					{
						q[0] += png_predict_paeth(q[-bypp], 0, 0);
						q++;
					}
				}
				break;
			default:
				fprintf(stderr, "img_parse_png: unsupported filter mode %i %i %i\n", 0, y, typ);
				if(ubuf != NULL)
					free(ubuf);
				return NULL;
		}
	}

	// allocate + stash
	int iw, ih;
	iw = iwidth;
	ih = iheight;
#ifndef DEDI
	expandtex_gl(&iw, &ih);
#endif
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
	img->udtype = UD_IMG;
#ifndef DEDI
	img->tex = 0;
	img->tex_dirty = 1;
#endif

	// copy all the things
	img->head.idlen = 0;
	img->head.cmtype = 0;
	img->head.imgtype = 2;
	img->head.cmoffs = 0;
	img->head.cmlen = 0;
	img->head.cmbpp = 0;
	img->head.xstart = 0;
	img->head.ystart = iheight;
	img->head.width = iwidth;
	img->head.height = iheight;
	img->head.bpp = 32;
	img->head.flags = 0x20;

	for(y = 0; y < iheight; y++)
	{
		uint8_t *src = ubuf + ipitch*y + 1;
		uint8_t *dst = ((uint8_t *)(img->pixels)) + iw*y*4;

		switch(ihdr.ctyp)
		{
			case 0:
				// Greyscale
				for(x = 0; x < iwidth; x++)
				{
					dst[0] = src[0];
					dst[1] = src[0];
					dst[2] = src[0];
					dst[3] = (trns_len == 0
						|| trns[0] != src[0]
							? 0xFF : 0x00);
					src += 1;
					dst += 4;
				}
				break;

			case 2:
				// RGB
				for(x = 0; x < iwidth; x++)
				{
					dst[0] = src[2];
					dst[1] = src[1];
					dst[2] = src[0];
					dst[3] = (trns_len == 0
						|| trns[0] != src[0]
						|| trns[2] != src[1]
						|| trns[4] != src[2]
							? 0xFF : 0x00);
					src += 3;
					dst += 4;
				}
				break;

			case 3:
				// Indexed colour
				for(x = 0; x < iwidth; x++)
				{
					dst[0] = pal[src[0]*3+2];
					dst[1] = pal[src[0]*3+1];
					dst[2] = pal[src[0]*3+0];
					dst[3] = (trns_len == 0 ? 0xFF : trns[src[0]]);
					src += 1;
					dst += 4;
				}
				break;

			case 4:
				// Greyscale + Alpha
				for(x = 0; x < iwidth; x++)
				{
					dst[0] = src[0];
					dst[1] = src[0];
					dst[2] = src[0];
					dst[3] = src[1];
					src += 2;
					dst += 4;
				}
				break;

			case 6:
				// RGBA
				for(x = 0; x < iwidth; x++)
				{
					dst[0] = src[2];
					dst[1] = src[1];
					dst[2] = src[0];
					dst[3] = src[3];
					src += 4;
					dst += 4;
				}
				break;
		}
	}

	if(ubuf != NULL)
		free(ubuf);
	return img;
}

img_t *img_load_png(const char *fname, lua_State *L)
{
	int flen;
	char *buf = net_fetch_file(fname, &flen);
	if(buf == NULL)
		return NULL;
	img_t *ret = img_parse_png(flen, buf, L);
	free(buf);
	return ret;
}

void img_write_png(const char *fname, img_t *img)
{
	size_t x, y, i;

	// Create an image buffer
	// Create a row
	size_t gap = 3;
	size_t src_row_size = img->head.width*gap;
	size_t row_size = img->head.width*gap + gap;
	size_t img_size = row_size * img->head.height;
	size_t img_uncomp_len = (row_size - (gap-1)) * img->head.height;
	uint8_t *img_uncomp = malloc(img_uncomp_len);
	uint8_t rowP[1][row_size];
	uint8_t rowC[5][row_size];
	uint8_t *src_pixels = (uint8_t *)(img->pixels);
	int rowsel = 0;

	// Clear previous row
	for(x = 0; x < row_size; x++)
		rowC[0][x] = 0;

	// Apply predition
	for(y = 0; y < img->head.height; y++)
	{
		// Clear left pixel
		for(x = 0; x < gap; x++)
			rowC[0][x] = 0;

		// Copy to last
		memcpy(rowP, rowC[0], row_size);

		// Grab current pixel run
		memcpy(rowC[0] + gap,
			src_pixels + src_row_size*(img->head.height-1-y),
			src_row_size);

		// BGR -> RGB
		for(x = gap; x < row_size; x += gap)
		{
			uint8_t r = rowC[0][x+2];
			uint8_t g = rowC[0][x+1];
			uint8_t b = rowC[0][x+0];
			rowC[0][x+0] = r;
			rowC[0][x+1] = g;
			rowC[0][x+2] = b;
		}

		// Apply prediction types
		for(i = 1; i < 5; i++)
		{
			rowC[i][gap-1] = i;
			switch(i)
			{
				case 1:
					for(x = gap; x < row_size; x++)
						rowC[i][x] = rowC[0][x] - rowC[0][x-gap];
					break;
				case 2:
					for(x = gap; x < row_size; x++)
						rowC[i][x] = rowC[0][x] - rowP[0][x];
					break;
				case 3:
					for(x = gap; x < row_size; x++)
						rowC[i][x] = rowC[0][x] - (uint8_t)(
							(((int16_t)(rowP[0][x]))
							+((int16_t)(rowC[0][x-gap])))/2);
					break;
				case 4:
					for(x = gap; x < row_size; x++)
						rowC[i][x] = rowC[0][x] - png_predict_paeth(
							rowC[0][x-gap],
							rowP[0][x],
							rowP[0][x-gap]);
					break;

			}
		}

		// Estimate best prediction
		// TODO: check for redundancies that the LZSS step can gobble up
		// TODO: collect statistics!
		uint16_t rtab[256];
		int rbest = 0;
		uint64_t rbestscore = 0;

		for(i = 0; i < 5; i++)
		{
			// Clear freq table
			for(x = 0; x < 256; x++)
				rtab[x] = 0;

			// Add to freq table
			int symcount = 0;
			for(x = 2; x < row_size; x++)
			{
				if(rtab[rowC[i][x]] == 0)
					symcount++;

				rtab[rowC[i][x]]++;
			}

			// Sum total - the bigger the better
			uint64_t score = 0;
			for(x = 0; x < 256; x++)
			{
				uint64_t adder = (uint64_t)(rtab[x]);
				adder *= adder;
				score += adder;
			}

			// Apply symbol count
			// Ultimately we want something along the lines of the log2 of this
			// Using a loose A/(B+x) estimate
			score *= ((uint64_t)(4*0x100))/(uint64_t)(symcount + 4);

			// Is this the best score?
			if(i == 0 || score > rbestscore)
			{
				rbest = i;
				rbestscore = score;
			}
		}

		// Use this prediction!
		//printf("%i: %i %i\n", y, rbest, rbestscore);
		memcpy(img_uncomp + (row_size - (gap-1))*y,
			rowC[rbest] + (gap-1), row_size - (gap-1));
	}

	// Compress image
	uLongf cbound = compressBound(img_size);
	uint8_t *img_comp = malloc(cbound);
	if(compress((Bytef *)(img_comp), &cbound,
		(Bytef *)(img_uncomp), img_uncomp_len))
	{
		// abort
		fprintf(stderr, "img_write_png: compression failed!\n");
		free(img_uncomp);
		free(img_comp);
		return;
	}

	// Start writing
	FILE *fp = fopen(fname, "wb");
	if(fp == NULL) {
		perror("img_write_png");
		return;
	}

	int crc = 0;

	// Write header
	fwrite("\x89PNG\x0D\x0A\x1A\x0A", 8, 1, fp);
	uint8_t ihdr[25];
	ihdr[0] = 0;
	ihdr[1] = 0;
	ihdr[2] = 0;
	ihdr[3] = 13;
	ihdr[4] = 'I';
	ihdr[5] = 'H';
	ihdr[6] = 'D';
	ihdr[7] = 'R';
	ihdr[8] = 0;
	ihdr[9] = 0;
	ihdr[10] = img->head.width>>8;
	ihdr[11] = img->head.width&255;
	ihdr[12] = 0;
	ihdr[13] = 0;
	ihdr[14] = img->head.height>>8;
	ihdr[15] = img->head.height&255;
	ihdr[16] = 8;
	ihdr[17] = 2;
	ihdr[18] = 0;
	ihdr[19] = 0;
	ihdr[20] = 0; // Think we'll interlace these? THINK AGAIN
	crc = crc32(crc32(0L, Z_NULL, 0), ihdr+4, 13+4);
	ihdr[21] = (uint8_t)(crc>>24);
	ihdr[22] = (uint8_t)(crc>>16);
	ihdr[23] = (uint8_t)(crc>>8);
	ihdr[24] = (uint8_t)(crc);
	fwrite(ihdr, 25, 1, fp);

	// Write image
	uint32_t img_comp_len = (uint32_t)cbound;
	crc = crc32(crc32(0L, Z_NULL, 0), (const Bytef *)"IDAT", 4);
	crc = crc32(crc, (const Bytef *)img_comp, (size_t)img_comp_len);
	ihdr[0] = (uint8_t)(img_comp_len>>24);
	ihdr[1] = (uint8_t)(img_comp_len>>16);
	ihdr[2] = (uint8_t)(img_comp_len>>8);
	ihdr[3] = (uint8_t)(img_comp_len);
	ihdr[4] = (uint8_t)(crc>>24);
	ihdr[5] = (uint8_t)(crc>>16);
	ihdr[6] = (uint8_t)(crc>>8);
	ihdr[7] = (uint8_t)(crc);
	fwrite(ihdr, 4, 1, fp);
	fwrite("IDAT", 4, 1, fp);
	fwrite(img_comp, img_comp_len, 1, fp);
	fwrite(ihdr+4, 4, 1, fp);

	// Write IEND
	crc = crc32(crc32(0L, Z_NULL, 0), (const Bytef *)"IEND", 4);
	ihdr[0] = (uint8_t)(0>>24);
	ihdr[1] = (uint8_t)(0>>16);
	ihdr[2] = (uint8_t)(0>>8);
	ihdr[3] = (uint8_t)(0);
	ihdr[4] = (uint8_t)(crc>>24);
	ihdr[5] = (uint8_t)(crc>>16);
	ihdr[6] = (uint8_t)(crc>>8);
	ihdr[7] = (uint8_t)(crc);
	fwrite(ihdr, 4, 1, fp);
	fwrite("IEND", 4, 1, fp);
	fwrite(ihdr+4, 4, 1, fp);

	// Free uncompressed and compressed images
	free(img_uncomp);
	free(img_comp);

	// Close!
	fclose(fp);
}

