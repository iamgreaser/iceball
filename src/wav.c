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

int icesackit_bufoffs = 0;
int icesackit_freq = 0;
#ifndef DEDI
sackit_playback_t *icesackit_pb = NULL;
#endif
float icesackit_vol = 1.0f;
float icesackit_mvol = 1.0f;

#pragma pack(push, 1)
typedef struct wavfmt {
	uint16_t codec, chns;
	uint32_t freq;
	uint32_t bytes_sec;
	uint16_t blkalign, bps;
} wavfmt_t;
#pragma pack(pop)

// These 2 tables are from here: http://wiki.multimedia.cx/index.php?title=IMA_ADPCM
int ima_index_table[16] = {
	-1, -1, -1, -1, 2, 4, 6, 8,
	-1, -1, -1, -1, 2, 4, 6, 8
}; 

int ima_step_table[89] = { 
	7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 
	19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 
	50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 
	130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
	337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
	876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 
	2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
	5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 
	15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767 
};

#ifndef DEDI
float wav_cube_size = 1.0f;
int wav_mfreq = 44100;
int wav_bufsize = 4096;
float wav_gvol = 1.0f;
void (*wav_fn_mixer)(void *buf, int len) = NULL;
wavchn_t wchn[WAV_CHN_COUNT];
int wav_wctr = 0;

void wav_fn_mixer_s16he_stereo(void *buf, int len)
{
	int i,j;

	len /= 4;

	// clear buffer
	{
		int16_t *v = (int16_t *)buf;
		for(j = 0; j < len; j++)
		{
			*(v++) = 0;
			*(v++) = 0;
		}
	}

	// do the sackity thing
	// TODO: handle freeing correctly
	sackit_playback_t *sackit = icesackit_pb;
	if(sackit != NULL)
	{
		int16_t *v = (int16_t *)buf;
		int16_t *u = (int16_t *)sackit->buf;
		j = 0;
		while(j < len)
		{
			if(icesackit_bufoffs == 4096)
			{
				icesackit_bufoffs = 0;
				sackit_playback_update(sackit);
			}
			int sirem = 4096 - icesackit_bufoffs;
			if(sirem > len)
				sirem = len;

			for(i = 0; i < sirem*2; i++)
			{
				int q = u[i+icesackit_bufoffs*2];
				q = (icesackit_mvol*icesackit_vol*q);
				if(q > 0x7FFF) q = 0x7FFF;
				if(q < -0x8000) q = -0x8000;
				*(v++) = (int16_t)q;
			}
			v += sirem*2;

			j += sirem;
			icesackit_bufoffs += sirem;
		}
	}

	// now for the wav mixing
	for(i = 0; i < WAV_CHN_COUNT; i++)
	{
		wavchn_t *wc = &wchn[i];

		// check if playing
		if((!(wc->flags & WCF_ACTIVE)) || wc->src == NULL)
			continue;

		// determine output values in 3D space per speaker
		// TODO: make this work on more than just stereo
		float vol[2];
		float delay[2];
		for(j = 0; j < 2; j++) {
			float dx = wc->x;
			float dy = wc->y;
			float dz = wc->z;

			// perform global transform if necessary
			if(wc->flags & WCF_GLOBAL)
			{
				float odx = dx - tcam.mpx;
				float ody = dy - tcam.mpy;
				float odz = dz - tcam.mpz;

				dx = odx*tcam.mxx + ody*tcam.mxy + odz*tcam.mxz;
				dy = odx*tcam.myx + ody*tcam.myy + odz*tcam.myz;
				dz = odx*tcam.mzx + ody*tcam.mzy + odz*tcam.mzz;

				dx = -dx;
				dy = -dy;
				dz = -dz;

				//printf("%.3f %.3f %.3f\n", dx, dy, dz);
			}

			// apply speaker positioning
			// TODO: config option - this is for headphones
			const float speaker_sep = 0.3f;

			float dotx, doty, dotz;
			if(j == 0)
			{
				dx -= speaker_sep/2.0f/wav_cube_size;
				dotx = -0.866f;
				doty =  0.000f;
				dotz = -0.500f;
			} else {
				dx += speaker_sep/2.0f/wav_cube_size;
				dotx =  0.866f;
				doty =  0.000f;
				dotz = -0.500f;
			}

			// work out distance
			float dist2 = dx*dx + dy*dy + dz*dz;
			float dist = sqrtf(dist2);
			if(dist < 0.00001f)
				dist = 0.00001f;

			// normalise dxyz
			dx /= dist;
			dy /= dist;
			dz /= dist;

			// calculate distance in metres
			float distm = dist*wav_cube_size;
			distm /= 10.0f;
			float att = 1.0f/(distm*distm);
			if(att > 1.0f)
				att = 1.0f;

			// apply attenuation
			att *= wc->vol;
			att *= wav_gvol;
			// TODO: work out how to apply vol_spread? or do we just scrap it?

			// calculate delay
			delay[j] = distm/330.0f;

			// get volume
			const float ambient = 0.33f;
			vol[j] = (dotx*dx + doty*dy + dotz*dz);
			vol[j] = (1.0-ambient)*vol[j] + ambient;
			vol[j] *= att;
		}

		// get the base speed
		float freq = wc->src->freq*wc->freq_mod;
		float speed = ((float)freq)/((float)wav_mfreq);

		// get the other stuff too
		int16_t *data = wc->src->data;
		uint32_t slen = wc->src->len;
		int16_t *data_end = data+slen;

		// apply delays
		float cspeed[2];
		float delay_scale = (float)wav_mfreq/(float)len;
		cspeed[0] = speed * (1.0f + (wc->ldelay[0]-delay[0])*delay_scale);
		cspeed[1] = speed * (1.0f + (wc->ldelay[1]-delay[1])*delay_scale);

		// avoid going backwards through the sample
		if(cspeed[0] < 0.0f) { cspeed[0] = 0.0f; }
		if(cspeed[1] < 0.0f) { cspeed[1] = 0.0f; }

		// move stuff into registers
		float offs[2];
		offs[0] = wc->offs[0];
		offs[1] = wc->offs[1];
		int16_t *v = (int16_t *)buf;

		for(j = 0; j < len; j++)
		{
			if(((int)offs[0]) >= slen && ((int)offs[1]) >= slen)
			{
				wav_chn_kill(wc);
				break;
			}

			int16_t d[2];
			d[0] = ((int)offs[0] >= slen ? 0.0f : data[(int)offs[0]]);
			d[1] = ((int)offs[1] >= slen ? 0.0f : data[(int)offs[1]]);
			int32_t v0 = (int32_t)(*v) + (int32_t)(vol[0]*d[0]);
			int32_t v1 = (int32_t)(*(v+1)) + (int32_t)(vol[1]*d[1]);
			if(v0 >  0x7FFF) v0 =  0x7FFF;
			if(v0 < -0x7FFF) v0 = -0x7FFF;
			if(v1 >  0x7FFF) v1 =  0x7FFF;
			if(v1 < -0x7FFF) v1 = -0x7FFF;

			*(v++) = (int16_t)v0;
			*(v++) = (int16_t)v1;

			offs[0] += cspeed[0];
			offs[1] += cspeed[1];
		}

		if(wc->flags & WCF_ACTIVE)
		{
			// move stuff back
			wc->offs[0] = offs[0];
			wc->offs[1] = offs[1];
		}
	}
}
#endif

int adpcm_predict(int v, int *pred, int *step)
{
	int diff;

	diff = (((v&7)*2 + 1) * ima_step_table[*step]) / 8;

	*step += ima_index_table[v];
	if(*step < 0) *step = 0;
	if(*step > 88) *step = 88;

	*pred += ((v & 8) != 0 ? -diff : diff);
	if(*pred < -0x8000) *pred = -0x8000;
	if(*pred >  0x7FFF) *pred =  0x7FFF;

	return *pred;
}

int adpcm_load_block(int16_t **wptr, int *pred, int *step, uint8_t **dbase, uint8_t *dbend)
{
	int i;
	int v;

	for(i = 0; i < 4; i++)
	{
		if(((*dbase)+1) > dbend)
		{
			fprintf(stderr, "adpcm_load_block: block ended too early!\n");
			return 1;
		}

		v = *((*dbase)++);
		*((*wptr)++) = adpcm_predict(v&15, pred, step);
		*((*wptr)++) = adpcm_predict((v>>4)&15, pred, step);
	}

	return 0;
}

wav_t *wav_parse(char *buf, int len)
{
	int i, j;
	char *end = buf + len;

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

	uint32_t rifflen = *(uint32_t *)(buf+4);
	uint32_t fmtlen = *(uint32_t *)(buf+16);

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
	if(fmt.codec != 0x0001 && fmt.codec != 0x0011)
	{
		fprintf(stderr, "wav_parse: codec 0x%04X not supported\n", fmt.codec);
		return NULL;
	}
	if(fmt.chns != 1)
	{
		fprintf(stderr, "wav_parse: only mono .wav is supported (not %i-channel)\n", fmt.chns);
		return NULL;
	}
	if(fmt.bps != 4 && fmt.bps != 8 && fmt.bps != 16)
	{
		fprintf(stderr, "wav_parse: only 8bps/16bps .wav or 4bps ADPCM is supported (not %ibps)\n", fmt.bps);
		return NULL;
	}

	// check integrity
	if(fmt.codec == 0x0001 && fmt.blkalign != ((fmt.bps+7)>>3)*fmt.chns)
	{
		fprintf(stderr, "wav_parse: block alignment is inconsistent\n");
		return NULL;
	}
	if(fmt.codec == 0x0001 && fmt.bytes_sec != fmt.freq*fmt.blkalign)
	{
		fprintf(stderr, "wav_parse: bytes per second is inconsistent\n");
		return NULL;
	}
	if(fmt.blkalign == 0)
	{
		fprintf(stderr, "wav_parse: invalid block alignment\n");
		return NULL;
	}

	// now attempt to load data
	uint32_t last_chunk_len = 0;
	char *next_chunk = buf + 20 + fmtlen;

	while (1) {
		// Check there's enough data for the chunk header
		if (next_chunk + 8 > end || next_chunk + 8 < buf) {
			fprintf(stderr, "wav_parse: file too short\n");
			return NULL;
		}

		// Check if chunk is one we want
		if (!memcmp(next_chunk, "data", 4)) {
			break;
		}

		// Skip unwanted chunk
		printf("wav_parse: skipping \"%.4s\" chunk\n", next_chunk);
		last_chunk_len = (*(uint32_t *)(next_chunk + 4)) + 8;
		next_chunk += last_chunk_len;
	}

	uint32_t datalen = *(uint32_t *)(next_chunk + 4);
	void *data_void = next_chunk + 8;
	if(data_void + datalen > end || data_void + datalen < buf)
	{
		fprintf(stderr, "wav_parse: file too short for \"data\" section\n");
		return NULL;
	}

	if((datalen % fmt.blkalign) != 0)
	{
		fprintf(stderr, "wav_parse: data not block-aligned\n");
		return NULL;
	}

	uint32_t datalen_smps = datalen/fmt.blkalign;
	if(fmt.codec == 0x0011)
	{
		// Technically you're supposed to use the fact chunk
		datalen_smps *= (fmt.blkalign-4)*2;
	}

	wav_t *wav = (wav_t*)malloc(sizeof(wav_t) + sizeof(((wav_t*)0)->data[0]) * datalen_smps);

	if (wav == NULL)
	{
		fprintf(stderr, "wav_parse: malloc failed - weird file or out of memory\n");
		return NULL;
	}

	wav->udtype = UD_WAV;
	wav->refcount = 1;
	wav->len = datalen_smps;
	wav->freq = fmt.freq;

	if(fmt.codec == 0x0011 && fmt.bps == 4)
	{
		int16_t *wptr1 = wav->data;
		int lpred, lstep;
		uint8_t *dbase2 = (uint8_t *)data_void;
		uint8_t **dbase = &dbase2;
		uint8_t *dbend = dbase2 + datalen;

		for(i = 0; i < len/fmt.blkalign; i++)
		{
			// Feed predictors
			if(((*dbase)+4) > dbend)
			{
				fprintf(stderr, "adpcm_load_block: block ended too early!\n");
				free(wav);
				return NULL;
			}

			lpred = (*dbase)[1];
			lpred <<= 8;
			lpred |= (*dbase)[0];
			lstep = (*dbase)[2];
			(*dbase) += 4;

			if(lpred >= 0x8000) lpred -= 0x10000;

			//printf("pred %i %i\n", lpred, lstep);

			// Actually predict things
			for(j = 0; j < (fmt.blkalign/(4*fmt.chns))-1; j++) {
				if (adpcm_load_block(&wptr1, &lpred, &lstep, dbase, dbend)) {
					free(wav);
					return NULL;
				}
			}

		}

	} else if(fmt.bps == 8) {
		int16_t *d = wav->data;
		uint8_t *s = (uint8_t *)data_void;

		if (s + datalen_smps > (uint8_t *)end) {
			fprintf(stderr, "wav_parse: file too short\n");
			free(wav);
			return NULL;
		}

		for(i = 0; i < datalen_smps; i++)
			*(d++) = (((int16_t)(*s++))-0x80)<<8;
	} else if(fmt.bps == 16) {
		uint32_t size = datalen_smps * 2;
		if (data_void + size > end) {
			fprintf(stderr, "wav_parse: file too short\n");
			free(wav);
			return NULL;
		}

		memcpy(wav->data, data_void, size);
	} else {
		fprintf(stderr, "wav_parse: Unknown codec/bps\n");
		free(wav);
		return NULL;
	}

	return wav;
}

wav_t *wav_load(const char *fname)
{
	int flen;
	char *buf = net_fetch_file(fname, &flen);
	if(buf == NULL)
		return NULL;
	wav_t *ret = wav_parse(buf, flen);
	free(buf);
	return ret;
}

#ifndef DEDI
void wav_chn_kill(wavchn_t *chn)
{
	wav_kill(chn->src);
	chn->src = NULL;
	chn->flags = 0;
}

wavchn_t *wav_chn_alloc(int flags, wav_t *wav, float x, float y, float z, float vol, float freq_mod, float vol_spread)
{
	int i;

	for(i = 0; i < WAV_CHN_COUNT+1; i++)
	{
		if(!(wchn[wav_wctr & (WAV_CHN_COUNT-1)].flags & WCF_ACTIVE))
			break;
		wav_wctr++;
	}

	wavchn_t *wc = &wchn[wav_wctr & (WAV_CHN_COUNT-1)];

	if(wc->flags & WCF_ACTIVE)
		wav_chn_kill(wc);

	wc->idx = wav_wctr;
	wav_wctr++;

	wc->flags = flags;
	wc->src = wav;
	wav->refcount++;
	wc->x = x;
	wc->y = y;
	wc->z = z;
	wc->vol = vol;
	wc->freq_mod = freq_mod;
	wc->vol_spread = vol_spread;

	for(i = 0; i < WAV_MAX_OUTPUTS; i++)
	{
		wc->offs[i] = 0.0f;
		wc->ldelay[i] = 0.0f;
	}

	return wc;
}

void wav_callback_sdl(void *userdata, Uint8 *stream, int len)
{
	if(wav_fn_mixer == NULL)
		return;

	wav_fn_mixer((void *)stream, len);
}
#endif

void wav_kill(wav_t *wav)
{
	if(wav != NULL)
	{
		wav->refcount--;
		if(wav->refcount == 0)
			free(wav);
	}
}

int wav_gc_lua(lua_State *L)
{
	wav_t **wav_ud = (wav_t **)lua_touserdata(L, 1);
	wav_t *wav = *wav_ud;
	if(wav != NULL)
	{
#ifdef ALLOW_EXPLICIT_FREE
		printf("Freeing wav @ %p\n", wav);
#endif
		wav_kill(wav);
	}

	return 0;
}

void wav_gc_set(lua_State *L)
{
	lua_newtable(L);
	lua_pushcfunction(L, wav_gc_lua);
	lua_setfield(L, -2, "__gc");
	lua_setmetatable(L, -2);
}

#ifndef DEDI
int wav_init(void)
{
	int i;

	for(i = 0; i < WAV_CHN_COUNT; i++)
	{
		wchn[i].src = NULL;
		wchn[i].flags = 0;
	}

	SDL_AudioSpec aspec;
	aspec.freq = wav_mfreq;
	aspec.format = AUDIO_S16SYS;
	aspec.channels = 2;
	aspec.samples = wav_bufsize;
	aspec.userdata = NULL;
	aspec.callback = wav_callback_sdl;
	if(SDL_OpenAudio(&aspec, NULL))
	{
		error_sdl("wav_init(nonfatal)");
		return 0;
	}

	icesackit_freq = wav_bufsize;

	wav_fn_mixer = wav_fn_mixer_s16he_stereo;
	SDL_PauseAudio(0);

	return 0;
}

void wav_deinit(void)
{
	int i;

	for(i = 0; i < WAV_CHN_COUNT; i++)
		wav_chn_kill(&wchn[i]);

	if(icesackit_pb != NULL)
		sackit_playback_free(icesackit_pb);

	icesackit_pb = NULL;
	icesackit_freq = 0;

	// TODO: disable sound
}
#endif
