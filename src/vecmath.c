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

#ifndef __SSE__

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

	const int mask[4] = {0x00,0x55,0xAA,0xFF};

	for(i = 0; i < 4; i++)
	{
		accum.m = vec->m;
		_mm_shuffle_ps(accum.m, accum.m, mask[i]);
		accum.m *= mtx->c[i].m;
		ret.m += accum.m;
	}

#endif

	return ret;
}


void cam_point_dir(camera_t *model, float dx, float dy, float dz, float zoom, float roll)
{
	// Another case where I'd copy-paste code from my aimbot.
	// Except the last time I did it, I redid it from scratch,
	// and then dumped it. (VUW COMP308 Project 2012T2, anyone?)
	//
	// But yeah, basically this code's useful for making aimbots >:D
	//
	// Am I worried?
	// Well, the average skid is too lazy to compile this.
	// So, uh, no, not really.

	// Get two distance values.
	float d2 = dx*dx+dz*dz;
	float d3 = dy*dy+d2;

	// Square root them so they're actually distance values.
	d2 = sqrtf(d2);
	d3 = sqrtf(d3);

	// Get the normalised distances.
	float nx = dx/d3;
	float ny = dy/d3;
	float nz = dz/d3;

	// Now build that matrix!

	// Front vector (Z): Well, duh.
	model->mzx = nx*zoom;
	model->mzy = ny*zoom;
	model->mzz = nz*zoom;

	// Left (TODO: confirm) vector (X): Simple 2D 90deg rotation.
	// Can be derived from a bit of trial and error.
	model->mxx = dz/d2;
	model->mxy = 0.0f;
	model->mxz = -dx/d2;

	// Down vector (Y): STUPID GIMBAL LOCK GRR >:(
	// But really, this one's the hardest of them all.
	//
	// I decided to cheat and look at my aimbot anyway.
	// Still didn't *quite* solve my problem.
	model->myx = -dx*ny/d2;
	model->myy = sqrtf(1.0f - ny*ny);
	model->myz = -dz*ny/d2;
}
