/*
    This file is part of Buld Then Snip.

    Buld Then Snip is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Buld Then Snip is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Buld Then Snip.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "common.h"

// TODO: bump up to 127.5f
#define FOG_DISTANCE 40.0f

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
model_t *rtmp_camera;
map_t *rtmp_map;

/*
 * REFERENCE IMPLEMENTATION
 * 
 */

void render_vxl_face_vert(int blkx, int blky, int blkz,
	float subx, float suby, float subz,
	int face,
	int gx, int gy, int gz)
{
	int sx,sy;
	int i;
	
	int lcx[cubemap_size];
	int lcy[cubemap_size];
	int cx1 = 0;
	int cy1 = 0;
	int cx2 = cubemap_size-1;
	int cy2 = cubemap_size-1;
	
	// get cubemaps
	uint32_t *ccolor = cubemap_color[face];
	float *cdepth = cubemap_depth[face];
	
	// populate line pixel counts
	for(i = 0; i < cubemap_size; i++)
		lcx[i] = lcy[i] = cubemap_size;
	
	// TEST: clear cubemap
	for(sy = 0; sy < cubemap_size; sy++)
	for(sx = 0; sx < cubemap_size; sx++)
	{
		ccolor[((sy)<<cubemap_shift)+sx] = 0x00000000+sx+(sy<<cubemap_shift);
		ccolor[((sy)<<cubemap_shift)+sx] += ((face+1)<<(24-3));
		cdepth[((sy)<<cubemap_shift)+sx] = FOG_DISTANCE;
	}
	
	// get X cube direction
	int xgx = gz+gy;
	int xgy = 0;
	int xgz = -gx;
	
	// get Y cube direction
	int ygx = 0;
	int ygy = gx+gz;
	int ygz = gy;
	
	// get distance to wall
	float dist = -(subx*gx+suby*gy+subz*gz);
	if(dist < 0.0f)
		dist += 1.0f;
	
	// now loop and follow through
	while(dist < FOG_DISTANCE)
	{
		// calculate frustrum
		int frustrum = (int)(dist*cubemap_size);
		
		// prep boundaries
		int bx1 = 0;
		int by1 = 0;
		int bx2 = frustrum*2;
		int by2 = frustrum*2;
		
		// clamp wrt pixel counts
		// TODO!
		
		// relocate
		bx1 -= frustrum;
		by1 -= frustrum;
		bx2 -= frustrum;
		by2 -= frustrum;
		
		// need to go towards 0, not -inf!
		// (can be done as shifts, just looks nicer this way)
		bx1 /= cubemap_size;
		by1 /= cubemap_size;
		bx2 /= cubemap_size;
		by2 /= cubemap_size;
		
		// go through loop
		int cox,coy;
		
		for(cox = bx1; cox <= bx2; cox++)
		for(coy = by1; coy <= by2; coy++)
		{
			// TODO!
		}
		
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
	
	int lcx[cubemap_size];
	int lcy[cubemap_size];
	int cx1 = 0;
	int cy1 = 0;
	int cx2 = cubemap_size-1;
	int cy2 = cubemap_size-1;
	
	// get cubemaps
	uint32_t *ccolor = cubemap_color[face];
	float *cdepth = cubemap_depth[face];
	
	// populate line pixel counts
	for(i = 0; i < cubemap_size; i++)
		lcx[i] = lcy[i] = cubemap_size;
	
	// TEST: clear cubemap
	for(sy = 0; sy < cubemap_size; sy++)
	for(sx = 0; sx < cubemap_size; sx++)
	{
		ccolor[((sy)<<cubemap_shift)+sx] = 0x00000000+sx+(sy<<cubemap_shift);
		ccolor[((sy)<<cubemap_shift)+sx] += ((face+1)<<(24-3));
		cdepth[((sy)<<cubemap_shift)+sx] = FOG_DISTANCE;
	}
	
	// get X cube direction
	int xgx = gz+gy;
	int xgy = 0;
	int xgz = -gx;
	
	// get Y cube direction
	int ygx = 0;
	int ygy = gx+gz;
	int ygz = gy;
	
	// get distance to wall
	float dist = -(subx*gx+suby*gy+subz*gz);
	if(dist < 0.0f)
		dist += 1.0f;
	
	// now loop and follow through
	while(dist < FOG_DISTANCE)
	{
		// calculate frustrum
		int frustrum = (int)(dist*cubemap_size);
		
		// prep boundaries
		int bx1 = 0;
		int by1 = 0;
		int bx2 = frustrum*2;
		int by2 = frustrum*2;
		
		// clamp wrt pixel counts
		// TODO!
		
		// relocate
		bx1 -= frustrum;
		by1 -= frustrum;
		bx2 -= frustrum;
		by2 -= frustrum;
		
		// need to go towards 0, not -inf!
		// (can be done as shifts, just looks nicer this way)
		bx1 /= cubemap_size;
		by1 /= cubemap_size;
		bx2 /= cubemap_size;
		by2 /= cubemap_size;
		
		// go through loop
		int cox,coy;
		
		for(cox = bx1; cox <= bx2; cox++)
		{
			// TODO!
			// TODO: sides as opposed to just fronts
		}
		
		dist += 1.0f;
	}
}

void render_vxl_redraw(model_t *camera, map_t *map)
{
	int x,y,z;
	
	// stash stuff in globals to prevent spamming the stack too much
	// (and in turn thrashing the cache)
	rtmp_camera = camera;
	rtmp_map = map;
	
	// get block pos
	int blkx = ((int)(camera->mpx)) & (map->xlen-1);
	int blky = ((int)(camera->mpy)) & (map->ylen-1);
	int blkz = ((int)(camera->mpz)) & (map->zlen-1);
	
	// get block subpos
	float subx = (camera->mpx - (float)(int)(camera->mpx));
	float suby = (camera->mpy - (float)(int)(camera->mpy));
	float subz = (camera->mpz - (float)(int)(camera->mpz));
	
	// render each face
	render_vxl_face_horiz(blkx, blky, blkz, subx, suby, subz, CM_NX, -1,  0,  0);
	render_vxl_face_vert(blkx, blky, blkz, subx, suby, subz, CM_NY,  0, -1,  0);
	render_vxl_face_horiz(blkx, blky, blkz, subx, suby, subz, CM_NZ,  0,  0, -1);
	render_vxl_face_horiz(blkx, blky, blkz, subx, suby, subz, CM_PX,  1,  0,  0);
	render_vxl_face_vert(blkx, blky, blkz, subx, suby, subz, CM_PY,  0,  1,  0);
	render_vxl_face_horiz(blkx, blky, blkz, subx, suby, subz, CM_PZ,  0,  0,  1);
}

void render_cubemap(uint32_t *pixels, int width, int height, int pitch, model_t *camera, map_t *map)
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
					((cubemap_size-1)&(int)(fz*tracemul/fx+traceadd))
					|(((cubemap_size-1)&(int)(fy*tracemul/fx+traceadd))<<cubemap_shift)];
			} else if(fabsf(fz) > fabsf(fy) && fabsf(fz) > fabsf(fx)) {
				*p++ = cubemap_color[fz >= 0.0f ? CM_PZ : CM_NZ][
					((cubemap_size-1)&(int)(fx*tracemul/fz+traceadd))
					|(((cubemap_size-1)&(int)(fy*tracemul/fz+traceadd))<<cubemap_shift)];
			} else {
				*p++ = cubemap_color[fy >= 0.0f ? CM_PY : CM_NY][
					((cubemap_size-1)&(int)(fz*tracemul/fy+traceadd))
					|(((cubemap_size-1)&(int)(fx*tracemul/fy+traceadd))<<cubemap_shift)];
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
	
}
