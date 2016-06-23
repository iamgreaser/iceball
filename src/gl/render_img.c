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

void expandtex_gl(int *iw, int *ih)
{
	if(gl_expand_textures)
	{
		(*iw)--;
		(*iw) |= (*iw)>>1;
		(*iw) |= (*iw)>>2;
		(*iw) |= (*iw)>>4;
		(*iw) |= (*iw)>>8;
		(*iw) |= (*iw)>>16;
		(*iw)++;

		(*ih)--;
		(*ih) |= (*ih)>>1;
		(*ih) |= (*ih)>>2;
		(*ih) |= (*ih)>>4;
		(*ih) |= (*ih)>>8;
		(*ih) |= (*ih)>>16;
		(*ih)++;

		if((*iw) < 64)
			*iw = 64;
		if((*ih) < 64)
			*ih = 64;
	}
}


void render_blit_img_toimg(uint32_t *pixels, int width, int height, int pitch,
	img_t *src, int dx, int dy, int bw, int bh, int sx, int sy, uint32_t color,
	float scalex, float scaley);

img_t *render_dump_img(int width, int height, int sx, int sy) {
	size_t img_size = (width - sx) * (height - sy) * 3;
	img_t *img = malloc(sizeof(img_t) + img_size);
	img->head.idlen = 0; // no ID
	img->head.cmtype = 0; // no colourmap
	img->head.imgtype = 2; // uncompressed RGB
	img->head.cmoffs = 0;
	img->head.cmlen = 0;
	img->head.cmbpp = 0;
	img->head.xstart = 0;
	img->head.ystart = height - sy;
	img->head.width = width - sx;
	img->head.height = height - sy;
	img->head.bpp = 24;
	img->head.flags = 0x0;
	img->udtype = UD_IMG;

	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glReadPixels(sx, sy, width, height, GL_BGR, GL_UNSIGNED_BYTE, img->pixels);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 4);

	return img;
}

GLuint vbo_img = 0;
void render_blit_img(uint32_t *pixels, int width, int height, int pitch,
	img_t *src, int dx, int dy, int bw, int bh, int sx, int sy, uint32_t color, float scalex, float scaley)
{
	if (scalex <= 0.000001f || scaley <= 0.000001f)
	{
		return;
	}
	
	if(pixels != NULL)
	{
		if(src->udtype != UD_IMG)
		{
			printf("ABORT: Trying to blit an FBO to an img_t!\n");
			fflush(stdout);
			abort();
		}

		expandtex_gl(&width, &height);
		pitch = width;
		return render_blit_img_toimg(pixels,width,height,pitch,src,dx,dy,bw,bh,sx,sy,color,scalex,scaley);
	}

	int iw, ih;
	if(src->udtype == UD_IMG)
	{
		iw = src->head.width;
		ih = src->head.height;
		expandtex_gl(&iw, &ih);
	} else {
		fbo_t *fbo = (fbo_t *)src;
		iw = fbo->width;
		ih = fbo->height;
	}

	glEnable(GL_TEXTURE_2D);
	if(src->udtype == UD_IMG && src->tex_dirty)
	{
		if(src->tex == 0)
		{
			glGenTextures(1, &(src->tex));
			glBindTexture(GL_TEXTURE_2D, src->tex);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
			if(GLAD_GL_ARB_texture_storage)
			{
				glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA8, iw, ih);
			} else {
				glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, iw, ih, 0, GL_BGRA, GL_UNSIGNED_BYTE, NULL);
			}
		} else {
			glBindTexture(GL_TEXTURE_2D, src->tex);
		}
		glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, iw, ih, GL_BGRA, GL_UNSIGNED_BYTE, src->pixels);

		src->tex_dirty = 0;
	} else {
		glBindTexture(GL_TEXTURE_2D, src->tex);
		if(src->udtype == UD_FBO)
		{
			glClientActiveTexture(GL_TEXTURE1);
			glActiveTexture(GL_TEXTURE1);
			glEnable(GL_TEXTURE_2D);
			glBindTexture(GL_TEXTURE_2D, ((fbo_t *)src)->dstex);
			glClientActiveTexture(GL_TEXTURE0);
			glActiveTexture(GL_TEXTURE0);
		}
	}

	glDisable(GL_DEPTH_TEST);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
	glTranslatef(-1.0f, 1.0f, 0.0f);
	glScalef(2.0f/width, -2.0f/height, 1.0f);
	
	float dx1 = dx;
	float dy1 = dy;
	float dx2 = dx+bw;
	float dy2 = dy+bh;

	float sx1 = (sx)/(float)iw;
	float sx2 = (sx+bw)/(float)iw;
	float sy1 = (sy)/(float)ih;
	float sy2 = (sy+bh)/(float)ih;

	sx2 /= scalex;
	sy2 /= scaley;

	if(src->udtype == UD_FBO)
	{
		sy1 = 1.0f - sy1;
		sy2 = 1.0f - sy2;
	}
	
	glColor4f(((color>>16)&255)/255.0f,((color>>8)&255)/255.0f,((color)&255)/255.0f,((color>>24)&255)/255.0f);
	GLfloat va[6*5] = {
		sx1, sy1, dx1, dy1, 1.0f,
		sx1, sy2, dx1, dy2, 1.0f,
		sx2, sy1, dx2, dy1, 1.0f,
		sx2, sy1, dx2, dy1, 1.0f,
		sx1, sy2, dx1, dy2, 1.0f,
		sx2, sy2, dx2, dy2, 1.0f,

	};
	if(vbo_img == 0)
	{
		glGenBuffers(1, &(vbo_img));
	}

	if(vbo_img != 0)
	{
		glBindBuffer(GL_ARRAY_BUFFER, vbo_img);
		glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*5*6, va, GL_STATIC_DRAW);
		glVertexPointer(3, GL_FLOAT, sizeof(GLfloat)*5, ((GLfloat *)0) + 2);
		glTexCoordPointer(2, GL_FLOAT, sizeof(GLfloat)*5, ((GLfloat *)0) + 0);

	} else {
		glVertexPointer(3, GL_FLOAT, sizeof(GLfloat)*5, va + 2);
		glTexCoordPointer(2, GL_FLOAT, sizeof(GLfloat)*5, va + 0);
	}

	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glDrawArrays(GL_TRIANGLES, 0, 6);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glDisableClientState(GL_VERTEX_ARRAY);

	if(vbo_img != 0)
	{
		glBindBuffer(GL_ARRAY_BUFFER, 0);
	}
	/*
	glBegin(GL_QUADS);
		glTexCoord2f(sx1, sy1); glVertex3f(dx1, dy1, 1.0f);
		glTexCoord2f(sx1, sy2); glVertex3f(dx1, dy2, 1.0f);
		glTexCoord2f(sx2, sy2); glVertex3f(dx2, dy2, 1.0f);
		glTexCoord2f(sx2, sy1); glVertex3f(dx2, dy1, 1.0f);
	glEnd();
	*/
	
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	glDisable(GL_BLEND);
	glBindTexture(GL_TEXTURE_2D, 0);		
	glDisable(GL_TEXTURE_2D);
	if(src->udtype == UD_FBO)
	{
		glClientActiveTexture(GL_TEXTURE1);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, 0);
		glDisable(GL_TEXTURE_2D);
		glClientActiveTexture(GL_TEXTURE0);
		glActiveTexture(GL_TEXTURE0);
	}
	glEnable(GL_DEPTH_TEST);
}

void render_blit_img_toimg(uint32_t *pixels, int width, int height, int pitch,
	img_t *src, int dx, int dy, int bw, int bh, int sx, int sy, uint32_t color,
	float scalex, float scaley)
{
	if (scalex <= 0.000001f || scaley <= 0.000001f)
	{
		return;
	}
	if (scalex != 1 && scaley != 1)
	{
		//TODO: at least some sort of scaling
	}
	int x,y;
	int iscalex, iscaley;
	iscalex = 0x10000/scalex;
	iscaley = 0x10000/scaley;
	
	// clip blit width/height
	if(bw/scalex > src->head.width-sx)
		bw = (src->head.width-sx)*scalex;
	if(bh/scaley > src->head.height-sy)
		bh = (src->head.height-sy)*scaley;
	if(sx < 0)
	{
		bw -= -sx*scalex;
		dx += -sx*scalex;
		sx = 0;
	}
	if(sy < 0)
	{
		bh -= -sy*scaley;
		dy += -sy*scaley;
		sy = 0;
	}
	
	// drop if completely out of range
	if(dx >= width || dy >= height)
		return;
	if(dx+bw <= 0 || dy+bh <= 0)
		return;
	
	// top-left clip
	if(dx < 0)
	{
		sx += -dx/scalex;
		bw -= -dx/scalex;
		dx = 0;
	}
	if(dy < 0)
	{
		sy += -dy/scaley;
		bh -= -dy/scaley;
		dy = 0;
	}
	
	// bottom-right clip
	if(dx+bw > width)
		bw = width-dx;
	if(dy+bh > height)
		bh = height-dy;
	
	// drop if width/height sucks
	if(bw <= 0 || bh <= 0)
		return;
	
	// get pointers
	int iw, ih;
	iw = src->head.width;
	ih = src->head.height;
	expandtex_gl(&iw, &ih);
	uint32_t *ps = src->pixels;
	ps = &ps[sx+sy*iw];
	uint32_t *pd = &(pixels[dx+dy*pitch]);
	//int spitch = iw - bw;
	int spitch = iw;
	int dpitch = pitch - bw;

	int xctr, yctr;
	yctr = 0;
	
	//printf("[%i %i] [%i %i] %016llX %016llX %i %i %08X\n"
	//	, bw, bh, dx, dy, (long long)ps, (long long)pd, dpitch, spitch, color);
	
#ifdef __SSE2__
	// TODO: improve prefetching
	
	// from the Intel 64 and IA-32 Architectures Optimization Manual:
	//
	// Assembly/Compiler Coding Rule 76. (M impact, H generality) Align data to
	// 32-byte boundary when possible. Prefer store alignment over load alignment.
	
	if(bw >= 16 && scalex == 1.0f)
	{
		const __m128i xmmconst_0 = _mm_setzero_si128();
		const __m128i xmmconst_256 = _mm_set1_epi16(256);
		const __m128i xmmconst_roundcolor = _mm_set_epi16(8,8,8,8,8,8,8,8);
		const __m128i xmmconst_incalpha = _mm_set_epi16(127,0x7FFF,0x7FFF,0x7FFF,127,0x7FFF,0x7FFF,0x7FFF);
		
		// set base color
		__m128i xmm_bcol = _mm_unpacklo_epi8(_mm_set_epi32(0,0,color,color),xmmconst_0);
		
		for(y = 0; y < bh; y++)
		{
			// strip mine
			for(x = 0; x < bw; x += 8)
				_mm_prefetch(ps+x, _MM_HINT_T0);
			for(x = 0; x < bw; x += 8)
				_mm_prefetch(pd+x, _MM_HINT_T0);
			
			// do the left part first
			// TODO: look for a mask instruction
			uint32_t *fs = ps;
			for(x = 0; x < bw; x++)
			{
				uint32_t s = *(fs++);
				uint32_t d = *pd;
				
				// apply base color
				// DANGER! BRACKETITIS!
				if(color != 0xFFFFFFFF)
				s = (((s&0xFF)*((color&0xFF))>>8)
					| ((((s>>8)&0xFF)*(((color>>8)&0xFF)+1))&0xFF00)
					| ((((s>>8)&0xFF00)*(((color>>16)&0xFF)+1))&0xFF0000)
					| ((((s>>8)&0xFF0000)*(((color>>24)&0xFF)+1))&0xFF000000)
				);
				
				uint32_t alpha = (s >> 24);
				if(alpha >= 0x80) alpha++;
				uint32_t ialpha = 0x100 - alpha;
				
				uint32_t sa = s & 0x00FF00FF;
				uint32_t sb = (s & 0xFF00FF00)>>8;
				uint32_t da = d & 0x00FF00FF;
				uint32_t db = (d & 0xFF00FF00)>>8;
				
				sa *= alpha;
				sb *= alpha;
				da *= ialpha;
				db *= ialpha;
				
				uint32_t va = ((sa + da)>>8) & 0x00FF00FF;
				uint32_t vb = (sb + db) & 0xFF00FF00;
				uint32_t vv = va+vb;
				
				//if(((uint64_t)pd) < 0x00000000FFFFFFFFL)
				//	printf("%i %i %08X\n", alpha, ialpha, vv);
				
				*(pd++) = vv;
			}
			
			// do the middle
			// NOTE: i don't have AVX2 so don't expect an AVX2 version.
			for(; x < bw-4; x+=4)
			{
				__m128i xmm_src = _mm_loadu_si128((__m128i *)fs);
				fs += 4;
				__m128i xmm_dst = _mm_load_si128((__m128i *)pd);
				
				// unpack
				__m128i xmm_src0 = _mm_unpacklo_epi8(xmm_src,xmmconst_0);
				__m128i xmm_dst0 = _mm_unpacklo_epi8(xmm_dst,xmmconst_0);
				__m128i xmm_src1 = _mm_unpackhi_epi8(xmm_src,xmmconst_0);
				__m128i xmm_dst1 = _mm_unpackhi_epi8(xmm_dst,xmmconst_0);
				
				// apply base color
				xmm_src0 = _mm_mulhi_epi16(
					_mm_add_epi16(_mm_slli_epi16(xmm_src0, 4), xmmconst_roundcolor),
					_mm_add_epi16(_mm_slli_epi16(xmm_bcol, 4), xmmconst_roundcolor));
				xmm_src1 = _mm_mulhi_epi16(
					_mm_add_epi16(_mm_slli_epi16(xmm_src1, 4), xmmconst_roundcolor),
					_mm_add_epi16(_mm_slli_epi16(xmm_bcol, 4), xmmconst_roundcolor));
				
				// increase alpha a bit
				xmm_src0 = _mm_sub_epi16(xmm_src0,
					_mm_cmpgt_epi16(xmm_src0,xmmconst_incalpha));
				xmm_src1 = _mm_sub_epi16(xmm_src1,
					_mm_cmpgt_epi16(xmm_src1,xmmconst_incalpha));
				
				// get src alpha
				/*
				OK this is getting really really annoying.
				Let's do a diagram of what the hell I need to do.
				
				A1 R1 G1 B1 A0 R0 G0 B0
				
				unpack high / unpack low
				
				A1 A1 R1 R1 G1 G1 B1 B1 /  A0 A0 R0 R0 G0 G0 B0 B0
				
				shuffle correctly
				
				A1 A1 A1 A1 A0 A0 A0 A0
				
				*/
				
				__m128i xmm_src0_alpha = xmm_src0;
				__m128i xmm_src1_alpha = xmm_src1;
				__m128i xmm_src0_alpha0 = _mm_unpackhi_epi16(xmm_src0_alpha,xmm_src0_alpha);
				__m128i xmm_src0_alpha1 = _mm_unpacklo_epi16(xmm_src0_alpha,xmm_src0_alpha);
				__m128i xmm_src1_alpha0 = _mm_unpackhi_epi16(xmm_src1_alpha,xmm_src1_alpha);
				__m128i xmm_src1_alpha1 = _mm_unpacklo_epi16(xmm_src1_alpha,xmm_src1_alpha);
				
#ifdef _MSC_VER
				xmm_src0_alpha = _mm_castps_si128(_mm_shuffle_ps(_mm_castsi128_ps(xmm_src0_alpha1),_mm_castsi128_ps(xmm_src0_alpha0),0xFF));
				xmm_src1_alpha = _mm_castps_si128(_mm_shuffle_ps(_mm_castsi128_ps(xmm_src1_alpha1),_mm_castsi128_ps(xmm_src1_alpha0),0xFF));
#else
				xmm_src0_alpha = (__m128i)_mm_shuffle_ps((__m128)xmm_src0_alpha1,(__m128)xmm_src0_alpha0,0xFF);
				xmm_src1_alpha = (__m128i)_mm_shuffle_ps((__m128)xmm_src1_alpha1,(__m128)xmm_src1_alpha0,0xFF);
#endif				
				
				// Found some instructions which should speed this up.
				// NOTE: actually runs at the same damn speed... maybe even worse.
				// Using older method for now.
				/*
				__m128i xmm_src0_alpha = _mm_shufflelo_epi16(xmm_src0, 0xFF);
				__m128i xmm_src1_alpha = _mm_shufflelo_epi16(xmm_src1, 0xFF);
				xmm_src0_alpha = _mm_shufflehi_epi16(xmm_src0_alpha, 0xFF);
				xmm_src1_alpha = _mm_shufflehi_epi16(xmm_src1_alpha, 0xFF);
				*/
				
				// get inverse alpha
				__m128i xmm_ialpha0 = _mm_sub_epi16(xmmconst_256,xmm_src0_alpha);
				__m128i xmm_ialpha1 = _mm_sub_epi16(xmmconst_256,xmm_src1_alpha);
				
				// ALPHA BLAND
				xmm_src0_alpha = _mm_slli_epi16(xmm_src0_alpha, 4);
				xmm_ialpha0 = _mm_slli_epi16(xmm_ialpha0, 4);
				xmm_src0 = _mm_slli_epi16(xmm_src0, 4);
				xmm_dst0 = _mm_slli_epi16(xmm_dst0, 4);
				xmm_src1_alpha = _mm_slli_epi16(xmm_src1_alpha, 4);
				xmm_ialpha1 = _mm_slli_epi16(xmm_ialpha1, 4);
				xmm_src1 = _mm_slli_epi16(xmm_src1, 4);
				xmm_dst1 = _mm_slli_epi16(xmm_dst1, 4);
				
				__m128i xmm_combo0 = _mm_add_epi16(
					_mm_mulhi_epi16(xmm_src0_alpha, xmm_src0),
					_mm_mulhi_epi16(xmm_ialpha0, xmm_dst0));
				__m128i xmm_combo1 = _mm_add_epi16(
					_mm_mulhi_epi16(xmm_src1_alpha, xmm_src1),
					_mm_mulhi_epi16(xmm_ialpha1, xmm_dst1));
				
				// pack back!
				__m128i xmm_combo = _mm_packus_epi16(xmm_combo0, xmm_combo1);
				_mm_store_si128((__m128i *)pd, xmm_combo);
				
				pd += 4;
			}
			
			// finish off with the right part
			for(; x < bw; x++)
			{
				uint32_t s = *(fs++);
				uint32_t d = *pd;
				
				// apply base color
				// DANGER! BRACKETITIS!
				if(color != 0xFFFFFFFF)
				s = (((s&0xFF)*((color&0xFF))>>8)
					| ((((s>>8)&0xFF)*(((color>>8)&0xFF)+1))&0xFF00)
					| ((((s>>8)&0xFF00)*(((color>>16)&0xFF)+1))&0xFF0000)
					| ((((s>>8)&0xFF0000)*(((color>>24)&0xFF)+1))&0xFF000000)
				);
				
				uint32_t alpha = (s >> 24);
				if(alpha >= 0x80) alpha++;
				uint32_t ialpha = 0x100 - alpha;
				
				uint32_t sa = s & 0x00FF00FF;
				uint32_t sb = s & 0x0000FF00;
				uint32_t da = d & 0x00FF00FF;
				uint32_t db = d & 0x0000FF00;
				
				sa *= alpha;
				sb *= alpha;
				da *= ialpha;
				db *= ialpha;
				
				//printf("%i %i\n", alpha, ialpha);
				
				uint32_t va = ((sa + da)>>8) & 0x00FF00FF;
				uint32_t vb = ((sb + db)>>8) & 0x0000FF00;
				
				*(pd++) = va + vb;
			}
			
			yctr += iscaley;
			ps += spitch*(yctr>>16);
			yctr &= 0xFFFF;
			pd += dpitch;
		}
	} else {
		// now blit!
		for(y = 0; y < bh; y++)
		{
			xctr = 0;

			for(x = 0; x < bw; x++)
			{
				uint32_t s = ps[xctr>>16];
				uint32_t d = *pd;
				xctr += iscalex;
				
				// apply base color
				// DANGER! BRACKETITIS!
				if(color != 0xFFFFFFFF)
				s = (((s&0xFF)*((color&0xFF))>>8)
					| ((((s>>8)&0xFF)*(((color>>8)&0xFF)+1))&0xFF00)
					| ((((s>>8)&0xFF00)*(((color>>16)&0xFF)+1))&0xFF0000)
					| ((((s>>8)&0xFF0000)*(((color>>24)&0xFF)+1))&0xFF000000)
				);
				
				uint32_t alpha = (s >> 24);
				if(alpha >= 0x80) alpha++;
				uint32_t ialpha = 0x100 - alpha;
				
				uint32_t sa = s & 0x00FF00FF;
				uint32_t sb = (s & 0xFF00FF00)>>8;
				uint32_t da = d & 0x00FF00FF;
				uint32_t db = (d & 0xFF00FF00)>>8;
				
				sa *= alpha;
				sb *= alpha;
				da *= ialpha;
				db *= ialpha;
				
				uint32_t va = ((sa + da)>>8) & 0x00FF00FF;
				uint32_t vb = (sb + db) & 0xFF00FF00;
				uint32_t vv = va+vb;
				
				//if(((uint64_t)pd) < 0x00000000FFFFFFFFL)
				//	printf("%i %i %08X\n", alpha, ialpha, vv);
				
				*(pd++) = vv;
			}
			
			yctr += iscaley;
			ps += spitch*(yctr>>16);
			yctr &= 0xFFFF;
			pd += dpitch;
		}
	}
#else
	// now blit!
	for(y = 0; y < bh; y++)
	{
		xctr = 0;

		for(x = 0; x < bw; x++)
		{
			uint32_t s = ps[xctr>>16];
			uint32_t d = *pd;
			xctr += iscalex;
			
			// apply base color
			// DANGER! BRACKETITIS!
			if(color != 0xFFFFFFFF)
			s = (((s&0xFF)*((color&0xFF))>>8)
				| ((((s>>8)&0xFF)*(((color>>8)&0xFF)+1))&0xFF00)
				| ((((s>>8)&0xFF00)*(((color>>16)&0xFF)+1))&0xFF0000)
				| ((((s>>8)&0xFF0000)*(((color>>24)&0xFF)+1))&0xFF000000)
			);
			
			uint32_t alpha = (s >> 24);
			if(alpha >= 0x80) alpha++;
			uint32_t ialpha = 0x100 - alpha;
			
			uint32_t sa = s & 0x00FF00FF;
			uint32_t sb = (s & 0xFF00FF00)>>8;
			uint32_t da = d & 0x00FF00FF;
			uint32_t db = (d & 0xFF00FF00)>>8;
			
			sa *= alpha;
			sb *= alpha;
			da *= ialpha;
			db *= ialpha;
			
			uint32_t va = ((sa + da)>>8) & 0x00FF00FF;
			uint32_t vb = (sb + db) & 0xFF00FF00;
			uint32_t vv = va+vb;
			
			//if(((uint64_t)pd) < 0x00000000FFFFFFFFL)
			//	printf("%i %i %08X\n", alpha, ialpha, vv);
			
			*(pd++) = vv;
		}
		
		yctr += iscaley;
		ps += spitch*(yctr>>16);
		yctr &= 0xFFFF;
		pd += dpitch;
	}
#endif
}

