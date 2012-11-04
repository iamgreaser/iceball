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
#include "config.h"

SDL_Surface *screen = NULL;
int screen_width = 800;
int screen_height = 600;

char *fnmap = "mesa.vxl";

int error_sdl(char *msg)
{
	fprintf(stderr, "%s: %s\n", msg, SDL_GetError());
	return 1;
}

int error_perror(char *msg)
{
	perror(msg);
	return 1;
}

int platform_init(void)
{
	if(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_NOPARACHUTE))
		return error_sdl("SDL_Init");
	
	return 0;
}

int video_init(void)
{
	SDL_WM_SetCaption("buld then snip",NULL);
	
	screen = SDL_SetVideoMode(screen_width, screen_height, 32, 0);
	
	if(screen == NULL)
		return error_sdl("SDL_SetVideoMode");
	
	return 0;
}

void video_deinit(void)
{
	// don't do anything
}

void platform_deinit(void)
{
	SDL_Quit();
}

void run_game(void)
{
	map_t *map = map_load_aos(fnmap);
	
	camera_t tcam;
	tcam.mpx = 256.5f;
	tcam.mpz = 256.5f;
	tcam.mpy = map->pillars[((int)tcam.mpz)*map->xlen+((int)tcam.mpy)][4+1]-2.0f;
	
	tcam.mxx = 1.0f;
	tcam.mxy = 0.0f;
	tcam.mxz = 0.0f;
	tcam.myx = 0.0f;
	tcam.myy = 1.0f;
	tcam.myz = 0.0f;
	tcam.mzx = 0.0f;
	tcam.mzy = 0.0f;
	tcam.mzz = 1.0f;
	
	int i;
	
	float angy = 0.0f;
	float angx = 0.0f;
	
	int key_left = 0;
	int key_right = 0;
	int key_up = 0;
	int key_down = 0;
	
	int key_w = 0;
	int key_s = 0;
	int key_a = 0;
	int key_d = 0;
	int key_space = 0;
	int key_ctrl = 0;
	
	render_vxl_redraw(&tcam, map);
	
	int quitflag = 0;
	
	int frame_prev = 0;
	int frame_now = 0;
	int fps = 0;
	
	while(!quitflag)
	{
		float zoom = 1.0f;
		
		// update angles
		if(key_left)
			angy += 0.02f/zoom;
		if(key_right)
			angy -= 0.02f/zoom;
		if(key_up)
			angx -= 0.02f/zoom;
		if(key_down)
			angx += 0.02f/zoom;
		
		// clamp angle, YOU MUST NOT LOOK DIRECTLY UP OR DOWN!
		if(angx > M_PI*0.499f)
			angx = M_PI*0.499f;
		if(angx < -M_PI*0.499f)
			angx = -M_PI*0.499f;
		
		// set camera direction
		float sya = sinf(angy);
		float cya = cosf(angy);
		float sxa = sinf(angx);
		float cxa = cosf(angx);
		cam_point_dir(&tcam, sya*cxa, sxa, cya*cxa, zoom, 0.0f);
		
		// move along
		float mvx = 0.0f;
		float mvy = 0.0f;
		float mvz = 0.0f;
		
		if(key_w)
			mvz += 1.0f;
		if(key_s)
			mvz -= 1.0f;
		if(key_a)
			mvx += 1.0f;
		if(key_d)
			mvx -= 1.0f;
		if(key_ctrl)
			mvy += 1.0f;
		if(key_space)
			mvy -= 1.0f;
		
		float mvspd = 0.2f/zoom;
		mvx *= mvspd;
		mvy *= mvspd;
		mvz *= mvspd;
		
		tcam.mpx += mvx*tcam.mxx+mvy*tcam.myx+mvz*tcam.mzx;
		tcam.mpy += mvx*tcam.mxy+mvy*tcam.myy+mvz*tcam.mzy;
		tcam.mpz += mvx*tcam.mxz+mvy*tcam.myz+mvz*tcam.mzz;
		
		if(mvx != 0.0f || mvy != 0.0f || mvz != 0.0f)
			render_vxl_redraw(&tcam, map);
		
		frame_now = SDL_GetTicks();
		fps++;
		
		if(frame_now - frame_prev > 1000)
		{
			char buf[64]; // topo how the hell did this not crash at 16 --GM
			sprintf(buf, "buld then snip | FPS: %d", fps);
			SDL_WM_SetCaption(buf, NULL);
			fps = 0;
			frame_prev = SDL_GetTicks();
		}
		
		//printf("%.2f",);
		SDL_LockSurface(screen);
		//memset(screen->pixels, 0x51, screen->h*screen->pitch);
		render_cubemap(screen->pixels,
			screen->w, screen->h, screen->pitch/4,
			&tcam, map);
		SDL_UnlockSurface(screen);
		SDL_Flip(screen);
		
		//SDL_Delay(10);
		
		SDL_Event ev;
		while(SDL_PollEvent(&ev))
		switch(ev.type)
		{
			case SDL_KEYUP:
			case SDL_KEYDOWN:
			switch(ev.key.keysym.sym)
			{
				case BTSK_LOOKUP:
					key_up = (ev.type == SDL_KEYDOWN);
					break;
				case BTSK_LOOKDOWN:
					key_down = (ev.type == SDL_KEYDOWN);
					break;
				case BTSK_LOOKLEFT:
					key_left = (ev.type == SDL_KEYDOWN);
					break;
				case BTSK_LOOKRIGHT:
					key_right = (ev.type == SDL_KEYDOWN);
					break;
				case BTSK_FORWARD:
					key_w = (ev.type == SDL_KEYDOWN);
					break;
				case BTSK_BACK:
					key_s = (ev.type == SDL_KEYDOWN);
					break;
				case BTSK_LEFT:
					key_a = (ev.type == SDL_KEYDOWN);
					break;
				case BTSK_RIGHT:
					key_d = (ev.type == SDL_KEYDOWN);
					break;
				case BTSK_CROUCH:
					key_ctrl = (ev.type == SDL_KEYDOWN);
					break;
				case BTSK_JUMP:
					key_space = (ev.type == SDL_KEYDOWN);
					break;
				default:
					// -Wswitch: SHUT. UP.
					break;
			} break;
			case SDL_QUIT:
				quitflag = 1;
				break;
		}
	}
	map_free(map);
}

int main(int argc, char *argv[])
{
	if(!platform_init()) {
	if(!btslua_init()) {
	if(!net_init()) {
	if(!video_init()) {
	if(!render_init(screen->w, screen->h)) {
		if(argc > 1)
			fnmap = argv[1];
		
		run_game();
		render_deinit();
	} video_deinit();
	} net_deinit();
	} btslua_deinit();
	} platform_deinit();
	}
	
	return 0;
}
