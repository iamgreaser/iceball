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

void expandtex_gl(int *iw, int *ih);

int oc_wait_cycle = 1;
int flood_cycle = 0;

int lwidth = 0;
int lheight = 0;
float znear = 0.05f;
float zfar = 20.0f;

GLfloat mtx_baseproj[16] = {
	-1, 0, 0, 0,
	 0,-1, 0, 0,
	 0, 0, 1, 1,
	 0, 0,-0.1, 0,
};

const GLfloat vfinf_cube[3*9] = {
	0, 1, 0,   0, 0, 1,  1, 0, 0,
	0, 0, 1,   1, 0, 0,  0, 1, 0,
	1, 0, 0,   0, 1, 0,  0, 0, 1,
};

#if 0
#define DEBUG_INVERT_DRAW_DIR
#endif
#if 0
#define DEBUG_SHOW_TOP_BOTTOM
#define DEBUG_HIDE_MAIN
#endif

#define CUBESUX_MARKER 20
#define RAYC_MAX ((int)((FOG_MAX_DISTANCE+1)*(FOG_MAX_DISTANCE+1)*8+10))

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

int cam_shading_map[6][4] = {
	{CM_PZ, CM_NZ, CM_PY, CM_NY},
	{CM_NX, CM_PX, CM_NZ, CM_PZ},
	{CM_NX, CM_PX, CM_PY, CM_NY},
	{CM_NZ, CM_PZ, CM_PY, CM_NY},
	{CM_PX, CM_NX, CM_PZ, CM_NZ},
	{CM_PX, CM_NX, CM_PY, CM_NY},
};

float fog_distance = FOG_INIT_DISTANCE;
uint32_t fog_color = 0xD0E0FF;

uint32_t cam_shading[6] = {
	 0x000C0, 0x000A0, 0x000D0, 0x000E0, 0x00FF, 0x000D0,
};

void render_pillar(map_t *map, map_chunk_t *chunk, int x, int z);

/*
 * REFERENCE IMPLEMENTATION
 * 
 */

/* custom mod function that handles negative numbers */
int render_mod ( int x , int y )
{
	return x >= 0 ? x % y : y - 1 - ((-x-1) % y) ;
}

uint32_t render_shade(uint32_t color, int face)
{
	if(!map_enable_side_shading) return color;

	uint32_t fc = cam_shading[face];
	return (((((color&0x00FF00FF)*fc)>>8)&0x00FF00FF))
		|((((((color>>8)&0x00FF00FF)*fc))&0xFF00FF00))|0x01000000;
}

GLfloat render_darken_color(GLfloat original_color, GLfloat factor)
{
	return original_color + (factor * (0.0f - original_color)) / 1.0f;
}

int render_map_get_block_at(map_t *map, int x, int y, int z)
{
	int i;
	uint8_t *data = NULL;

	if (map == NULL)
		return 0;

	if (y < 0)
		return 0;

	data = map->pillars[(z&(map->zlen-1))*(map->xlen)+(x&(map->xlen-1))];
	data += 4;

	for(;;)
	{
		if (y>=data[1] && y<=data[2])
			return 1;

		if (y>=data[3] && y<data[1])
			return 0;

		if(data[0] == 0)
			return 1;

		data += 4*(int)data[0];
	}
	return 0;
}

GLfloat render_get_average_light(map_t *map, int x1, int y1, int z1, int x2, int y2, int z2, int x3, int y3, int z3, int x4, int y4, int z4)
{
	GLfloat average = (
		render_map_get_block_at(map, x1, y1, z1)
		+ render_map_get_block_at(map, x2, y2, z2)
		+ render_map_get_block_at(map, x3, y3, z3)
		+ render_map_get_block_at(map, x4, y4, z4)
		) / 4.0f;
	return average;
}

int render_visible_chunks_array_offset(map_t *map, int x, int z)
{
	return render_mod(z, map->visible_chunks_len) * (int) map->visible_chunks_len
		+ render_mod(x, map->visible_chunks_len);
}

void render_untesselate_visible_chunk(map_chunk_t *chunk)
{
	if (chunk == NULL)
		return;

	if (chunk->vbo_arr != NULL)
	{
		free(chunk->vbo_arr);
		chunk->vbo_arr = NULL;
	}

	if (chunk->vbo != 0)
	{
		glDeleteBuffers(1, &(chunk->vbo));
		chunk->vbo = 0;
	}

	if(chunk->oq != 0)
	{
		glDeleteQueries(1, &(chunk->oq));
		chunk->oq = 0;
	}

	chunk->vbo_dirty = 0;
	chunk->vbo_arr_len = 0;
}

void render_free_visible_chunk(map_chunk_t *chunk)
{
	if (chunk == NULL)
		return;

	render_untesselate_visible_chunk(chunk);

	chunk->cx = 0;
	chunk->cz = 0;
}

void render_free_visible_chunks(map_t *map)
{
	int x, z;

	if(map == NULL || map->visible_chunks_arr == NULL)
		return;

	for (x = 0; x < (int) map->visible_chunks_len; x++)
	{
		for (z = 0; z < (int) map->visible_chunks_len; z++)
		{
			render_free_visible_chunk(&map->visible_chunks_arr[render_visible_chunks_array_offset(map, x, z)]);
		}
	}
}

void render_init_visible_chunks(map_t *map, int starting_chunk_coordinate_x, int starting_chunk_coordinate_z)
{
	/*
		example for gl_visible_chunks = 9

		- array size would be 3x3
		- virtual center of the circular array would be [1,1] at init

			0   1   2  
		  +---+---+---+
		0 |   |   |   |
		  +---#####---+
		1 |   #   #   |
		  +---#####---+
		2 |   |   |   |
		  +---+---+---+
	*/

	int x, z;
	/* chunk coordinates */
	int cx, cz;

	if (map == NULL)
		return;

	if (map->visible_chunks_arr != NULL)
	{
		render_free_visible_chunks(map);
		free(map->visible_chunks_arr);
		map->visible_chunks_arr = NULL;
	}

	map->visible_chunks_len = ((((int)fog_distance)+(gl_chunk_size+1)/2)/gl_chunk_size)*2+1;
	map->visible_chunks_arr = (map_chunk_t *) malloc(map->visible_chunks_len * map->visible_chunks_len * sizeof(map_chunk_t));
	
	/* check if the visible chunks array has been allocated properly */
	if(map->visible_chunks_arr == NULL)
	{
		fprintf(stderr, "render_init_visible_chunks: could not allocate visible chunks array\n");
		return;
	}

	map->visible_chunks_vcenter_cx = starting_chunk_coordinate_x;
	map->visible_chunks_vcenter_cz = starting_chunk_coordinate_z;

	for (x = 0; x < (int) map->visible_chunks_len; x++)
	{
		for (z = 0; z < (int) map->visible_chunks_len; z++)
		{
			cx = starting_chunk_coordinate_x - (int) map->visible_chunks_len/2 + x;
			cz = starting_chunk_coordinate_z - (int) map->visible_chunks_len/2 + z;

			map_chunk_t *chunk = &(map->visible_chunks_arr[render_visible_chunks_array_offset(map, x, z)]);

			chunk->cx = cx;
			chunk->cz = cz;
			chunk->vbo = 0;
			chunk->vbo_dirty = 1;
			chunk->vbo_arr_len = 0;
			chunk->vbo_arr = NULL;

			chunk->oq = 0;
			chunk->oc_wait = 0;
			chunk->oc_posted = 0;

			chunk->flood_ctr = 0;
			chunk->flood_next = NULL;
		}
	}

	map->visible_chunks_vcenter_x = (int) map->visible_chunks_len/2;
	map->visible_chunks_vcenter_z = (int) map->visible_chunks_len/2;
}

void render_init_va_format(map_t *map)
{
	if(gl_shaders)
	{
		map->stride = 9;
		map->vertex_offs = 0; map->vertex_size = 3;
		map->color_offs = 3; map->color_size = 3;
		map->normal_offs = 6; map->normal_size = 3;
		map->tc0_offs = 0; map->tc0_size = 0;
	} else {
		map->stride = 6;
		map->vertex_offs = 0; map->vertex_size = 3;
		map->color_offs = 3; map->color_size = 3;
		map->normal_offs = 0; map->normal_size = 0;
		map->tc0_offs = 0; map->tc0_size = 0;
	}

	render_init_visible_chunks(map, 0, 0);

}

void render_shift_visible_chunks(map_t *map, int camera_chunk_coordinate_x, int camera_chunk_coordinate_z)
{
	int position_shift_x, position_shift_z;
	int offset_x, offset_z;
	int index_x, index_z;
	int x, z;

	if(map == NULL || map->visible_chunks_arr == NULL)
		return;

	position_shift_x = camera_chunk_coordinate_x - map->visible_chunks_vcenter_cx;
	position_shift_z = camera_chunk_coordinate_z - map->visible_chunks_vcenter_cz;

	/* if position is the same, nothing to do */
	if (position_shift_x == 0 && position_shift_z == 0)
		return;

	/* setting the new virtual center of the circular array */
	map->visible_chunks_vcenter_x = render_mod(map->visible_chunks_vcenter_x + position_shift_x, (int) map->visible_chunks_len);
	map->visible_chunks_vcenter_z = render_mod(map->visible_chunks_vcenter_z + position_shift_z, (int) map->visible_chunks_len);

	/* setting the chunk coordinates of the virtual center of the circular array */
	map->visible_chunks_vcenter_cx = camera_chunk_coordinate_x;
	map->visible_chunks_vcenter_cz = camera_chunk_coordinate_z;

	for (x = 0; x < (int) map->visible_chunks_len; x++)
	{
		for (z = 0; z < (int) map->visible_chunks_len; z++)
		{
			offset_x = x - ((int) map->visible_chunks_len- 1)/2;
			offset_z = z - ((int) map->visible_chunks_len- 1)/2;
			index_x = render_mod(map->visible_chunks_vcenter_x + offset_x, (int) map->visible_chunks_len);
			index_z = render_mod(map->visible_chunks_vcenter_z + offset_z, (int) map->visible_chunks_len);

			/* untesselate chunks not visible anymore */
			if (map->visible_chunks_arr[render_visible_chunks_array_offset(map, index_x, index_z)].cx != map->visible_chunks_vcenter_cx + offset_x
				|| map->visible_chunks_arr[render_visible_chunks_array_offset(map, index_x, index_z)].cz != map->visible_chunks_vcenter_cz + offset_z)
			{
				render_free_visible_chunk(&map->visible_chunks_arr[render_visible_chunks_array_offset(map, index_x, index_z)]);
			}

			/* add chunks that are visible */
			if (map->visible_chunks_arr[render_visible_chunks_array_offset(map, index_x, index_z)].vbo_arr == NULL)
			{
				map->visible_chunks_arr[render_visible_chunks_array_offset(map, index_x, index_z)].cx = map->visible_chunks_vcenter_cx + offset_x;
				map->visible_chunks_arr[render_visible_chunks_array_offset(map, index_x, index_z)].cz = map->visible_chunks_vcenter_cz + offset_z;
				map->visible_chunks_arr[render_visible_chunks_array_offset(map, index_x, index_z)].vbo_dirty = 1;
			}
		}
	}

}

void render_map_visible_chunks_draw(map_t *map, float fx, float fy, float fz, float cx, float cy, float cz)
{
	int x, z;
	int i;

	//glDepthFunc(GL_ALWAYS);
	if(map == NULL || map->visible_chunks_arr == NULL)
		return;
	
	// get normalised 3D forward vector
	float f3d = sqrtf(fx*fx + fy*fy + fz*fz);
	float f3x = fx/f3d;
	float f3y = fy/f3d;
	float f3z = fz/f3d;

	int cdraw = 0, cskip = 0;

	float emax = 1.0f / sqrtf(3.0f);

	int flood_cx = render_mod(map->visible_chunks_vcenter_x, map->visible_chunks_len);
	int flood_cz = render_mod(map->visible_chunks_vcenter_z, map->visible_chunks_len);

	int chunks_rem = 1;

	flood_cycle++;
	map_chunk_t *chunk = &(map->visible_chunks_arr[render_visible_chunks_array_offset(map, flood_cx, flood_cz)]);
	map_chunk_t *cfollow = chunk;

	//printf("%i %i = %i %i\n", flood_cx, flood_cz, chunk->cx, chunk->cz);

	for(; chunks_rem > 0; chunks_rem--)
	{
		x = chunk->cx;
		z = chunk->cz;

		do {

			if(cfollow == NULL)
			{
				cfollow = chunk;
				cfollow->flood_next = NULL;
			}

			// Spread
			{
				chunk->flood_ctr = flood_cycle;

				map_chunk_t *c0 = &(map->visible_chunks_arr[render_visible_chunks_array_offset(map, x+1, z)]);
				map_chunk_t *c1 = &(map->visible_chunks_arr[render_visible_chunks_array_offset(map, x, z+1)]);
				map_chunk_t *c2 = &(map->visible_chunks_arr[render_visible_chunks_array_offset(map, x-1, z)]);
				map_chunk_t *c3 = &(map->visible_chunks_arr[render_visible_chunks_array_offset(map, x, z-1)]);

				//
#define DO_FLOOD(cN,X,Z) \
				if(cN->flood_ctr != flood_cycle) \
				{ \
					cN->flood_ctr = flood_cycle; \
					cfollow->flood_next = cN; \
					cfollow = cN; \
					cfollow->flood_next = NULL; \
					chunks_rem++; \
				}

				DO_FLOOD(c0,x+1,z);
				DO_FLOOD(c1,x,z+1);
				DO_FLOOD(c2,x-1,z);
				DO_FLOOD(c3,x,z-1);
			}

			if (chunk->vbo_arr_len > 0)
			{
				cdraw++;
				if(gl_frustum_cull)
				if(cx < (chunk->cx-1)*gl_chunk_size
					|| cz < (chunk->cz-1)*gl_chunk_size
					|| cx > (chunk->cx+2)*gl_chunk_size
					|| cz > (chunk->cz+2)*gl_chunk_size)
				{
					// calculate appropriate Y
					float ydist = (fy < 0.0
						? (cy-chunk->ytmin)*fy
						: (chunk->ybmax+1-cy)*fy);
	
					// calculate first corner
					float px000 = chunk->cx*gl_chunk_size - cx;
					float pz000 = chunk->cz*gl_chunk_size - cz;

					// calculate subsequent corners
					float px010 = px000 + gl_chunk_size;
					float pz010 = pz000;
					float px100 = px000;
					float pz100 = pz000 + gl_chunk_size;
					float px110 = px010;
					float pz110 = pz010 + gl_chunk_size;

					// calculate Y coordinates for corners
					float py000 = ydist;
					float py010 = ydist;
					float py100 = ydist;
					float py110 = ydist;

					// get lengths of corners
					float d000 = sqrtf(px000 * px000 + py000 * py000 + pz000 * pz000);
					float d100 = sqrtf(px100 * px100 + py000 * py000 + pz100 * pz100);
					float d010 = sqrtf(px010 * px010 + py000 * py000 + pz010 * pz010);
					float d110 = sqrtf(px110 * px110 + py000 * py000 + pz110 * pz110);

					// normalise corners
					px000 /= d000; py000 /= d000; pz000 /= d000;
					px100 /= d100; py100 /= d100; pz100 /= d100;
					px010 /= d010; py010 /= d010; pz010 /= d010;
					px110 /= d110; py110 /= d110; pz110 /= d110;

					// get dot products against forward vector
					float e000 = px000 * f3x + py000 * f3y + pz000 * f3z;
					float e100 = px100 * f3x + py100 * f3y + pz100 * f3z;
					float e010 = px010 * f3x + py010 * f3y + pz010 * f3z;
					float e110 = px110 * f3x + py110 * f3y + pz110 * f3z;

					// frustum cull
					if(e000 < emax && e010 < emax && e100 < emax && e110 < emax)
					{
						cskip++;
						continue;
					}
				}

				// select pointers
				glColor3f(1.0f, 1.0f, 1.0f);
				glNormal3f(0.0f,-1.0f, 0.0f);
				if (chunk->vbo == 0)
				{
					if(map->vertex_size >= 1) glVertexPointer(map->vertex_size, GL_FLOAT, sizeof(float)*map->stride, chunk->vbo_arr + map->vertex_offs);
					if(map->color_size >= 1) glColorPointer(map->color_size, GL_FLOAT, sizeof(float)*map->stride, chunk->vbo_arr + map->color_offs);
					if(map->normal_size >= 1) glNormalPointer(GL_FLOAT, sizeof(float)*map->stride, chunk->vbo_arr + map->normal_offs);
					if(map->tc0_size >= 1) glTexCoordPointer(map->tc0_size, GL_FLOAT, sizeof(float)*map->stride, chunk->vbo_arr + map->tc0_offs);
				} else {
					glBindBuffer(GL_ARRAY_BUFFER, chunk->vbo);
					if(map->vertex_size >= 1) glVertexPointer(map->vertex_size, GL_FLOAT, sizeof(float)*map->stride, ((float *)0) + map->vertex_offs);
					if(map->color_size >= 1) glColorPointer(map->color_size, GL_FLOAT, sizeof(float)*map->stride, ((float *)0) + map->color_offs);
					if(map->normal_size >= 1) glNormalPointer(GL_FLOAT, sizeof(float)*map->stride, ((float *)0) + map->normal_offs);
					if(map->tc0_size >= 1) glTexCoordPointer(map->tc0_size, GL_FLOAT, sizeof(float)*map->stride, ((float *)0) + map->tc0_offs);
				}

				// draw
				if(chunk->oc_wait > 0)
				{
					chunk->oc_wait--;
					cskip++;
				} else {
					int delay_draw = 0;

					if(chunk->oq)
					{
						if(chunk->oc_posted)
						{
							GLuint s;
							glGetQueryObjectuiv(chunk->oq, GL_QUERY_RESULT, &s);
							delay_draw = (s == 0);
							chunk->oc_posted = 0;
						}
					}

					if(delay_draw)
					{
						//chunk->oc_wait = map->visible_chunks_len * map->visible_chunks_len;
						chunk->oc_wait = oc_wait_cycle;
						oc_wait_cycle--;
						if(oc_wait_cycle <= 0)
							//oc_wait_cycle = map->visible_chunks_len * map->visible_chunks_len / 10;
							oc_wait_cycle = gl_occlusion_cull;
					} else {
						if(chunk->oq)
						{
							glBeginQuery(GL_SAMPLES_PASSED, chunk->oq);
						}

						if(map->vertex_size >= 1) glEnableClientState(GL_VERTEX_ARRAY);
						if(map->color_size >= 1) glEnableClientState(GL_COLOR_ARRAY);
						if(map->normal_size >= 1) glEnableClientState(GL_NORMAL_ARRAY);
						if(map->tc0_size >= 1) glEnableClientState(GL_TEXTURE_COORD_ARRAY);
						glDrawArrays((gl_expand_quads
							? GL_TRIANGLES
							: GL_QUADS),
							0, chunk->vbo_arr_len);
						if(map->tc0_size >= 1) glDisableClientState(GL_TEXTURE_COORD_ARRAY);
						if(map->normal_size >= 1) glDisableClientState(GL_NORMAL_ARRAY);
						if(map->color_size >= 1) glDisableClientState(GL_COLOR_ARRAY);
						if(map->vertex_size >= 1) glDisableClientState(GL_VERTEX_ARRAY);

						if(chunk->oq)
						{
							glEndQuery(GL_SAMPLES_PASSED);
							chunk->oc_posted = 1;
						}
					}
				}

				// unbind buffer
				if (chunk->vbo != 0)
					glBindBuffer(GL_ARRAY_BUFFER, 0);
			}
		} while(0);

		chunk = chunk->flood_next;
	}

	//printf("draw: %i/%i (%.2f%%)\n", (cdraw-cskip), cdraw, 100.0f*((float)(cdraw-cskip))/((float)cdraw));

	//glDepthFunc(GL_LEQUAL);
}

int render_map_visible_chunks_count_dirty(map_t *map)
{
	int x, z;
	int dirty_chunks_count = 0;

	if(map == NULL || map->visible_chunks_arr == NULL)
		return 0;
	
	for (x = 0; x < (int) map->visible_chunks_len; x++)
	{
		for (z = 0; z < (int) map->visible_chunks_len; z++)
		{
			if (map->visible_chunks_arr[render_visible_chunks_array_offset(map, x, z)].vbo_dirty)
			{
				dirty_chunks_count++;
			}
		}
	}
	return dirty_chunks_count;
}

void render_map_tesselate_visible_chunks(map_t *map, int camx, int camz)
{
	int x, z, i, vx, vz;
	int bx, bz;
	/* pillar coords */
	int px, pz;
	map_chunk_t *chunk;
	int chunks_tesselated = 0;

	if(map == NULL || map->visible_chunks_arr == NULL)
		return;
	
	bx = bz = 0;
	vx = 1; vz = 0;
	for(i = 0; i < map->visible_chunks_len * map->visible_chunks_len; i++)
	{
		x = bx + camx;
		z = bz + camz;

		int do_render = 1;

		if(!mk_compat_mode)
		if(x < 0 || z < 0 || x*gl_chunk_size >= map->xlen || z*gl_chunk_size >= map->zlen)
			do_render = 0;

		x += map->visible_chunks_len/2;
		z += map->visible_chunks_len/2;

		x = render_mod(x, map->visible_chunks_len);
		z = render_mod(z, map->visible_chunks_len);
		chunk = &map->visible_chunks_arr[render_visible_chunks_array_offset(map, x, z)];

		if (chunks_tesselated >= gl_chunks_tesselated_per_frame)
			return;

		if (do_render && chunk->vbo_dirty)
		{
			render_untesselate_visible_chunk(chunk);
			chunk->ytmin = map->ylen;
			chunk->ytmax = 0;
			chunk->ybmax = 0;
			for (px = 0; px < gl_chunk_size; px++)
			{
				for (pz = 0; pz < gl_chunk_size; pz++)
				{
					int cpx = chunk->cx * gl_chunk_size + px;
					int cpz = chunk->cz * gl_chunk_size + pz;

					// Occlusion culling method 1.
					// The impact this section has on performance is in theory negligible.
					// Hence why there is no "if".
					uint8_t *data = 4 + map->pillars[(cpz&(map->zlen-1))*(map->xlen)+(cpx&(map->xlen-1))];

					int ytop = data[1];
					if(chunk->ytmin > ytop) chunk->ytmin = ytop;

					while(data[0] != 0)
					{
						data += 4*(int)(data[0]);

						if(data[1] > data[3])
							ytop = data[1];
					}

					if(chunk->ytmax < ytop) chunk->ytmax = ytop;
					if(chunk->ybmax < (int)(data[2])) chunk->ybmax = (int)(data[2]);

					render_pillar(map, chunk, cpx, cpz);
				}
			}

			//printf("ocull1 (%i,%i) %i %i %i\n", chunk->cx, chunk->cz, chunk->ytmin, chunk->ytmax, chunk->ybmax);

			if(chunk->vbo == 0)
				glGenBuffers(1, &(chunk->vbo));
			if(chunk->oq == 0 && GLAD_GL_ARB_occlusion_query && gl_occlusion_cull >= 1)
				glGenQueries(1, &(chunk->oq));

			if(chunk->vbo != 0)
			{
				glBindBuffer(GL_ARRAY_BUFFER, chunk->vbo);
				glBufferData(GL_ARRAY_BUFFER, sizeof(float)*map->stride*chunk->vbo_arr_len, chunk->vbo_arr, GL_STATIC_DRAW);
				glBindBuffer(GL_ARRAY_BUFFER, 0);
			}

			chunk->vbo_dirty = 0;
			chunks_tesselated++;
		}

		// rotate around in a spiral
		bx += vx;
		bz += vz;
		if(vz == 0
			? (vx == 1 ? bx > bz : bx <= bz )
			: (vz == 1 ? bz >= -bx : bz <= -bx ))
		{
			int t = vx;
			vx = vz;
			vz = -t;
		}
	}
}

void render_map_mark_chunks_as_dirty(map_t *map, int pillar_x, int pillar_z)
{
	int x, z;
	int chunk_x, chunk_z;
	int neighbor_chunk_x, neighbor_chunk_z;
	map_chunk_t *neighbor_chunk = NULL;

	chunk_x = pillar_x/gl_chunk_size;
	chunk_z = pillar_z/gl_chunk_size;

	if(map == NULL || map->visible_chunks_arr == NULL)
		return;
	
	for (x = 0; x < (int) map->visible_chunks_len; x++)
	{
		for (z = 0; z < (int) map->visible_chunks_len; z++)
		{
			int offs = render_visible_chunks_array_offset(map, x, z);
			map_chunk_t *chunk = &map->visible_chunks_arr[offs];
			int rcx = render_mod(chunk->cx, map->xlen/gl_chunk_size);
			int rcz = render_mod(chunk->cz, map->zlen/gl_chunk_size);

			if (rcx == chunk_x && rcz == chunk_z)
			{
				chunk->vbo_dirty = 1;

				/* If pillar coords are between two chunks, we need to update the neighbor chunks as well */
				if (render_mod(pillar_x, gl_chunk_size) == 0)
				{
					neighbor_chunk_x = render_mod(x - 1, (int) map->visible_chunks_len);
					neighbor_chunk_z = z;
					neighbor_chunk = &map->visible_chunks_arr[render_visible_chunks_array_offset(map, neighbor_chunk_x, neighbor_chunk_z)];
					int ncx = render_mod(neighbor_chunk->cx, map->xlen/gl_chunk_size);
					int ncz = render_mod(neighbor_chunk->cz, map->zlen/gl_chunk_size);
					if (ncx == render_mod(chunk_x - 1, map->xlen/gl_chunk_size) && ncz == chunk_z)
					{
						neighbor_chunk->vbo_dirty = 1;
					}
				} else if (render_mod(pillar_x, gl_chunk_size) == gl_chunk_size-1) {
					neighbor_chunk_x = render_mod(x + 1, (int) map->visible_chunks_len);
					neighbor_chunk_z = z;
					neighbor_chunk = &map->visible_chunks_arr[render_visible_chunks_array_offset(map, neighbor_chunk_x, neighbor_chunk_z)];
					int ncx = render_mod(neighbor_chunk->cx, map->xlen/gl_chunk_size);
					int ncz = render_mod(neighbor_chunk->cz, map->zlen/gl_chunk_size);
					if (ncx == render_mod(chunk_x + 1, map->xlen/gl_chunk_size) && ncz == chunk_z)
					{
						neighbor_chunk->vbo_dirty = 1;
					}
				}

				if (render_mod(pillar_z, gl_chunk_size) == 0)
				{
					neighbor_chunk_x = x;
					neighbor_chunk_z = render_mod(z - 1, (int) map->visible_chunks_len);
					neighbor_chunk = &map->visible_chunks_arr[render_visible_chunks_array_offset(map, neighbor_chunk_x, neighbor_chunk_z)];
					int ncx = render_mod(neighbor_chunk->cx, map->xlen/gl_chunk_size);
					int ncz = render_mod(neighbor_chunk->cz, map->zlen/gl_chunk_size);
					if (ncx == chunk->cx && ncz == render_mod(chunk->cz - 1, map->zlen/gl_chunk_size))
					{
						neighbor_chunk->vbo_dirty = 1;
					}
				} else if (render_mod(pillar_z, gl_chunk_size) == gl_chunk_size-1) {
					neighbor_chunk_x = x;
					neighbor_chunk_z = render_mod(z + 1, (int) map->visible_chunks_len);
					neighbor_chunk = &map->visible_chunks_arr[render_visible_chunks_array_offset(map, neighbor_chunk_x, neighbor_chunk_z)];
					int ncx = render_mod(neighbor_chunk->cx, map->xlen/gl_chunk_size);
					int ncz = render_mod(neighbor_chunk->cz, map->zlen/gl_chunk_size);
					if (ncx == chunk->cx && ncz == render_mod(chunk->cz + 1, map->zlen/gl_chunk_size))
					{
						neighbor_chunk->vbo_dirty = 1;
					}
				}
			}
		}
	}
}

void render_update_vbo(float **arr, int *len, int *max, int newlen, int vals_per_point)
{
	int xlen = 0;
	
	if(*arr == NULL)
	{
		xlen = newlen + 10;
	} else if(newlen <= *max) {
		return;
	} else {
		xlen = ((*max)*3)/2+1;
		if(xlen < newlen)
			xlen = newlen + 10;
	}

	*arr = (float*)realloc(*arr, xlen*sizeof(float)*vals_per_point);
	*max = xlen;
}

#define EXPAND_QUAD \
	if(gl_expand_quads) \
	{ \
		memcpy(arr, arr-vals_per_point*4, vals_per_point*sizeof(float)); \
		memcpy(arr+vals_per_point, arr-vals_per_point*2, vals_per_point*sizeof(float)); \
		arr += vals_per_point*2; \
	}

void render_gl_cube_pmf(model_bone_t *bone, float x, float y, float z, float r, float g, float b, float rad)
{
	int i;
	float ua,ub,uc;
	float va,vb,vc;

	int points_per_quad = (gl_expand_quads ? 6 : 4);
	int vals_per_point = (gl_shaders ? 9 : 6);
	int vo = 0;
	int co = 3;
	int no = 6;
	int to = 9;
	int vs = 3;
	int cs = 3;
	int ns = (gl_shaders ? 3 : 0);
	int ts = (gl_shaders ? 0 : 0);

	render_update_vbo(&(bone->vbo_arr), &(bone->vbo_arr_len), &(bone->vbo_arr_max),
		bone->vbo_arr_len+points_per_quad*6, vals_per_point);
	float *arr = bone->vbo_arr;
	arr += bone->vbo_arr_len*vals_per_point;
	bone->vbo_arr_len += points_per_quad*6;

	for(i = 0; i < 3; i++)
	{
		float s2 = (map_enable_side_shading ? ((int)cam_shading[i+0])/255.0f : 1.0f);
		float s1 = (map_enable_side_shading ? ((int)cam_shading[i+3])/255.0f : 1.0f);
		float cr,cg,cb;
		float nx,ny,nz;

		ua = vfinf_cube[i*9+0];
		ub = vfinf_cube[i*9+1];
		uc = vfinf_cube[i*9+2];
		va = vfinf_cube[i*9+3];
		vb = vfinf_cube[i*9+4];
		vc = vfinf_cube[i*9+5];
		nx = -vfinf_cube[i*9+6];
		ny = -vfinf_cube[i*9+7];
		nz = -vfinf_cube[i*9+8];
		
#define ARR_ADD(tx,ty,vx,vy,vz) \
		if(vs >= 1) { arr[vo+0] = vx; arr[vo+1] = vy; arr[vo+2] = vz; } \
		if(cs >= 1) { arr[co+0] = cr; arr[co+1] = cg; arr[co+2] = cb; } \
		if(ns >= 1) { arr[no+0] = nx; arr[no+1] = ny; arr[no+2] = nz; } \
		if(ts >= 1) { arr[to+0] = tx; arr[to+1] = ty; } \
		arr += vals_per_point; \

		/* Quad 1 */
		cr = r*s1; cg = g*s1, cb = b*s1;
		ARR_ADD(0,0,x,y,z);
		ARR_ADD(1,0,x+rad*ua,y+rad*ub,z+rad*uc);
		ARR_ADD(1,1,x+rad*(ua+va),y+rad*(ub+vb),z+rad*(uc+vc));
		ARR_ADD(0,1,x+rad*va,y+rad*vb,z+rad*vc);

		EXPAND_QUAD;

		nx = -nx;
		ny = -ny;
		nz = -nz;

		/* Quad 2 */
		cr = r*s2; cg = g*s2, cb = b*s2;
		ARR_ADD(0,0,x+rad,y+rad,z+rad);
		ARR_ADD(1,0,x+rad*(1-va),y+rad*(1-vb),z+rad*(1-vc));
		ARR_ADD(1,1,x+rad*(1-ua-va),y+rad*(1-ub-vb),z+rad*(1-uc-vc));
		ARR_ADD(0,1,x+rad*(1-ua),y+rad*(1-ub),z+rad*(1-uc));

		EXPAND_QUAD;
#undef ARR_ADD
	}
}

void render_gl_cube_map(map_t *map, map_chunk_t *chunk, float x, float y, float z, float r, float g, float b, float rad)
{
	int i;
	float ua,ub,uc;
	float va,vb,vc;
	float average_light_vertex1, average_light_vertex2, average_light_vertex3, average_light_vertex4;

	int points_per_quad = (gl_expand_quads ? 6 : 4);
	int vals_per_point = map->stride;
	int vo = map->vertex_offs;
	int co = map->color_offs;
	int no = map->normal_offs;
	int to = map->tc0_offs;
	int vs = map->vertex_size;
	int cs = map->color_size;
	int ns = map->normal_size;
	int ts = map->tc0_size;

	float *arr = chunk->vbo_arr;

	/* Quads rendering explained (sort of)

	   'o' in drawings represents the vertex at origin
	   '+' a vertex
	   '1' digits represents vertex number

	   i = 0                                          | i = 1                                          | i = 2                                         
	   -----                                          | -----                                          | -----                                         
		                                              |                                                |                                               
	   Quad 1 (left)               Quad 2 (right)     | Quad 1 (top)            Quad 2 (bottom)        | Quad 1 (back)              Quad 2 (front)     
		                                              |                                                |         
		           1                       3          |             1         4                        |            1        2                         
	    +-- x       o.......         o......+         |  +-- x       o------+         o.......         |  +-- x      o------+         o.......         
	   /|        4 /|     ..        ..   4 /|         | /|          /.     /.        ..     ..         | /|         .|     .|      3 ..     2.         
	   z y	      +.|..... .       .......+ |         |z y         +------+ .       ........ .         |z y        ..|..... |       +------+ .         
	              | +.......       . .....|.+         |           2. ......3.       . +------+         |           . +------+       | .....|..         
	              |/ 2   ..        ..     |/ 2        |            ..     ..        ./ 3   ./ 4        |           .. 4   .. 3      |.     |/          
	              +.......         .......+           |            ........         +------+           |           ........         +------+           
	             3                         1          |                            2        1          |                           4        1                                                
		                                              |                                                |                                               
		ua = 0.0       va = 0.0                       | ua = 0.0       va = 1.0                        | ua = 1.0        va = 0.0                      
		ub = 1.0       vb = 0.0                       | ub = 0.0       vb = 0.0                        | ub = 0.0        vb = 1.0                      
		uc = 0.0       vc = 1.0                       | uc = 1.0       vc = 0.0                        | uc = 0.0        vc = 0.0                      
		                                              |                                                |                                               
		                                              |                                                |                                               
		Neighbor to check for face drawing toggle     | Neighbor to check for face drawing toggle      | Neighbor to check for face drawing toggle
		                                              |                                                |                                               
		Quad1                       Quad2             | Quad1                       Quad2              | Quad1                       Quad2
		x - 1                       x + 1             | y - 1                       y + 1              | z - 1                       z + 1             
		                                              |                                                |                                              
		                                              |                                                |                                               
		Neighbors to check for light average          | Neighbors to check for light average           | Neighbors to check for light average
		                                              |                                                |                                              
		Left                      Right               | Top                       Bottom               | Back                      Front               
		----                      -----               | ------                    ---                  | ----                      -----               
		                                              |                                                |                                               
		Vertex1                   Vertex1             | Vertex1                   Vertex1              | Vertex1                   Vertex1                  
		x-1, y,   z               x+1, y,   z         | x,   y-1, z               x,   y+1, z          | x,   y,   z-1             x,   y,   z+1                      
		x-1, y-1, z               x+1, y+1, z         | x-1, y-1, z               x+1, y+1, z          | x-1, y,   z-1             x+1, y,   z+1                      
		x-1, y-1, z-1             x+1, y+1, z+1       | x-1, y-1, z-1             x+1  y+1, z+1        | x-1, y-1, z-1             x+1, y+1, z+1                      
		x-1, y,   z-1             x+1, y,   z+1       | x,   y-1, z-1             x,   y+1, z+1        | x,   y-1, z-1             x,   y+1, z+1                      
		                                              |                                                |                                               
		Vertex2                   Vertex2             | Vertex2                   Vertex2              | Vertex2                   Vertex2                  
		x-1, y,   z               x+1, y,   z         | x,   y-1, z               x,   y+1, z          | x,   y,   z-1             x,   y,   z+1                   
		x-1, y+1, z               x+1, y+1, z         | x-1, y-1, z               x-1, y+1, z          | x+1, y,   z-1             x+1, y,   z+1                   
		x-1, y+1, z-1             x+1, y+1, z-1       | x-1, y-1, z+1             x-1, y+1, z+1        | x+1, y-1, z-1             x+1, y-1, z+1                   
		x-1, y,   z-1             x+1, y,   z-1       | x,   y-1, z+1             x,   y+1, z+1        | x,   y-1, z-1             x,   y-1, z+1                   
		                                              |                                                |                                               
		Vertex3                   Vertex3             | Vertex3                   Vertex3              | Vertex3                   Vertex3                  
		x-1, y,   z               x+1, y,   z         | x,   y-1, z               x,   y+1, z          | x,   y,   z-1             x,   y,   z+1                 
		x-1, y+1, z               x+1, y-1, z         | x+1, y-1, z               x-1, y+1, z          | x+1, y,   z-1             x-1, y,   z+1                 
		x-1, y+1, z+1             x+1, y-1, z-1       | x+1, y-1, z+1             x-1, y+1, z-1        | x+1, y+1, z-1             x-1, y-1, z+1                 
		x-1, y,   z+1             x+1, y,   z-1       | x,   y-1, z+1             x,   y+1, z-1        | x,   y+1, z-1             x,   y-1, z+1                 
		                                              |                                                |                                               
		Vertex4                   Vertex4             | Vertex4                   Vertex4              | Vertex4                   Vertex4                  
		x-1, y,   z               x+1, y,   z         | x,   y-1, z               x,   y+1  z          | x,   y,   z-1             x,   y,   z+1                  
		x-1, y-1, z               x+1, y-1, z         | x+1, y-1, z               x+1, y+1  z          | x-1, y,   z-1             x-1, y,   z+1                  
		x-1, y-1, z+1             x+1, y-1, z+1       | x+1, y-1, z-1             x+1, y+1  z-1        | x-1, y+1, z-1             x-1, y+1, z+1                  
		x-1, y  , z+1             x+1, y,   z+1       | x,   y-1, z-1             x,   y+1  z-1        | x,   y+1, z-1             x,   y+1, z+1                  


		Neighbors to check for face drawing :

		Quad 1                                    Quad 2
		------                                    ------

		x - ub, y - uc, z - ua                    x + vc, y + va, z + vb


		Generic coordinates formula (<=> regardless of i value) to check for each vertex (holy moly, it seems to be working ^^) :

		Quad 1                                    Quad 2               
		------                                    ------

		V1                                        V1                           
		x-ub, y-uc, z-ua                          x+vc, y+va, z+vb                         
		x-1, y-1+ua, z-ua                         x+1, y+1-vb, z+vb                      
		x-1, y-1, z-1                             x+1, y+1, z+1                             
		x-ub, y-1+ub, z-1                         x+vc, y+1-vc, z+1                         

		V2                                        V2                           
		x-ub, y-uc, z-ua                          x+vc, y+va, z+vb                          
		x-1+2*ua, y+(1-ua)-2*uc, z-ua             x+1-2*va, y+1-vb, z+vb                           
		x-1+2*ua, y-1+2*ub, z-1+2*uc              x+1-2*va, y+1-2*vb, z+1-2*vc                                                       
		x-ub, y-1+ub, z-1+2*uc                    x+vc, y+(1-vc)-2*vb, z+1-2*vc                                                

		V3                                        V3                           
		x-ub, y-uc, z-ua                          x+vc, y+va, z+vb                                          
		x+1-2*ub, y+(1-ua)-2*uc, z-ua             x-1+2*vc, y+(1-vb)-2*vc, z+vb                                               
		x+1-2*ub, y+1-2*uc, z+1-2*ua              x-1+2*vc, y-1+2*va, z-1+2*vb                                                              
		x-ub, y+(1-ub)-2*uc, z+1-2*ua             x+vc, y+(1-vc)-2*vb, z-1+2*vb                                                      

		V4                                        V4                           
		x-ub, y-uc, z-ua                          x+vc, y+va, z+vb                                          
		x-1+2*uc, y-1+ua, z-ua                    x+1-2*vb, y+(1-vb)-2*vc, z+vb                                                
		x-1+2*uc, y-1+2*ua, z-1+2*ub              x+1-2*vb, y+1-2*vc, z+1-2*va                                                     
		x-ub, y+(1-ub)-2*uc, z-1+2*ub             x+vc, y+1-vc, z+1-2*va                                         
*/

	for(i = 0; i < 3; i++)
	{
		float nx,ny,nz;
		ua = vfinf_cube[i*9+0];
		ub = vfinf_cube[i*9+1];
		uc = vfinf_cube[i*9+2];
		va = vfinf_cube[i*9+3];
		vb = vfinf_cube[i*9+4];
		vc = vfinf_cube[i*9+5];
		nx = -vfinf_cube[i*9+6];
		ny = -vfinf_cube[i*9+7];
		nz = -vfinf_cube[i*9+8];

		float s2 = (map_enable_side_shading ? ((int)cam_shading[i+0])/255.0f : 1.0f);
		float s1 = (map_enable_side_shading ? ((int)cam_shading[i+3])/255.0f : 1.0f);
		float cr,cg,cb;
	
#define ARR_ADD(tx,ty,vx,vy,vz) \
		if(vs >= 1) { arr[vo+0] = vx; arr[vo+1] = vy; arr[vo+2] = vz; } \
		if(cs >= 1) { arr[co+0] = cr; arr[co+1] = cg; arr[co+2] = cb; } \
		if(ns >= 1) { arr[no+0] = nx; arr[no+1] = ny; arr[no+2] = nz; } \
		if(ts >= 1) { arr[to+0] = tx; arr[to+1] = ty; } \
		arr += vals_per_point; \

		/* check visibility of the face (is face exposed to air ?) */
		if (render_map_get_block_at(map, x - ub, y - uc, z - ua) == 0)
		{
			render_update_vbo(&(chunk->vbo_arr), &(chunk->vbo_arr_len), &(chunk->vbo_arr_max), chunk->vbo_arr_len+points_per_quad, vals_per_point);
			arr = chunk->vbo_arr;
			arr += chunk->vbo_arr_len*vals_per_point;
			chunk->vbo_arr_len += points_per_quad;

			if (map_enable_ao && screen_smooth_lighting)
			{
				average_light_vertex1 = render_get_average_light(
					map,
					x-ub, y-uc, z-ua,
					x-1, y-1+ua, z-ua,
					x-1, y-1, z-1,
					x-ub, y-1+ub, z-1);

				average_light_vertex2 = render_get_average_light(
					map,
					x-ub, y-uc, z-ua,
					x-1+2*ua, y+(1-ua)-2*uc, z-ua,
					x-1+2*ua, y-1+2*ub, z-1+2*uc,
					x-ub, y-1+ub, z-1+2*uc);

				average_light_vertex3 = render_get_average_light(
					map,
					x-ub, y-uc, z-ua,
					x+1-2*ub, y+(1-ua)-2*uc, z-ua,
					x+1-2*ub, y+1-2*uc, z+1-2*ua,
					x-ub, y+(1-ub)-2*uc, z+1-2*ua);

				average_light_vertex4 = render_get_average_light(
					map,
					x-ub, y-uc, z-ua,
					x-1+2*uc, y-1+ua, z-ua,
					x-1+2*uc, y-1+2*ua, z-1+2*ub,
					x-ub, y+(1-ub)-2*uc, z-1+2*ub);
			} else {
				average_light_vertex1 = 0.0f;
				average_light_vertex2 = 0.0f;
				average_light_vertex3 = 0.0f;
				average_light_vertex4 = 0.0f;
			}

			/* Check if the quad needs to be rotated (fix for ambient occlusion on sides) */
			if ((average_light_vertex1 + average_light_vertex3 > average_light_vertex2 + average_light_vertex4
				? !gl_flip_quads
				: gl_flip_quads))
			{
				/* Quad 1 rotated */
				
				/* vertex 2 */
				cr = r*s1; cg = g*s1, cb = b*s1;
				cr = render_darken_color(cr, average_light_vertex2);
				cg = render_darken_color(cg, average_light_vertex2);
				cb = render_darken_color(cb, average_light_vertex2);
				ARR_ADD(1,0,x+rad*ua,y+rad*ub,z+rad*uc);

				/* vertex 3 */
				cr = r*s1; cg = g*s1, cb = b*s1;
				cr = render_darken_color(cr, average_light_vertex3);
				cg = render_darken_color(cg, average_light_vertex3);
				cb = render_darken_color(cb, average_light_vertex3);
				ARR_ADD(1,1,x+rad*(ua+va),y+rad*(ub+vb),z+rad*(uc+vc));

				/* vertex 4 */
				cr = r*s1; cg = g*s1, cb = b*s1;
				cr = render_darken_color(cr, average_light_vertex4);
				cg = render_darken_color(cg, average_light_vertex4);
				cb = render_darken_color(cb, average_light_vertex4);
				ARR_ADD(0,1,x+rad*va,y+rad*vb,z+rad*vc);

				/* vertex 1 */
				cr = r*s1; cg = g*s1, cb = b*s1;
				cr = render_darken_color(cr, average_light_vertex1);
				cg = render_darken_color(cg, average_light_vertex1);
				cb = render_darken_color(cb, average_light_vertex1);
				ARR_ADD(0,0,x,y,z);

				EXPAND_QUAD;

			} else {
				/* Quad 1 normal */

				/* vertex 1 */
				cr = r*s1; cg = g*s1, cb = b*s1;
				cr = render_darken_color(cr, average_light_vertex1);
				cg = render_darken_color(cg, average_light_vertex1);
				cb = render_darken_color(cb, average_light_vertex1);
				ARR_ADD(0,0,x,y,z);

				/* vertex 2 */
				cr = r*s1; cg = g*s1, cb = b*s1;
				cr = render_darken_color(cr, average_light_vertex2);
				cg = render_darken_color(cg, average_light_vertex2);
				cb = render_darken_color(cb, average_light_vertex2);
				ARR_ADD(1,0,x+rad*ua,y+rad*ub,z+rad*uc);

				/* vertex 3 */
				cr = r*s1; cg = g*s1, cb = b*s1;
				cr = render_darken_color(cr, average_light_vertex3);
				cg = render_darken_color(cg, average_light_vertex3);
				cb = render_darken_color(cb, average_light_vertex3);
				ARR_ADD(1,1,x+rad*(ua+va),y+rad*(ub+vb),z+rad*(uc+vc));

				/* vertex 4 */
				cr = r*s1; cg = g*s1, cb = b*s1;
				cr = render_darken_color(cr, average_light_vertex4);
				cg = render_darken_color(cg, average_light_vertex4);
				cb = render_darken_color(cb, average_light_vertex4);
				ARR_ADD(0,1,x+rad*va,y+rad*vb,z+rad*vc);

				EXPAND_QUAD;

			}
		}

		nx = -nx;
		ny = -ny;
		nz = -nz;

		/* check visibility of the face (is face exposed to air ?) */
		if (render_map_get_block_at(map, x + vc, y + va, z + vb) == 0)
		{
			render_update_vbo(&(chunk->vbo_arr), &(chunk->vbo_arr_len), &(chunk->vbo_arr_max), chunk->vbo_arr_len+points_per_quad, vals_per_point);
			arr = chunk->vbo_arr;
			arr += chunk->vbo_arr_len*vals_per_point;
			chunk->vbo_arr_len += points_per_quad;

			if (map_enable_ao && screen_smooth_lighting)
			{
				average_light_vertex1 = render_get_average_light(
					map, 
					x+vc, y+va, z+vb,
					x+1, y+1-vb, z+vb,
					x+1, y+1, z+1,
					x+vc, y+1-vc, z+1);

				average_light_vertex2 = render_get_average_light(
					map,
					x+vc, y+va, z+vb,
					x+1-2*va, y+1-vb, z+vb,
					x+1-2*va, y+1-2*vb, z+1-2*vc,
					x+vc, y+(1-vc)-2*vb, z+1-2*vc);

				average_light_vertex3 = render_get_average_light(
					map,
					x+vc, y+va, z+vb,
					x-1+2*vc, y+(1-vb)-2*vc, z+vb,
					x-1+2*vc, y-1+2*va, z-1+2*vb,
					x+vc, y+(1-vc)-2*vb, z-1+2*vb);

				average_light_vertex4 = render_get_average_light(
					map,
					x+vc, y+va, z+vb,
					x+1-2*vb, y+(1-vb)-2*vc, z+vb,
					x+1-2*vb, y+1-2*vc, z+1-2*va,
					x+vc, y+1-vc, z+1-2*va);
			} else {
				average_light_vertex1 = 0.0f;
				average_light_vertex2 = 0.0f;
				average_light_vertex3 = 0.0f;
				average_light_vertex4 = 0.0f;
			}

			/* Check if the quad needs to be rotated (fix for ambient occlusion on sides) */
			if ((average_light_vertex1 + average_light_vertex3 > average_light_vertex2 + average_light_vertex4
				? !gl_flip_quads
				: gl_flip_quads))
			{
				/* Quad 2 rotated */
				
				/* vertex 2 */
				cr = r*s2; cg = g*s2, cb = b*s2;
				cr = render_darken_color(cr, average_light_vertex2);
				cg = render_darken_color(cg, average_light_vertex2);
				cb = render_darken_color(cb, average_light_vertex2);
				ARR_ADD(0,1,x+rad*(1-va),y+rad*(1-vb),z+rad*(1-vc));

				/* vertex 3 */
				cr = r*s2; cg = g*s2, cb = b*s2;
				cr = render_darken_color(cr, average_light_vertex3);
				cg = render_darken_color(cg, average_light_vertex3);
				cb = render_darken_color(cb, average_light_vertex3);
				ARR_ADD(1,1,x+rad*(1-ua-va),y+rad*(1-ub-vb),z+rad*(1-uc-vc));

				/* vertex 4 */
				cr = r*s2; cg = g*s2, cb = b*s2;
				cr = render_darken_color(cr, average_light_vertex4);
				cg = render_darken_color(cg, average_light_vertex4);
				cb = render_darken_color(cb, average_light_vertex4);
				ARR_ADD(1,0,x+rad*(1-ua),y+rad*(1-ub),z+rad*(1-uc));

				/* vertex 1 */
				cr = r*s2; cg = g*s2, cb = b*s2;
				cr = render_darken_color(cr, average_light_vertex1);
				cg = render_darken_color(cg, average_light_vertex1);
				cb = render_darken_color(cb, average_light_vertex1);
				ARR_ADD(0,0,x+rad,y+rad,z+rad);

				EXPAND_QUAD;

			} else {
				/* Quad 2 normal */

				/* vertex 1 */
				cr = r*s2; cg = g*s2, cb = b*s2;
				cr = render_darken_color(cr, average_light_vertex1);
				cg = render_darken_color(cg, average_light_vertex1);
				cb = render_darken_color(cb, average_light_vertex1);
				ARR_ADD(0,0,x+rad,y+rad,z+rad);

				/* vertex 2 */
				cr = r*s2; cg = g*s2, cb = b*s2;
				cr = render_darken_color(cr, average_light_vertex2);
				cg = render_darken_color(cg, average_light_vertex2);
				cb = render_darken_color(cb, average_light_vertex2);
				ARR_ADD(0,1,x+rad*(1-va),y+rad*(1-vb),z+rad*(1-vc));

				/* vertex 3 */
				cr = r*s2; cg = g*s2, cb = b*s2;
				cr = render_darken_color(cr, average_light_vertex3);
				cg = render_darken_color(cg, average_light_vertex3);
				cb = render_darken_color(cb, average_light_vertex3);
				ARR_ADD(1,1,x+rad*(1-ua-va),y+rad*(1-ub-vb),z+rad*(1-uc-vc));

				/* vertex 4 */
				cr = r*s2; cg = g*s2, cb = b*s2;
				cr = render_darken_color(cr, average_light_vertex4);
				cg = render_darken_color(cg, average_light_vertex4);
				cb = render_darken_color(cb, average_light_vertex4);
				ARR_ADD(1,0,x+rad*(1-ua),y+rad*(1-ub),z+rad*(1-uc));

				EXPAND_QUAD;

			}
		}
#undef ARR_ADD
	}
}

void render_vxl_cube(map_t *map, map_chunk_t *chunk, int x, int y, int z, uint8_t *color)
{
	render_gl_cube_map(map, chunk, x, y, z, color[2]/255.0f, color[1]/255.0f, color[0]/255.0f, 1);
}

void render_pmf_cube(model_bone_t *bone, float x, float y, float z, int r, int g, int b, float rad)
{
	float hrad = rad/2.0f;
	render_gl_cube_pmf(bone, x-hrad, y-hrad, z-hrad, r/255.0f, g/255.0f, b/255.0f, rad);
}

void render_vxl_redraw(camera_t *camera, map_t *map)
{
	if(map == NULL)
		return;
	
	int x,y,z;
	int cx,cy,cz;

	cx = camera->mpx;
	cy = camera->mpy;
	cz = camera->mpz;

	render_shift_visible_chunks(map, cx/gl_chunk_size, cz/gl_chunk_size);

	render_map_tesselate_visible_chunks(map, cx/gl_chunk_size, cz/gl_chunk_size);
}

void render_pillar(map_t *map, map_chunk_t *chunk, int x, int z)
{
	int y, i;

	if(map == NULL || chunk == NULL)
		return;
	
	uint8_t *data = map->pillars[(z&(map->zlen-1))*(map->xlen)+(x&(map->xlen-1))];
	data += 4;

	int lastct = 0;
	for(;;)
	{
		for(y = data[1]; y <= data[2]; y++)
			render_vxl_cube(map, chunk, x, y, z, &data[4*(y-data[1]+1)]);

		lastct = -(data[2]-data[1]+1);
		if(lastct < 0)
			lastct = 0;
		lastct += data[0]-1;

		if(data[0] == 0)
			break;
		
		data += 4*(int)data[0];

		for(y = data[3]-lastct; y < data[3]; y++)
			render_vxl_cube(map, chunk, x, y, z, &data[4*(y-data[3])]);
	}
}

void render_clear(camera_t *camera)
{
	float fog[4] = {
		((fog_color>>16)&255)/255.0,((fog_color>>8)&255)/255.0,((fog_color)&255)/255.0,1
	};

	float cx,cy,cz;
	cx = camera->mpx;
	cy = camera->mpy;
	cz = camera->mpz;

	float cfx,cfy,cfz;
	cfx = camera->mzx;
	cfy = camera->mzy;
	cfz = camera->mzz;
	float cfd2 = cfx*cfx+cfy*cfy+cfz*cfz;
	cfd2 = 1.0f/cfd2;

	float cdist = fog_distance/sqrtf(2.0f*cfd2);
	zfar = cdist;

	render_init(lwidth, lheight);
	glClearColor(fog[0], fog[1], fog[2], 1);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	glDisable(GL_STENCIL_TEST);
	glEnable(GL_ALPHA_TEST);
	glAlphaFunc(GL_GREATER, 0.0f);
	glEnable(GL_CULL_FACE);
	glEnable(GL_DEPTH_TEST);
	glEnable(GL_FOG);
	glFogi(GL_FOG_MODE, GL_LINEAR);
	glFogf(GL_FOG_START, cdist/2.0f);
	glFogf(GL_FOG_END, cdist);
	glFogfv(GL_FOG_COLOR, fog);
	glTexCoord2f(-1.0f, -1.0f);

	GLfloat mtx_mv[16] = {
		camera->mxx, camera->myx, camera->mzx, 0,
		camera->mxy, camera->myy, camera->mzy, 0,
		camera->mxz, camera->myz, camera->mzz, 0,
		0,0,0,1
	};
	
	glMatrixMode(GL_MODELVIEW);
	glLoadMatrixf(mtx_mv);
	glTranslatef(-cx,-cy,-cz);
}

void render_cubemap(uint32_t *pixels, int width, int height, int pitch, camera_t *camera, map_t *map,
	img_t **img, int do_blend, char sfactor, char dfactor, float alpha, int img_count)
{
	int i;
	int x,y,z;
	float cx,cy,cz;

	cx = camera->mpx;
	cy = camera->mpy;
	cz = camera->mpz;

	if(map == NULL)
		return;
	
	if(map->fog_distance != fog_distance
		|| map->enable_side_shading != map_enable_side_shading
		|| map->enable_ao != map_enable_ao
		|| map->visible_chunks_arr == NULL)
	{
		map->fog_distance = fog_distance;
		map->enable_side_shading = map_enable_side_shading;
		map->enable_ao = map_enable_ao;
		render_init_visible_chunks(map, 0, 0);
	}

	float cfx,cfy,cfz;
	cfx = camera->mzx;
	cfy = camera->mzy;
	cfz = camera->mzz;

	for(i = 0; i < img_count; i++)
	if(img[i] != NULL)
	{
		int iw, ih;
		if(img[i]->udtype == UD_FBO)
		{
			iw = ((fbo_t *)(img[i]))->width;
			ih = ((fbo_t *)(img[i]))->height;
		} else {
			iw = img[i]->head.width;
			ih = img[i]->head.height;
			expandtex_gl(&iw, &ih);
		}

		glClientActiveTexture(GL_TEXTURE0 + i);
		glActiveTexture(GL_TEXTURE0 + i);
		glEnable(GL_TEXTURE_2D);
		if(img[i]->udtype == UD_IMG && img[i]->tex_dirty)
		{
			if(img[i]->tex == 0)
			{
				glGenTextures(1, &(img[i]->tex));
				glBindTexture(GL_TEXTURE_2D, img[i]->tex);

				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
				// BILINEAR FILTERING IS FOR PLEBS
				// (just kidding, I may add support for it later)
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

				if(GLAD_GL_ARB_texture_storage) {
					glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA8, iw, ih);
				} else {
					glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, iw, ih, 0, GL_BGRA, GL_UNSIGNED_BYTE, NULL);
				}
			} else {
			
				glBindTexture(GL_TEXTURE_2D, img[i]->tex);
			}

			glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, iw, ih, GL_BGRA, GL_UNSIGNED_BYTE, img[i]->pixels);
			img[i]->tex_dirty = 0;
		} else {
			glBindTexture(GL_TEXTURE_2D, img[i]->tex);
		}
		glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
	}
	glClientActiveTexture(GL_TEXTURE0);
	glActiveTexture(GL_TEXTURE0);

	if(do_blend)
	{
		glEnable(GL_BLEND);

		GLenum rsfactor = GL_ONE;
		GLenum rdfactor = GL_ZERO;

		switch(sfactor)
		{
			case '0': rsfactor = GL_ZERO; break;
			case '1': rsfactor = GL_ONE; break;
			case 'C': rsfactor = GL_DST_COLOR; break;
			case 'R': rsfactor = GL_ONE_MINUS_DST_COLOR; break;
			case 'a': rsfactor = GL_SRC_ALPHA; break;
			case 'A': rsfactor = GL_DST_ALPHA; break;
			case 'h': rsfactor = GL_ONE_MINUS_SRC_ALPHA; break;
			case 'H': rsfactor = GL_ONE_MINUS_DST_ALPHA; break;
			case 's': rsfactor = GL_SRC_ALPHA_SATURATE; break;
		}

		switch(dfactor)
		{
			case '0': rdfactor = GL_ZERO; break;
			case '1': rdfactor = GL_ONE; break;
			case 'c': rdfactor = GL_SRC_COLOR; break;
			case 'r': rdfactor = GL_ONE_MINUS_SRC_COLOR; break;
			case 'a': rdfactor = GL_SRC_ALPHA; break;
			case 'A': rdfactor = GL_DST_ALPHA; break;
			case 'h': rdfactor = GL_ONE_MINUS_SRC_ALPHA; break;
			case 'H': rdfactor = GL_ONE_MINUS_DST_ALPHA; break;
		}

		glBlendFunc(rsfactor, rdfactor);
		glColor4f(1.0f, 1.0f, 1.0f, alpha);
	} else {
		glDisable(GL_BLEND);
		glColor3f(1.0f, 1.0f, 1.0f);
	}

	render_map_visible_chunks_draw(map, cfx, cfy, cfz, cx, cy, cz);

	for(i = 0; i < img_count; i++)
	if(img[i] != NULL)
	{
		glClientActiveTexture(GL_TEXTURE0 + i);
		glActiveTexture(GL_TEXTURE0 + i);
		glBindTexture(GL_TEXTURE_2D, 0);
		glDisable(GL_TEXTURE_2D);
	}
	glClientActiveTexture(GL_TEXTURE0);
	glActiveTexture(GL_TEXTURE0);

	glDisable(GL_BLEND);
}

void render_pmf_bone(uint32_t *pixels, int width, int height, int pitch, camera_t *cam_base,
	model_bone_t *bone, int islocal,
	float px, float py, float pz, float ry, float rx, float ry2, float scale)
{
	int i;

	int points_per_quad = (gl_expand_quads ? 6 : 4);
	int vals_per_point = (gl_shaders ? 9 : 6);

	glPushMatrix();
	if(islocal)
		glLoadIdentity();
	glTranslatef(px, py, pz);
	glScalef(scale,scale,scale);
	glRotatef(ry2*180.0f/M_PI, 0.0f, 1.0f, 0.0f);
	glRotatef(rx*180.0f/M_PI, 1.0f, 0.0f, 0.0f);
	glRotatef(ry*180.0f/M_PI, 0.0f, 1.0f, 0.0f);

	if(bone->vbo_dirty)
	{
		bone->vbo_arr_len = 0;
		for(i = 0; i < bone->ptlen; i++)
		{
			float ox, oy, oz;

			const float oamp = 0.0004;
			const float oper = 0.031;
			
			/*
			ox = oamp*sin(i*oper*M_PI*2.0);
			oy = oamp*sin(i*oper*M_PI*2.0 + M_PI*2.0/3.0);
			oz = oamp*sin(i*oper*M_PI*2.0 - M_PI*2.0/3.0);
			*/

			// Disabled. If you get Z fighting, your loss.
			// (Use a VA loader for a more GL-friendly format.)
			ox = 0.0f;
			oy = 0.0f;
			oz = 0.0f;

			model_point_t *pt = &(bone->pts[i]);
			render_pmf_cube(bone, pt->x/256.0f+ox, pt->y/256.0f+oy, pt->z/256.0f+oz, pt->r, pt->g, pt->b, pt->radius*2.0f/256.0f); // + oamp);
		}
		
		bone->vbo_dirty = 0;
		
		if(bone->vbo == 0)
			glGenBuffers(1, &(bone->vbo));

		if(bone->vbo != 0)
		{
			glBindBuffer(GL_ARRAY_BUFFER, bone->vbo);
			glBufferData(GL_ARRAY_BUFFER, sizeof(float)*vals_per_point*bone->vbo_arr_len, bone->vbo_arr, GL_STATIC_DRAW);
			glBindBuffer(GL_ARRAY_BUFFER, 0);
		}
	}

	if(bone->vbo == 0)
	{
		if(gl_shaders)
		{
			glVertexPointer(3, GL_FLOAT, sizeof(float)*9, bone->vbo_arr);
			glColorPointer(3, GL_FLOAT, sizeof(float)*9, bone->vbo_arr+3);
			glNormalPointer(GL_FLOAT, sizeof(float)*9, bone->vbo_arr+6);
		} else {
			glVertexPointer(3, GL_FLOAT, sizeof(float)*6, bone->vbo_arr);
			glColorPointer(3, GL_FLOAT, sizeof(float)*6, bone->vbo_arr+3);
		}
	} else {
		glBindBuffer(GL_ARRAY_BUFFER, bone->vbo);
		if(gl_shaders)
		{
			glVertexPointer(3, GL_FLOAT, sizeof(float)*9, (void *)(0));
			glColorPointer(3, GL_FLOAT, sizeof(float)*9, (void *)(0 + sizeof(float)*3));
			glNormalPointer(GL_FLOAT, sizeof(float)*9, (void *)(0 + sizeof(float)*6));
		} else {
			glVertexPointer(3, GL_FLOAT, sizeof(float)*6, (void *)(0));
			glColorPointer(3, GL_FLOAT, sizeof(float)*6, (void *)(0 + sizeof(float)*3));
		}
	}
	glTexCoord2f(-1.0f, -1.0f);
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_COLOR_ARRAY);
	if(gl_shaders) glEnableClientState(GL_NORMAL_ARRAY);
	glDrawArrays((gl_expand_quads ? GL_TRIANGLES : GL_QUADS), 0, bone->vbo_arr_len);
	if(gl_shaders) glDisableClientState(GL_NORMAL_ARRAY);
	glDisableClientState(GL_COLOR_ARRAY);
	glDisableClientState(GL_VERTEX_ARRAY);
	if(bone->vbo != 0)
		glBindBuffer(GL_ARRAY_BUFFER, 0);

	glPopMatrix();
}

void render_vertex_array(uint32_t *pixels, int width, int height, int pitch, camera_t *cam_base,
	va_t *va, int islocal,
	float px, float py, float pz, float ry, float rx, float ry2, float scale,
	img_t **img, int do_blend, char sfactor, char dfactor, float alpha, int img_count)
{
	int i;

	glPushMatrix();
	if(islocal)
		glLoadIdentity();
	glTranslatef((islocal ? -px : px), py, pz);
	glScalef(scale,scale,scale);
	glRotatef(ry2*180.0f/M_PI, 0.0f, 1.0f, 0.0f);
	glRotatef(rx*180.0f/M_PI, 1.0f, 0.0f, 0.0f);
	glRotatef(ry*180.0f/M_PI, 0.0f, 1.0f, 0.0f);

	if(va->vbo_dirty)
	{
		va->vbo_dirty = 0;
		
		if(va->vbo == 0)
			glGenBuffers(1, &(va->vbo));

		if(va->vbo != 0)
		{
			glBindBuffer(GL_ARRAY_BUFFER, va->vbo);
			glBufferData(GL_ARRAY_BUFFER, sizeof(float)*va->stride*va->data_len, va->data, GL_STATIC_DRAW);
			glBindBuffer(GL_ARRAY_BUFFER, 0);
		}
	}

	for(i = 0; i < img_count; i++)
	if(img[i] != NULL)
	{
		int iw, ih;
		if(img[i]->udtype == UD_FBO)
		{
			iw = ((fbo_t *)(img[i]))->width;
			ih = ((fbo_t *)(img[i]))->height;
		} else {
			iw = img[i]->head.width;
			ih = img[i]->head.height;
			expandtex_gl(&iw, &ih);
		}

		glClientActiveTexture(GL_TEXTURE0 + i);
		glActiveTexture(GL_TEXTURE0 + i);
		glEnable(GL_TEXTURE_2D);
		if(img[i]->udtype == UD_IMG && img[i]->tex_dirty)
		{
			if(img[i]->tex == 0)
			{
				glGenTextures(1, &(img[i]->tex));
				glBindTexture(GL_TEXTURE_2D, img[i]->tex);

				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
				// BILINEAR FILTERING IS FOR PLEBS
				// (just kidding, I may add support for it later)
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

				if(GLAD_GL_ARB_texture_storage) {
					glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA8, iw, ih);
				} else {
					glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, iw, ih, 0, GL_BGRA, GL_UNSIGNED_BYTE, NULL);
				}
			} else {
			
				glBindTexture(GL_TEXTURE_2D, img[i]->tex);
			}

			glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, iw, ih, GL_BGRA, GL_UNSIGNED_BYTE, img[i]->pixels);

			img[i]->tex_dirty = 0;
		} else {
			glBindTexture(GL_TEXTURE_2D, img[i]->tex);
		}
		glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
	}
	glClientActiveTexture(GL_TEXTURE0);
	glActiveTexture(GL_TEXTURE0);

	if(do_blend)
	{
		glEnable(GL_BLEND);

		GLenum rsfactor = GL_ONE;
		GLenum rdfactor = GL_ZERO;

		switch(sfactor)
		{
			case '0': rsfactor = GL_ZERO; break;
			case '1': rsfactor = GL_ONE; break;
			case 'C': rsfactor = GL_DST_COLOR; break;
			case 'R': rsfactor = GL_ONE_MINUS_DST_COLOR; break;
			case 'a': rsfactor = GL_SRC_ALPHA; break;
			case 'A': rsfactor = GL_DST_ALPHA; break;
			case 'h': rsfactor = GL_ONE_MINUS_SRC_ALPHA; break;
			case 'H': rsfactor = GL_ONE_MINUS_DST_ALPHA; break;
			case 's': rsfactor = GL_SRC_ALPHA_SATURATE; break;
		}

		switch(dfactor)
		{
			case '0': rdfactor = GL_ZERO; break;
			case '1': rdfactor = GL_ONE; break;
			case 'c': rdfactor = GL_SRC_COLOR; break;
			case 'r': rdfactor = GL_ONE_MINUS_SRC_COLOR; break;
			case 'a': rdfactor = GL_SRC_ALPHA; break;
			case 'A': rdfactor = GL_DST_ALPHA; break;
			case 'h': rdfactor = GL_ONE_MINUS_SRC_ALPHA; break;
			case 'H': rdfactor = GL_ONE_MINUS_DST_ALPHA; break;
		}

		glBlendFunc(rsfactor, rdfactor);
		glColor4f(1.0f, 1.0f, 1.0f, alpha);
	} else {
		glDisable(GL_BLEND);
		glColor3f(1.0f, 1.0f, 1.0f);
	}

	for(i = 0; i < va->texcoord_count; i++)
	{
		glClientActiveTexture(GL_TEXTURE0 + i);
		glActiveTexture(GL_TEXTURE0 + i);
		glTexCoord2f(0.0f, 0.0f);
	}
	glClientActiveTexture(GL_TEXTURE0);
	glActiveTexture(GL_TEXTURE0);

	glTexCoord2f(-1.0f, -1.0f);
	if(va->vbo == 0)
	{
		glVertexPointer(va->vertex_size, GL_FLOAT, sizeof(float)*va->stride, va->data + va->vertex_offs);
		if(va->color_offs != -1) glColorPointer(va->color_size, GL_FLOAT, sizeof(float)*va->stride, va->data+va->color_offs);
		if(va->normal_offs != -1) glNormalPointer(GL_FLOAT, sizeof(float)*va->stride, va->data+va->normal_offs);
		if(va->texcoord_count >= 1)
		for(i = 0; i < va->texcoord_count || i < img_count; i++)
		{
			glClientActiveTexture(GL_TEXTURE0 + i);
			glActiveTexture(GL_TEXTURE0 + i);
			glTexCoordPointer(va->texcoord_size[i%va->texcoord_count], GL_FLOAT, sizeof(float)*va->stride, va->data+va->texcoord_offs[i%va->texcoord_count]);
		}

		if(gl_shaders)
		for(i = 0; i < va->attr_count; i++)
		{
			glVertexAttribPointer(i+1, va->attr_size[i], GL_FLOAT, GL_FALSE,
				sizeof(float)*va->stride, va->data+va->attr_offs[i]);
		}

	} else {
		glBindBuffer(GL_ARRAY_BUFFER, va->vbo);
		glVertexPointer(va->vertex_size, GL_FLOAT, sizeof(float)*va->stride, (void *)(0 + sizeof(float)*va->vertex_offs));
		if(va->color_offs != -1) glColorPointer(va->color_size, GL_FLOAT, sizeof(float)*va->stride, (void *)(0 + sizeof(float)*va->color_offs));
		if(va->normal_offs != -1) glNormalPointer(GL_FLOAT, sizeof(float)*va->stride, (void *)(0 + sizeof(float)*va->normal_offs));
		if(va->texcoord_count >= 1)
		for(i = 0; i < va->texcoord_count || i < img_count; i++)
		{
			glClientActiveTexture(GL_TEXTURE0 + i);
			glActiveTexture(GL_TEXTURE0 + i);
			glTexCoordPointer(va->texcoord_size[i%va->texcoord_count], GL_FLOAT, sizeof(float)*va->stride, (void *)(sizeof(float)*va->texcoord_offs[i%va->texcoord_count]));
		}

		if(gl_shaders)
		for(i = 0; i < va->attr_count; i++)
		{
			glVertexAttribPointer(i+1, va->attr_size[i], GL_FLOAT, GL_FALSE,
				sizeof(float)*va->stride, ((float *)0) + va->attr_offs[i]);
		}
	}
	glClientActiveTexture(GL_TEXTURE0);
	glActiveTexture(GL_TEXTURE0);
	glEnableClientState(GL_VERTEX_ARRAY);
	if(va->color_offs != -1) glEnableClientState(GL_COLOR_ARRAY);
	if(va->normal_offs != -1) glEnableClientState(GL_NORMAL_ARRAY);
	if(va->texcoord_count >= 1)
	for(i = 0; i < va->texcoord_count || i < img_count; i++)
	{
		glClientActiveTexture(GL_TEXTURE0 + i);
		glActiveTexture(GL_TEXTURE0 + i);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	}
	glClientActiveTexture(GL_TEXTURE0);
	glActiveTexture(GL_TEXTURE0);

	if(gl_shaders)
		for(i = 0; i < va->attr_count; i++)
			glEnableVertexAttribArray(i+1);

	glDrawArrays(GL_TRIANGLES, 0, va->data_len);

	if(gl_shaders)
		for(i = 0; i < va->attr_count; i++)
			glDisableVertexAttribArray(i+1);
	if(va->texcoord_count >= 1)
	for(i = 0; i < va->texcoord_count || i < img_count; i++)
	{
		glClientActiveTexture(GL_TEXTURE0 + i);
		glActiveTexture(GL_TEXTURE0 + i);
		glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	}
	glClientActiveTexture(GL_TEXTURE0);
	glActiveTexture(GL_TEXTURE0);

	if(va->normal_offs != -1) glDisableClientState(GL_NORMAL_ARRAY);
	if(va->color_offs != -1) glDisableClientState(GL_COLOR_ARRAY);
	glDisableClientState(GL_VERTEX_ARRAY);
	if(va->vbo != 0)
		glBindBuffer(GL_ARRAY_BUFFER, 0);

	for(i = 0; i < img_count; i++)
	if(img[i] != NULL)
	{
		glClientActiveTexture(GL_TEXTURE0 + i);
		glActiveTexture(GL_TEXTURE0 + i);
		glBindTexture(GL_TEXTURE_2D, 0);
		glDisable(GL_TEXTURE_2D);
	}
	glClientActiveTexture(GL_TEXTURE0);
	glActiveTexture(GL_TEXTURE0);

	glPopMatrix();
	glDisable(GL_BLEND);
}

void render_resize(int width, int height)
{
	glMatrixMode(GL_PROJECTION);
	mtx_baseproj[10] = (zfar + znear)/(zfar - znear);
	mtx_baseproj[14] = -(2.0f * zfar * znear)/(zfar - znear);
	mtx_baseproj[11] = 1;
	glLoadMatrixf(mtx_baseproj);
	if(width > height)
		glScalef(1.0f,((float)width)/((float)height),1.0f);
	else
		glScalef(((float)height)/((float)width),1.0f,1.0f);
	glMatrixMode(GL_MODELVIEW);

	lwidth = width;
	lheight = height;
}

int render_init(int width, int height)
{
	render_resize(width, height);
	glLoadIdentity();

	if (gl_quality > 0)
	{
		/* set highest quality */
		glShadeModel(GL_SMOOTH);
		glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
		glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);
		glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);
		glHint(GL_POINT_SMOOTH_HINT, GL_NICEST);
		glHint(GL_TEXTURE_COMPRESSION_HINT, GL_NICEST);
		glHint(GL_FOG_HINT, GL_NICEST);
	} else {
		/* set lowest quality */
		glShadeModel(GL_FLAT);
		glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_FASTEST);
		glHint(GL_LINE_SMOOTH_HINT, GL_FASTEST);
		glHint(GL_POLYGON_SMOOTH_HINT, GL_FASTEST);
		glHint(GL_POINT_SMOOTH_HINT, GL_FASTEST);
		glHint(GL_TEXTURE_COMPRESSION_HINT, GL_FASTEST);
		glHint(GL_FOG_HINT, GL_FASTEST);
	}
	
	// probably something.
	return 0;
}

void render_deinit(void)
{
	// probably nothing.
}

