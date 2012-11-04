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

#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <errno.h>

#include <math.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <SDL.h>

typedef struct camera
{
	// camera bollocks
	float mxx,mxy,mxz,mxpad;
	float myx,myy,myz,mypad;
	float mzx,mzy,mzz,mzpad;
	float mpx,mpy,mpz,mppad;
	
} camera_t;

/*

Pillar data:

Note, indices are like so:
0 1 2 3

Column header:
L - - -:
  (L+1)*4 = length in bytes
  - = reserved

Chunk header:
N S E A:
  N = number of 4bytes including header this chunk has (N=0 => last chunk)
  S = starting block for top part
  E = ending block for top part
  A = air start after bottom part (N=0 => E-S+1 blocks are stored)

Block data:
B G R T:
  B = blue
  G = green
  R = red! suprised?
  T = type of block.

In other words, VOXLAP vxl with a length header and different 4th data byte,
  and you can actually store crap in the invisible sections.
(Trust me. This format packs incredibly well.)

If you're keen to store interesting stuff that's not visible,
feel free to store it in the "invisible" parts.

*Yes*, you can get away with this! We're not using a static 16MB heap.

*/

typedef struct map
{
	int xlen, ylen, zlen;
	uint8_t **pillars;
	// TODO ? heap allocator ?
} map_t;

enum
{
	BT_INVALID = 0, // don't use this type!
	BT_SOLID_BREAKABLE,
	
	BT_MAX
};

// lua.c
int btslua_init(void);
void btslua_deinit(void);

// main.c
int error_sdl(char *msg);
int error_perror(char *msg);

// map.c
map_t *map_load_aos(char *fname);
map_t *map_load_bts(char *fname);
void map_free(map_t *map);

// model.c

// network.c
int net_init(void);
void net_deinit(void);

// render.c
void render_vxl_redraw(camera_t *camera, map_t *map);
void render_cubemap(uint32_t *pixels, int width, int height, int pitch, camera_t *camera, map_t *map);
int render_init(int width, int height);
void render_deinit(void);

// vecmath.c
void cam_point_dir(camera_t *model, float dx, float dy, float dz);
