#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <errno.h>

#include <SDL.h>

#include "sackit.h"

#define BUFLEN 1024

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

void test_sdl_callback(void *userdata, Uint8 *stream, int len)
{
	int offs = 0;
	sackit_playback_t *sackit = (sackit_playback_t *)userdata;
	int16_t *outbuf = (int16_t *)stream;
	int16_t *nvbuf = (int16_t *)sound_buf;
	
	len /= 2;
	
	while(offs < len)
	{
		if(sound_queue_pos < BUFLEN)
		{
			int xlen = BUFLEN-sound_queue_pos;
			if(xlen > len-offs)
				xlen = len;
			
			memcpy(&stream[offs*2], &sound_queue[sound_queue_pos], xlen*2);
			sound_queue_pos += xlen;
			offs += xlen;
		} else {
			memcpy(sound_queue, nvbuf, BUFLEN*2);
			sound_queue_pos = 0;
			sound_ready = 1;
		}
	}
}

int main(int argc, char *argv[])
{
	int x,y,i;
	
	int argoffs = 1;
	int pausemode = 0;

	if(!strcmp(argv[argoffs], "-p"))
	{
		argoffs++;
		pausemode = 1;
	}

	it_module_t *module = sackit_module_load(argv[argoffs]);
	
	if(module == NULL)
		return 1;
	
	SDL_Init(SDL_INIT_VIDEO|SDL_INIT_AUDIO|SDL_INIT_TIMER|SDL_INIT_NOPARACHUTE);
	
	SDL_WM_SetCaption("sackit IT player", NULL);
	screen = SDL_SetVideoMode(800, 600, 32, 0);
	
	// draw something
	uint32_t *pbuf = screen->pixels;
	int divpitch = screen->pitch/sizeof(uint32_t);
	for(y = 0; y < screen->h; y++)
		for(x = 0; x < screen->w; x++)
			pbuf[divpitch*y+x] = 0x00000000;
	
	int16_t *refbuf = (argc > argoffs ? malloc(44100*60*10*2) : NULL);
	
	for(i = argoffs; i < argc; i++)
	{
		FILE *fp = fopen(argv[i], "rb");
		if(fgetc(fp) == 'R')
		{
			fseek(fp, 44, SEEK_SET); // cheat a bit, skip the parsing and go straight to the data
		} else {
			fseek(fp, 0, SEEK_SET); // not a RIFF. assume raw.
		}
		
		x = 0;
		for(;;)
		{
			y = fgetc(fp);
			if(y == -1)
				break;
			y += fgetc(fp)<<8;
			//y ^= 0x8000;
			refbuf[x++] = y;
		}
		fclose(fp);
	}
	
	sackit_playback_t *sackit = sackit_playback_new(module, BUFLEN, 256, MIXER_IT214FC);
	
	SDL_AudioSpec aspec;
	aspec.freq = 44100;
	aspec.format = AUDIO_S16SYS;
	aspec.channels = 1;
	aspec.samples = BUFLEN;
	aspec.callback = test_sdl_callback;
	sound_buf = calloc(1,BUFLEN*2);
	sound_queue = calloc(1,BUFLEN*2);
	SDL_OpenAudio(&aspec, NULL);
	SDL_PauseAudio(0);
	
	int refoffs = 0;
	
	int play_a_sound = 1;
	
	int quitflag = 0;
	while(!quitflag)
	{
		SDL_Event ev;
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
		
		if(play_a_sound && sound_ready)
		{
			if(pausemode)
				play_a_sound = 0;
			sackit_playback_update(sackit);
			
			// VISUALISE
			memset(screen->pixels, 0, screen->pitch*screen->h);
			for(x = 0; x < screen->w; x++)
			{
				int yb = sackit->buf[x];
				int yr = (refbuf == NULL ? 0 : refbuf[x+refoffs]);
				
				y = 0;
				y = (y+0x8000)*screen->h/0x10000;
				y = screen->h-1-y;
				pbuf[divpitch*y+x] = 0xFFFFFF;
				
				y = yb;
				y = (y+0x8000)*screen->h/0x10000;
				y = screen->h-1-y;
				pbuf[divpitch*y+x] = 0xFF0000;
				//fgetc(fp);fgetc(fp);
				
				y = yr;
				y = (y+0x8000)*screen->h/0x10000;
				y = screen->h-1-y;
				pbuf[divpitch*y+x] = 0x0000FF;
				
				y = yr-yb;
				if(y < -0x8000) y = -0x8000;
				if(y > 0x7FFF) y = 0x7FFF;
				//y = (y+0x8000)*screen->h/0x10000;
				y += screen->h/2;
				y = screen->h-1-y;
				if(y < 0)
					y = 0;
				if(y >= screen->h)
					y = screen->h-1;
				pbuf[divpitch*y+x] = 0x00FF00;
			}
			if(refbuf != NULL)
				refoffs += sackit->buf_len;
			
			SDL_Flip(screen);
			
			int16_t *nvbuf = (int16_t *)sound_buf;
			memcpy(nvbuf, sackit->buf, BUFLEN*2);
			sound_ready = 0;
		}
		
		SDL_Delay(10);
	}
	
	sackit_playback_free(sackit);
	sackit_module_free(module);
	
	return 0;
}
