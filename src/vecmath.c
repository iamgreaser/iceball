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

#ifndef __SSE__

vec4f_t mtx_apply_vec(matrix_t *mtx, vec4f_t *vec)
{
	int i,j;
	vec4f_t ret;

	// TODO: SIMD versions

	for(j = 0; j < 4; j++)
	{
		ret.a[j] = 0.0f;
		for(i = 0; i < 4; i++)
			ret.a[j] += vec->a[i] * mtx->c[i].a[j];
	}

	return ret;

}

#else

// MatrixMultiply3 -- a C++/ASM version of MatrixMultiply2, which takes
// advantage of Intel's SSE instructions.  This version requires that
// M be in column-major order.
//
// Performance: 57 cycles/vector
void MatrixMultiply3(matrix_t *mtx, vec4f_t *vec)
{
	vec4f_t ret;
	__asm__ __volatile__ (
		".intel_syntax prefix\n"
		//"mov	%[vec], vin"
		//"mov	edi, vout"

		// load columns of matrix into xmm4-7
		"movaps	%%xmm4, [%[mtx]]"
		"movaps	%%xmm5, [%[mtx]+0x10]"
		"movaps	%%xmm6, [%[mtx]+0x20]"
		"movaps	%%xmm7, [%[mtx]+0x30]"

		// load v into xmm0.
		"movaps	%%xmm0, [%[vec]]"

		// we'll store the final result in %[xmm_out]; initialize it
		// to zero
		"xorps	%[xmm_out], %[xmm_out]"

		// broadcast x into xmm1, multiply it by the first
		// column of the matrix (xmm4), and add it to the total
		"movaps	%%xmm1, %%xmm0"
		"shufps	%%xmm1, %%xmm1, 0x00"
		"mulps	%%xmm1, %%xmm4"
		"addps	%[xmm_out], %%xmm1"

		// repeat the process for y, z and w
		"movaps	%%xmm1, %%xmm0"
		"shufps	%%xmm1, %%xmm1, 0x55"
		"mulps	%%xmm1, %%xmm5"
		"addps	%[xmm_out], %%xmm1"
		"movaps	%%xmm1, %%xmm0"
		"shufps	%%xmm1, %%xmm1, 0xAA"
		"mulps	%%xmm1, %%xmm6"
		"addps	%[xmm_out], %%xmm1"
		"movaps	%%xmm1, %%xmm0"
		"shufps	%%xmm1, %%xmm1, 0xFF"
		"mulps	%%xmm1, %%xmm7"
		"addps	%[xmm_out], %%xmm1"

		// write the results to vout
		//"movaps	[edi], xmm2"
		".att_syntax prefix\n"
		: [xmm_out] "=x" (ret)
		: [mtx] "r" (mtx), [vec] "r" (vec)
		: "xmm1", "xmm4", "xmm5", "xmm6", "xmm7"
		);

	return ret;
}

#endif


void mtx_identity(matrix_t *mtx)
{
	int i,j;

	for(i = 0; i < 4; i++)
		for(j = 0; j < 4; j++)
			mtx->c[j].a[i] = (i==j ? 1 : 0);
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
