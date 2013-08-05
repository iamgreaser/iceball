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

#ifdef USE_OPENGL
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

img_t *img_parse_png(int len, const char *data)
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

	if(ihdr.bpc != 8)
	{
		fprintf(stderr, "img_parse_png: only 8-bits-per-component images currently supported\n");
		return NULL;
	}

	if(ihdr.ctyp != 0 && ihdr.ctyp != 2 && ihdr.ctyp != 3 && ihdr.ctyp != 4 && ihdr.ctyp != 6)
	{
		fprintf(stderr, "img_parse_png: colour type not supported");
		return NULL;
	}

	if(ihdr.ctyp != 2 && ihdr.ctyp != 6)
	{
		fprintf(stderr, "img_parse_png: given colour type not supported yet!");
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
#ifdef USE_OPENGL
	expandtex_gl(&iw, &ih);
#endif
	img_t *img = (img_t*)malloc(sizeof(img_t)+4*iw*ih);
	if(img == NULL)
	{
		// this is very much fatal. if we don't crash now, it'll crash later anyway.
		fprintf(stderr, "img_parse_tga: *** COULD NOT ALLOCATE IMAGE! CHECK IF YOU HAVE ENOUGH RAM! ***\n");
		fflush(stderr);
		fflush(stdout);
		abort();
	}
	img->udtype = UD_IMG;
#ifdef USE_OPENGL
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
			case 2:
				// RGB
				for(x = 0; x < iwidth; x++)
				{
					dst[0] = src[2];
					dst[1] = src[1];
					dst[2] = src[0];
					dst[3] = 0xFF; // TODO: tRNS block
					src += 3;
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

	// TODO!
	if(ubuf != NULL)
		free(ubuf);
	return img;
}

img_t *img_load_png(const char *fname)
{
	int flen;
	char *buf = net_fetch_file(fname, &flen);
	if(buf == NULL)
		return NULL;
	img_t *ret = img_parse_png(flen, buf);
	free(buf);
	return ret;
}

