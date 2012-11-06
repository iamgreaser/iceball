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

model_t *model_new(int bonemax)
{
	model_t *pmf = malloc(sizeof(model_t)+sizeof(model_bone_t *)*bonemax);
	// TODO: check if NULL
	
	pmf->bonelen = 0;
	pmf->bonemax = bonemax;
	
	return pmf;
}

model_t *model_extend(model_t *pmf, int bonemax)
{
	pmf = realloc(pmf, sizeof(model_t)+sizeof(model_bone_t *)*bonemax);
	// TODO: check if NULL
	
	pmf->bonemax = bonemax;
	
	return pmf;
}

void model_free(model_t *pmf)
{
	while(pmf->bonelen != 0)
		model_bone_free(pmf->bones[pmf->bonelen-1]);
	
	free(pmf);
}

model_bone_t *model_bone_new(model_t *pmf, int ptmax)
{
	model_bone_t *bone = malloc(sizeof(model_bone_t)+sizeof(model_point_t)*ptmax);
	// TODO: check if NULL
	
	bone->ptlen = 0;
	bone->ptmax = ptmax;
	
	bone->parent = pmf;
	bone->parent_idx = pmf->bonelen++;
	pmf->bones[bone->parent_idx] = bone;
	
	return bone;
}

model_bone_t *model_bone_extend(model_bone_t *bone, int ptmax)
{
	model_t *pmf = bone->parent;
	bone = realloc(bone, sizeof(model_bone_t)+sizeof(model_point_t)*ptmax);
	// TODO: check if NULL
	
	bone->ptmax = ptmax;
	
	return bone;
}

void model_bone_free(model_bone_t *bone)
{
	int i = bone->parent_idx;
	
	bone->parent->bonelen--;
	for(i = 0; i < bone->parent->bonelen; i++)
		bone->parent->bones[i] = bone->parent->bones[i+1];
	
	free(bone);
}

model_t *model_load_pmf(void)
{
	// TODO!
	return NULL;
}
