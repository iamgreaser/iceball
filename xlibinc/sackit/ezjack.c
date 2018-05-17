/*
EZJACK: a simple wrapper for JACK to make stuff a bit easier
Copyright (c) Ben "GreaseMonkey" Russell, 2014.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <errno.h>

#include <unistd.h> /* usleep(3) */

#include <jack/jack.h>
#include <jack/ringbuffer.h>

#include "ezjack.h"

static volatile jack_status_t lasterr = 0;
static volatile EZJackCallback maincb = NULL;

static int _helper_get_fmt_size(ezjack_format_t fmt)
{
	switch(fmt)
	{
		case EZJackFormatFloat32Native:
		case EZJackFormatFloat32LE:
		case EZJackFormatFloat32BE:
			return 4;

		case EZJackFormatU8:
		case EZJackFormatS8:
			return 1;

		case EZJackFormatS16Native:
		case EZJackFormatS16LE:
		case EZJackFormatS16BE:
		case EZJackFormatU16Native:
		case EZJackFormatU16LE:
		case EZJackFormatU16BE:
			return 2;
	}

	return 0; // invalid
}

jack_status_t ezjack_get_error(void)
{
	// FIXME: possibly not thread-safe!
	jack_status_t ret = lasterr;
	lasterr = 0;
	return ret;
}

int ezjack_set_callback(EZJackCallback cb)
{
	maincb = cb;
	return 0;
}

int ezjack_default_callback(jack_nframes_t nframes, void *arg)
{
	int i, j;
	int ret = 0;
	ezjack_bundle_t *bun = (ezjack_bundle_t *)arg;

	// Sample rate
	float sfreq = jack_get_sample_rate(bun->client);

	float convgrad = (bun->freq/sfreq) - 0.00001f;
	int convsize = nframes * convgrad;

	if(bun->fbuflen != convsize)
	{
		bun->fbuflen = convsize;
		bun->fbuf = realloc(bun->fbuf, convsize*sizeof(float));
	}

#define HELPER_CALLBACK_GETSPACE(varname, vardef, foorb, foocount, jack_ringbuffer_foo_space) \
	int varname = sizeof(float) * (vardef); \
	for(i = 0; i < bun->portstack.foocount; i++) \
	{ \
		int cspace = (int)jack_ringbuffer_foo_space(bun->portstack.foorb[i]); \
 \
		if(cspace < varname) \
			varname = cspace; \
	} \

	// Get space for writing to input ringbuffer
	//HELPER_CALLBACK_GETSPACE(minreadspace, bun->bufsize, inrb, incount, jack_ringbuffer_write_space);

	// Inputs
	for(i = 0; i < bun->portstack.incount; i++)
	{
		jack_port_t *p = bun->portstack.in[i];
		jack_ringbuffer_t *rb = bun->portstack.inrb[i];
		float *buf = jack_port_get_buffer(p, nframes);

		// TODO: support other interpolations
		int k = 0;
		for(j = 0; j < nframes; j++)
			for(; k < (j+1)*convgrad; k++)
				bun->fbuf[k] = buf[j];

		// An overrun can happen - in this case, it's the app's fault
		jack_ringbuffer_write(rb, (char *)(bun->fbuf), convsize*sizeof(float));
	}

	// Get space for writing to output ringbuffer
	HELPER_CALLBACK_GETSPACE(minwriteoutspace, bun->bufsize, outrb, outcount, jack_ringbuffer_write_space);

	// Get space for reading from input ringbuffer
	HELPER_CALLBACK_GETSPACE(minreadinspace, bun->bufsize, inrb, incount, jack_ringbuffer_read_space);

	// Call our callback
	EZJackCallback cb = maincb;
	if(cb != NULL)
		// TODO: input
		ret = cb(minreadinspace/sizeof(float), minwriteoutspace/sizeof(float), bun);

	// Get space for reading from output ringbuffer
	HELPER_CALLBACK_GETSPACE(minoutspace, convsize, outrb, outcount, jack_ringbuffer_read_space);

	// Outputs
	for(i = 0; i < bun->portstack.outcount; i++)
	{
		jack_port_t *p = bun->portstack.out[i];
		jack_ringbuffer_t *rb = bun->portstack.outrb[i];
		float *buf = jack_port_get_buffer(p, nframes);

		jack_ringbuffer_read(rb, (char *)(bun->fbuf), minoutspace);
		
		// TODO: support other interpolations
		for(j = 0; j < nframes; j++)
			buf[j] = bun->fbuf[(int)(j*convgrad)];
	}

	return ret;
}

ezjack_bundle_t *ezjack_open(const char *client_name, int inputs, int outputs, int bufsize, float freq, ezjack_portflags_t flags)
{
	int i;
	ezjack_bundle_t bun;
	char namebuf[16];

	// Open client
	jack_status_t temperr = lasterr;
	bun.client = jack_client_open(client_name, JackNoStartServer, &temperr);
	lasterr = temperr;

	if(bun.client == NULL)
		return NULL;
	
	bun.freq = freq;
	bun.bufsize = bufsize;
	bun.fbuflen = 0;
	bun.fbuf = NULL;
	
	// Create some ports
	bun.portstack.incount = 0;
	bun.portstack.outcount = 0;

#define HELPER_OPEN_PORTS(foo, fooputs, foocount, foorb, foobuf, foofmt, flags) \
	for(i = 0; i < fooputs; i++) \
	{ \
		snprintf(namebuf, 16, foofmt, i+1); \
		bun.portstack.foo[i] = jack_port_register(bun.client, namebuf, JACK_DEFAULT_AUDIO_TYPE, flags, bufsize); \
		if(bun.portstack.foo[i] == NULL) \
		{ \
			lasterr = JackFailure; \
			jack_client_close(bun.client); \
			return NULL; \
		} \
 \
		bun.portstack.foorb[i] = jack_ringbuffer_create(bufsize*sizeof(float)); \
		bun.portstack.foobuf[i] = malloc(bufsize*sizeof(float)); \
 \
		bun.portstack.foocount++; \
	}

	HELPER_OPEN_PORTS(in, inputs, incount, inrb, inbuf, "in_%i", JackPortIsInput);
	HELPER_OPEN_PORTS(out, outputs, outcount, outrb, outbuf, "out_%i", JackPortIsOutput);

#undef HELPER_OPEN_PORTS

	// Prepare our bundle
	ezjack_bundle_t *ret = malloc(sizeof(ezjack_bundle_t));
	memcpy(ret, &bun, sizeof(ezjack_bundle_t));

	// Set callback
	// FIXME: error needs to be acted upon
	jack_set_process_callback(bun.client, ezjack_default_callback, ret);

	return ret;
}

int ezjack_autoconnect(ezjack_bundle_t *bun)
{
	int i;

	// Find ports
	// If we can't find any physical ports, don't worry.
	// If a connection fails, don't worry either.
#define HELPER_FIND_PORTS(foo, foocount, foonames, foopattern, fooflags, footo, foofrom) \
	if(bun->portstack.foocount > 0) \
	{ \
		const char **foonames = jack_get_ports(bun->client, foopattern, JACK_DEFAULT_AUDIO_TYPE, fooflags|JackPortIsPhysical); \
		if(foonames != NULL) \
		{ \
			i = 0; \
			while(foonames[i] != NULL) \
			{ \
				jack_connect(bun->client, foofrom, footo); \
				i++; \
			} \
		} \
	} \

	HELPER_FIND_PORTS(in, incount, innames, ".*:capture_.*", JackPortIsOutput, jack_port_name(bun->portstack.in[i % bun->portstack.incount]), innames[i]);
	HELPER_FIND_PORTS(out, outcount, outnames, ".*:playback_.*", JackPortIsInput, outnames[i], jack_port_name(bun->portstack.out[i % bun->portstack.outcount]));

#undef HELPER_FIND_PORTS

	return 0;
}

void ezjack_close(ezjack_bundle_t *bun)
{
	int i;

	jack_deactivate(bun->client);

	for(i = 0; i < bun->portstack.incount; i++)
	{
		jack_ringbuffer_free(bun->portstack.inrb[i]);
		free(bun->portstack.inbuf[i]);
	}

	for(i = 0; i < bun->portstack.outcount; i++)
	{
		jack_ringbuffer_free(bun->portstack.outrb[i]);
		free(bun->portstack.outbuf[i]);
	}

	if(bun->fbuf != NULL)
		free(bun->fbuf);

	jack_client_close(bun->client);

	free(bun);
}

int ezjack_activate(ezjack_bundle_t *bun)
{
	return jack_activate(bun->client);
}

int ezjack_deactivate(ezjack_bundle_t *bun)
{
	return jack_deactivate(bun->client);
}

int ezjack_read(ezjack_bundle_t *bun, void *buf, int len, ezjack_format_t fmt)
{
	int i, j;

	int fmtsize = _helper_get_fmt_size(fmt); // FIXME: handle erroneous format
	int blockalign = bun->portstack.incount * fmtsize;
	if(len % blockalign != 0) abort(); // FIXME: do this more gracefully
	int reqlen = len/blockalign;

	while(reqlen > 0)
	{
		int minspace = reqlen * sizeof(float);

		// Get smallest space count
		for(i = 0; i < bun->portstack.incount; i++)
		{
			int cspace = (int)jack_ringbuffer_read_space(bun->portstack.inrb[i]);

			if(cspace < minspace)
				minspace = cspace;
		}

		minspace /= sizeof(float);
		//fprintf(stderr, "minspace %i\n", minspace);

		// Read from ring buffers
		if(minspace > 0)
		{
			// Fetch data
			for(i = 0; i < bun->portstack.incount; i++)
			{
				// FIXME: handle the case where this returns something wrong
				jack_ringbuffer_read(bun->portstack.inrb[i], (char *)(bun->portstack.inbuf[i]), minspace*sizeof(float));
			}

			// Read from temporaries
			// FIXME: handle all formats
#define HELPER_READ_FORMAT(typ, low, high, wrap) \
			for(j = 0; j < minspace; j++) \
				for(i = 0; i < bun->portstack.incount; i++) \
				{ \
					float v = (bun->portstack.inbuf[i][j]); \
 \
					*(typ *)buf = (v <= -1.0f ? low : \
						(v >= 1.0f ? high : (typ)(wrap)) \
							); \
 \
					buf += sizeof(typ); \
				} \

			switch(fmt)
			{
				case EZJackFormatFloat32LE:
				case EZJackFormatFloat32Native:
					HELPER_READ_FORMAT(float, -1.0f, 1.0f, v);
					break;

				case EZJackFormatU8:
					HELPER_READ_FORMAT(uint8_t, 0, 255, (v+1.0f)*127.0f);
					break;

				case EZJackFormatS8:
					HELPER_READ_FORMAT(int8_t, -128, 127, v*127.0f);
					break;

				case EZJackFormatS16Native:
				case EZJackFormatS16LE:
					HELPER_READ_FORMAT(uint16_t, -32768, 32767, v*32767.0f);
					break;

				case EZJackFormatU16Native:
				case EZJackFormatU16LE:
					HELPER_READ_FORMAT(int16_t, 0, 65535, (v+1.0f)*32767.0f);
					break;

			}

#undef HELPER_READ_FORMAT

			reqlen -= minspace;
		}

		// Sleep a bit.
		// TODO: use a notify system
		usleep(1000);
	}

	return len;
}

// TODO: nonblocking version
int ezjack_write(ezjack_bundle_t *bun, void *buf, int len, ezjack_format_t fmt)
{
	int i, j;

	int fmtsize = _helper_get_fmt_size(fmt); // FIXME: handle erroneous format
	int blockalign = bun->portstack.outcount * fmtsize;
	if(len % blockalign != 0) abort(); // FIXME: do this more gracefully
	int reqlen = len/blockalign;

	while(reqlen > 0)
	{
		int minspace = reqlen * sizeof(float);

		// Get smallest space count
		for(i = 0; i < bun->portstack.outcount; i++)
		{
			int cspace = (int)jack_ringbuffer_write_space(bun->portstack.outrb[i]);

			if(cspace < minspace)
				minspace = cspace;
		}

		minspace /= sizeof(float);

		// Write to ring buffers
		if(minspace > 0)
		{
			// Write to temporaries
			// FIXME: handle all formats
#define HELPER_WRITE_FORMAT(inc, wrap) \
			for(j = 0; j < minspace; j++) \
				for(i = 0; i < bun->portstack.outcount; i++) \
				{ \
					bun->portstack.outbuf[i][j] = wrap; \
					buf += inc; \
				} \

			switch(fmt)
			{
				case EZJackFormatFloat32LE:
				case EZJackFormatFloat32Native:
					HELPER_WRITE_FORMAT(sizeof(float), *(float *)buf);
					break;

				case EZJackFormatU8:
					HELPER_WRITE_FORMAT(1, ((float)*(uint8_t *)buf)/128.0f-1.0f);
					break;

				case EZJackFormatS8:
					HELPER_WRITE_FORMAT(1, ((float)*(int8_t *)buf)/128.0f);
					break;

				case EZJackFormatS16Native:
				case EZJackFormatS16LE:
					HELPER_WRITE_FORMAT(2, ((float)*(int16_t *)buf)/32768.0f);
					break;

				case EZJackFormatU16Native:
				case EZJackFormatU16LE:
					HELPER_WRITE_FORMAT(2, ((float)*(uint16_t *)buf)/32768.0f-1.0f);
					break;

			}

#undef HELPER_WRITE_FORMAT

			// Commit data
			for(i = 0; i < bun->portstack.outcount; i++)
			{
				// FIXME: handle the case where this returns something wrong
				jack_ringbuffer_write(bun->portstack.outrb[i], (char *)(bun->portstack.outbuf[i]), minspace*sizeof(float));
			}

			reqlen -= minspace;
		}

		// Sleep a bit.
		// TODO: use a notify system
		usleep(1000);
	}

	return len;
}


