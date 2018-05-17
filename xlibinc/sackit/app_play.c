#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <errno.h>

#include <SDL.h>

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

#include "sackit.h"

#define BUFSIZE 4096
#define FREQ 48000

SDL_Surface *screen = NULL;

uint32_t palette[4] = {
	0x00FFFFFF,
	0x00FF0000,
	0x0000FF00,
	0x000000FF,
};

volatile int sound_ready = 1;
int16_t *sound_buf = NULL;
int16_t *sound_queue = NULL;
int sound_queue_pos = (int)(((unsigned int)-1)>>1);

#ifdef __EMSCRIPTEN__
float mozsux_expticks = -99999;
float mozsux_curticks = -1;
#endif

void test_sdl_callback(void *userdata, Uint8 *stream, int len)
{
	int offs = 0;
	sackit_playback_t *sackit = (sackit_playback_t *)userdata;
	int16_t *outbuf = (int16_t *)stream;
	int16_t *nvbuf = (int16_t *)sound_buf;
	
	len /= 4;
	
	while(offs < len)
	{
		if(sound_queue_pos < BUFSIZE)
		{
			int xlen = BUFSIZE-sound_queue_pos;
			if(xlen > len-offs)
				xlen = len;
			
			memcpy(&stream[offs*4], &sound_queue[sound_queue_pos*2], xlen*4);
			sound_queue_pos += xlen;
			offs += xlen;
		} else {
			memcpy(sound_queue, nvbuf, BUFSIZE*4);
			sound_queue_pos = 0;
			sound_ready = 1;
		}
	}
}

int play_a_sound = 1;

#ifdef __EMSCRIPTEN__
sackit_playback_t *sackit_glb;
#endif

int mainloop(sackit_playback_t *sackit)
{
	int x, y;
#ifndef __EMSCRIPTEN__
	uint32_t *pbuf = screen->pixels;
	int divpitch = screen->pitch/sizeof(uint32_t);
#endif

	int quitflag = 0;

	SDL_Event ev;
#ifndef __EMSCRIPTEN__
	while(SDL_PollEvent(&ev))
	switch(ev.type)
	{
		case SDL_KEYDOWN:
			play_a_sound = 1;
			break;
		case SDL_QUIT:
			quitflag = 1;
			break;
	}
#endif
		
	if(play_a_sound && sound_ready)
	{
		//play_a_sound = 0;
#ifdef __EMSCRIPTEN__
		mozsux_curticks = SDL_GetTicks();
		if(mozsux_expticks == -99999)
			mozsux_expticks = mozsux_curticks - 1000;
		if(mozsux_curticks >= mozsux_expticks)
		{
			//printf("%i\n", mozsux_curticks);
			sackit_playback_update(sackit);

			int16_t *nvbuf = (int16_t *)sound_buf;
			memcpy(nvbuf, sackit->buf, BUFSIZE*4);
			sound_ready = 0;

			mozsux_expticks += 1000.0f*BUFSIZE/(float)(FREQ);
			if(mozsux_expticks + 1500.0f < mozsux_curticks)
				mozsux_expticks = mozsux_curticks - 1500.0f;
			SDL_PauseAudio(0);
		} else {
			SDL_PauseAudio(1);
		}
#else
		sackit_playback_update(sackit);

		int16_t *nvbuf = (int16_t *)sound_buf;
		memcpy(nvbuf, sackit->buf, BUFSIZE*4);
		sound_ready = 0;
#endif
		
		// VISUALISE
#ifndef __EMSCRIPTEN__
		memset(screen->pixels, 0, screen->pitch*screen->h);
		for(x = 0; x < screen->w*2; x++)
		{
			int yb = sackit->buf[x];
			
			if((x&1) == 0)
			{
				y = 0;
				y = (y+0x8000)*screen->h/0x10000;
				y = screen->h-1-y;
				pbuf[divpitch*y+(x>>1)] = 0xFFFFFF;
			}
			
			y = yb;
			y = (y+0x8000)*screen->h/0x10000;
			y = screen->h-1-y;
			pbuf[divpitch*y+(x>>1)] |= ((x&1) ? 0x0000FF : 0xFF0000);
		}
		
		SDL_Flip(screen);
#endif
	}

	return quitflag;
}

#ifdef __EMSCRIPTEN__
void mainloop_em()
{
	mainloop(sackit_glb);
}
#endif

int main(int argc, char *argv[])
{
	int x,y,i;
	
#ifdef STATIC_FNAME
	it_module_t *module = sackit_module_load(STATIC_FNAME);
#else
	it_module_t *module = sackit_module_load(argv[1]);
#endif
	
	if(module == NULL)
		return 1;
	
	//SDL_Init(SDL_INIT_VIDEO|SDL_INIT_AUDIO|SDL_INIT_TIMER|SDL_INIT_NOPARACHUTE);
	SDL_Init(SDL_INIT_VIDEO|SDL_INIT_AUDIO|SDL_INIT_NOPARACHUTE);
	
	SDL_WM_SetCaption("sackit IT player", NULL);
#ifndef __EMSCRIPTEN__
	screen = SDL_SetVideoMode(800, 600, 32, 0);
	
	// draw something
	uint32_t *pbuf = screen->pixels;
	int divpitch = screen->pitch/sizeof(uint32_t);
	for(y = 0; y < screen->h; y++)
		for(x = 0; x < screen->w; x++)
			pbuf[divpitch*y+x] = 0x00000000;
#endif
	
	sackit_playback_t *sackit = sackit_playback_new2(module, BUFSIZE, 256, fnlist_itmixer[MIXER_IT214FS], 4, FREQ);
	//sackit_playback_t *sackit = sackit_playback_new2(module, BUFSIZE, 256, fnlist_itmixer[MIXER_INTFAST_AS], 4, FREQ);
	//sackit_playback_t *sackit = sackit_playback_new2(module, BUFSIZE, 256, fnlist_itmixer[MIXER_IT212S], 4, FREQ);
	
	SDL_AudioSpec aspec;
	aspec.freq = FREQ;
	aspec.format = AUDIO_S16SYS;
	aspec.channels = 2;
#ifdef __EMSCRIPTEN__
	aspec.samples = 512;
#else
	aspec.samples = BUFSIZE;
#endif
	aspec.callback = test_sdl_callback;
	sound_buf = calloc(1,BUFSIZE*4);
	sound_queue = calloc(1,BUFSIZE*4);
	SDL_OpenAudio(&aspec, NULL);
	SDL_PauseAudio(0);
	
	int refoffs = 0;

#ifdef __EMSCRIPTEN__
	sackit_glb = sackit;
	emscripten_set_main_loop(mainloop_em, 100, 1);
#else
	while(!mainloop(sackit))
	{
		SDL_Delay(10);
	}

	sackit_playback_free(sackit);
	sackit_module_free(module);

	free(sound_buf);
	free(sound_queue);

	// to help shut valgrind up
	SDL_Quit();
	
	return 0;
#endif
}

