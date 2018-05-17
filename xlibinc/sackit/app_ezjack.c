#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <errno.h>

#include "sackit.h"

#include "ezjack.h"

int main(int argc, char *argv[])
{
#ifdef STATIC_FNAME
	it_module_t *module = sackit_module_load(STATIC_FNAME);
#else
	it_module_t *module = sackit_module_load(argv[1]);
#endif
	
	if(module == NULL)
		return 1;
	
	sackit_playback_t *sackit = sackit_playback_new(module, 1024, 256, MIXER_IT214FS);

	ezjack_bundle_t *bun = ezjack_open("sackit", 0, 2, 2048, 44100.0f, 0);
	ezjack_activate(bun);
	ezjack_autoconnect(bun);

	for(;;)
	{
		sackit_playback_update(sackit);
		ezjack_write(bun, sackit->buf, sackit->buf_len*4, EZJackFormatS16Native);
	}

	ezjack_close(bun);

	sackit_playback_free(sackit);
	sackit_module_free(module);

	return 0;
}

