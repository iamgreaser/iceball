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

#define DF_NX 0x01
#define DF_NZ 0x02
#define DF_PX 0x04
#define DF_PZ 0x08
#define DF_SPREAD 0x0F

uint32_t *rtmp_pixels;
int rtmp_width, rtmp_height, rtmp_pitch;
model_t *rtmp_camera;
map_t *rtmp_map;

/*
 * REFERENCE IMPLEMENTATION
 * 
 */

void render_vxl(uint32_t *pixels, int width, int height, int pitch, model_t *camera, map_t *map)
{
	int x,y,z;
	
	// stash stuff in globals to prevent spamming the stack too much
	rtmp_pixels = pixels;
	rtmp_width = width;
	rtmp_height = height;
	rtmp_pitch = pitch;
	rtmp_camera = camera;
	rtmp_map = map;
	
	// get block pos
	int blkx = ((int)(camera->mpx)) & (map->xlen-1);
	int blky = ((int)(camera->mpy)) & (map->ylen-1);
	int blkz = ((int)(camera->mpz)) & (map->zlen-1);
	
	// get block subpos
	float subx = (camera->mpx - (float)(int)(camera->mpx));
	float suby = (camera->mpx - (float)(int)(camera->mpy));
	float subz = (camera->mpx - (float)(int)(camera->mpz));
	
	
	// calculate trace dir
	// TODO!
}
