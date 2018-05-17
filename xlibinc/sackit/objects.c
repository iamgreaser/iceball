#include "sackit_internal.h"

it_module_t *sackit_module_new(void)
{
	int i;
	
	it_module_t *module = malloc(sizeof(it_module_t));
	
	for(i = 0; i < MAX_ORDERS; i++)
		module->orders[i] = 0xFF;
	for(i = 0; i < MAX_INSTRUMENTS; i++)
		module->instruments[i] = NULL;
	for(i = 0; i < MAX_SAMPLES; i++)
		module->samples[i] = NULL;
	for(i = 0; i < MAX_PATTERNS; i++)
		module->patterns[i] = NULL;
	
	return module;
}

void sackit_module_free(it_module_t *module)
{
	int i;

	for(i = 0; i < MAX_INSTRUMENTS; i++)
		if(module->instruments[i] != NULL)
			free(module->instruments[i]);
	for(i = 0; i < MAX_SAMPLES; i++)
		if(module->samples[i] != NULL)
		{
			if(module->samples[i]->data != NULL)
				free(module->samples[i]->data);

			free(module->samples[i]);
		}
	for(i = 0; i < MAX_PATTERNS; i++)
		if(module->patterns[i] != NULL)
			free(module->patterns[i]);
	
	free(module);
}

char sackit_file_getc(sackit_reader_t *reader)
{
	return fgetc((FILE *)reader->in);
}

size_t sackit_file_read(sackit_reader_t *reader, void *out, size_t size)
{
	return fread(out, size, 1, (FILE *)reader->in);
}

void sackit_file_seek(sackit_reader_t *reader, long offset, int mode)
{
	fseek((FILE *)reader->in, offset, mode);
}

long sackit_file_tell(sackit_reader_t *reader)
{
	return ftell((FILE *)reader->in);
}

char sackit_mem_getc(sackit_reader_t *reader)
{
	sackit_reader_data_mem_t *data = (sackit_reader_data_mem_t *)reader->in;
	if (data->pos >= data->len) return EOF;
	else return data->ptr[data->pos++];
}

size_t sackit_mem_read(sackit_reader_t *reader, void *out, size_t psize)
{
	sackit_reader_data_mem_t *data = (sackit_reader_data_mem_t *)reader->in;
	size_t size = data->len - data->pos;
	if (psize < size) size = psize;
	memcpy(out, &(data->ptr[data->pos]), size);
	data->pos += size;
	return size > 0 ? 1 : 0;
}

void sackit_mem_seek(sackit_reader_t *reader, long offset, int mode)
{
	sackit_reader_data_mem_t *data = (sackit_reader_data_mem_t *)reader->in;
	switch (mode)
	{
		case SEEK_CUR:
			data->pos += offset;
			break;
		case SEEK_SET:
			data->pos = offset;
			break;
		case SEEK_END:
			data->pos = data->len - offset;
			break;
	}

	if (data->pos < 0) data->pos = 0;
}

long sackit_mem_tell(sackit_reader_t *reader)
{
	sackit_reader_data_mem_t *data = (sackit_reader_data_mem_t *)reader->in;
	return data->pos;
}

it_module_t *sackit_module_load_offs(const char *fname, int fboffs)
{
	it_module_t *module;
	sackit_reader_t reader;

	FILE *fp = fopen(fname, "rb");
	if(fp == NULL)
	{
		perror("sackit_module_load");
		return NULL;
	}

	reader.in = (void *)fp;
	reader.getch = &sackit_file_getc;
	reader.read = &sackit_file_read;
	reader.seek = &sackit_file_seek;
	reader.tell = &sackit_file_tell;

	module = sackit_module_load_offs_internal(&reader, fboffs);

	fclose(fp);
	return module;
}

it_module_t *sackit_module_load_memory(const void *data, const long length)
{
	it_module_t *module;
	sackit_reader_t reader;
	sackit_reader_data_mem_t memdata;

	memdata.ptr = data;
	memdata.pos = 0;
	memdata.len = length;

	reader.in = &memdata;
	reader.getch = &sackit_mem_getc;
	reader.read = &sackit_mem_read;
	reader.seek = &sackit_mem_seek;
	reader.tell = &sackit_mem_tell;

	module = sackit_module_load_offs_internal(&reader, 0);

	return module;
}

it_module_t *sackit_module_load_offs_internal(sackit_reader_t *reader, int fboffs)
{
	int i, j, k;
	
	// create module
	it_module_t *module = sackit_module_new();
	
	// load header
	reader->seek(reader, fboffs, SEEK_SET);
	if(reader->read(reader, &(module->header), sizeof(it_module_header_t)) != 1)
	{
		fprintf(stderr, "sackit_module_load: could not read header\n");
		sackit_module_free(module);
		return NULL;
	}
	
	// check magic
	if(memcmp(module->header.magic, "IMPM", 4))
	{
		fprintf(stderr, "sackit_module_load: invalid magic\n");
		sackit_module_free(module);
		return NULL;
	}
	
	// sanity checks
	if(module->header.ordnum > MAX_ORDERS
		|| module->header.insnum > MAX_INSTRUMENTS
		|| module->header.smpnum > MAX_SAMPLES
		|| module->header.patnum > MAX_PATTERNS)
	{
		fprintf(stderr, "sackit_module_load: header limits exceeded\n");
		sackit_module_free(module);
		return NULL;
	}
	
	module->header.song_name[25] = 0x00;
	//printf("module name: \"%s\"\n", module->header.song_name);
	
	if(reader->read(reader, module->orders, module->header.ordnum) != 1)
	{
		fprintf(stderr, "sackit_module_load: could not read orderlist\n");
		sackit_module_free(module);
		return NULL;
	}
	
	static uint32_t offset_instruments[MAX_INSTRUMENTS];
	static uint32_t offset_samples[MAX_SAMPLES];
	static uint32_t offset_patterns[MAX_PATTERNS];
	
	if((module->header.insnum != 0 && reader->read(reader, offset_instruments, module->header.insnum*4) != 1)
		|| (module->header.smpnum != 0 && reader->read(reader, offset_samples, module->header.smpnum*4) != 1)
		|| (module->header.patnum != 0 && reader->read(reader, offset_patterns, module->header.patnum*4) != 1))
	{
		fprintf(stderr, "sackit_module_load: could not read pointers from header\n");
		sackit_module_free(module);
		return NULL;
	}
	
	// instruments
	for(i = 0; i < module->header.insnum; i++)
	{
		reader->seek(reader, fboffs + offset_instruments[i], SEEK_SET);
		module->instruments[i] = malloc(sizeof(it_instrument_t));

#ifdef _MSC_VER
		reader->read(reader, module->instruments[i], sizeof(it_instrument_t));
#else
		//reader->read(reader, module->instruments[i], sizeof(it_instrument_t));
		// XXX: work around a compiler bug in MinGW GCC 4.7.2
		reader->read(reader, module->instruments[i], (void *)(&((it_instrument_t *)0)->evol) - (void *)0);
#endif

		for(j = 0; j < 3; j++)
		{
			it_envelope_t *ev = NULL;

			switch(j)
			{
				case 0: ev = &module->instruments[i]->evol; break;
				case 1: ev = &module->instruments[i]->epan; break;
				case 2: ev = &module->instruments[i]->epitch; break;
			}

			ev->flg = reader->getch(reader);
			ev->num = reader->getch(reader);
			ev->lpb = reader->getch(reader);
			ev->lpe = reader->getch(reader);
			ev->slb = reader->getch(reader);
			ev->sle = reader->getch(reader);

			for(k = 0; k < 25; k++)
			{
				int vy = reader->getch(reader);
				int vxl = reader->getch(reader);
				int vxh = reader->getch(reader);

				ev->points[k].y = vy;
				ev->points[k].x = vxl | (vxh<<8);
			}

			reader->getch(reader);
		}
	}
	
	// samples
	for(i = 0; i < module->header.smpnum; i++)
	{
		reader->seek(reader, fboffs + offset_samples[i], SEEK_SET);
		it_sample_t *smp = malloc(sizeof(it_sample_t));
		module->samples[i] = smp;
		reader->read(reader, smp, sizeof(it_sample_t)-sizeof(int16_t *));
		
		smp->data = NULL;
		if(smp->samplepointer != 0 && smp->length != 0 && (smp->flg & IT_SMP_EXISTS))
		{
			// NO WE ARE NOT SUPPORTING STEREO SAMPLES PISS OFF MODPLUG
			reader->seek(reader, fboffs + smp->samplepointer, SEEK_SET);
			smp->data = malloc(smp->length*sizeof(int16_t));
			
			// check compression flag
			if(smp->flg & IT_SMP_COMPRESS)
			{
				// worst case scenario
				static uint8_t buf[65538];
				
				// calc some things
				int blkunlen = (smp->flg & IT_SMP_16BIT
					? 0x4000
					: 0x8000);
				int blkbasewidth = (smp->flg & IT_SMP_16BIT
					? 17
					: 9);
				int blkbaseshift = (smp->flg & IT_SMP_16BIT
					? 0
					: 8);
				int blkbasebits = (smp->flg & IT_SMP_16BIT
					? 4
					: 3);
				
				int offs;
				for(offs = 0; offs < (int)smp->length; offs += blkunlen)
				{
					// clear block
					for(j = 0; j < blkunlen && j+offs < (int)smp->length; j++)
						smp->data[j+offs] = 0;
					
					// get length
					reader->read(reader, buf, 2);
					int blklen = buf[0]|(buf[1]<<8);
					
					// get block
					reader->read(reader, buf, blklen);
					
					//printf("block = %i bytes\n", blklen);
					
					// decompress
					int boffs = 0;
					int dw = blkbasewidth;
					for(j = 0; j < blkunlen && j+offs < (int)smp->length && boffs < (blklen<<3); j++)
					{
						//printf("%08X %i %i\n", offs, j, dw);
						int bbigoffs, bsuboffs;
						bbigoffs = (boffs>>3);
						bsuboffs = (boffs&7);
						
						// read value
						int v = buf[bbigoffs]
							|(buf[bbigoffs+1]<<8)
							|(buf[bbigoffs+2]<<16);
						v >>= bsuboffs;
						v &= (1<<dw)-1;
						if((v&(1<<(dw-1))) != 0)
							v |= ~((1<<dw)-1);
						
						//printf("QERR %i %05X\n", v, v&0xFFFFF);
						// advance
						boffs += dw;
						
						// now, based on dw...
						if(dw <= 6)
						{
							// type A: 1 through 6 bits
							
							// is this 100...00?
							if(v == ~((1<<(dw-1))-1))
							{
								// read next 3/4 bits
								bbigoffs = (boffs>>3);
								bsuboffs = (boffs&7);
								v = buf[bbigoffs]
									|(buf[bbigoffs+1]<<8);
								v >>= bsuboffs;
								v &= (1<<blkbasebits)-1;
								boffs += blkbasebits;
								
								// calculate new bit width
								v++;
								if(v >= dw)
									v++;
								
								// change bit width
								dw = v;
								j--;
								continue;
							}
						} else if(dw == blkbasewidth) {
							//printf("TYPE C\n");
							// type C: bps+1 bits
							// is the top bit set?
							if(v & (1<<(dw-1)))
							{
								// use the bottom 8 bits
								// TODO: confirm this is what happens
								dw = v&255;
								dw++;
								
								// is this out of range?
								if(dw > blkbasewidth || dw == 0)
								{
									// bail out
									fprintf(stderr,
										"IT214 block error [%08X/%08X/%i]: invalid width %i\n"
										, reader->tell(reader) - blklen - 2
										, reader->tell(reader) - blklen + (boffs>>3)
										, j
										, dw);
									break;
								}
								
								j--;
								continue;
							}
						} else {
							// type B: 7 through bps bits
							// is this 01...1x000 through 10...0y111?
							// ( 8bps: x=1, y=0)
							// (16bps: x=0, y=1)
							if(v >= (1<<(dw-1))-(1<<(blkbasebits-1))
								|| v <= ~((1<<(dw-1))-(1<<(blkbasebits-1))))
							{
								// steal next 3/4 bits
								v += (1<<(blkbasebits-1));
								v &= 15;
								
								// calculate new bit width
								v++;
								if(v >= dw)
									v++;
								
								// change bit width
								dw = v;
								j--;
								continue;
							}
						}
						
						// store value
						//printf("v = %i\n", v);
						smp->data[j+offs] = v<<blkbaseshift;
					}
					//printf("blk size %i end at %i\n", blklen<<3, boffs);
					
					// perform delta conversion
					for(j = 1; j < blkunlen && j+offs < (int)smp->length; j++)
						smp->data[j+offs] += smp->data[j+offs-1];
					
					// convert
					if(!(smp->cvt & 0x01))
					{
						// TODO!
					}
					
					if(smp->cvt & 0x04)
					{
						for(j = 1; j < blkunlen && j+offs < (int)smp->length; j++)
							smp->data[j+offs] += smp->data[j+offs-1];
					}
					
					// TODO: not repeat ourselves
					// TODO: other conversion flags
				}
			} else {
				// load
				if(smp->flg & IT_SMP_16BIT)
				{
					reader->read(reader, smp->data, smp->length*2);
				} else {
					for(j = 0; j < (int)smp->length; j++)
						smp->data[j] = (reader->getch(reader))<<8;
				}
				
				// convert
				if(!(smp->cvt & 0x01))
				{
					// TODO!
					for(j = 0; j < (int)smp->length; j++)
						smp->data[j] ^= 0x8000;
				}
				
				// TODO: other conversion flags
			}
		}
	}
	
	// patterns
	for(i = 0; i < module->header.patnum; i++)
	{
		reader->seek(reader, fboffs + offset_patterns[i], SEEK_SET);
		module->patterns[i] = malloc(sizeof(it_pattern_t));
		reader->read(reader, module->patterns[i], sizeof(it_pattern_t)-65536);
		reader->read(reader, 8+(uint8_t *)module->patterns[i], module->patterns[i]->length);
	}

	return module;
}

void sackit_playback_free(sackit_playback_t *sackit)
{
	if(sackit->buf != NULL)
		free(sackit->buf);
	if(sackit->mixbuf != NULL)
		free(sackit->mixbuf);

	free(sackit);
}

void sackit_playback_reset_env(sackit_envelope_t *aenv, int8_t def)
{
	aenv->carry_idx = aenv->idx = 0;
	aenv->carry_x = aenv->x = 0;
	aenv->def = def;
	aenv->y = def*256;
	aenv->carry_flags = aenv->flags = 0;
}

void sackit_playback_reset_achn(sackit_achannel_t *achn)
{
	achn->note = 253;

	achn->freq = 0;
	achn->ofreq = 0;
	achn->offs = 0;
	achn->suboffs = 0;
	achn->suboffs_f = 0.0f;
	
	achn->flags = 0;
	
	achn->instrument = NULL;
	achn->sample = NULL;
	
	achn->sv = 0;
	achn->vol = 0;
	achn->fv = 0;
	achn->cv = 0;
	achn->iv = 128;
	achn->pan = 32;

	achn->anticlick[0] = 0;
	achn->anticlick[1] = 0;
	achn->anticlick_f[0] = 0.0f;
	achn->anticlick_f[1] = 0.0f;
	
	achn->svib_speed = 0;
	achn->svib_type = 0;
	achn->svib_depth = 0;
	achn->svib_rate = 0;
	achn->svib_power = 0;
	achn->svib_offs = 0;
	
	achn->lramp = 0;
	
	achn->fadeout = 1024;

	achn->filt_cut = 127;
	achn->filt_res = 0;
	achn->filt_prev[0][0] = 0.0f;
	achn->filt_prev[0][1] = 0.0f;
	achn->filt_prev[1][0] = 0.0f;
	achn->filt_prev[1][1] = 0.0f;
	
	achn->next = achn->prev = NULL;
	achn->parent = NULL;
	
	sackit_playback_reset_env(&(achn->evol), 64);
	sackit_playback_reset_env(&(achn->epan), 0);
	sackit_playback_reset_env(&(achn->epitch), 0);
}

void sackit_playback_reset_pchn(sackit_pchannel_t *pchn)
{
	pchn->achn = NULL;
	pchn->bg_achn = NULL;
	pchn->tfreq = 0;
	pchn->nfreq = 0;
	pchn->freq = 0;
	pchn->note = 253;
	pchn->lins = 0;
	
	pchn->cv = 64;
	pchn->vol = 0;
	pchn->pan = 32;
	
	pchn->slide_vol = 0;
	pchn->slide_vol_cv = 0;
	pchn->slide_vol_gv = 0;
	pchn->slide_pan = 0;
	pchn->slide_pitch = 0;
	pchn->slide_porta = 0;
	pchn->arpeggio = 0;
	pchn->note_cut = 0;
	pchn->note_delay = 0;
	pchn->vib_speed = 0;
	pchn->vib_depth = 0;
	pchn->vib_offs = 0;
	pchn->vib_type = 0;
	pchn->vib_lins = 0;
	pchn->tre_speed = 0;
	pchn->tre_depth = 0;
	pchn->tre_offs = 0;
	pchn->tre_type = 0;
	pchn->trm_val = 0;
	pchn->trm_flags = 0;
	pchn->trm_cur_on = 0;
	pchn->trm_cur_off = 0;
	pchn->rtg_val = 0;
	pchn->rtg_flags = 0;
	pchn->rtg_counter = 0;
	
	pchn->loop_start = 0;
	pchn->loop_times = 0;
	
	pchn->nna = 0;
	
	pchn->eff_slide_vol = 0;
	pchn->eff_slide_vol_cv = 0;
	pchn->eff_slide_vol_gv = 0;
	pchn->eff_slide_vol_veff = 0;
	pchn->eff_slide_pitch = 0;
	pchn->eff_slide_porta = 0;
	pchn->eff_sample_offs = 0;
	pchn->eff_misc = 0;
	pchn->eff_arpeggio = 0;
	pchn->eff_vibrato = 0;
	pchn->eff_tremolo = 0;
	pchn->eff_tempo = 0;
	pchn->eff_tremor = 0x11;
	pchn->eff_retrig = 0x00;

	pchn->filt_cut = 127;
	pchn->filt_res = 0;
	
	pchn->instrument = NULL;
	pchn->sample = NULL;
}

void sackit_playback_reset2(sackit_playback_t *sackit, int buf_len, int achn_count,
	void (*f_mix)(sackit_playback_t *sackit, int offs, int len), int mixer_bytes, int freq)
{
	int i;
	
	sackit->current_tick = 1;
	sackit->max_tick = sackit->module->header.is;
	sackit->row_counter = 1;
	sackit->tempo_inc = 0;
	
	sackit->current_row = 0xFFFE;
	sackit->process_row = 0xFFFE;
	sackit->break_row = 0;
	sackit->number_of_rows = 64;
	
	sackit->current_pattern = 0;
	sackit->process_order = -1;
	
	sackit->pat_ptr = 0;
	sackit->pat_row = 0;
	
	sackit->gv = sackit->module->header.gv;
	sackit->mv = sackit->module->header.mv;
	sackit->anticlick[0] = 0;
	sackit->anticlick[1] = 0;
	sackit->anticlick_f[0] = 0.0f;
	sackit->anticlick_f[1] = 0.0f;
	
	sackit->tempo = sackit->module->header.it;
	
	sackit->achn_count = achn_count;
	sackit->f_mix = f_mix;
	sackit->mixer_bytes = mixer_bytes;
	sackit->freq = freq;
	sackit->buf_len = buf_len;
	sackit->buf_tick_rem = 0;
	//printf("%i\n", buf_len);
	sackit->buf = malloc(sizeof(int16_t)*mixer_bytes*sackit->buf_len);
	sackit->mixbuf = malloc(sizeof(int32_t)*mixer_bytes*sackit->buf_len);
	
	for(i = 0; i < SACKIT_MAX_ACHANNEL; i++)
		sackit_playback_reset_achn(&(sackit->achn[i]));
	for(i = 0; i < 64; i++)
	{
		sackit_playback_reset_pchn(&(sackit->pchn[i]));
		
		/*sackit->pchn[i].achn = &(sackit->achn[i]);
		sackit->pchn[i].achn->parent = &(sackit->pchn[i]);*/
		
		sackit->pchn[i].cv = sackit->module->header.chnl_vol[i];
		sackit->pchn[i].pan = sackit->module->header.chnl_pan[i];
	}
}

void sackit_playback_reset(sackit_playback_t *sackit, int buf_len, int achn_count, int mixeridx)
{
	// deprecated function
	sackit_playback_reset2(sackit, buf_len, achn_count,
		fnlist_itmixer[mixeridx], itmixer_bytes[mixeridx], 44100);

}

sackit_playback_t *sackit_playback_new2(it_module_t *module, int buf_len, int achn_count,
	void (*f_mix)(sackit_playback_t *sackit, int offs, int len), int mixer_bytes, int freq)
{
	// allocate
	sackit_playback_t *sackit = malloc(sizeof(sackit_playback_t));
	sackit->module = module;
	sackit_playback_reset2(sackit, buf_len, achn_count, f_mix, mixer_bytes, freq);
	
	return sackit;
}
sackit_playback_t *sackit_playback_new(it_module_t *module, int buf_len, int achn_count, int mixeridx)
{
	// deprecated function
	return sackit_playback_new2(module, buf_len, achn_count,
		fnlist_itmixer[mixeridx], itmixer_bytes[mixeridx], 44100);
}

it_module_t *sackit_module_load(const char *fname)
{
	return sackit_module_load_offs(fname, 0);
}

