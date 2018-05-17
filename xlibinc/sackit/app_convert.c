#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <errno.h>

#include "sackit.h"

int main(int argc, char *argv[])
{
	int x,y,i;
	
	int maxlen = atoi(argv[3]);

	FILE *fp = fopen(argv[2], "wb");
	
	if(fp == NULL)
		return 1;

	it_module_t *module = sackit_module_load(argv[1]);
	
	if(module == NULL)
		return 1;
	
	sackit_playback_t *sackit = sackit_playback_new(module, 44100, 256, MIXER_IT214FS);

	for(i = 0; i < maxlen; i++)
	{
		sackit_playback_update(sackit);
		fwrite(sackit->buf, 44100*4, 1, fp);
	}

	fclose(fp);

	//
	sackit_playback_free(sackit);
	sackit_module_free(module);

	return 0;
}

