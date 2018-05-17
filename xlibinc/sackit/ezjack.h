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

#ifndef _EZJACK_H_
#define _EZJACK_H_
#include <jack/jack.h>
#include <jack/ringbuffer.h>

typedef enum EZJackFormats
{
	EZJackFormatFloat32Native,
	EZJackFormatFloat32LE,
	EZJackFormatFloat32BE,

	EZJackFormatU8,
	EZJackFormatS8,

	EZJackFormatS16Native,
	EZJackFormatS16LE,
	EZJackFormatS16BE,

	EZJackFormatU16Native,
	EZJackFormatU16LE,
	EZJackFormatU16BE,
} ezjack_format_t;

typedef enum EZJackPortFlags
{
	// Nothing here yet.
	ThisOnlyExistsBecauseCDoesntLikeAnEmptyEnum,
} ezjack_portflags_t;

#define EZJACK_PORTSTACK_MAX 32
#define EZJACK_RB_SIZE ((1<<17)*sizeof(float))
typedef struct EZJackPortStack
{
	int incount, outcount;
	jack_port_t *in[EZJACK_PORTSTACK_MAX];
	jack_port_t *out[EZJACK_PORTSTACK_MAX];
	jack_ringbuffer_t *inrb[EZJACK_PORTSTACK_MAX];
	jack_ringbuffer_t *outrb[EZJACK_PORTSTACK_MAX];

	// leave this section alone
	float *inbuf[EZJACK_PORTSTACK_MAX];
	float *outbuf[EZJACK_PORTSTACK_MAX];
} ezjack_portstack_t;

typedef struct EZJackBundle
{
	jack_client_t *client;
	ezjack_portstack_t portstack;
	int bufsize;
	float freq;

	// leave this section alone
	float *fbuf;
	int fbuflen;
} ezjack_bundle_t;

typedef int (*EZJackCallback)(int nframes_in, int nframes_out, ezjack_bundle_t *bun);

jack_status_t ezjack_get_error(void);

ezjack_bundle_t *ezjack_open(const char *client_name, int inputs, int outputs, int bufsize, float freq, ezjack_portflags_t flags);
int ezjack_autoconnect(ezjack_bundle_t *bun);
void ezjack_close(ezjack_bundle_t *bun);
int ezjack_activate(ezjack_bundle_t *bun);
int ezjack_deactivate(ezjack_bundle_t *bun);
int ezjack_set_callback(EZJackCallback cb);
int ezjack_read(ezjack_bundle_t *bun, void *buf, int len, ezjack_format_t fmt);
int ezjack_write(ezjack_bundle_t *bun, void *buf, int len, ezjack_format_t fmt);

#endif /* ifndef _EZJACK_H_ */

