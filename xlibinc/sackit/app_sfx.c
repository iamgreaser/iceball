#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <errno.h>

#include <SDL.h>

#include "sackit.h"

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
	
	len /= 4;
	
	while(offs < len)
	{
		if(sound_queue_pos < 4096)
		{
			int xlen = 4096-sound_queue_pos;
			if(xlen > len-offs)
				xlen = len;
			
			memcpy(&stream[offs*4], &sound_queue[sound_queue_pos*2], xlen*4);
			sound_queue_pos += xlen;
			offs += xlen;
		} else {
			memcpy(sound_queue, nvbuf, 4096*4);
			sound_queue_pos = 0;
			sound_ready = 1;
		}
	}
}

int play_a_sound = 1;

int mainloop(sackit_playback_t *sackit)
{
	int x, y;
	uint32_t *pbuf = screen->pixels;
	int divpitch = screen->pitch/sizeof(uint32_t);

	int quitflag = 0;

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
		//play_a_sound = 0;
		sackit_playback_update(sackit);

		int16_t *nvbuf = (int16_t *)sound_buf;
		memcpy(nvbuf, sackit->buf, 4096*4);
		sound_ready = 0;
		
		// VISUALISE
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
	}

	return quitflag;
}

int main(int argc, char *argv[])
{
	int x,y,i;

	// find IMPM magic
	int64_t fboffs = 0;
#ifdef WIN32
	{
		char buf[5];
		int toffs;
		int img_base;
		int16_t numsects;
		// TODO: get proper running name! (MSDN will help!)
		FILE *fp = fopen(argv[0], "rb");
		fread(buf, 2, 1, fp);
		if(buf[0] != 'M' || buf[1] != 'Z')
			abort();
		fseek(fp, 0x3C, SEEK_SET);
		fread(&toffs, 4, 1, fp);
		fseek(fp, toffs, SEEK_SET);
		fread(buf, 4, 1, fp);
		if(memcmp(buf, "PE\x00\x00", 4))
			abort();

		// get image base + section count
		fseek(fp, 0x06 + toffs, SEEK_SET);
		fread(&numsects, 2, 1, fp);
		fseek(fp, 0x34 + toffs, SEEK_SET);
		fread(&img_base, 2, 1, fp);

		// nosey through the sections
		int i;
		for(i = 0; i < numsects; i++)
		{
			int hoffs, hlen;
			fseek(fp, 0xF8 + toffs + 0x28*i + 0x08, SEEK_SET);
			fread(&hlen, 4, 1, fp);
			fseek(fp, 0xF8 + toffs + 0x28*i + 0x14, SEEK_SET);
			fread(&hoffs, 4, 1, fp);
			printf("sect: %08X, %08X\n", hoffs, hlen);
			hoffs += hlen;
			if(hlen != 0 && hoffs > fboffs)
				fboffs = hoffs;
		}
		if(fboffs & 0x1FF)
			fboffs = (fboffs+0x200)&~0x1FF;
		fclose(fp);
	}
	printf("offset: %016llX\n", fboffs);
	it_module_t *module = sackit_module_load_offs(argv[0], fboffs);
#else
	{
		char buf[5];
		FILE *fp = fopen("/proc/self/exe", "rb");
		fread(buf, 4, 1, fp);
		if(!memcmp(buf, "ELF\x7F", 4))
			abort();

		// we don't care about endianness
		// BUT 32/64-bit is important here
		int fclass = fgetc(fp);
		int is64 = (fclass == 2);
		printf("64-bit: %i\n", is64);
		// finally, as we're already running the damn thing, the version doesn't matter too much as it's obviously right.

		fseek(fp, is64 ? 0x20 : 0x1C, SEEK_SET);
		int64_t phoff = 0; // just in case we have to for some WEIRD reason look up a 64-bit ELF in 32-bit code
		int64_t shoff = 0;
		// TODO: get 32-bit big endian to work here
		// bigger TODO: get sackit to actually WORK on big endian
		fread(&phoff, is64 ? 8 : 4, 1, fp);
		fread(&shoff, is64 ? 8 : 4, 1, fp);

		fseek(fp, is64 ? 0x36 : 0x2A, SEEK_SET);
		int16_t phentsize, phnum;
		int16_t shentsize, shnum;
		fread(&phentsize, 2, 1, fp);
		fread(&phnum, 2, 1, fp);
		fread(&shentsize, 2, 1, fp);
		fread(&shnum, 2, 1, fp);

		// look through program headers
		printf("%016llX\n", phoff);
		int i;
		for(i = 0; i < phnum; i++)
		{
			int64_t hoffs, hlen;
			hoffs = hlen = 0;
			fseek(fp, phoff + i*phentsize + (is64 ? 0x08 : 0x04), SEEK_SET);
			fread(&hoffs, is64 ? 8 : 4, 1, fp);
			fseek(fp, phoff + i*phentsize + (is64 ? 0x20 : 0x10), SEEK_SET);
			fread(&hlen, is64 ? 8 : 4, 1, fp);
			printf("prog: %016llX, %016llX\n", hoffs, hlen);
			hoffs += hlen;
			if(hlen != 0 && hoffs > fboffs)
				fboffs = hoffs;
		}

		// look through section headers
		for(i = 0; i < shnum; i++)
		{
			int64_t hoffs, hlen;
			int flags;
			hoffs = hlen = 0;
			fseek(fp, shoff + i*shentsize + (is64 ? 0x04 : 0x04), SEEK_SET);
			fread(&flags, 4, 1, fp);
			fseek(fp, shoff + i*shentsize + (is64 ? 0x18 : 0x10), SEEK_SET);
			fread(&hoffs, is64 ? 8 : 4, 1, fp);
			fread(&hlen, is64 ? 8 : 4, 1, fp);
			printf("sect: %016llX, %016llX%s\n", hoffs, hlen, (flags == 8 ? " (NOBITS)" : ""));
			hoffs += hlen;
			if((flags != 8) && hlen != 0 && hoffs > fboffs)
				fboffs = hoffs;
		}

		if(fboffs < shoff + shnum*shentsize)
			fboffs = shoff + shnum*shentsize;

		fclose(fp);
	}
	printf("offset: %016llX\n", fboffs);
	it_module_t *module = sackit_module_load_offs("/proc/self/exe", fboffs);
#endif

	
	if(module == NULL)
		return 1;
	
	SDL_Init(SDL_INIT_VIDEO|SDL_INIT_AUDIO|SDL_INIT_TIMER|SDL_INIT_NOPARACHUTE);
	
	SDL_WM_SetCaption("sackit IT player (self-extracting)", NULL);
	screen = SDL_SetVideoMode(800, 600, 32, 0);
	
	// draw something
	uint32_t *pbuf = screen->pixels;
	int divpitch = screen->pitch/sizeof(uint32_t);
	for(y = 0; y < screen->h; y++)
		for(x = 0; x < screen->w; x++)
			pbuf[divpitch*y+x] = 0x00000000;
	
	sackit_playback_t *sackit = sackit_playback_new(module, 4096, 256, MIXER_IT214FS);
	
	SDL_AudioSpec aspec;
	aspec.freq = 44100;
	aspec.format = AUDIO_S16SYS;
	aspec.channels = 2;
	aspec.samples = 4096;
	aspec.callback = test_sdl_callback;
	sound_buf = calloc(1,4096*4);
	sound_queue = calloc(1,4096*4);
	SDL_OpenAudio(&aspec, NULL);
	SDL_PauseAudio(0);
	
	int refoffs = 0;

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
}

