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

vec4f_t mtx_apply_vec(matrix_t *mtx, vec4f_t *vec)
{
	int i,j;

#if !defined(__SSE__) || defined(_MSC_VER)

	vec4f_t ret;

	for(j = 0; j < 4; j++)
	{
		ret.a[j] = 0.0f;
		for(i = 0; i < 4; i++)
			ret.a[j] += vec->a[i] * mtx->c[i].a[j];
	}

#else

	vec4f_t ret = {.m = {}}; //c99 + vector extensions, hopefully it optimizes
	vec4f_t accum;

	for(i = 0; i < 4; i++)
	{
		accum.m = vec->m;
		switch(i)
		{
			case 0: _mm_shuffle_ps(accum.m, accum.m, 0x00); break;
			case 1: _mm_shuffle_ps(accum.m, accum.m, 0x55); break;
			case 2: _mm_shuffle_ps(accum.m, accum.m, 0xAA); break;
			case 3: _mm_shuffle_ps(accum.m, accum.m, 0xFF); break;
		}
		accum.m *= mtx->c[i].m;
		ret.m += accum.m;
	}

#endif

	return ret;
}

void cam_point_dir_sky(camera_t *model, float dx, float dy, float dz, float sx, float sy, float sz, float zoom)
{
	// Double cross product method:
	//
	// left =  forward x sky
	// down =  forward x left
	//
	// Much nicer than the aimbot shit.

	// hack to make this play nice in the OpenGL renderer
	zoom = 1.0f/zoom;
	
	// Get the distances.
	float dist_d = dx*dx+dy*dy+dz*dz;
	float dist_s = sx*sx+sy*sy+sz*sz;
	dist_d = sqrtf(dist_d);
	dist_s = sqrtf(dist_s);
	
	// Get the normalised vectors.
	dx = dx/dist_d;
	dy = dy/dist_d;
	dz = dz/dist_d;
	
	sx = sx/dist_s;
	sy = sy/dist_s;
	sz = sz/dist_s;
	
	// Get the left vector.
	float ax = dy*sz - dz*sy;
	float ay = dz*sx - dx*sz;
	float az = dx*sy - dy*sx;
	
	// Get the down vector.
	float bx = dy*az - dz*ay;
	float by = dz*ax - dx*az;
	float bz = dx*ay - dy*ax;
	
	// Get their distances.
	float dist_a = ax*ax+ay*ay+az*az;
	float dist_b = bx*bx+by*by+bz*bz;
	dist_a = sqrtf(dist_a);
	dist_b = sqrtf(dist_b);
	
	// Get their normalised vectors.
	ax = ax/dist_a;
	ay = ay/dist_a;
	az = az/dist_a;
	
	bx = bx/dist_b;
	by = by/dist_b;
	bz = bz/dist_b;
	
	// Now build that matrix!
	
	// Front vector (Z)
	model->mzx = dx*zoom;
	model->mzy = dy*zoom;
	model->mzz = dz*zoom;
	
	// Left vector (X)
	model->mxx = ax;
	model->mxy = ay;
	model->mxz = az;
	
	// Down vector (Y)
	model->myx = bx;
	model->myy = by;
	model->myz = bz;
}

void cam_point_dir(camera_t *model, float dx, float dy, float dz, float zoom, float roll)
{
	// COMPLETE REWRITE
	
	float d2 = sqrtf(dx*dx + dz*dz);
	float sr = sin(roll);
	float cr = cos(roll);
	
	cam_point_dir_sky(model, dx, dy, dz, -sr*dz/d2, -cr, sr*dx/d2, zoom);
}
