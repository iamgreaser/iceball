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

float *dbuf;

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
		//blky--;
		
		blkx--;
		blkz--;
	}
	dist -= 1.0f;
	
	//int coz = blky;
	
	// now build pillars
	static uint32_t cdata[256]; // hypothetical maximum
	
	// render cubes from centre out
	float odist = dist;
	
	int lbx1 = 2;
	int lby1 = 2;
	int lbx2 = -2;
	int lby2 = -2;
	
	// prep boundaries
	int bx1 = 0;
	int by1 = 0;
	int bx2 = 0;
	int by2 = 0;
	
	if(gy < 0)
	{
		bx1++;
		by1++;
		bx2++;
		by2++;
	}
	
	int xlen = rtmp_map->xlen;
	int ylen = rtmp_map->ylen;
	int zlen = rtmp_map->zlen;
	int xlenm1 = xlen-1;
	int ylenm1 = ylen-1;
	int zlenm1 = zlen-1;
	
	while(dist < FOG_DISTANCE)
	{
		// go through each
		int cox,coy;
		cox = bx1; coy = by1;
		int pdx = 1, pdy = 0;
		
		for(;;)
		{
			// skip already-rendered stuff
			//if(cox >= lbx1 && coy >= lby1 && cox <= lbx2 && coy <= lby2)
			//	continue;
			
			// get pillar
			uint8_t *pillar = rtmp_map->pillars[
				((cox+blkx)&(xlenm1))
				+(((coy+blkz)&(zlenm1))*xlen)]+4;
			
			// load data
			
			i = 0;
			for(;;)
			{
				uint8_t *csrc = &pillar[4];
				
				int nrem = pillar[0]-1;
				
				for(; i < pillar[1]; i++)
					cdata[i] = 0;
				
				for(; i <= pillar[2]; i++, nrem--, csrc += 4)
					cdata[i] = *(uint32_t *)csrc;
				
				if(pillar[0] == 0)
					break;
				
				pillar += 4*(int)pillar[0];
				
				for(; i < pillar[3]-nrem; i++)
					cdata[i] = 1;
				
				for(; i < pillar[3]; i++, csrc += 4)
					cdata[i] = *(uint32_t *)csrc;
			}
			
			for(; i < ylen; i++)
				cdata[i] = 1;
			
			// render data
			if(gy >= 0)
			{
				// bottom cubemap
				float fdist = 0.0f-blky-suby;
				// TODO: work out min required distance by frustum
				
				i = 0;
				
				fdist += i;
				for(; i < ylen; i++)
				{
					if(fdist >= dist && fdist >= 0.001f && cdata[i] > 1)
					{
						float boxsize = tracemul/fdist;
						float px1 = (cox+cmoffsx)*boxsize+traceadd;
						float py1 = (coy+cmoffsy)*boxsize+traceadd;
						float px2 = px1+boxsize;
						float py2 = py1+boxsize;
						
						if(1 || i == 0 || cdata[i-1] == 0)
						{
							render_vxl_cube(ccolor, cdepth,
								(int)px1, (int)py1, (int)px2, (int)py2,
								cdata[i], fdist);
						} else {
							render_vxl_cube_sides(ccolor, cdepth,
								(int)px1, (int)py1, (int)px2, (int)py2,
								cdata[i], fdist);
						}
					}
					
					fdist += 1.0f;
					
					if(fdist >= FOG_DISTANCE)
						break;
				}
			} else {
				// top cubemap
				float fdist = 0.0f-blky-suby;
				fdist = -ylen-fdist;
				
				// TODO: work out min required distance by frustum
				
				i = ylenm1;
				for(; i >= 0; i--)
				{
					if(fdist >= dist && fdist >= 0.001f && cdata[i] > 1)
					{
						float boxsize = tracemul/fdist;
						float px1 = (-cox+cmoffsx)*boxsize+traceadd;
						float py1 = (-coy+cmoffsy)*boxsize+traceadd;
						float px2 = px1+boxsize;
						float py2 = py1+boxsize;
						
						if(1 || i == ylenm1 || cdata[i+1] == 0)
						{
							render_vxl_cube(ccolor, cdepth,
								(int)px1, (int)py1, (int)px2, (int)py2,
								cdata[i], fdist);
						} else {
							render_vxl_cube_sides(ccolor, cdepth,
								(int)px1, (int)py1, (int)px2, (int)py2,
								cdata[i], fdist);
						}
					}
					
					fdist += 1.0f;
					
					if(fdist >= FOG_DISTANCE)
						break;
				}
			}
			
			if(cox == bx2 && coy == by1)
				pdx = 0, pdy = 1;
			if(cox == bx2 && coy == by2)
				pdx = -1, pdy = 0;
			if(cox == bx1 && coy == by2)
				pdx = 0, pdy = -1;
			if(cox == bx1 && coy == by1 && pdy == -1)
				break;
			
			cox += pdx;
			coy += pdy;
		}
		
		// store "last" bounding box
		lbx1 = bx1;
		lby1 = by1;
		lbx2 = bx2;
		lby2 = by2;
		
		// expand box
		bx1--;by1--;
		bx2++;by2++;
		// advance
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
			if(fabsf(fx) > fabsf(fy) && fabsf(fx) > fabsf(fz))
			{
				pidx = ((cubemap_size-1)&(int)(-fz*tracemul/fx+traceadd))
					|(((cubemap_size-1)&(int)(fy*tracemul/fabsf(fx)+traceadd))<<cubemap_shift);
				pmap = fx >= 0.0f ? CM_PX : CM_NX;
			} else if(fabsf(fz) > fabsf(fy) && fabsf(fz) > fabsf(fx)) {
				pidx = ((cubemap_size-1)&(int)(fx*tracemul/fz+traceadd))
					|(((cubemap_size-1)&(int)(fy*tracemul/fabsf(fz)+traceadd))<<cubemap_shift);
				pmap = fz >= 0.0f ? CM_PZ : CM_NZ;
			} else {
				pidx = ((cubemap_size-1)&(int)(fx*tracemul/fy+traceadd))
					|(((cubemap_size-1)&(int)(fz*tracemul/fy+traceadd))<<cubemap_shift);
				pmap = fy >= 0.0f ? CM_PY : CM_NY;
			}
			
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
	float px, float py, float pz, float ry, float rx, float scale)
{
	// stash stuff in globals to prevent spamming the stack too much
	// (and in turn thrashing the cache)
	rtmp_pixels = pixels;
	rtmp_width = width;
	rtmp_height = height;
	rtmp_pitch = pitch;
	rtmp_camera = cam_base;
	
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
		
		float tx = (x*cry+z*sry);
		float ty = y;
		float tz = (z*cry-x*sry);
		
		x = tx;
		y = (ty*crx-tz*srx);
		z = (tz*crx+ty*srx);
		
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
			float nz = x*cam_base->mzx+y*cam_base->mzy+z*cam_base->mzz;
			
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
	
	// allocate space for FTB buffers
	ftb_first = malloc(cubemap_size*sizeof(int));
	// TODO: check if NULL
	
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
	
	// deallocate FTB buffers
	if(ftb_first != NULL)
	{
		free(ftb_first);
		ftb_first = NULL;
	}
	
	// deallocate depth buffer
	if(dbuf != NULL)
	{
		free(dbuf);
		dbuf = NULL;
	}
}
