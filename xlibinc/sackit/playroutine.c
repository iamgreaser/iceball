#include "sackit_internal.h"

void (*(fnlist_itmixer[]))(sackit_playback_t *sackit, int offs, int len) = {
	sackit_playback_mixstuff_it211,
	sackit_playback_mixstuff_it211s,
	sackit_playback_mixstuff_it211l,
	sackit_playback_mixstuff_it211ls,
	sackit_playback_mixstuff_it212,
	sackit_playback_mixstuff_it212s,
	sackit_playback_mixstuff_it212l,
	sackit_playback_mixstuff_it212ls,
	sackit_playback_mixstuff_it214,
	sackit_playback_mixstuff_it214s,
	sackit_playback_mixstuff_it214l,
	sackit_playback_mixstuff_it214ls,
	sackit_playback_mixstuff_it214c,
	sackit_playback_mixstuff_it214cs,
	sackit_playback_mixstuff_it214f,
	sackit_playback_mixstuff_it214fs,
	sackit_playback_mixstuff_it214fl,
	sackit_playback_mixstuff_it214fls,
	sackit_playback_mixstuff_it214fc,
	sackit_playback_mixstuff_it214fcs,
	sackit_playback_mixstuff_intfast_a,
	sackit_playback_mixstuff_intfast_as,
};

int itmixer_bytes[] = { 2, 4, 2, 4, 2, 4, 2, 4, 2, 4, 2, 4, 2, 4, 2, 4, 2, 4, 2, 4, 2, 4 };

void sackit_update_effects(sackit_playback_t *sackit)
{
	int i;
	
	sackit->tempo += sackit->tempo_inc;
	if(sackit->tempo < 32)
		sackit->tempo = 32;
	if(sackit->tempo > 255)
		sackit->tempo = 255;
	
	for(i = 0; i < 64; i++)
	{
		sackit_pchannel_t *pchn = &(sackit->pchn[i]);
		
		sackit_effect_volslide_cv(sackit, pchn, pchn->slide_vol_cv);
		sackit_effect_volslide_gv(sackit, pchn, pchn->slide_vol_gv);
		sackit_effect_volslide(sackit, pchn, pchn->slide_vol);
		sackit_effect_retrig(sackit, pchn, 0);
		
		// TODO: confirm order
		sackit_effect_pitchslide(sackit, pchn, pchn->slide_pitch);
		sackit_effect_portaslide(sackit, pchn, pchn->slide_porta);
		
		if(pchn->achn != NULL)
			pchn->achn->ofreq = pchn->achn->freq;
		
		sackit_effect_vibrato(sackit, pchn);
		sackit_effect_tremolo(sackit, pchn);
		
		uint16_t arp = (pchn->arpeggio>>4)&15;
		if(arp != 0)
		{
			uint32_t arpmul = (uint32_t)pitch_table[(arp+60)*2+1];
			arpmul <<= 16;
			arpmul += (uint32_t)pitch_table[(arp+60)*2];
			if(pchn->achn != NULL)
				pchn->achn->ofreq = sackit_mul_fixed_16_int_32(arpmul, pchn->achn->ofreq);
		}
		
		pchn->arpeggio = ((pchn->arpeggio<<4)&0xFFF)|((pchn->arpeggio>>8)&15);
		
		sackit_effect_tremor(sackit, pchn);
		
		if(pchn->note_cut != 0)
		{
			pchn->note_cut--;
			if(pchn->note_cut == 0)
				sackit_nna_note_cut(sackit, pchn->achn);
		}
		
		if(pchn->note_delay != 0)
		{
			pchn->note_delay--;
			if(pchn->note_delay == 0)
			{
				sackit_update_effects_chn(sackit, pchn
					,pchn->note_delay_note
					,pchn->note_delay_ins
					,pchn->note_delay_vol
					,0,0);
				pchn->note_delay = sackit->max_tick;
			}
		}
	}
}

void sackit_update_pattern(sackit_playback_t *sackit)
{
	int i;
	
	it_pattern_t *pat = sackit->module->patterns[sackit->current_pattern];
	int ptr = sackit->pat_ptr;
	uint8_t *data = (pat == NULL ? NULL : pat->data);
	
	if(sackit->pat_row > sackit->process_row)
	{
		sackit->pat_row = 0;
		ptr = 0;
	}
	
	uint8_t note[64], ins[64], vol[64], eft[64], efp[64];
	
	for(i = 0; i < 64; i++)
	{
		note[i] = 253;
		ins[i] = 0;
		vol[i] = 255;
		eft[i] = 0;
		efp[i] = 0;
	}
	
	//printf("pat_row %i %i\n", sackit->pat_row, sackit->process_row);
	
	while(sackit->pat_row <= sackit->process_row)
	{
		while(data != NULL && data[ptr] != 0x00)
		{
			uint8_t cval = data[ptr++];
			uint8_t chn = ((cval-1)&0x3F);
			sackit_pchannel_t *pchn = &(sackit->pchn[chn]);
			
			if(cval&0x80)
				pchn->lmask = data[ptr++];
			
			if(pchn->lmask&0x01)
				pchn->ldata[0] = data[ptr++];
			if(pchn->lmask&0x02)
				pchn->ldata[1] = data[ptr++];
			if(pchn->lmask&0x04)
				pchn->ldata[2] = data[ptr++];
			if(pchn->lmask&0x08)
			{
				pchn->ldata[3] = data[ptr++];
				pchn->ldata[4] = data[ptr++];
			}
			
			if(sackit->pat_row == sackit->process_row)
			{
				if(pchn->lmask&0x11)
					note[chn] = pchn->ldata[0];
				if(pchn->lmask&0x22)
					ins[chn] = pchn->ldata[1];
				if(pchn->lmask&0x44)
					vol[chn] = pchn->ldata[2];
				if(pchn->lmask&0x88)
				{
					eft[chn] = pchn->ldata[3];
					efp[chn] = pchn->ldata[4];
				}
			}
		}
		ptr++;
		
		sackit->pat_row++;
	}
	
	sackit->tempo_inc = 0;

	for(i = 0; i < 64; i++)
		sackit_update_effects_chn(sackit, &(sackit->pchn[i]),
			note[i], ins[i], vol[i], eft[i], efp[i]);
	
	sackit->pat_ptr = ptr;
}

void sackit_env_update(sackit_playback_t *sackit, sackit_achannel_t *achn
	, sackit_envelope_t *aenv, it_envelope_t *ienv)
{
	if(!(ienv->flg & IT_ENV_ON))
	{
		aenv->y = 256*(int32_t)aenv->def;
		return;
	}

	// TODO: check the case where points[0].x != 0
	// TODO: check the case where lpbeg/end are out of range
	// TODO: clamp x correctly
	
	int lpbeg, lpend;
	
	int can_fade = 1;
	int can_bail = 1;
	
	lpbeg = lpend = ienv->num-1;
	
	if(ienv->flg & IT_ENV_LOOP)
	{
		lpbeg = ienv->lpb;
		lpend = ienv->lpe;
		can_fade = 0;
		can_bail = 0;
	}
	
	if((ienv->flg & IT_ENV_SUSLOOP) && (achn->flags & SACKIT_ACHN_SUSTAIN))
	{
		lpbeg = ienv->slb;
		lpend = ienv->sle;
		can_fade = 0;
		can_bail = 0;
	}
	
	int iy0 = ienv->points[aenv->idx].y;
	int iy1 = ienv->points[aenv->idx+1].y;
	int ix0 = ienv->points[aenv->idx].x;
	int ix1 = ienv->points[aenv->idx+1].x;
	if(aenv->x <= ix0)
	{
		aenv->y = iy0*256;
	} else if(aenv->x >= ix1) {
		aenv->y = iy1*256;
	} else {
		// TODO: get correct rounding
		aenv->y = iy0*256 + (256*(iy1-iy0)*(aenv->x-ix0))/(ix1-ix0);
	}

	aenv->x++;
	//printf("k %i %i\n",lpend,aenv->x);
	if(aenv->x > ix1 || aenv->idx == lpend)
	{
		aenv->idx++;
		
		if(aenv->idx >= lpend)
		{
			aenv->idx = lpbeg;
			aenv->x = ienv->points[lpbeg].x;
			//printf("E %i %i\n",aenv->x,aenv->def);
			
			if(aenv->def == 64)
			{
				if(can_fade)
					sackit_nna_note_fade(sackit, achn);
				if(can_bail && ienv->points[lpend].y == 0)
				{
					sackit_nna_note_cut(sackit, achn);
					//printf("loldie\n");
				}
			}
		}
		// biscuitworld.it exposes a weird quirk caused by modplug tracker sucking ass
		if(aenv->x > ienv->points[aenv->idx].x)
			aenv->x = ienv->points[aenv->idx].x+1;
	}
}

/*

once again, ITTECH.TXT:

       ┌─────────────────────────────────────────────────────────┐
       │ Set note volume to volume set for each channel          │
       │ Set note frequency to frequency set for each channel    │
       └────────────┬────────────────────────────────────────────┘
                    │
       ┌────────────┴────────────┐
       │ Decrease tick counter   │        Yes
       │  Is tick counter 0 ?    ├─────────────────────────┐
       └────────────┬────────────┘                         │
                    │                                      │
                No  │                ┌─────────────────────┴──────────────────┐
       ┌────────────┴────────────┐   │ Tick counter = Tick counter set        │
       │ Update effects for each │   │                  (the current 'speed') │
       │  channel as required.   │   │      Decrease Row counter.             │
       │                         │   │        Is row counter 0?               │
       └───┬─────────────────────┘   └────────────┬──────────┬────────────────┘
           │                                  No  │          │
           │                ┌─────────────────────┘          │ Yes
           │                │                                │
           │  ┌─────────────┴──────────────┐ ┌───────────────┴────────────────┐
           │  │ Call update-effects for    │ │  Row counter = 1               │
           │  │ each channel.              │ │                                │
           │  └──────────────┬─────────────┘ │ Increase ProcessRow            │
           │                 │               │ Is ProcessRow > NumberOfRows?  │
           ├─────────────────┘               └────────┬──────────────────┬────┘
           │                                      Yes │                  │ No
           │         ┌────────────────────────────────┴──────────────┐   │
           │         │  ProcessRow = BreakRow                        │   │
           │         │  BreakRow = 0                                 │   │
           │         │  Increase ProcessOrder                        │   │
           │         │  while Order[ProcessOrder] = 0xFEh,           │   │
           │         │                         increase ProcessOrder │   │
           │         │  if Order[ProcessOrder] = 0xFFh,              │   │
           │         │                         ProcessOrder = 0      │   │
           │         │  CurrentPattern = Order[ProcessOrder]         │   │
           │         └─────────────────────┬─────────────────────────┘   │
           │                               │                             │
           │                               ├─────────────────────────────┘
           │                               │
           │         ┌─────────────────────┴──────────────────────────┐
           │         │ CurrentRow = ProcessRow                        │
           │         │ Update Pattern Variables (includes jumping to  │
           │         │  the appropriate row if requried and getting   │
           │         │  the NumberOfRows for the pattern)             │
           │         └─────────────────────┬──────────────────────────┘
           │                               │
           ├───────────────────────────────┘
           │
       ┌───┴───────────────┐       Yes        ┌───────────────────────────────┐
       │ Instrument mode?  ├──────────────────┤ Update Envelopes as required  │
       └───┬───────────────┘                  │ Update fadeout as required    │
           │                                  │ Calculate final volume if req │
           │ No (Sample mode)                 │ Calculate final pan if req    │
           │                                  │ Process sample vibrato if req │
       ┌───┴─────────────────────────────────┐└───────────────┬───────────────┘
       │ Calculate final volume if required  │                │
       │ Calculate final pan if requried     │                │
       │ Process sample vibrato if required  │                │
       └───┬─────────────────────────────────┘                │
           │                                                  │
           │                                                  │
           └─────────────────────────┬────────────────────────┘
                                     │
                    ┌────────────────┴──────────────────┐
                    │ Output sound!!!                   │
                    └───────────────────────────────────┘
*/


void sackit_tick(sackit_playback_t *sackit)
{
	int i;
	/*
	printf("%i %i %i %i %i\n"
		,sackit->current_tick
		,sackit->max_tick
		,sackit->process_row
		,sackit->process_order
		,sackit->current_pattern);*/
	
	for(i = 0; i < sackit->achn_count; i++)
	{
		sackit_achannel_t *achn = &(sackit->achn[i]);
		// Set note volume to volume set for each channel
		if(achn->parent != NULL && achn->parent->achn == achn)
			achn->vol = achn->parent->vol;
		// not on the graph D:
		if(achn->parent != NULL && achn->parent->achn == achn)
			achn->pan = achn->parent->pan;
		
		// Set note frequency to frequency set for each channel
		if(achn->parent != NULL && achn->parent->achn == achn)
			achn->freq = achn->parent->freq;
		achn->ofreq = achn->freq;
	}
	
	// Decrease tick counter
	sackit->current_tick--;
	
	// Is tick counter 0 ?
	if(sackit->current_tick == 0)
	{
		// Yes
		// Tick counter = Tick counter set (the current 'speed')
		sackit->current_tick = sackit->max_tick;
		
		// Decrease Row counter.
		sackit->row_counter--;
		
		// Is row counter 0?
		if(sackit->row_counter == 0)
		{
			// Yes
			// Row counter = 1
			// NOTE: DONE LATER
			sackit->row_counter = 0;
			
			// Increase ProcessRow
			sackit->process_row++;
			
			// Is ProcessRow > NumberOfRows?
			if(sackit->process_row >= sackit->number_of_rows)
			{
				// Yes
				// ProcessRow = BreakRow
				sackit->process_row = sackit->break_row;
				
				// BreakRow = 0
				sackit->break_row = 0;
				
				// Increase ProcessOrder
				sackit->process_order++;
				
				// while Order[ProcessOrder] = 0xFEh,
				// increase ProcessOrder
				while(sackit->module->orders[sackit->process_order] == 0xFE)
					sackit->process_order++;
				
				// if Order[ProcessOrder] = 0xFFh,
				// ProcessOrder = 0
				if(sackit->module->orders[sackit->process_order] == 0xFF)
					sackit->process_order = 0;
				
				// NOT LISTED ON CHART: Repeat the "while" loop --GM
				while(sackit->module->orders[sackit->process_order] == 0xFE)
					sackit->process_order++;
				
				// TODO: handle the case where we get 0xFF again
				
				// CurrentPattern = Order[ProcessOrder]
				sackit->current_pattern = sackit->module->orders[sackit->process_order];
				sackit->number_of_rows = (sackit->module->patterns[sackit->current_pattern] == NULL
					? 64
					: sackit->module->patterns[sackit->current_pattern]->rows);
				sackit->pat_row = -1;

				// clear the pattern previous values
				// atrk-bu spits out broken files D:
				for(i=0;i<64;i++)
				{
					sackit_pchannel_t *pchn = &(sackit->pchn[i]);
					pchn->lmask = 0;
					pchn->ldata[0] = 253;
					pchn->ldata[1] = 0;
					pchn->ldata[2] = 255;
					pchn->ldata[3] = 0;
					pchn->ldata[4] = 0;
				}
			}
			
			// CurrentRow = ProcessRow
			sackit->current_row = sackit->process_row;
			
			// Update Pattern Variables (includes jumping to
			// the appropriate row if requried and getting 
			// the NumberOfRows for the pattern)
			sackit_update_pattern(sackit);
			
			// Row counter = 1
			// (later than noted in ITTECH.TXT)
			if(sackit->row_counter == 0)
				sackit->row_counter = 1;
		} else {
			// No
			// Call update-effects for each channel. 
			sackit_update_effects(sackit);
		}
	} else {
		// No
		// Update effects for each channel as required.
		sackit_update_effects(sackit);
	}
	
	// ----------------------------------------------------
	
	// Instrument mode?
	// TODO!
	if(sackit->module->header.flags & IT_MOD_INSTR)
	{
		// Yes
		for(i = 0; i < sackit->achn_count; i++)
		{
			sackit_achannel_t *achn = &(sackit->achn[i]);
			if(achn->flags & SACKIT_ACHN_PLAYING)
			{
				// Update Envelopes as required
				sackit_env_update(sackit, achn, &(achn->evol), &(achn->instrument->evol));
				sackit_env_update(sackit, achn, &(achn->epan), &(achn->instrument->epan));
				sackit_env_update(sackit, achn, &(achn->epitch), &(achn->instrument->epitch));
				
				if(achn->instrument != NULL)
				{
					if(achn->epitch.y != 0 && !(achn->instrument->epitch.flg & IT_ENV_FILTER))
					{
						// TODO: analyse this more closely
						if(sackit->module->header.flags & IT_MOD_LINEAR)
							achn->ofreq = sackit_pitchslide_linear(achn->ofreq, achn->epitch.y/32);
						else
							achn->ofreq = sackit_pitchslide_amiga_fine(achn->ofreq, achn->epitch.y/4);
					}
				}
				
				// Update fadeout as required
				if(achn->flags & SACKIT_ACHN_FADEOUT)
				{
					achn->fadeout -= achn->instrument->fadeout;
					if(achn->fadeout <= 0)
					{
						sackit_nna_note_cut(sackit, achn);
					}
				}
			}
		}
	}
	/*
	from ITTECH.TXT:
	
	Abbreviations:
		FV = Final Volume (Ranges from 0 to 128). In versions 1.04+, mixed output
		devices are reduced further to a range from 0 to 64 due to lack of
		memory.
		Vol = Volume at which note is to be played. (Ranges from 0 to 64)
		SV = Sample Volume (Ranges from 0 to 64)
		IV = Instrument Volume (Ranges from 0 to 128)
		CV = Channel Volume (Ranges from 0 to 64)
		GV = Global Volume (Ranges from 0 to 128)
		VEV = Volume Envelope Value (Ranges from 0 to 64)
	
	In Sample mode, the following calculation is done:
		FV = Vol * SV * CV * GV / 262144
	Note that 262144 = 2^18 - So bit shifting can be done.
	
	In Instrument mode the following procedure is used:
		1) Update volume envelope value. Check for loops / end of envelope.
		2) If end of volume envelope (ie. position >= 200 or VEV = 0FFh), then turn
			on note fade.
		3) If notefade is on, then NoteFadeComponent (NFC) = NFC - FadeOut
			; NFC should be initialised to 1024 when a note is played.
		4) FV = Vol * SV * IV * CV * GV * VEV * NFC / 2^41
	*/
	
	for(i = 0; i < sackit->achn_count; i++)
	{
		sackit_achannel_t *achn = &(sackit->achn[i]);
		
		// Calculate final volume if required
		// TODO!
		
		// Calculate final pan if requried
		// FIXME: Lacking stereo wavewriter! Can only guess here!
		// TODO!
		
		// Process sample vibrato if required
		sackit_effect_samplevibrato(sackit, achn);
	}
	
	// ----------------------------------------------------
	
	// Output sound!!!
	// -- handled elsewhere
}

void sackit_playback_update(sackit_playback_t *sackit)
{
	int offs = 0;
	
	while(offs+sackit->buf_tick_rem <= sackit->buf_len)
	{
		if(sackit->buf_tick_rem != 0)
		{
			sackit->f_mix(sackit, offs, sackit->buf_tick_rem);
		}
		offs += sackit->buf_tick_rem;
		
		sackit_tick(sackit);
		sackit->buf_tick_rem = (sackit->freq*10)/(sackit->tempo*4);
	}
	
	if(offs != (int)sackit->buf_len)
	{
		sackit->f_mix(sackit, offs, sackit->buf_len-offs);
		sackit->buf_tick_rem -= sackit->buf_len-offs;
	}
	//printf("rem %i row %i\n", sackit->buf_tick_rem, sackit->process_row);
}

