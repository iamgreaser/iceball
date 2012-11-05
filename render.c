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

// TODO: bump up to 127.5f
#define FOG_DISTANCE 40.0f

#define FTB_MAX_PERSPAN 50

#define DF_NX 0x01
#define DF_NY 0x02
#define DF_NZ 0x04
#define DF_PX 0x08
#define DF_PY 0x10
#define DF_PZ 0x20
#define DF_SPREAD 0x3F

enum
{
	CM_NX = 0,
	CM_NY,
	CM_NZ,
	CM_PX,
	CM_PY,
	CM_PZ,
	CM_MAX
};

uint32_t *cubemap_color[CM_MAX];
float *cubemap_depth[CM_MAX];
int cubemap_size;
int cubemap_shift;

uint32_t *rtmp_pixels;
int rtmp_width, rtmp_height, rtmp_pitch;
camera_t *rtmp_camera;
map_t *rtmp_map;

int *ftb_first;

/*
 * REFERENCE IMPLEMENTATION
 * 
 */

uint32_t render_fog_apply(uint32_t color, float depth)
{
	int b = color&255;
	int g = (color>>8)&255;
	int r = (color>>16)&255;
	int t = (color>>24)&255;
	
	float fog = (FOG_DISTANCE-(depth < 0.001f ? 0.001f : depth))/FOG_DISTANCE;
	if(fog > 1.0f)
		fog = 1.0f;
	if(fog < 0.0f)
		fog = 0.0f;
	
	r = (r*fog+0.5f);
	g = (g*fog+0.5f);
	b = (b*fog+0.5f);
	
	return b|(g<<8)|(r<<16)|(t<<24);
}

void render_rect_clip(uint32_t *color, int *x1, int *y1, int *x2, int *y2, float depth)
{
	*color = render_fog_apply(*color, depth);
	
	// arrange *1 <= *2
	if(*x1 > *x2)
	{
		int t = *x1;
		*x1 = *x2;
		*x2 = t;
	}
	
	if(*y1 > *y2)
	{
		int t = *y1;
		*y1 = *y2;
		*y2 = t;
	}
	
	// clip
	if(*x1 < 0)
		*x1 = 0;
	if(*y1 < 0)
		*y1 = 0;
	if(*x2 > cubemap_size)
		*x2 = cubemap_size;
	if(*y2 > cubemap_size)
		*y2 = cubemap_size;
}

void render_vxl_rect_btf(uint32_t *ccolor, float *cdepth, int x1, int y1, int x2, int y2, uint32_t color, float depth)
{
	int x,y;
	
	// clip
	render_rect_clip(&color, &x1, &y1, &x2, &y2, depth);
	
	if(x2 <= 0)
		return;
	if(x1 >= cubemap_size)
		return;
	if(y2 <= 0)
		return;
	if(y1 >= cubemap_size)
		return;
	if(x1 == x2)
		return;
	if(y1 == y2)
		return;
	
	// render
	uint32_t *cptr = &ccolor[(y1<<cubemap_shift)+x1];
	float *dptr = &cdepth[(y1<<cubemap_shift)+x1];
	int stride = x2-x1;
	int pitch = cubemap_size - stride;
	
	// split it into two, it's more cache/register-friendly (i think)
	
	// FIXME: the depth loop causes a crash! don't use this yet!
//if defined(USE_ASM) && (defined(__i386__) || defined(__amd64__))
#if 0
	int ylen = y2-y1;
	//stride <<= 2;
	pitch <<= 2;
	//printf("%i %i %i %i\n",x1,x2,y1,y2);
	// AT%T SYNTAX SUCKS
	__asm__ (
		"render_vxl_rect_btf_lp_color_y:\n\t"
#if defined(__amd64__)
		"movq %0, %%rcx\n\t"
#else
		"movl %0, %%ecx\n\t"
#endif
		"cld\n\trep\n\tstosl\n\t" // IT'S REP STOSD YOU *IDIOTS*!
#if defined(__amd64__)
		"add %1, %%rdi\n\t"
#else
		"add %1, %%edi\n\t"
#endif
		"dec %2\n\t"
		"jnz render_vxl_rect_btf_lp_color_y\n\t"
		: /* no outputs */
#if defined(__amd64__)
		: "g"((uint64_t)stride), "g"((uint64_t)pitch), "g"((uint64_t)ylen),
			"D"(cptr), "a"(color)
#else
		: "g"(stride), "g"(pitch), "g"(ylen), 
			"D"(cptr), "a"(color)
#endif
		: "ecx", "%1", "%2"
	);
	
	//printf("%i %i %i\n",y1,y2,ylen);
	
	// FIXME: depth causes a crash, probably because i suck at inline asm
	/*
	uint32_t idepth = *(uint32_t *)(float *)&depth;
	
	__asm__ __volatile__ (
		"render_vxl_rect_btf_lp_depth_y:\n\t"
#if defined(__amd64__)
		"movq %0, %%rcx\n\t"
#else
		"movl %0, %%ecx\n\t"
#endif
		"cld\n\trep\n\tstosl\n\t" // IT'S REP STOSD YOU *IDIOTS*!
#if defined(__amd64__)
		"add %1, %%rdi\n\t"
#else
		"add %1, %%edi\n\t"
#endif
		"dec %2\n\t"
		"jnz render_vxl_rect_btf_lp_depth_y\n\t"
		: // no outputs
#if defined(__amd64__)
		: "g"((uint64_t)stride), "g"((uint64_t)pitch), "g"((uint64_t)ylen),
			"D"(dptr), "a"(idepth)
#else
		: "g"(stride), "g"(pitch), "g"(ylen), 
			"D"(dptr), "a"(idepth)
#endif
		: "ecx", "%1", "%2", "memory"
	);
	*/
	
#else
	for(y = y1; y < y2; y++)
	{
		for(x = x1; x < x2; x++)
			*(cptr++) = color;
		
		cptr += pitch;
	}
	
	for(y = y1; y < y2; y++)
	{
		for(x = x1; x < x2; x++)
			*(dptr++) = depth;
		
		dptr += pitch;
	}
#endif
}

// TODO: get my head around this.
void todo_render_vxl_rect_ftb_fast(uint32_t *ccolor, float *cdepth, int x1, int y1, int x2, int y2, uint32_t color, float depth)
{
	int x,y;
	
	// clip
	render_rect_clip(&color, &x1, &y1, &x2, &y2, depth);
	
	if(x2 <= 0)
		return;
	if(x1 >= cubemap_size)
		return;
	if(y2 <= 0)
		return;
	if(y1 >= cubemap_size)
		return;
	if(x1 == x2)
		return;
	if(y1 == y2)
		return;
	
	// render
	uint32_t *cptr = &ccolor[(y1<<cubemap_shift)+x1];
	uint32_t *cstarty = &ccolor[(y1<<cubemap_shift)];
	float *dptr = &cdepth[(y1<<cubemap_shift)+x1];
	int pitch = cubemap_size - (x2-x1);
	
	for(y = y1; y < y2; y++)
	{
		// read from FTB buffer
		int *lf = &(ftb_first[y]);
		int f = *lf;
		
		// UPPER = next
		// LOWER = length
		
		while(f < x2)
		{
			// read value
			uint32_t *pv = &(ccolor[f]);
			uint32_t v = *pv;
			
			// check if we're in the right sort of area
			if(f >= x1)
			{
				// plot it
				for(x = x1; x < x2; x++)
					*(cptr++) = color;
				
				for(x = x1; x < x2; x++)
					*(dptr++) = depth;
				
			} else if(x1 < f+(int)(v&0xFFFF)) {
				
			}
			
			lf = (int *)&ccolor[f];
		}
		
		cptr += pitch;
		dptr += pitch;
		cstarty += cubemap_size;
	}
}

void render_vxl_rect_ftb_fast(uint32_t *ccolor, float *cdepth, int x1, int y1, int x2, int y2, uint32_t color, float depth)
//void render_vxl_rect_ftb_slow(uint32_t *ccolor, float *cdepth, int x1, int y1, int x2, int y2, uint32_t color, float depth)
{
	int x,y;
	
	// TODO: stop using this bloody function
	// (alternatively, switch to the fast FTB as used in Doom and Quake)
	//
	// NOTE: this approach seems to be faster than render_vxl_rect_btf.
	
	// clip
	render_rect_clip(&color, &x1, &y1, &x2, &y2, depth);
	
	if(x2 <= 0)
		return;
	if(x1 >= cubemap_size)
		return;
	if(y2 <= 0)
		return;
	if(y1 >= cubemap_size)
		return;
	if(x1 == x2)
		return;
	if(y1 == y2)
		return;
	
	// render
	uint32_t *cptr = &ccolor[(y1<<cubemap_shift)+x1];
	float *dptr = &cdepth[(y1<<cubemap_shift)+x1];
	int pitch = cubemap_size - (x2-x1);
	
	for(y = y1; y < y2; y++)
	{
		for(x = x1; x < x2; x++)
		{
			if(*cptr == 0)
			{
				*cptr = color;
				*dptr = depth;
			}
			cptr++;
			dptr++;
		}
		
		cptr += pitch;
		dptr += pitch;
	}
}

void render_vxl_trap_ftb_fast(uint32_t *ccolor, float *cdepth,
	int x1, int y1, int x2, int y2, int x3, int y3, int x4, int y4,
	uint32_t color, float depth)
//void render_vxl_trap_ftb_slow(uint32_t *ccolor, float *cdepth,
//	int x1, int y1, int x2, int y2, int x3, int y3, int x4, int y4,
//	uint32_t color, float depth)
{
	// TODO: fast FTB version
	//render_fog_apply(&color, depth);
	// TODO: clip
	// TODO: form actual trapezia
	int x12 = (x1+x2)>>1;
	int x23 = (x2+x3)>>1;
	int x34 = (x3+x4)>>1;
	int x41 = (x4+x1)>>1;
	
	int y12 = (y1+y2)>>1;
	int y23 = (y2+y3)>>1;
	int y34 = (y3+y4)>>1;
	int y41 = (y4+y1)>>1;
	
	//render_vxl_rect_ftb_fast(ccolor, cdepth, x1, y1, x2,);
}

void render_vxl_cube(uint32_t *ccolor, float *cdepth, int x1, int y1, int x2, int y2, uint32_t color, float depth)
{
	render_vxl_rect_ftb_fast(ccolor, cdepth, x1, y1, x2, y2, color, depth);
	
	int hsize = (cubemap_size>>1);
	
	int x3 = ((x1-hsize)*depth)/(depth+0.5f)+hsize;
	int y3 = ((y1-hsize)*depth)/(depth+0.5f)+hsize;
	int x4 = ((x2-hsize)*depth)/(depth+0.5f)+hsize;
	int y4 = ((y2-hsize)*depth)/(depth+0.5f)+hsize;
	
	// TODO: replace these with trapezium drawing routines
	if(x3 < x1)
		render_vxl_rect_ftb_fast(ccolor, cdepth,
			(int)x3, (int)y3, (int)x1, (int)y4,
			color, depth);
	else if(x2 < x4)
		render_vxl_rect_ftb_fast(ccolor, cdepth,
			(int)x2, (int)y3, (int)x4, (int)y4,
			color, depth);
	
	if(y3 < y1)
		render_vxl_rect_ftb_fast(ccolor, cdepth,
			(int)x3, (int)y3, (int)x4, (int)y1,
			color, depth);
	else if(y2 < y4)
		render_vxl_rect_ftb_fast(ccolor, cdepth,
			(int)x3, (int)y2, (int)x4, (int)y4,
			color, depth);
}

void render_vxl_face_vert(int blkx, int blky, int blkz,
	float subx, float suby, float subz,
	int face,
	int gx, int gy, int gz)
{
	// TODO: this function sucks, speed it up a bit
	int sx,sy;
	int i;
	
	float tracemul = cubemap_size/2;
	float traceadd = tracemul;
	
	// get cubemaps
	uint32_t *ccolor = cubemap_color[face];
	float *cdepth = cubemap_depth[face];
	
	// clear cubemap
	for(i = 0; i < cubemap_size*cubemap_size; i++)
	{
		ccolor[i] = 0x00000000;
		cdepth[i] = FOG_DISTANCE;
	}
	
	// clear FTB buffers
	for(i = 0; i < cubemap_size; i++)
	{
		ftb_first[i] = 0;
		//ccolor[i<<cubemap_shift] = cubemap_size|(cubemap_size<<16);
	}
	
	// get X cube direction
	int xgx = gz+gy;
	int xgy = 0;
	int xgz = -gx;
	
	// get Y cube direction
	int ygx = 0;
	int ygy = gx+gz;
	int ygz = gy;
	
	// get cubemap offset
	float cmoffsx = -(xgx*subx+xgy*suby+xgz*subz);
	float cmoffsy = -(ygx*subx+ygy*suby+ygz*subz);
	
	// get distance to wall
	float dist = -(subx*gx+suby*gy+subz*gz);
	if(dist < 0.0f)
		dist = 1.0f+dist;
	else {
		blky--;
		
		blkx--;
		blkz--;
	}
	dist -= 1.0f;
	
	int coz = blky;
	
	// now loop and follow through
	while(dist < FOG_DISTANCE)
	{
		if(coz < 0 || coz >= rtmp_map->ylen)
		{
			coz += gy;
			dist += 1.0f;
			
			if(gy*coz > 0)
				break;
			
			continue;
		}
		
		// calculate frustum
		int frustum = (int)(dist*cubemap_size);
		
		// prep boundaries
		int bx1 = 0;
		int by1 = 0;
		int bx2 = frustum*2;
		int by2 = frustum*2;
		
		// clamp wrt pixel counts
		// TODO!
		
		// relocate
		bx1 -= frustum;
		by1 -= frustum;
		bx2 -= frustum;
		by2 -= frustum;
		
		// need to go towards 0, not -inf!
		// (can be done as shifts, just looks nicer this way)
		bx1 /= cubemap_size;
		by1 /= cubemap_size;
		bx2 /= cubemap_size;
		by2 /= cubemap_size;
		
		bx1--;by1--;
		bx2+=2;by2+=2;
		
		// go through loop
		int cox,coy;
		
		//printf("%.3f %i %i %i %i\n ", dist, bx1, by1, bx2, by2);
		
		if(dist >= 0.001f)
		{
			float boxsize = tracemul/dist;
			if(gy >= 0)
			{
				// bottom cubemap face
				for(cox = bx1; cox <= bx2; cox++)
				for(coy = by1; coy <= by2; coy++)
				{
					uint8_t *pillar = rtmp_map->pillars[
						((cox+blkx)&(rtmp_map->xlen-1))
						+(((coy+blkz)&(rtmp_map->zlen-1))*rtmp_map->xlen)]+4;
					
					//printf("%4i %4i %4i - %i %i %i %i\n",cox,coy,coz,
					//	pillar[0],pillar[1],pillar[2],pillar[3]);
					// get correct height
					
					int ln = 0;
					for(;;)
					{
						if(coz >= pillar[1] && coz <= pillar[2])
						{
							// TODO: distinguish between top and nontop faces
							
							float px1 = (cox+cmoffsx)*boxsize+traceadd;
							float py1 = (coy+cmoffsy)*boxsize+traceadd;
							float px2 = px1+boxsize;
							float py2 = py1+boxsize;
							//printf("%i %i %i %i\n",(int)px1,(int)py1,(int)px2,(int)py2);
							
							render_vxl_cube(ccolor, cdepth,
								(int)px1, (int)py1, (int)px2, (int)py2,
								*(uint32_t *)(&pillar[4*(coz-pillar[1]+1)]), dist);
							break;
							
						} else if(ln != 0 && (coz < pillar[3] && coz > pillar[3]-ln)) {
							float px1 = (cox+cmoffsx)*boxsize+traceadd;
							float py1 = (coy+cmoffsy)*boxsize+traceadd;
							float px2 = px1+boxsize;
							float py2 = py1+boxsize;
							//printf("%i %i %i %i\n",(int)px1,(int)py1,(int)px2,(int)py2);
							
							render_vxl_cube(ccolor, cdepth,
								(int)px1, (int)py1, (int)px2, (int)py2,
								*(uint32_t *)(&pillar[4*(coz-pillar[3])]), dist);
							// TODO: sides
							break;
						} else if(pillar[0] == 0 || (coz < pillar[1])) {
							break;
						} else {
							ln = pillar[0]-(pillar[2]-pillar[1]+1);
							pillar += pillar[0]*4;
						}
					}
					
				}
			} else {
				// top cubemap face
				for(cox = bx1; cox <= bx2; cox++)
				for(coy = by1; coy <= by2; coy++)
				{
					uint8_t *pillar = rtmp_map->pillars[
						((cox+blkx)&(rtmp_map->xlen-1))
						+(((coy+blkz)&(rtmp_map->zlen-1))*rtmp_map->xlen)]+4;
					
					//if(pillar[0] == 0)
					//	continue;
					
					//printf("%4i %4i %4i - %i %i %i %i\n",cox,coy,coz,
					//	pillar[0],pillar[1],pillar[2],pillar[3]);
					// get correct height
					int ln = 0;
					for(;;)
					{
						if(coz >= pillar[1] && coz <= pillar[2])
						{
							float px1 = (-cox+cmoffsx)*boxsize+traceadd;
							float py1 = (-coy+cmoffsy)*boxsize+traceadd;
							float px2 = px1+boxsize;
							float py2 = py1+boxsize;
							
							render_vxl_cube(ccolor, cdepth,
								(int)px1, (int)py1, (int)px2, (int)py2,
								*(uint32_t *)(&pillar[4*(coz-pillar[1]+1)]), dist);
							// TODO: sides
							// wait, how the hell am i going to do these here?!
							break;
						} else if(ln != 0 && (coz < pillar[3] && coz > pillar[3]-ln)) {
							float px1 = (-cox+cmoffsx)*boxsize+traceadd;
							float py1 = (-coy+cmoffsy)*boxsize+traceadd;
							float px2 = px1+boxsize;
							float py2 = py1+boxsize;
							//printf("%i %i %i %i\n",(int)px1,(int)py1,(int)px2,(int)py2);
							
							render_vxl_cube(ccolor, cdepth,
								(int)px1, (int)py1, (int)px2, (int)py2,
								*(uint32_t *)(&pillar[4*(coz-pillar[3])]), dist);
							// TODO: sides
							break;
						} else if(pillar[0] == 0 || (coz < pillar[1])) {
							break;
						} else {
							ln = pillar[0]-(pillar[2]-pillar[1]+1);
							pillar += pillar[0]*4;
						}
					}
					
				}
			}
		}
		
		coz += gy;
		dist += 1.0f;
	}
}

void render_vxl_face_horiz(int blkx, int blky, int blkz,
	float subx, float suby, float subz,
	int face,
	int gx, int gy, int gz)
{
	int sx,sy;
	int i;
	
	float tracemul = cubemap_size/2;
	float traceadd = tracemul;
	
	// get cubemaps
	uint32_t *ccolor = cubemap_color[face];
	float *cdepth = cubemap_depth[face];
	
	// clear cubemap
	for(i = 0; i < cubemap_size*cubemap_size; i++)
	{
		ccolor[i] = 0x00000000;
		cdepth[i] = FOG_DISTANCE;
	}
	
	// clear FTB buffers
	for(i = 0; i < cubemap_size; i++)
	{
		ftb_first[i] = 0;
		//ccolor[i<<cubemap_shift] = cubemap_size|(cubemap_size<<16);
	}
	
	// get X cube direction
	int xgx = gz+gy;
	int xgy = 0;
	int xgz = -gx;
	
	// get Y cube direction
	int ygx = 0;
	int ygy = gx+gz;
	int ygz = gy;
	
	// get cubemap offset
	float cmoffsx = -(xgx*subx+xgy*suby+xgz*subz);
	float cmoffsy = -(ygx*subx+ygy*suby+ygz*subz);
	if(cmoffsy >= 0.0f)
		cmoffsy = -cmoffsy;
	if(cmoffsx >= 0.0f)
		cmoffsx -= 1.0f;
	//else
	//	blky--;
	
	
	// get distance to wall
	float dist = -(subx*gx+suby*gy+subz*gz);
	if(dist < 0.0f)
		dist = 1.0f+dist;
	dist -= 1.0f;
	
	int coz = blky;
	
	// now loop and follow through
	while(dist < FOG_DISTANCE)
	{
		// calculate frustum
		int frustum = (int)(dist*cubemap_size);
		
		// prep boundaries
		int bx1 = 0;
		int by1 = 0;
		int bx2 = frustum*2;
		int by2 = frustum*2;
		
		// clamp wrt pixel counts
		// TODO!
		
		// relocate
		bx1 -= frustum;
		by1 -= frustum;
		bx2 -= frustum;
		by2 -= frustum;
		
		// need to go towards 0, not -inf!
		// (can be done as shifts, just looks nicer this way)
		bx1 /= cubemap_size;
		by1 /= cubemap_size;
		bx2 /= cubemap_size;
		by2 /= cubemap_size;
		
		bx1-=2;by1--;
		bx2+=2;by2++;
		
		// go through loop
		int cox,coy;
		cox = 0;
		coy = 0;
		
		if(dist >= 0.001f)
		{
			float boxsize = tracemul/dist;
			float nboxsize = tracemul/(dist+0.5f);
			for(cox = bx1; cox <= bx2; cox++)
			{
				coz = 0;
				
				uint8_t *pillar = rtmp_map->pillars[
					((cox*gz+blkx)&(rtmp_map->xlen-1))
					+(((-cox*gx+blkz)&(rtmp_map->zlen-1))*rtmp_map->xlen)]+4;
				
				//printf("%4i %4i %4i - %i %i %i %i\n",cox,coy,coz,
				//	pillar[0],pillar[1],pillar[2],pillar[3]);
				
				for(;;)
				{
					uint8_t *pcol = pillar+4;
					
					// render top
					if(pillar[2]-blky >= by1 && pillar[1]-blky <= by2)
					for(coz = pillar[1]; coz <= pillar[2]; coz++)
					{
						if(coz-blky >= by1 && coz-blky <= by2)
						{
							float px1 = (cox+cmoffsx)*boxsize+traceadd;
							float py1 = (coz+cmoffsy-blky)*boxsize+traceadd;
							float px2 = px1+boxsize;
							float py2 = py1+boxsize;
							
							render_vxl_cube(ccolor, cdepth,
								(int)px1, (int)py1, (int)px2, (int)py2,
								*((uint32_t *)pcol), dist);
						}
						pcol+=4;
					}
					
					// advance where sensible
					if(pillar[2]-blky > by2)
						break;
					
					if(pillar[0] == 0)
						break;
					
					pillar += pillar[0]*4;
					
					// render bottom
					int diff = (pillar-pcol)>>2;
					
					for(coz = pillar[3]-diff; coz < pillar[3]; coz++)
					{
						if(coz-blky >= by1 && coz-blky <= by2)
						{
							float px1 = (cox+cmoffsx)*boxsize+traceadd;
							float py1 = (coz+cmoffsy-blky)*boxsize+traceadd;
							float px2 = px1+boxsize;
							float py2 = py1+boxsize;
							
							render_vxl_cube(ccolor, cdepth,
								(int)px1, (int)py1, (int)px2, (int)py2,
								*((uint32_t *)pcol), dist);
						}
						pcol+=4;
					}
				}
			}
		}
		
		dist += 1.0f;
		blkx += gx;
		blkz += gz;
	}
}

void render_vxl_redraw(camera_t *camera, map_t *map)
{
	int x,y,z;
	
	// stash stuff in globals to prevent spamming the stack too much
	// (and in turn thrashing the cache)
	rtmp_camera = camera;
	rtmp_map = map;
	
	// get block pos
	int blkx = ((int)floor(camera->mpx)) & (map->xlen-1);
	int blky = ((int)floor(camera->mpy));// & (map->ylen-1);
	int blkz = ((int)floor(camera->mpz)) & (map->zlen-1);
	
	// get block subpos
	float subx = (camera->mpx - floor(camera->mpx));
	float suby = (camera->mpy - floor(camera->mpy));
	float subz = (camera->mpz - floor(camera->mpz));
	
	// render each face
	render_vxl_face_horiz(blkx, blky, blkz, subx, suby, subz, CM_NX, -1,  0,  0);
	render_vxl_face_vert(blkx, blky, blkz, subx, suby, subz, CM_NY,  0, -1,  0);
	render_vxl_face_horiz(blkx, blky, blkz, subx, suby, subz, CM_NZ,  0,  0, -1);
	render_vxl_face_horiz(blkx, blky, blkz, subx, suby, subz, CM_PX,  1,  0,  0);
	render_vxl_face_vert(blkx, blky, blkz, subx, suby, subz, CM_PY,  0,  1,  0);
	render_vxl_face_horiz(blkx, blky, blkz, subx, suby, subz, CM_PZ,  0,  0,  1);
}

void render_cubemap(uint32_t *pixels, int width, int height, int pitch, camera_t *camera, map_t *map)
{
	int x,y,z;
	
	// stash stuff in globals to prevent spamming the stack too much
	// (and in turn thrashing the cache)
	rtmp_pixels = pixels;
	rtmp_width = width;
	rtmp_height = height;
	rtmp_pitch = pitch;
	rtmp_camera = camera;
	rtmp_map = map;
	
	// get corner traces
	float tracemul = cubemap_size/2;
	float traceadd = tracemul;
	float ctrx1 = (camera->mzx+camera->mxx-camera->myx);
	float ctry1 = (camera->mzy+camera->mxy-camera->myy);
	float ctrz1 = (camera->mzz+camera->mxz-camera->myz);
	float ctrx2 = (camera->mzx-camera->mxx-camera->myx);
	float ctry2 = (camera->mzy-camera->mxy-camera->myy);
	float ctrz2 = (camera->mzz-camera->mxz-camera->myz);
	float ctrx3 = (camera->mzx+camera->mxx+camera->myx);
	float ctry3 = (camera->mzy+camera->mxy+camera->myy);
	float ctrz3 = (camera->mzz+camera->mxz+camera->myz);
	float ctrx4 = (camera->mzx-camera->mxx+camera->myx);
	float ctry4 = (camera->mzy-camera->mxy+camera->myy);
	float ctrz4 = (camera->mzz-camera->mxz+camera->myz);
	
	// calculate deltas
	float fbx = ctrx1, fby = ctry1, fbz = ctrz1; // base
	float fex = ctrx2, fey = ctry2, fez = ctrz2; // end
	float flx = ctrx3-fbx, fly = ctry3-fby, flz = ctrz3-fbz; // left side
	float frx = ctrx4-fex, fry = ctry4-fey, frz = ctrz4-fez; // right side
	flx /= (float)width; fly /= (float)width; flz /= (float)width;
	frx /= (float)width; fry /= (float)width; frz /= (float)width;
	
	// scale cubemap correctly
	fbx += flx*((float)(width-height))/2.0f;
	fby += fly*((float)(width-height))/2.0f;
	fbz += flz*((float)(width-height))/2.0f;
	fex += frx*((float)(width-height))/2.0f;
	fey += fry*((float)(width-height))/2.0f;
	fez += frz*((float)(width-height))/2.0f;
	
	// raytrace it
	// TODO: find some faster method
	uint32_t *p = pixels;
	int hwidth = width/2;
	int hheight = height/2;
	for(y = -hheight; y < hheight; y++)
	{
		float fx = fbx;
		float fy = fby;
		float fz = fbz;
		
		float fdx = (fex-fbx)/(float)width;
		float fdy = (fey-fby)/(float)width;
		float fdz = (fez-fbz)/(float)width;
		
		for(x = -hwidth; x < hwidth; x++)
		{
			// get correct cube map and draw
			if(fabsf(fx) > fabsf(fy) && fabsf(fx) > fabsf(fz))
			{
				*p++ = cubemap_color[fx >= 0.0f ? CM_PX : CM_NX][
					((cubemap_size-1)&(int)(-fz*tracemul/fx+traceadd))
					|(((cubemap_size-1)&(int)(fy*tracemul/fabsf(fx)+traceadd))<<cubemap_shift)];
			} else if(fabsf(fz) > fabsf(fy) && fabsf(fz) > fabsf(fx)) {
				*p++ = cubemap_color[fz >= 0.0f ? CM_PZ : CM_NZ][
					((cubemap_size-1)&(int)(fx*tracemul/fz+traceadd))
					|(((cubemap_size-1)&(int)(fy*tracemul/fabsf(fz)+traceadd))<<cubemap_shift)];
			} else {
				*p++ = cubemap_color[fy >= 0.0f ? CM_PY : CM_NY][
					((cubemap_size-1)&(int)(fx*tracemul/fy+traceadd))
					|(((cubemap_size-1)&(int)(fz*tracemul/fy+traceadd))<<cubemap_shift)];
			}
			
			fx += fdx;
			fy += fdy;
			fz += fdz;
		}
		
		p += pitch-width;
		
		fbx += flx;
		fby += fly;
		fbz += flz;
		
		fex += frx;
		fey += fry;
		fez += frz;
	}
	
	/*
	// TEST: draw something
	for(x = 0; x < 512; x++)
	for(y = 0; y < 512; y++)
	{
		pixels[y*pitch+x] = *(uint32_t *)&(map->pillars[y*map->xlen+x][8]);
		//pixels[y*pitch+x] = cubemap_color[CM_PZ][y*cubemap_size+x];
	}*/
}

int render_init(int width, int height)
{
	int i;
	int size = (width > height ? width : height);
	
	// get nearest power of 2
	size = (size-1);
	size |= size>>1;
	size |= size>>2;
	size |= size>>4;
	size |= size>>8;
	size++;
	
	// reduce quality a little bit
	// 800x600 -> 1024^2 -> 512^2 ends up as 1MB x 6 textures = 6MB
	
	size >>= 1;
	
	// allocate cubemaps
	for(i = 0; i < CM_MAX; i++)
	{
		cubemap_color[i] = malloc(size*size*4);
		cubemap_depth[i] = malloc(size*size*4);
		if(cubemap_color[i] == NULL || cubemap_depth[i] == NULL)
		{
			// Can't allocate :. Can't continue
			// Clean up like a boss
			fprintf(stderr, "render_init: could not allocate cubemap %i\n", i);
			for(; i >= 0; i--)
			{
				if(cubemap_color[i] != NULL)
					free(cubemap_color[i]);
				if(cubemap_depth[i] != NULL)
					free(cubemap_depth[i]);
				cubemap_color[i] = NULL;
				cubemap_depth[i] = NULL;
			}
			
			return 1;
		}
	}
	
	// we might as well set this, too!
	cubemap_size = size;
	
	// calculate shift factor
	cubemap_shift = -1;
	while(size != 0)
	{
		cubemap_shift++;
		size >>= 1;
	}
	
	// allocate space for FTB buffers
	ftb_first = malloc(cubemap_size*sizeof(int));
	// TODO: check if NULL
	
	return 0;
}

void render_deinit(void)
{
	int i;
	
	// deallocate cubemaps
	for(i = 0; i < CM_MAX; i++)
	{
		if(cubemap_color[i] != NULL)
		{
			free(cubemap_color[i]);
			cubemap_color[i] = NULL;
		}
		if(cubemap_depth[i] != NULL)
		{
			free(cubemap_depth[i]);
			cubemap_depth[i] = NULL;
		}
	}
	
	// deallocate FTB buffers
	if(ftb_first != NULL)
	{
		free(ftb_first);
		ftb_first = NULL;
	}
}
