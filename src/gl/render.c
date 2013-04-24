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

const GLfloat mtx_baseproj[16] = {
	-1, 0, 0, 0,
	 0,-1, 0, 0,
	 0, 0, 1, 1,
	 0, 0,-0.1, 0,
};

const GLfloat vfinf_cube[3*6] = {
	0, 1, 0,   0, 0, 1, 
	0, 0, 1,   1, 0, 0, 
	1, 0, 0,   0, 1, 0, 
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
inline int render_mod ( int x , int y )
{
    return x >= 0 ? x % y : y - 1 - ((-x-1) % y) ;
}

uint32_t render_shade(uint32_t color, int face)
{
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

int render_visible_chunks_array_offset(int x, int z)
{
	return z * (int) sqrtf(gl_visible_chunks) + x;
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

	for (x = 0; x < (int) sqrtf(gl_visible_chunks); x++)
	{
		for (z = 0; z < (int) sqrtf(gl_visible_chunks); z++)
		{
			render_free_visible_chunk(&map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)]);
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
	
	map->visible_chunks_arr = (map_chunk_t *) malloc(gl_visible_chunks * sizeof(map_chunk_t));
	map->visible_chunks_vcenter_cx = starting_chunk_coordinate_x;
	map->visible_chunks_vcenter_cz = starting_chunk_coordinate_z;

	for (x = 0; x < (int) sqrtf(gl_visible_chunks); x++)
	{
		for (z = 0; z < (int) sqrtf(gl_visible_chunks); z++)
		{
			cx = starting_chunk_coordinate_x - (int) sqrtf(gl_visible_chunks)/2 + x;
			cz = starting_chunk_coordinate_z - (int) sqrtf(gl_visible_chunks)/2 + z;
			map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].cx = cx;
			map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].cz = cz;
			map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].vbo = 0;
			map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].vbo_dirty = 1;
			map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].vbo_arr_len = 0;
			map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].vbo_arr = NULL;
		}
	}

	map->visible_chunks_vcenter_x = (int) sqrtf(gl_visible_chunks)/2;
	map->visible_chunks_vcenter_z = (int) sqrtf(gl_visible_chunks)/2;
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
    map->visible_chunks_vcenter_x = render_mod(map->visible_chunks_vcenter_x + position_shift_x, (int) sqrtf(gl_visible_chunks));
    map->visible_chunks_vcenter_z = render_mod(map->visible_chunks_vcenter_z + position_shift_z, (int) sqrtf(gl_visible_chunks));

    /* setting the chunk coordinates of the virtual center of the circular array */
    map->visible_chunks_vcenter_cx = camera_chunk_coordinate_x;
    map->visible_chunks_vcenter_cz = camera_chunk_coordinate_z;

	for (x = 0; x < (int) sqrtf(gl_visible_chunks); x++)
	{
		for (z = 0; z < (int) sqrtf(gl_visible_chunks); z++)
		{
			offset_x = x - ((int) sqrtf(gl_visible_chunks)- 1)/2;
			offset_z = z - ((int) sqrtf(gl_visible_chunks)- 1)/2;
			index_x = render_mod(map->visible_chunks_vcenter_x + offset_x, (int) sqrtf(gl_visible_chunks));
			index_z = render_mod(map->visible_chunks_vcenter_z + offset_z, (int) sqrtf(gl_visible_chunks));

			/* untesselate chunks not visible anymore */
			if (map->visible_chunks_arr[render_visible_chunks_array_offset(index_x, index_z)].cx != map->visible_chunks_vcenter_cx + offset_x
				|| map->visible_chunks_arr[render_visible_chunks_array_offset(index_x, index_z)].cz != map->visible_chunks_vcenter_cz + offset_z)
			{
				render_free_visible_chunk(&map->visible_chunks_arr[render_visible_chunks_array_offset(index_x, index_z)]);
			}

			/* add chunks that are visible */
			if (map->visible_chunks_arr[render_visible_chunks_array_offset(index_x, index_z)].vbo_arr == NULL)
			{
				map->visible_chunks_arr[render_visible_chunks_array_offset(index_x, index_z)].cx = map->visible_chunks_vcenter_cx + offset_x;
				map->visible_chunks_arr[render_visible_chunks_array_offset(index_x, index_z)].cz = map->visible_chunks_vcenter_cz + offset_z;
				map->visible_chunks_arr[render_visible_chunks_array_offset(index_x, index_z)].vbo_dirty = 1;
			}
		}
	}

}

void render_map_visible_chunks_draw(map_t *map)
{
	int x, z;

	if(map == NULL || map->visible_chunks_arr == NULL)
		return;
	
	for (x = 0; x < (int) sqrtf(gl_visible_chunks); x++)
	{
		for (z = 0; z < (int) sqrtf(gl_visible_chunks); z++)
		{
			if (map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].vbo_arr_len > 0)
			{
				glPushMatrix();
				if (map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].vbo == 0)
				{
					glVertexPointer(3, GL_FLOAT, sizeof(float)*6, map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].vbo_arr);
					glColorPointer(3, GL_FLOAT, sizeof(float)*6, map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].vbo_arr+3);
				} else {
					glBindBuffer(GL_ARRAY_BUFFER, map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].vbo);
					glVertexPointer(3, GL_FLOAT, sizeof(float)*6, (void *)(0));
					glColorPointer(3, GL_FLOAT, sizeof(float)*6, (void *)(0 + sizeof(float)*3));
				}

				glEnableClientState(GL_VERTEX_ARRAY);
				glEnableClientState(GL_COLOR_ARRAY);
				glDrawArrays(GL_QUADS, 0, map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].vbo_arr_len);
				glDisableClientState(GL_VERTEX_ARRAY);
				glDisableClientState(GL_COLOR_ARRAY);
				glPopMatrix();

				if (map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].vbo != 0)
					glBindBuffer(GL_ARRAY_BUFFER, 0);
			}
		}
	}	
}

int render_map_visible_chunks_count_dirty(map_t *map)
{
	int x, z;
	int dirty_chunks_count = 0;

	if(map == NULL || map->visible_chunks_arr == NULL)
		return 0;
	
	for (x = 0; x < (int) sqrtf(gl_visible_chunks); x++)
	{
		for (z = 0; z < (int) sqrtf(gl_visible_chunks); z++)
		{
			if (map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].vbo_dirty)
			{
				dirty_chunks_count++;
			}
		}
	}
	return dirty_chunks_count;
}

void render_map_tesselate_visible_chunks(map_t *map)
{
	int x, z;
	/* pillar coords */
	int px, pz;
	map_chunk_t *chunk;
	int chunks_tesselated = 0;

	if(map == NULL || map->visible_chunks_arr == NULL)
		return;
	
	for (x = 0; x < (int) sqrtf(gl_visible_chunks); x++)
	{
		for (z = 0; z < (int) sqrtf(gl_visible_chunks); z++)
		{
			chunk = &map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)];

			if (chunks_tesselated >= gl_chunks_tesselated_per_frame)
				return;

			if (chunk->vbo_dirty)
			{
				render_untesselate_visible_chunk(chunk);
				for (px = 0; px < gl_chunk_size; px++)
				{
					for (pz = 0; pz < gl_chunk_size; pz++)
					{
						render_pillar(map, chunk, chunk->cx * gl_chunk_size + px, chunk->cz * gl_chunk_size + pz);
					}
				}
				if(chunk->vbo == 0 && GL_ARB_vertex_buffer_object)
					glGenBuffers(1, &(chunk->vbo));

				if(chunk->vbo != 0)
				{
					glBindBuffer(GL_ARRAY_BUFFER, chunk->vbo);
					glBufferData(GL_ARRAY_BUFFER, sizeof(float)*6*chunk->vbo_arr_len, chunk->vbo_arr, GL_STATIC_DRAW);
					glBindBuffer(GL_ARRAY_BUFFER, 0);
				}
				chunk->vbo_dirty = 0;
				chunks_tesselated++;
			}
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
	
	for (x = 0; x < (int) sqrtf(gl_visible_chunks); x++)
	{
		for (z = 0; z < (int) sqrtf(gl_visible_chunks); z++)
		{
			if (map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].cx == chunk_x && map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].cz == chunk_z)
			{
				map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)].vbo_dirty = 1;

				/* If pillar coords are between two chunks, we need to update the neighbor chunks as well */
				if (render_mod(pillar_x, gl_chunk_size) == 0)
				{
					neighbor_chunk_x = render_mod(x - 1, (int) sqrtf(gl_visible_chunks));
					neighbor_chunk_z = z;
					neighbor_chunk = &map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)];
					if (neighbor_chunk->cx == chunk_x - 1 && neighbor_chunk->cz == chunk_z)
					{
						neighbor_chunk->vbo_dirty = 1;
					}
				} else if (render_mod(pillar_x, gl_chunk_size) == gl_chunk_size-1)
				{
					neighbor_chunk_x = render_mod(x + 1, (int) sqrtf(gl_visible_chunks));
					neighbor_chunk_z = z;
					neighbor_chunk = &map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)];
					if (neighbor_chunk->cx == chunk_x + 1 && neighbor_chunk->cz == chunk_z)
					{
						neighbor_chunk->vbo_dirty = 1;
					}
				}
				if (render_mod(pillar_z, gl_chunk_size) == 0)
				{
					neighbor_chunk_x = x;
					neighbor_chunk_z = render_mod(z - 1, (int) sqrtf(gl_visible_chunks));
					neighbor_chunk = &map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)];
					if (neighbor_chunk->cx == chunk_x && neighbor_chunk->cz == chunk_z - 1)
					{
						neighbor_chunk->vbo_dirty = 1;
					}
				} else if (render_mod(pillar_z, gl_chunk_size) == gl_chunk_size-1)
				{
					neighbor_chunk_x = x;
					neighbor_chunk_z = render_mod(z + 1, (int) sqrtf(gl_visible_chunks));
					neighbor_chunk = &map->visible_chunks_arr[render_visible_chunks_array_offset(x, z)];
					if (neighbor_chunk->cx == chunk_x && neighbor_chunk->cz == chunk_z + 1)
					{
						neighbor_chunk->vbo_dirty = 1;
					}
				}
				return;
			}
		}
	}
}

void render_update_vbo(float **arr, int *len, int *max, int newlen)
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

	*arr = (float*)realloc(*arr, xlen*sizeof(float)*6);
	*max = xlen;
}

void render_gl_cube_pmf(model_bone_t *bone, float x, float y, float z, float r, float g, float b, float rad)
{
	int i;
	float ua,ub,uc;
	float va,vb,vc;

	render_update_vbo(&(bone->vbo_arr), &(bone->vbo_arr_len), &(bone->vbo_arr_max), bone->vbo_arr_len+4*6);
	float *arr = bone->vbo_arr;
	arr += bone->vbo_arr_len*6;
	bone->vbo_arr_len += 4*6;

	for(i = 0; i < 3; i++)
	{
		float s2 = ((int)cam_shading[i+0])/255.0f;
		float s1 = ((int)cam_shading[i+3])/255.0f;
		float cr,cg,cb;

		ua = vfinf_cube[i*6+0];
		ub = vfinf_cube[i*6+1];
		uc = vfinf_cube[i*6+2];
		va = vfinf_cube[i*6+3];
		vb = vfinf_cube[i*6+4];
		vc = vfinf_cube[i*6+5];
		
#define ARR_ADD(vx,vy,vz) \
		*(arr++) = vx; *(arr++) = vy; *(arr++) = vz; \
		*(arr++) = cr; *(arr++) = cg; *(arr++) = cb;

		/* Quad 1 */
		cr = r*s1; cg = g*s1, cb = b*s1;
		ARR_ADD(x,y,z);
		ARR_ADD(x+rad*ua,y+rad*ub,z+rad*uc);
		ARR_ADD(x+rad*(ua+va),y+rad*(ub+vb),z+rad*(uc+vc));
		ARR_ADD(x+rad*va,y+rad*vb,z+rad*vc);

		/* Quad 2 */
		cr = r*s2; cg = g*s2, cb = b*s2;
		ARR_ADD(x+rad,y+rad,z+rad);
		ARR_ADD(x+rad*(1-va),y+rad*(1-vb),z+rad*(1-vc));
		ARR_ADD(x+rad*(1-ua-va),y+rad*(1-ub-vb),z+rad*(1-uc-vc));
		ARR_ADD(x+rad*(1-ua),y+rad*(1-ub),z+rad*(1-uc));
#undef ARR_ADD
	}
}

void render_gl_cube_map(map_t *map, map_chunk_t *chunk, float x, float y, float z, float r, float g, float b, float rad)
{
	int i;
	float ua,ub,uc;
	float va,vb,vc;
	float average_light_vertex1, average_light_vertex2, average_light_vertex3, average_light_vertex4;

	float *arr = chunk->vbo_arr;

	/* Quads rendering explained (sort of)

	   i = 0                                          | i = 1                                          | i = 2                                         
	   -----                                          | -----                                          | -----                                         
	                                                  |                                                |                                               
	   Quad 1 (left)               Quad 2 (right)     | Quad 1 (top)            Quad 2 (bottom)        | Quad 1 (back)              Quad 2 (front)     
	                                                  |                                                |         
	               1                       3          |             1         4                        |            1        2                         
	    +-- x       +.......         .......+         |  +-- x       +------+         ........         |  +-- x      +------+         ........         
	   /|        4 /|     ..        ..   4 /|         | /|          /.     /.        ..     ..         | /|         .|     .|      3 ..     2.         
	   z y        +.|..... .       .......+ |         |z y         +------+ .       ........ .         |z y        ..|..... |       +------+ .         
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


	    Generic coordinates formula to check for each vertex (god, I don't even know what I'm writing, it would miraculous if it works) :

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
		ua = vfinf_cube[i*6+0];
		ub = vfinf_cube[i*6+1];
		uc = vfinf_cube[i*6+2];
		va = vfinf_cube[i*6+3];
		vb = vfinf_cube[i*6+4];
		vc = vfinf_cube[i*6+5];

		float s2 = ((int)cam_shading[i+0])/255.0f;
		float s1 = ((int)cam_shading[i+3])/255.0f;
		float cr,cg,cb;
	
#define ARR_ADD(vx,vy,vz) \
		*(arr++) = vx; *(arr++) = vy; *(arr++) = vz; \
		*(arr++) = cr; *(arr++) = cg; *(arr++) = cb;

		/* check visibility of the face (is face exposed to air ?) */
		if (render_map_get_block_at(map, x - ub, y - uc, z - ua) == 0)
		{
			render_update_vbo(&(chunk->vbo_arr), &(chunk->vbo_arr_len), &(chunk->vbo_arr_max), chunk->vbo_arr_len+4);
			arr = chunk->vbo_arr;
			arr += chunk->vbo_arr_len*6;
			chunk->vbo_arr_len += 4;

			if (screen_smooth_lighting)
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

			/* Quad 1 */
			/* vertex 1 */
			cr = r*s1; cg = g*s1, cb = b*s1;
			cr = render_darken_color(cr, average_light_vertex1);
			cg = render_darken_color(cg, average_light_vertex1);
			cb = render_darken_color(cb, average_light_vertex1);
			ARR_ADD(x,y,z);

			/* vertex 2 */
			cr = r*s1; cg = g*s1, cb = b*s1;
			cr = render_darken_color(cr, average_light_vertex2);
			cg = render_darken_color(cg, average_light_vertex2);
			cb = render_darken_color(cb, average_light_vertex2);
			ARR_ADD(x+rad*ua,y+rad*ub,z+rad*uc);

			/* vertex 3 */
			cr = r*s1; cg = g*s1, cb = b*s1;
			cr = render_darken_color(cr, average_light_vertex3);
			cg = render_darken_color(cg, average_light_vertex3);
			cb = render_darken_color(cb, average_light_vertex3);
			ARR_ADD(x+rad*(ua+va),y+rad*(ub+vb),z+rad*(uc+vc));

			/* vertex 4 */
			cr = r*s1; cg = g*s1, cb = b*s1;
			cr = render_darken_color(cr, average_light_vertex4);
			cg = render_darken_color(cg, average_light_vertex4);
			cb = render_darken_color(cb, average_light_vertex4);
			ARR_ADD(x+rad*va,y+rad*vb,z+rad*vc);
		}

		/* check visibility of the face (is face exposed to air ?) */
		if (render_map_get_block_at(map, x + vc, y + va, z + vb) == 0)
		{
			render_update_vbo(&(chunk->vbo_arr), &(chunk->vbo_arr_len), &(chunk->vbo_arr_max), chunk->vbo_arr_len+4);
			arr = chunk->vbo_arr;
			arr += chunk->vbo_arr_len*6;
			chunk->vbo_arr_len += 4;

			if (screen_smooth_lighting)
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


			/* Quad 2 */
			/* vertex 1 */
			cr = r*s2; cg = g*s2, cb = b*s2;
			cr = render_darken_color(cr, average_light_vertex1);
			cg = render_darken_color(cg, average_light_vertex1);
			cb = render_darken_color(cb, average_light_vertex1);
			ARR_ADD(x+rad,y+rad,z+rad);

			/* vertex 2 */
			cr = r*s2; cg = g*s2, cb = b*s2;
			cr = render_darken_color(cr, average_light_vertex2);
			cg = render_darken_color(cg, average_light_vertex2);
			cb = render_darken_color(cb, average_light_vertex2);
			ARR_ADD(x+rad*(1-va),y+rad*(1-vb),z+rad*(1-vc));
		
			/* vertex 3 */
			cr = r*s2; cg = g*s2, cb = b*s2;
			cr = render_darken_color(cr, average_light_vertex3);
			cg = render_darken_color(cg, average_light_vertex3);
			cb = render_darken_color(cb, average_light_vertex3);
			ARR_ADD(x+rad*(1-ua-va),y+rad*(1-ub-vb),z+rad*(1-uc-vc));

			/* vertex 4 */
			cr = r*s2; cg = g*s2, cb = b*s2;
			cr = render_darken_color(cr, average_light_vertex4);
			cg = render_darken_color(cg, average_light_vertex4);
			cb = render_darken_color(cb, average_light_vertex4);
			ARR_ADD(x+rad*(1-ua),y+rad*(1-ub),z+rad*(1-uc));
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

	render_map_tesselate_visible_chunks(map);
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

void render_cubemap(uint32_t *pixels, int width, int height, int pitch, camera_t *camera, map_t *map)
{
	int x,y,z;
	float cx,cy,cz;

	float fog[4] = {
		((fog_color>>16)&255)/255.0,((fog_color>>8)&255)/255.0,((fog_color)&255)/255.0,1
	};

	float cfx,cfy,cfz;
	cfx = camera->mzx;
	cfy = camera->mzy;
	cfz = camera->mzz;
	float cfd2 = cfx*cfx+cfy*cfy+cfz*cfz;
	cfd2 = 1.0f/cfd2;

	glClearColor(fog[0], fog[1], fog[2], 1);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	glEnable(GL_CULL_FACE);
	glEnable(GL_DEPTH_TEST);
	glEnable(GL_FOG);
	glFogi(GL_FOG_MODE, GL_LINEAR);
	float cdist = fog_distance/sqrtf(2.0f*cfd2);
	glFogf(GL_FOG_START, cdist/2.0f);
	glFogf(GL_FOG_END, cdist);
	glFogfv(GL_FOG_COLOR, fog);

	cx = camera->mpx;
	cy = camera->mpy;
	cz = camera->mpz;

	GLfloat mtx_mv[16] = {
		camera->mxx, camera->myx, camera->mzx, 0,
		camera->mxy, camera->myy, camera->mzy, 0,
		camera->mxz, camera->myz, camera->mzz, 0,
		0,0,0,1
	};
	
	glMatrixMode(GL_MODELVIEW);
	glLoadMatrixf(mtx_mv);
	glTranslatef(-cx,-cy,-cz);
	
	if(map == NULL)
		return;
	
	render_map_visible_chunks_draw(map);
}

void render_pmf_bone(uint32_t *pixels, int width, int height, int pitch, camera_t *cam_base,
	model_bone_t *bone, int islocal,
	float px, float py, float pz, float ry, float rx, float ry2, float scale)
{
	int i;

	glEnable(GL_DEPTH_TEST);
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
			model_point_t *pt = &(bone->pts[i]);
			render_pmf_cube(bone, pt->x/256.0f, pt->y/256.0f, pt->z/256.0f, pt->r, pt->g, pt->b, pt->radius*2.0f/256.0f);
		}
		
		bone->vbo_dirty = 0;
		
		if(bone->vbo == 0 && GL_ARB_vertex_buffer_object)
			glGenBuffers(1, &(bone->vbo));

		if(bone->vbo != 0)
		{
			glBindBuffer(GL_ARRAY_BUFFER, bone->vbo);
			glBufferData(GL_ARRAY_BUFFER, sizeof(float)*6*bone->vbo_arr_len, bone->vbo_arr, GL_STATIC_DRAW);
			glBindBuffer(GL_ARRAY_BUFFER, 0);
		}
	}

	if(bone->vbo == 0)
	{
		glVertexPointer(3, GL_FLOAT, sizeof(float)*6, bone->vbo_arr);
		glColorPointer(3, GL_FLOAT, sizeof(float)*6, bone->vbo_arr+3);
	} else {
		glBindBuffer(GL_ARRAY_BUFFER, bone->vbo);
		glVertexPointer(3, GL_FLOAT, sizeof(float)*6, (void *)(0));
		glColorPointer(3, GL_FLOAT, sizeof(float)*6, (void *)(0 + sizeof(float)*3));
	}
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_COLOR_ARRAY);
	glDrawArrays(GL_QUADS, 0, bone->vbo_arr_len);
	glDisableClientState(GL_VERTEX_ARRAY);
	glDisableClientState(GL_COLOR_ARRAY);
	if(bone->vbo != 0)
		glBindBuffer(GL_ARRAY_BUFFER, 0);

	glPopMatrix();
}

int render_init(int width, int height)
{
	glMatrixMode(GL_PROJECTION);
	glLoadMatrixf(mtx_baseproj);
	if(width > height)
		glScalef(1.0f,((float)width)/((float)height),1.0f);
	else
		glScalef(((float)height)/((float)width),1.0f,1.0f);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	
	// probably something.
	return 0;
}

void render_deinit(void)
{
	// probably nothing.
}

