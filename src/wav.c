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

typedef struct wavfmt {
	uint16_t codec, chns;
	uint32_t freq;
	uint32_t bytes_sec;
	uint16_t blkalign, bps;
} __attribute__((__packed__)) wavfmt_t;

float wav_cube_size;
int wav_mfreq = 0;
void (*wav_fn_mixer)(void *buf, int len) = NULL;
wavchn_t wchn[WAV_CHN_COUNT];
int wav_wctr = 0;

void wav_fn_mixer_s16he(void *buf, int len)
{
	int i;
	for(i = 0; i < WAV_CHN_COUNT; i++)
	{
		
	}
}

wav_t *wav_parse(char *buf, int len)
{
	if(len < 28+16)
	{
		fprintf(stderr, "wav_parse: file too short\n");
		return NULL;
	}
	
	if(memcmp(buf, "RIFF", 4))
	{
		fprintf(stderr, "wav_parse: not a RIFF file\n");
		return NULL;
	}
	
	if(memcmp(buf+8, "WAVE", 4))
	{
		fprintf(stderr, "wav_parse: not a WAVE RIFF file\n");
		return NULL;
	}
	
	if(memcmp(buf+12, "fmt ", 4))
	{
		fprintf(stderr, "wav_parse: expected \"fmt \" tag\n");
		return NULL;
	}
	
	int rifflen = (int)*(uint32_t *)(buf+4);
	int fmtlen = (int)*(uint32_t *)(buf+16);
	
	if(fmtlen < 16)
	{
		fprintf(stderr, "wav_parse: \"fmt \" tag too short (%i < %i)\n", fmtlen, 16);
		return NULL;
	}
	
	if(len < 28+fmtlen)
	{
		fprintf(stderr, "wav_parse: file too short\n");
		return NULL;
	}
	
	wavfmt_t fmt;
	memcpy(&fmt, buf+20, 16);
	
	/*
	from here: http://www.sonicspot.com/guide/wavefiles.html
	
	0 (0x0000)  Unknown
	1 (0x0001)  PCM/uncompressed
	2 (0x0002)  Microsoft ADPCM
	6 (0x0006)  ITU G.711 a-law
	7 (0x0007)  ITU G.711 mu-law
	17 (0x0011) IMA ADPCM
	20 (0x0016) ITU G.723 ADPCM (Yamaha)
	49 (0x0031) GSM 6.10
	64 (0x0040) ITU G.721 ADPCM
	
	hoping to support MS-ADPCM as well as IMA ADPCM.
	might support mu-law, too, even though ADPCM is superior.
	
	*/
	
	// check support
	if(fmt.codec != 1)
	{
		fprintf(stderr, "wav_parse: codec %i not supported\n", fmt.codec);
		return NULL;
	}
	if(fmt.chns != 1)
	{
		fprintf(stderr, "wav_parse: only mono .wav is supported (not %i-channel)\n", fmt.chns);
		return NULL;
	}
	if(fmt.bps != 8 && fmt.bps != 16)
	{
		fprintf(stderr, "wav_parse: only 8bps/16bps .wav is supported (not %ibps)\n", fmt.bps);
		return NULL;
	}
	
	// check integrity
	if(fmt.blkalign != ((fmt.bps+7)>>1)*fmt.chns)
	{
		fprintf(stderr, "wav_parse: block alignment is inconsistent\n");
		return NULL;
	}
	if(fmt.bytes_sec != fmt.freq*fmt.blkalign)
	{
		fprintf(stderr, "wav_parse: bytes per second is inconsistent\n");
		return NULL;
	}
	
	// now attempt to load data
	if(memcmp(buf+20+fmtlen, "data", 4))
	{
		fprintf(stderr, "wav_parse: expected \"data\" tag\n");
		return NULL;
	}
	
	int datalen = (int)*(uint32_t *)(buf+24+fmtlen);
	void *data_void = buf+28+fmtlen;
	if(len < datalen+28+fmtlen)
	{
		fprintf(stderr, "wav_parse: file too short for \"data\" section\n");
		return NULL;
	}
	
	if((datalen % fmt.blkalign) != 0)
	{
		fprintf(stderr, "wav_parse: data not block-aligned\n");
		return NULL;
	}
	
	printf("TODO: actual .wav loading\n");
	
	return NULL;
}

void wav_chn_kill(wavchn_t *chn)
{
	if(chn->src != NULL)
	{
		chn->src->refcount--;
		if(chn->src->refcount == 0)
			free(chn->src);
		chn->src = NULL;
	}
	chn->flags = 0;
}

int wav_init(void)
{
	int i;
	
	for(i = 0; i < WAV_CHN_COUNT; i++)
	{
		wchn[i].src = NULL;
		wchn[i].flags = 0;
	}
	
	// TODO: actually get output working
	
	return 0;
}

void wav_deinit(void)
{
	int i;
	
	for(i = 0; i < WAV_CHN_COUNT; i++)
		wav_chn_kill(&wchn[i]);
	
	// TODO: disable sound
}
