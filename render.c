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

#if 0
#define DEBUG_INVERT_DRAW_DIR
#endif
#if 0
#define DEBUG_SHOW_TOP_BOTTOM
#define DEBUG_HIDE_MAIN
#endif
// TODO: bump up to 127.5f
#define FOG_DISTANCE 60.0f

#define RAYC_MAX ((int)((FOG_DISTANCE+1)*(FOG_DISTANCE+1)*8+10))

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

typedef struct raydata {
	int16_t x,y,z;
	int8_t gx,gz;
	
	float y1,y2;
	float sx,sy,sz;
} raydata_t;

typedef struct rayblock {
	uint32_t color;
	float x,y,z;
} rayblock_t;

int rayc_block_len, rayc_block_head;
int rayc_data_len, rayc_data_head;
raydata_t rayc_data[RAYC_MAX];
rayblock_t *rayc_block = NULL;
int *rayc_mark = NULL;
int rayc_block_size = 0;
int rayc_mark_size = 0;

float *dbuf;

#ifdef RENDER_FACE_COUNT
	int render_face_current = 0;
	int render_face_remain = 0;
#endif


/*
 * REFERENCE IMPLEMENTATION
 * 
 */

uint32_t render_fog_apply_new(uint32_t color, float depth)
{
	int b = color&255;
	int g = (color>>8)&255;
	int r = (color>>16)&255;
	int t = (color>>24)&255;
	
	//float fog = (FOG_DISTANCE*FOG_DISTANCE/depth)/256.0f;
	float fog = (FOG_DISTANCE*FOG_DISTANCE-(depth < 0.001f ? 0.001f : depth))
		/(FOG_DISTANCE*FOG_DISTANCE);
	if(fog > 1.0f)
		fog = 1.0f;
	if(fog < 0.0f)
		fog = 0.0f;
	
	r = (r*fog+0.5f);
	g = (g*fog+0.5f);
	b = (b*fog+0.5f);
	
	return b|(g<<8)|(r<<16)|(t<<24);
}

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

void render_rect_clip_screen(uint32_t *color, int *x1, int *y1, int *x2, int *y2, float depth)
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
	if(*x2 > rtmp_width)
		*x2 = rtmp_width;
	if(*y2 > rtmp_height)
		*y2 = rtmp_height;
}

void render_rect_zbuf(uint32_t *ccolor, float *cdepth, int x1, int y1, int x2, int y2, uint32_t color, float depth)
{
	int x,y;
	
	// clip
	render_rect_clip_screen(&color, &x1, &y1, &x2, &y2, depth);
	//uint32_t dummy;
	//render_rect_clip_screen(&dummy, &x1, &y1, &x2, &y2, depth);
	
	if(x2 <= 0)
		return;
	if(x1 >= rtmp_width)
		return;
	if(y2 <= 0)
		return;
	if(y1 >= rtmp_height)
		return;
	if(x1 == x2)
		return;
	if(y1 == y2)
		return;
	
	// render
	uint32_t *cptr = &ccolor[y1*rtmp_pitch+x1];
	float *dptr = &cdepth[y1*rtmp_width+x1];
	int stride = x2-x1;
	int pitch = rtmp_pitch - stride;
	int dpitch = rtmp_width - stride;
	
	for(y = y1; y < y2; y++)
	{
		for(x = x1; x < x2; x++)
		{
			if(*dptr > depth)
			{
				*dptr = depth;
				*cptr = color;
			}
			cptr++; dptr++;
		}
		
		dptr += dpitch;
		cptr += pitch;
	}
}

// TODO: fast ver?
void render_vxl_rect_ftb_fast(uint32_t *ccolor, float *cdepth, int x1, int y1, int x2, int y2, uint32_t color, float depth)
//void render_vxl_rect_ftb_slow(uint32_t *ccolor, float *cdepth, int x1, int y1, int x2, int y2, uint32_t color, float depth)
{
	int x,y;
	
	// TODO: stop using this bloody function
	// (alternatively, switch to the fast FTB as used in Doom and Quake)
	//
	// NOTE: this approach seems to be faster than render_vxl_rect_btf.
	
	// clip
	uint32_t dummy;
	render_rect_clip(&dummy, &x1, &y1, &x2, &y2, depth);
	
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

void render_vxl_cube_sides(uint32_t *ccolor, float *cdepth, int x1, int y1, int x2, int y2, uint32_t color, float depth)
{
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

void render_vxl_cube(uint32_t *ccolor, float *cdepth, int x1, int y1, int x2, int y2, uint32_t color, float depth)
{
	render_vxl_rect_ftb_fast(ccolor, cdepth, x1, y1, x2, y2, color, depth);
	render_vxl_cube_sides(ccolor, cdepth, x1, y1, x2, y2, color, depth);
}

void render_vxl_face_raycast(int blkx, int blky, int blkz,
	float subx, float suby, float subz,
	int face,
	int gx, int gy, int gz)
{
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
	
	// get X cube direction
	int xgx = gz+gy;
	int xgy = 0;
	int xgz = -gx;
	
	// get Y cube direction
	int ygx = 0;
	int ygy = fabsf(gx+gz);
	int ygz = gy;
	
	// get base pos
	float bx = blkx+subx;
	float by = blky+suby;
	float bz = blkz+subz;
	
	if(xgx+xgy+xgz < 0)
	{
		bx += xgx;
		by += xgy;
		bz += xgz;
	}
	
	if(ygx+ygy+ygz < 0)
	{
		bx += ygx;
		by += ygy;
		bz += ygz;
	}
	
	if(gx+gy+gz < 0)
	{
		bx += gx;
		by += gy;
		bz += gz;
	}
	
	// now crawl through the block list
#ifdef DEBUG_INVERT_DRAW_DIR
	rayblock_t *b = &rayc_block[rayc_block_len-1];
	rayblock_t *b_end = &rayc_block[0];
	for(; b >= b_end; b--)
#else
	rayblock_t *b = &rayc_block[0];
	rayblock_t *b_end = &rayc_block[rayc_block_len];
	for(; b < b_end; b++)
#endif
	{
		// get block delta
		float dx = b->x - bx;
		float dy = b->y - by;
		float dz = b->z - bz;
		
		// get correct screen positions
		float sx = dx*xgx+dy*xgy+dz*xgz;
		float sy = dx*ygx+dy*ygy+dz*ygz;
		float sz = dx* gx+dy* gy+dz* gz;
		
		// check distance
		if(sz < 0.001f || sz >= FOG_DISTANCE)
			continue;
		
		// frustum cull
		if(fabsf(sx) > fabsf(sz+2.0f) || fabsf(sy) > fabsf(sz+2.0f))
			continue;
		
		// draw
		float boxsize = tracemul/fabsf(sz);
		float px1 = sx*boxsize+traceadd;
		float py1 = sy*boxsize+traceadd;
		float px2 = px1+boxsize;
		float py2 = py1+boxsize;
		
		uint32_t xcolor = render_fog_apply_new(b->color, sx*sx+sy*sy+sz*sz);
		
		render_vxl_cube(ccolor, cdepth,
			(int)px1, (int)py1, (int)px2, (int)py2,
			xcolor, sz);
	}
}

void render_vxl_redraw(camera_t *camera, map_t *map)
{
	int i,x,y,z;
	
	// stash stuff in globals to prevent spamming the stack too much
	// (and in turn thrashing the cache)
	rtmp_camera = camera;
	rtmp_map = map;
	
	// stash x/y/zlen
	int xlen = map->xlen;
	int ylen = map->ylen;
	int zlen = map->zlen;
	
	// get block pos
	int blkx = ((int)floor(camera->mpx)) & (xlen-1);
	int blky = ((int)floor(camera->mpy));// & (ylen-1);
	int blkz = ((int)floor(camera->mpz)) & (zlen-1);
	
	// get block subpos
	float subx = (camera->mpx - floor(camera->mpx));
	float suby = (camera->mpy - floor(camera->mpy));
	float subz = (camera->mpz - floor(camera->mpz));
	
	// get centre (base) pos
	float bx = blkx + subx;
	float by = blky + suby;
	float bz = blkz + subz;
	
	// check if we need to reallocate the mark table and block list
	{
		int markbase = xlen * zlen;
		int blockbase = markbase * ylen;
		
		if(rayc_mark_size != markbase)
		{
			rayc_mark_size = markbase;
			rayc_mark = realloc(rayc_mark, rayc_mark_size*sizeof(int));
		}
		
		if(rayc_block_size != blockbase)
		{
			rayc_block_size = markbase;
			rayc_block = realloc(rayc_block, rayc_block_size*sizeof(rayblock_t));
		}
	}
	
	// clear the mark table
	memset(rayc_mark, 0, rayc_mark_size*sizeof(int));
	
	// prep the starting block
	rayc_block_len = 0;
	rayc_block_head = 0;
	rayc_data_len = 1;
	rayc_data_head = 0;
	
	rayc_data[0].x = blkx;
	rayc_data[0].y = blky;
	rayc_data[0].z = blkz;
	rayc_data[0].gx = 0;
	rayc_data[0].gz = 0;
	rayc_data[0].y1 = blky+suby;
	rayc_data[0].y2 = blky+suby;
	rayc_data[0].sx = subx;
	rayc_data[0].sy = suby;
	rayc_data[0].sz = subz;
	rayc_mark[blkx + blkz*xlen] = 1;
	
	// build your way up
	while(rayc_data_head < rayc_data_len)
	{
		raydata_t *rd = &(rayc_data[rayc_data_head++]);
		
		// get delta
		float dx = rd->x - bx;
		float dz = rd->z - bz;
		if(rd->gx < 0) dx++;
		else if(rd->gx == 0) dx = 0;
		if(rd->gz < 0) dz++;
		else if(rd->gz == 0) dz = 0;
		
		// skip this if it's in the fog
		if(dx*dx+dz*dz >= FOG_DISTANCE*FOG_DISTANCE)
			continue;
		
		int near_cast = (rayc_data_head == 1);
		
		// find where we are
		int idx = (((int)(rd->z)) & (zlen-1))*xlen + (((int)rd->x) & (xlen-1));
		uint8_t *p = map->pillars[idx]+4;
		rayc_mark[idx] = -1;
		int lastn = 0;
		int topcount = 0;
		int lasttop = 0;
		
		float ysearch = rd->y1;
		while(p[0] != 0)
		{
			if(ysearch < p[2] && (lastn == 0 || ysearch >= lasttop))
				break;
			
			lastn = p[0];
			lasttop = p[1];
			topcount = p[0] - (p[2]-p[1]+1);
			p += p[0]*4;
		}
		
		int spreadflag = 1;
		
		// advance y1/y2
		float y1 = rd->y1;
		float y2 = rd->y2;
		
		if(near_cast)
		{
			rd->y1 = y1 = (lastn == 0 ? 0.0f : p[3]);
			rd->y2 = y2 = p[1];
		} else {
			float dist1 = sqrtf(dx*dx+dz*dz);
			float dist2 = dist1 + 1.0f; // approx max dist this can travel
			float travel = dist2/dist1;
			if(y1 < by)
				y1 = by + (y1-by)*travel;
			if(y2 > by)
				y2 = by + (y2-by)*travel;
		}
		
		int iy1 = floor(y1);
		int iy2 = floor(y2);
		float by1 = y1;
		float by2 = y2;
		
		// TODO: get the order right!
		
#ifdef DEBUG_SHOW_TOP_BOTTOM
		{
			rayblock_t *b = &rayc_block[rayc_block_len++];
			b->x = rd->x;
			b->z = rd->z;
			b->y = iy1;
			b->color = 0xFFFF0000;
		}
		{
			rayblock_t *b = &rayc_block[rayc_block_len++];
			b->x = rd->x;
			b->z = rd->z;
			b->y = iy2;
			b->color = 0xFF0000FF;
		}
#endif
		// add the top blocks (if they exist and we can see them)
		if(lastn == 0)
		{
			y1 = 0;
			y2 = p[1];
		} else if(p[3] >= rd->y1-1) {
			y1 = p[3];
			y2 = p[1];
			uint32_t *c = (uint32_t *)(&p[-4]);
#ifndef DEBUG_HIDE_MAIN
			for(i = p[3]-1; i >= p[3]-topcount && i >= iy1; i--)
			{
				rayblock_t *b = &rayc_block[rayc_block_len++];
				b->x = rd->x;
				b->z = rd->z;
				b->y = i;
				b->color = *(c--);
			}
#endif
		}
		
		// sneak your way down
		while(p[1] <= iy2)
		{
			if(p[1] != p[3])
				y2 = p[1];
			
			//printf("%i %i %i %i [%i, %i]\n", p[0],p[1],p[2],p[3],iy1,iy2);
			uint32_t *c = (uint32_t *)(&p[4]);
#ifndef DEBUG_HIDE_MAIN
			for(i = p[1]; i <= p[2] && i <= iy2; i++)
			{
				rayblock_t *b = &rayc_block[rayc_block_len++];
				b->x = rd->x;
				b->z = rd->z;
				b->y = i;
				b->color = *(c++);
			}
#endif
			if(p[0] == 0)
				break;
			
			lastn = p[0];
			lasttop = p[1];
			topcount = p[0] - (p[2]-p[1]+1);
			p += 4*p[0];
			
			if(p[1] != p[3] && rd->y2 >= p[3])
				y2 = p[1];
			
			c = (uint32_t *)(&p[-4]);
#ifndef DEBUG_HIDE_MAIN
			for(i = p[3]-1; i >= p[3]-topcount; i--)
			{
				if(i > iy2)
				{
					c--;
					continue;
				}
				rayblock_t *b = &rayc_block[rayc_block_len++];
				b->x = rd->x;
				b->z = rd->z;
				b->y = i;
				b->color = *(c--);
			}
#endif
		}
		
		// correct the y spread
		if(y1 < by1)
			y1 = by1;
		if(y2 > by2)
			y2 = by2;
		
		spreadflag = spreadflag && (y1 < y2);
		//spreadflag = 1;
		
		// spread out
		int ofx = 1;
		int ofz = 0;
		if(spreadflag) do
		{
			int idx2 = ((ofx + (int)rd->x) & (xlen-1))
				+ xlen * ((ofz + (int)rd->z) & (zlen-1));
			
			if(ofx * rd->gx < 0 || ofz * rd->gz < 0)
			{
				// do nothing
			} else if(rayc_mark[idx2] == 0) {
				rayc_mark[idx2] = rayc_data_len+1;
				raydata_t *rd2 = &(rayc_data[rayc_data_len++]);
				
				rd2->x = ofx + (int)rd->x;
				rd2->z = ofz + (int)rd->z;
				rd2->y1 = y1;
				rd2->y2 = y2;
				rd2->sx = subx;
				rd2->sy = suby;
				rd2->sz = subz;
				rd2->gx = (ofx == 0 ? rd->gx : ofx);
				rd2->gz = (ofz == 0 ? rd->gz : ofz);
			} else if(rayc_mark[idx2] != -1) {
				raydata_t *rd2 = &(rayc_data[rayc_mark[idx2]-1]);
				
				if(y1 < rd2->y1)
					rd2->y1 = y1;
				if(y2 > rd2->y2)
					rd2->y2 = y2;
				if(rd2->gx == 0)
					rd2->gx = (ofx == 0 ? rd->gx : ofx);
				if(rd2->gz == 0)
					rd2->gz = (ofz == 0 ? rd->gz : ofz);
			}
			
			{
				int t = ofx;
				ofx = -ofz;
				ofz = t;
			}
		} while(ofx != 1);
		
	}
	
	// render each face
#ifdef RENDER_FACE_COUNT
	for(i = 0; i < RENDER_FACE_COUNT && render_face_remain > 0; i++)
	{
		switch(render_face_current)
		{
			default:
				render_face_current = 0;
				/* FALL THROUGH */
			case 0:
				render_vxl_face_raycast(blkx, blky, blkz, subx, suby, subz, CM_NX, -1,  0,  0);
				break;
			case 1:
				render_vxl_face_raycast(blkx, blky, blkz, subx, suby, subz, CM_NY,  0, -1,  0);
				break;
			case 2:
				render_vxl_face_raycast(blkx, blky, blkz, subx, suby, subz, CM_NZ,  0,  0, -1);
				break;
			case 3:
				render_vxl_face_raycast(blkx, blky, blkz, subx, suby, subz, CM_PX,  1,  0,  0);
				break;
			case 4:
				render_vxl_face_raycast(blkx, blky, blkz, subx, suby, subz, CM_PY,  0,  1,  0);
				break;
			case 5:
				render_vxl_face_raycast(blkx, blky, blkz, subx, suby, subz, CM_PZ,  0,  0,  1);
				break;
		}
		render_face_current++;
		render_face_remain--;
	}
#else
	render_vxl_face_raycast(blkx, blky, blkz, subx, suby, subz, CM_NX, -1,  0,  0);
	render_vxl_face_raycast(blkx, blky, blkz, subx, suby, subz, CM_NY,  0, -1,  0);
	render_vxl_face_raycast(blkx, blky, blkz, subx, suby, subz, CM_NZ,  0,  0, -1);
	render_vxl_face_raycast(blkx, blky, blkz, subx, suby, subz, CM_PX,  1,  0,  0);
	render_vxl_face_raycast(blkx, blky, blkz, subx, suby, subz, CM_PY,  0,  1,  0);
	render_vxl_face_raycast(blkx, blky, blkz, subx, suby, subz, CM_PZ,  0,  0,  1);
#endif
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
	float *d = dbuf;
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
			int pidx, pmap;
			// get correct cube map + pos
			float tx,ty,tz,atz;
			
			if(fabsf(fx) > fabsf(fy) && fabsf(fx) > fabsf(fz))
			{
				tx = -fz;
				ty = fy;
				tz = fx;
				atz = fabs(tz);
				pmap = fx >= 0.0f ? CM_PX : CM_NX;
			} else if(fabsf(fz) > fabsf(fy) && fabsf(fz) > fabsf(fx)) {
				tx = fx;
				ty = fy;
				tz = fz;
				atz = fabs(tz);
				pmap = fz >= 0.0f ? CM_PZ : CM_NZ;
			} else {
				tx = fx;
				ty = fz;
				tz = fy;
				atz = tz;
				pmap = fy >= 0.0f ? CM_PY : CM_NY;
			}
			
			pidx = ((cubemap_size-1)&(int)(tx*tracemul/tz+traceadd))
				|(((cubemap_size-1)&(int)(ty*tracemul/atz+traceadd))<<cubemap_shift);
			
			*(p++) = cubemap_color[pmap][pidx];
			*(d++) = cubemap_depth[pmap][pidx];//*sqrtf(fx*fx+fy*fy+fz*fz);
			
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

void render_pmf_box(float x, float y, float z, float depth, float r, uint32_t color)
{
	// check Z straight away
	if(z < 0.001f)
		return;
	
	// get box
	int x1 = (( x-r)/z)*rtmp_width/2+rtmp_width/2;
	int y1 = (( y-r)/z)*rtmp_width/2+rtmp_height/2;
	int x2 = (( x+r)/z)*rtmp_width/2+rtmp_width/2;
	int y2 = (( y+r)/z)*rtmp_width/2+rtmp_height/2;
	
	// render
	render_rect_zbuf(rtmp_pixels, dbuf, x1, y1, x2, y2, color, depth);
}

void render_pmf_bone(uint32_t *pixels, int width, int height, int pitch, camera_t *cam_base,
	model_bone_t *bone, int islocal,
	float px, float py, float pz, float ry, float rx, float ry2, float scale)
{
	// stash stuff in globals to prevent spamming the stack too much
	// (and in turn thrashing the cache)
	rtmp_pixels = pixels;
	rtmp_width = width;
	rtmp_height = height;
	rtmp_pitch = pitch;
	rtmp_camera = cam_base;
	
	// get zoom factor
	float bzoom = (cam_base->mzx*cam_base->mzx
		+ cam_base->mzy*cam_base->mzy
		+ cam_base->mzz*cam_base->mzz);
	float unzoom = 1.0f/bzoom;
	scale /= 256.0f;
	int i;
	for(i = 0; i < bone->ptlen; i++)
	{
		model_point_t *pt = &(bone->pts[i]);
		
		// get color
		uint32_t color = (pt->b)|(pt->g<<8)|(pt->r<<16)|(1<<24);
		
		// get position
		float x = pt->x;
		float y = pt->y;
		float z = pt->z;
		
		// rotate
		float sry = sin(ry);
		float cry = cos(ry);
		float srx = sin(rx);
		float crx = cos(rx);
		float sry2 = sin(ry2);
		float cry2 = cos(ry2);
		
		float tx = (x*cry+z*sry);
		float ty = y;
		float tz = (z*cry-x*sry);
		
		y = (ty*crx-tz*srx);
		tz = (tz*crx+ty*srx);
		
		x = (tx*cry2+tz*sry2);
		z = (tz*cry2-tx*sry2);
		
		// scalinate
		x *= scale;
		y *= scale;
		z *= scale;
		
		// offsettate
		x += px;
		y += py;
		z += pz;
		
		if(!islocal)
		{
			x -= cam_base->mpx;
			y -= cam_base->mpy;
			z -= cam_base->mpz;
		}
		
		// get correct centre depth
		float max_axis = fabsf(x);
		if(max_axis < fabsf(y))
			max_axis = fabsf(y);
		if(max_axis < fabsf(z))
			max_axis = fabsf(z);
		float dlen = sqrtf(x*x+y*y+z*z);
		float depth = max_axis/dlen;
		
		// cameranananinate
		if(!islocal)
		{
			float nx = x*cam_base->mxx+y*cam_base->mxy+z*cam_base->mxz;
			float ny = x*cam_base->myx+y*cam_base->myy+z*cam_base->myz;
			float nz = x*cam_base->mzx*unzoom+y*cam_base->mzy*unzoom+z*cam_base->mzz*unzoom;
			
			x = nx;
			y = ny;
			z = nz;
		}
		depth *= z;
		
		// plotinate
		render_pmf_box(-x, y, z, depth, pt->radius*scale, color);
	}
}

void render_blit_img(uint32_t *pixels, int width, int height, int pitch,
	img_t *src, int dx, int dy, int bw, int bh, int sx, int sy, uint32_t color)
{
	int x,y;
	
	// clip blit width/height
	if(bw > src->head.width)
		bw = src->head.width;
	if(bh > src->head.height)
		bh = src->head.height;
	
	// drop if completely out of range
	if(dx >= width || dy >= height)
		return;
	if(dx+bw <= 0 || dy+bh <= 0)
		return;
	
	// top-left clip
	if(dx < 0)
	{
		sx += -dx;
		bw += -dx;
		dx = 0;
	}
	if(dy < 0)
	{
		sy += -dy;
		bh += -dy;
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
	
	// now blit!
	for(y = 0; y < bh; y++)
	{
		for(x = 0; x < bw; x++)
		{
			// TODO: MMX/SSE2 version
			uint32_t s = *(ps++);
			uint32_t d = *pd;
			
			// apply base color
			// DANGER! BRACKETITIS!
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
	
	int msize = size;
	
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
	
	// allocate space for depth buffer
	dbuf = malloc(width*height*sizeof(float));
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
	
	// deallocate depth buffer
	if(dbuf != NULL)
	{
		free(dbuf);
		dbuf = NULL;
	}
}
