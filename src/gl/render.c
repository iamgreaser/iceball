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
#include <GL/gl.h>

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

/*
 * REFERENCE IMPLEMENTATION
 * 
 */

uint32_t render_shade(uint32_t color, int face)
{
	uint32_t fc = cam_shading[face];
	return (((((color&0x00FF00FF)*fc)>>8)&0x00FF00FF))
		|((((((color>>8)&0x00FF00FF)*fc))&0xFF00FF00))|0x01000000;
}

void render_gl_cube_pmf(float x, float y, float z, float r, float g, float b, float rad)
{
	int i;
	float ua,ub,uc;
	float va,vb,vc;

	glColor3f(r,g,b);
	glBegin(GL_QUADS);
		for(i = 0; i < 3; i++)
		{
			ua = vfinf_cube[i*6+0];
			ub = vfinf_cube[i*6+1];
			uc = vfinf_cube[i*6+2];
			va = vfinf_cube[i*6+3];
			vb = vfinf_cube[i*6+4];
			vc = vfinf_cube[i*6+5];

			glVertex3f(x,y,z);
			glVertex3f(x+rad*ua,y+rad*ub,z+rad*uc);
			glVertex3f(x+rad*(ua+va),y+rad*(ub+vb),z+rad*(uc+vc));
			glVertex3f(x+rad*va,y+rad*vb,z+rad*vc);

			glVertex3f(x+rad,y+rad,z+rad);
			glVertex3f(x+rad*(1-va),y+rad*(1-vb),z+rad*(1-vc));
			glVertex3f(x+rad*(1-ua-va),y+rad*(1-ub-vb),z+rad*(1-uc-vc));
			glVertex3f(x+rad*(1-ua),y+rad*(1-ub),z+rad*(1-uc));
		}
	glEnd();
}

void render_gl_cube(float x, float y, float z, float r, float g, float b, float rad)
{
	int i;
	float ua,ub,uc;
	float va,vb,vc;

	glBegin(GL_QUADS);
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

			glColor3f(r*s1,g*s1,b*s1);
			glVertex3f(x,y,z);
			glVertex3f(x+rad*ua,y+rad*ub,z+rad*uc);
			glVertex3f(x+rad*(ua+va),y+rad*(ub+vb),z+rad*(uc+vc));
			glVertex3f(x+rad*va,y+rad*vb,z+rad*vc);

			glColor3f(r*s2,g*s2,b*s2);
			glVertex3f(x+rad,y+rad,z+rad);
			glVertex3f(x+rad*(1-va),y+rad*(1-vb),z+rad*(1-vc));
			glVertex3f(x+rad*(1-ua-va),y+rad*(1-ub-vb),z+rad*(1-uc-vc));
			glVertex3f(x+rad*(1-ua),y+rad*(1-ub),z+rad*(1-uc));
		}
	glEnd();
}

void render_vxl_cube(int x, int y, int z, uint8_t *color)
{
	render_gl_cube(x, y, z, color[2]/255.0f, color[1]/255.0f, color[0]/255.0f, 1);
}

void render_pmf_cube(float x, float y, float z, int r, int g, int b, float rad)
{
	float hrad = rad/2.0f;
	render_gl_cube_pmf(x-hrad, y-hrad, z-hrad, r/255.0f, g/255.0f, b/255.0f, rad);
}

void render_vxl_redraw(camera_t *camera, map_t *map)
{
	// TODO: update VBOs and stuff when we get to that point
}

void render_pillar(map_t *map, int x, int z)
{
	int y, i;

	if(map == NULL)
		return;
	
	uint8_t *data = map->pillars[(z&(map->zlen-1))*(map->xlen)+(x&(map->xlen-1))];
	data += 4;

	int lastct = 0;
	for(;;)
	{
		for(y = data[1]; y <= data[2]; y++)
			render_vxl_cube(x, y, z, &data[4*(y-data[1]+1)]);

		lastct = -(data[2]-data[1]+1);
		if(lastct < 0)
			lastct = 0;
		lastct += data[0]-1;

		if(data[0] == 0)
			break;
		
		data += 4*(int)data[0];

		for(y = data[3]-lastct; y < data[3]; y++)
			render_vxl_cube(x, y, z, &data[4*(y-data[3])]);
	}
}

void render_cubemap(uint32_t *pixels, int width, int height, int pitch, camera_t *camera, map_t *map)
{
	int x,y,z;
	float cx,cy,cz;

	glClearColor(((fog_color>>16)&255)/255.0,((fog_color>>8)&255)/255.0,((fog_color)&255)/255.0, 1);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	glEnable(GL_CULL_FACE);
	glEnable(GL_DEPTH_TEST);

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

	//
	for(z = (int)(cz-fog_distance-1); z <= (int)(cz+fog_distance); z++) 
	for(x = (int)(cx-fog_distance-1); x <= (int)(cx+fog_distance); x++) 
	{
		// TODO: proper fog dist check
		render_pillar(map,x,z);
	}

}

void render_pmf_bone(uint32_t *pixels, int width, int height, int pitch, camera_t *cam_base,
	model_bone_t *bone, int islocal,
	float px, float py, float pz, float ry, float rx, float ry2, float scale)
{
	glEnable(GL_DEPTH_TEST);
	glPushMatrix();
	glTranslatef(px, py, pz);
	glScalef(scale,scale,scale);
	glRotatef(ry2*180.0f/M_PI, 0.0f, 1.0f, 0.0f);
	glRotatef(rx*180.0f/M_PI, 1.0f, 0.0f, 0.0f);
	glRotatef(ry*180.0f/M_PI, 0.0f, 1.0f, 0.0f);

	int i;
	for(i = 0; i < bone->ptlen; i++)
	{
		model_point_t *pt = &(bone->pts[i]);
		render_pmf_cube(pt->x/256.0f, pt->y/256.0f, pt->z/256.0f, pt->r, pt->g, pt->b, pt->radius*2.0f/256.0f);
	}

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

