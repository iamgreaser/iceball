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

void render_blit_img(uint32_t *pixels, int width, int height, int pitch,
	img_t *src, int dx, int dy, int bw, int bh, int sx, int sy, uint32_t color, float scalex, float scaley)
{
	if (scalex == 0 || scaley == 0)
	{
		return;
	}
	if (scalex != 1 && scaley != 1)
	{
		//TODO: at least some sort of scaling
	}
	int x,y;
	
	// clip blit width/height
	if(bw > src->head.width-sx)
		bw = src->head.width-sx;
	if(bh > src->head.height-sy)
		bh = src->head.height-sy;
	if(sx < 0)
	{
		bw -= -sx;
		dx += -sx;
		sx = 0;
	}
	if(sy < 0)
	{
		bh -= -sy;
		dy += -sy;
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
		sx += -dx;
		bw -= -dx;
		dx = 0;
	}
	if(dy < 0)
	{
		sy += -dy;
		bh -= -dy;
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
	uint32_t *ps = src->pixels;
	ps = &ps[sx+sy*src->head.width];
	uint32_t *pd = &(pixels[dx+dy*pitch]);
	int spitch = src->head.width - bw;
	int dpitch = pitch - bw;
	
	//printf("[%i %i] [%i %i] %016llX %016llX %i %i %08X\n"
	//	, bw, bh, dx, dy, (long long)ps, (long long)pd, dpitch, spitch, color);
	
#ifdef __SSE2__
	// TODO: improve prefetching
	
	// from the Intel 64 and IA-32 Architectures Optimization Manual:
	//
	// Assembly/Compiler Coding Rule 76. (M impact, H generality) Align data to
	// 32-byte boundary when possible. Prefer store alignment over load alignment.
	
	if(bw >= 16)
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
			for(x = 0; x < bw; x++)
			{
				uint32_t s = *(ps++);
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
				uint32_t s = *ps;
				uint32_t d = *pd;
				
				__m128i xmm_src = _mm_loadu_si128((__m128i *)ps);
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
				
				xmm_src0_alpha = (__m128i)_mm_shuffle_ps((__m128)xmm_src0_alpha1,(__m128)xmm_src0_alpha0,0xFF);
				xmm_src1_alpha = (__m128i)_mm_shuffle_ps((__m128)xmm_src1_alpha1,(__m128)xmm_src1_alpha0,0xFF);
				
				
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
				
				ps += 4;
				pd += 4;
			}
			
			// finish off with the right part
			for(; x < bw; x++)
			{
				uint32_t s = *(ps++);
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
			
			ps += spitch;
			pd += dpitch;
		}
	} else {
		// now blit!
		for(y = 0; y < bh; y++)
		{
			for(x = 0; x < bw; x++)
			{
				uint32_t s = *(ps++);
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
			
			ps += spitch;
			pd += dpitch;
		}
	}
#else
#ifdef THISVERSIONISABITSLoWSODONTUSEIT__MMX__
	// TODO: pack this better
	// TODO: MAKE THIS FASTER it's slower than the reference implementation
	const __m64 mmconst_0 = _mm_setzero_si64();
	const __m64 mmconst_256 = _mm_set1_pi16(256);
	const __m64 mmconst_roundcolor = _mm_set_pi16(8,8,8,8);
	const __m64 mmconst_incalpha = _mm_set_pi16(127,0x7FFF,0x7FFF,0x7FFF);
	
	// set base color
	__m64 mm_bcol = _mm_unpacklo_pi8(_mm_cvtsi32_si64(color),mmconst_0);
	
	// now blit!
	for(y = 0; y < bh; y++)
	{
#ifdef __SSE__
		// strip mine
		for(x = 0; x < bw; x += 8)
			_mm_prefetch(ps+x, _MM_HINT_T0);
		for(x = 0; x < bw; x += 8)
			_mm_prefetch(pd+x, _MM_HINT_T0);
#endif
		
		for(x = 0; x < bw; x++)
		{
			uint32_t s = *(ps++);
			uint32_t d = *pd;
			
			__m64 mm_src = _mm_cvtsi32_si64(s);
			__m64 mm_dst = _mm_cvtsi32_si64(d);
			
			// unpack
			mm_src = _mm_unpacklo_pi8(mm_src,mmconst_0);
			mm_dst = _mm_unpacklo_pi8(mm_dst,mmconst_0);
			
			// apply base color
			mm_src = _mm_mulhi_pi16(
				_mm_add_pi16(_mm_slli_pi16(mm_src,  4), mmconst_roundcolor),
				_mm_add_pi16(_mm_slli_pi16(mm_bcol, 4), mmconst_roundcolor));
			
			// increase alpha a bit
			mm_src = _mm_sub_pi16(mm_src,
				_mm_cmpgt_pi16(mm_src,mmconst_incalpha));
			
			// get src alpha
			__m64 mm_src_alpha = mm_src;
			mm_src_alpha = _mm_unpackhi_pi16(mm_src_alpha,mm_src_alpha);
			mm_src_alpha = _mm_unpackhi_pi16(mm_src_alpha,mm_src_alpha);
			
			// get inverse alpha
			__m64 mm_ialpha = _mm_sub_pi16(mmconst_256,mm_src_alpha);
			
			// ALPHA BLAND
			mm_src_alpha = _mm_slli_pi16(mm_src_alpha, 4);
			mm_ialpha = _mm_slli_pi16(mm_ialpha, 4);
			mm_src = _mm_slli_pi16(mm_src, 4);
			mm_dst = _mm_slli_pi16(mm_dst, 4);
			
			__m64 mm_combo = _mm_add_pi16(
				_mm_mulhi_pi16(mm_src_alpha, mm_src),
				_mm_mulhi_pi16(mm_ialpha, mm_dst));
			
			// pack back!
			mm_combo = _mm_packs_pu16(mm_combo, mm_combo);
			*(pd++) = _mm_cvtsi64_si32(mm_combo);
		}
		
		ps += spitch;
		pd += dpitch;
	}
#else
	// now blit!
	for(y = 0; y < bh; y++)
	{
		for(x = 0; x < bw; x++)
		{
			uint32_t s = *(ps++);
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
		
		ps += spitch;
		pd += dpitch;
	}
#endif
#endif
}
