#include "sackit_internal.h"

void sackit_filter_calc(sackit_playback_t *sackit, sackit_achannel_t *achn)
{
	int cut = achn->filt_cut<<8;
	if(achn->instrument != NULL && (achn->instrument->epitch.flg & IT_ENV_FILTER) != 0 && (achn->instrument->epitch.flg & IT_ENV_ON) != 0)
		cut = (cut*(achn->epitch.y+8192))>>14;

	if(cut < 0)
	{
		printf("ERROR: cutoff should NOT be negative! (%i)\n", cut);
		fflush(stdout);
		abort();
	}

	//if(cut != 127*256)
	//	printf("%i\n", cut);

	int res = achn->filt_res;

	if(cut == 127*256 && res == 0)
	{
		achn->filt_coeff[0] = 1;
		achn->filt_coeff[1] = 0;
		achn->filt_coeff[2] = 0;
		return;
	}

	float r = pow(2.0, cut * -0.00016276040696538985) * 0.0012166619999334216 * sackit->freq;
	float d2 = quality_factor_table[res];
	//printf("%.9f %.9f\n", r, d2);
	
	float d = d2 * (r + 1.0f) - 1.0f;
	float e = r*r;

	float a = 1.0f / (1.0f + d + e);
	float b = (d + 2.0f*e) * a;
	float c = -e * a;

	achn->filt_coeff[0] = a;
	achn->filt_coeff[1] = b;
	achn->filt_coeff[2] = c;
	//printf("filt %f %f %f | %i %i\n", a,b,c, cut, res);
}

void sackit_note_retrig(sackit_playback_t *sackit, sackit_pchannel_t *pchn, int offs)
{
	sackit_achannel_t *lachn = pchn->achn;
	sackit_nna_allocate(sackit, pchn);
	
	pchn->achn->instrument = pchn->instrument;
	pchn->achn->sample = pchn->sample;
	
	pchn->achn->note = pchn->note;
	
	pchn->achn->freq = pchn->freq;
	pchn->achn->offs = offs;
	pchn->achn->suboffs = 0;
	pchn->achn->suboffs_f = 0.0;
	pchn->achn->cv = pchn->cv;
	pchn->achn->filt_cut = pchn->filt_cut;
	pchn->achn->filt_res = pchn->filt_res;
	if(pchn->instrument != NULL)
		pchn->achn->iv = pchn->instrument->gbv;
	if(pchn->sample != NULL)
	{
		pchn->achn->sv = pchn->sample->gvl;
		pchn->achn->svib_speed = pchn->sample->vis;
		pchn->achn->svib_depth = pchn->sample->vid;
		pchn->achn->svib_type = pchn->sample->vit;
		pchn->achn->svib_rate = pchn->sample->vir;
		
		// TODO: work out what to do with old effects mode
		if(pchn->achn->offs >= (int32_t)pchn->sample->length)
			pchn->achn->offs = 0;
	}
	pchn->achn->svib_offs = 0; // TODO: confirm
	pchn->achn->svib_power = 0;
	
	pchn->achn->flags |= (
		SACKIT_ACHN_MIXING
		|SACKIT_ACHN_PLAYING
		|SACKIT_ACHN_RAMP
		|SACKIT_ACHN_SUSTAIN);
	
	if(pchn->achn != lachn && lachn != NULL)
	{
		if(pchn->achn->instrument == lachn->instrument)
		{
			pchn->achn->evol.x = lachn->evol.x;
			pchn->achn->evol.idx = lachn->evol.idx;
			pchn->achn->epan.x = lachn->epan.x;
			pchn->achn->epan.idx = lachn->epan.idx;
			pchn->achn->epitch.x = lachn->epitch.x;
			pchn->achn->epitch.idx = lachn->epitch.idx;
		}
	}
	
	if(pchn->instrument == NULL || (pchn->instrument->evol.flg & IT_ENV_CARRY) == 0)
	{
		pchn->achn->evol.x = 0;
		pchn->achn->evol.idx = 0;
	}
	if(pchn->instrument == NULL || (pchn->instrument->epan.flg & IT_ENV_CARRY) == 0)
	{
		pchn->achn->epan.idx = 0;
		pchn->achn->epan.x = 0;
	}
	if(pchn->instrument == NULL || (pchn->instrument->epitch.flg & IT_ENV_CARRY) == 0)
	{
		pchn->achn->epitch.x = 0;
		pchn->achn->epitch.idx = 0;
	}
	
	if(pchn->instrument != NULL)
	{
		pchn->achn->evol.flags = pchn->instrument->evol.flg;
		pchn->achn->epan.flags = pchn->instrument->epan.flg;
		pchn->achn->epitch.flags = pchn->instrument->epitch.flg;
	}
	
	pchn->achn->fadeout = 1024;
	
	pchn->achn->flags &= ~(
		SACKIT_ACHN_REVERSE
		|SACKIT_ACHN_FADEOUT
		|SACKIT_ACHN_BACKGND);
}

void sackit_update_effects_chn(sackit_playback_t *sackit, sackit_pchannel_t *pchn,
	uint8_t note, uint8_t ins, uint8_t vol, uint8_t eft, uint8_t efp)
{
	//if(note != 253)
	//	printf("N %i %i\n", note, ins);
	
	uint8_t vnote = note;
	
	pchn->slide_vol = 0;
	pchn->slide_vol_cv = 0;
	pchn->slide_vol_gv = 0;
	pchn->slide_pan = 0;
	pchn->slide_pitch = 0;
	pchn->slide_porta = 0;
	pchn->arpeggio = 0;
	pchn->vib_speed = 0;
	pchn->vib_depth = 0;
	pchn->tre_speed = 0;
	pchn->tre_depth = 0;
	pchn->trm_flags &= ~1;
	pchn->rtg_flags &= ~1;
	pchn->rtg_val = 0;
	
	pchn->note_cut = 0;
	pchn->note_delay = 0;
	pchn->note_delay_note = note;
	pchn->note_delay_ins = ins;
	pchn->note_delay_vol = vol;
	
	int16_t slide_vol_now = 0;
	int16_t slide_vol_cv_now = 0;
	int16_t slide_vol_gv_now = 0;
	int16_t slide_pan_now = 0;
	int16_t slide_pitch_now = 0;
	int16_t slide_pitch_fine_now = 0;
	
	int flag_slide_porta = 0;
	int flag_retrig = 0;
	int flag_vibrato = 0;
	int flag_tremolo = 0;
	int flag_done_instrument = 0;
	int flag_nna_set = -1;
	int flag_s7x = -1;

	int can_set_cut = 1;
	int can_set_res = 1;
	
	uint32_t new_sample_offset = 0;
	
	uint8_t el = efp&15;
	uint8_t eh = efp>>4;
	int vfp = 0;
	switch(eft)
	{
		case 0x01: // Axx - Set Speed (mislabelled as "Tempo" in ITTECH.TXT --GM)
			if(efp != 0x00)
			{
				sackit->max_tick = efp;
				sackit->current_tick = efp;
			}
			break;
		
		case 0x02: // Bxx - Jump to Order
			sackit->process_order = efp - 1;
			sackit->process_row = 0xFFFE; // indicates new pattern internally for IT...
			break;
		
		case 0x03: // Cxx - Break to Row
			sackit->break_row = efp;
			sackit->process_row = 0xFFFE;
			break;
		
		case 0x04: // Dxx - Volume slide
		case 0x0B: // Kxx - (vibrato + vol slide)
		case 0x0C: // Lxx - (porta to note + vol slide)
			// TODO: confirm behaviour
			if(efp == 0)
			{
				efp = pchn->eff_slide_vol;
				el = efp&15;
				eh = efp>>4;
			} else {
				pchn->eff_slide_vol = efp;
			}
			
			if(el == 0)
				pchn->slide_vol += eh;
			else if(eh == 0)
				pchn->slide_vol -= el;
			else if(el == 0xF)
				slide_vol_now += eh;
			else if(eh == 0xF)
				slide_vol_now -= el;
			
			if(efp == 0x0F || efp == 0xF0)
				slide_vol_now += eh-el;
			
			efp = eh = el = 0;
			break;
		
		case 0x05: // Exx - (pitch slide down)
		case 0x06: // Fxx - (pitch slide up)
			if(efp == 0)
			{
				efp = pchn->eff_slide_pitch;
			} else {
				pchn->eff_slide_pitch = efp;
			}
			
			// TODO: confirm behaviour
			if(efp <= 0xDF)
			{
				pchn->slide_pitch += (eft == 0x05 ? -1 : 1)*efp;
			} else if(efp <= 0xEF) {
				slide_pitch_fine_now += (eft == 0x05 ? -1 : 1)*(efp&15);
			} else {
				slide_pitch_now += (eft == 0x05 ? -1 : 1)*(efp&15);
			}
			break;
		
		case 0x09: // Ixx - (tremor)
			if(efp == 0)
			{
				efp = pchn->eff_slide_pitch;
			} else {
				pchn->eff_slide_pitch = efp;
			}
			
			pchn->eff_tremor = efp;
			pchn->trm_val = efp;
			pchn->trm_flags |= 1;
			
			break;
		
		case 0x0A: // Jxx - (arpeggio)
			if(efp == 0)
			{
				efp = pchn->eff_arpeggio;
			} else {
				pchn->eff_arpeggio = efp;
			}
			pchn->arpeggio = efp;
			break;
		
		case 0x0D: // Mxx - (channel volume)
			// TODO: confirm behaviour
			if(efp <= 64)
			{
				pchn->cv = efp;
				if(pchn->achn != NULL)
					pchn->achn->cv = efp;
			}
			break;
		
		case 0x0E: // Nxx - (channel volume slide)
			// TODO: confirm behaviour
			if(efp == 0)
			{
				efp = pchn->eff_slide_vol_cv;
				el = efp&15;
				eh = efp>>4;
			} else {
				pchn->eff_slide_vol_cv = efp;
			}
			
			if(el == 0)
				pchn->slide_vol_cv += eh;
			else if(eh == 0)
				pchn->slide_vol_cv -= el;
			else if(el == 0xF)
				slide_vol_cv_now += eh;
			else if(eh == 0xF)
				slide_vol_cv_now -= el;
			
			efp = eh = el = 0;
			break;
		
		case 0x0F: // Oxx - (sample offset)
			// TODO: get out-of-range behaviour correct!
			if(efp == 0)
			{
				efp = pchn->eff_sample_offs;
			} else {
				pchn->eff_sample_offs = efp;
			}
			
			// TODO: SAx
			new_sample_offset = efp<<8;
			
			break;
		
		case 0x11: // Qxx - (retrigger)
			if(efp == 0)
			{
				efp = pchn->eff_retrig;
			} else {
				pchn->eff_retrig = efp;
			}
			
			pchn->rtg_flags |= 1;
			pchn->rtg_val = efp;
			
			break;
		
		case 0x12: // Rxx - (tremolo)
			// TODO: check if x,y independent
			if((efp&0x0F) == 0)
				efp |= (pchn->eff_tremolo&0x0F);
			if((efp&0xF0) == 0)
				efp |= (pchn->eff_tremolo&0xF0);
			
			pchn->eff_tremolo = efp;
			
			pchn->tre_speed += (efp>>4)*4;
			pchn->tre_depth += (efp&15)*(eft == 0x15 ? 1 : 4);
			
			//if(!(sackit->module->header.flags & IT_MOD_OLDFX))
			flag_tremolo = 1;
			break;
		case 0x13: // Sxx - (miscellaneous)
			if(efp == 0)
			{
				efp = pchn->eff_misc;
				el = efp&15;
				eh = efp>>4;
			} else {
				pchn->eff_misc = efp;
			}
			switch(eh)
			{
				case 0x6: // S6x - (delay by x ticks)
					sackit->current_tick += el;
					break;
				case 0x7: // S7x - (misc ins stuff)
				switch(el)
				{
					case 0x0: // S70 - (past note cut)
						sackit_nna_past_note(sackit, pchn->achn, 0);
						break;
					case 0x1: // S71 - (past note off)
						sackit_nna_past_note(sackit, pchn->achn, 2);
						break;
					case 0x2: // S72 - (past note fade)
						sackit_nna_past_note(sackit, pchn->achn, 3);
						break;
					case 0x3: // S73 - (NNA = cut)
						flag_nna_set = 0;
						break;
					case 0x4: // S74 - (NNA = continue)
						flag_nna_set = 1;
						break;
					case 0x5: // S75 - (NNA = off)
						flag_nna_set = 2;
						break;
					case 0x6: // S76 - (NNA = fade)
						flag_nna_set = 3;
						break;
					case 0x7: // S77 - (vol env off)
						flag_s7x = 0x7;
						break;
					case 0x8: // S78 - (vol env on)
						flag_s7x = 0x8;
						break;
					case 0x9: // S79 - (pan env off)
						flag_s7x = 0x9;
						break;
					case 0xA: // S7A - (pan env on)
						flag_s7x = 0xA;
						break;
					case 0xB: // S7B - (pitch env off)
						flag_s7x = 0xB;
						break;
					case 0xC: // S7C - (pitch env on)
						flag_s7x = 0xC;
						break;
				} break;
				case 0xB: // SBx - (loopback)
					// TRIVIA:
					// Before 1.04, this used song-global variables (as in S3M)
					// Before 2.10, this didn't set the loop start after a successful looping.
					if(el == 0)
					{
						// TODO: sort out the nasty SBx/Cxx/Bxx combos
						// (IIRC there's only one weird one)
						pchn->loop_start = sackit->current_row-1;
					} else {
						if(pchn->loop_times == 0)
						{
							pchn->loop_times = el;
						} else {
							pchn->loop_times--;
							if(pchn->loop_times == 0)
							{
								pchn->loop_start = sackit->current_row;
								break;
							}
						}
						sackit->process_row = pchn->loop_start;
					}
					break;
				case 0xC: // SCx - (note cut)
					pchn->note_cut = (el == 0 ? 1 : el);
					break;
				case 0xD: // SDx - (note delay)
					pchn->note_delay = (el == 0 ? 1 : el);
					if(ins != 0)
						pchn->lins = ins;
					return; // cut this part!
					break;
				case 0xE: // SEx - (pattern delay)
					if(sackit->row_counter == 0)
					{
						sackit->row_counter = el+1;
					}
					break;
			}
			break;
		
		case 0x14: // Txx - (tempo)
			if(efp == 0)
			{
				efp = pchn->eff_tempo;
			} else {
				pchn->eff_tempo = efp;
			}
			
			if(efp < 0x10)
			{
				sackit->tempo_inc = -efp;
			} else if(efp < 0x20) {
				sackit->tempo_inc = efp-0x10;
			} else {
				sackit->tempo = efp;
			}
			break;
		
		case 0x16: // Vxx - (global volume)
			if(efp <= 0x80)
			{
				sackit->gv = efp;
			}
			break;
		
		case 0x17: // Wxx - (global volume slide)
			// TODO: confirm behaviour
			if(efp == 0)
			{
				efp = pchn->eff_slide_vol_gv;
				el = efp&15;
				eh = efp>>4;
			} else {
				pchn->eff_slide_vol_gv = efp;
			}
			
			if(el == 0)
				pchn->slide_vol_gv += eh;
			else if(eh == 0)
				pchn->slide_vol_gv -= el;
			else if(el == 0xF)
				slide_vol_gv_now += eh;
			else if(eh == 0xF)
				slide_vol_gv_now -= el;
			
			efp = eh = el = 0;
			break;

		case 0x18: // Xxx - (panning)
			pchn->pan = (pchn->pan & 0x80) | ((efp+2)>>2);
			if(pchn->achn != NULL)
				pchn->achn->pan = pchn->pan;
			break;

		case 0x1A: // Zxx - (MIDI)
			// TODO: load MIDI data from the file itself
			if(efp <= 0x7F)
			{
				pchn->filt_cut = efp;
				if(pchn->achn != NULL)
					pchn->achn->filt_cut = pchn->filt_cut;

				can_set_cut = 0;
			} else if(efp <= 0x8F) {
				pchn->filt_res = (efp-0x80)*0x08;
				if(pchn->achn != NULL)
					pchn->achn->filt_res = pchn->filt_res;

				can_set_res = 0;
			}
			break;
	}
	
	switch(eft)
	{
		case 0x07: // Gxx - (porta to note)
		case 0x0C: // Lxx - (porta to note + vol slide)
			if(efp == 0)
			{
				efp = (sackit->module->header.flags & IT_MOD_COMPGXX
					? pchn->eff_slide_porta
					: pchn->eff_slide_pitch);
			} else if(sackit->module->header.flags & IT_MOD_COMPGXX) {
				pchn->eff_slide_porta = efp;
			} else {
				pchn->eff_slide_pitch = efp;
			}
			
			pchn->slide_porta += efp;
			flag_slide_porta = 1;
			// TODO: confirm behaviour
			break;
		
		case 0x08: // Hxx - (vibrato)
		case 0x15: // Uxx - (fine vibrato)
		case 0x0B: // Kxx - (vibrato + vol slide)
			// TODO: check if x,y independent
			if((efp&0x0F) == 0)
				efp |= (pchn->eff_vibrato&0x0F);
			if((efp&0xF0) == 0)
				efp |= (pchn->eff_vibrato&0xF0);
			
			pchn->eff_vibrato = efp;
			
			pchn->vib_speed += (efp>>4)*4;
			pchn->vib_depth += (efp&15)*(eft == 0x15 ? 1 : 4);
			
			//if(!(sackit->module->header.flags & IT_MOD_OLDFX))
			flag_vibrato = 1;
			break;
	}
	
	if(vol <= 64)
	{
		// volume
		// (OPTIONAL: Feel free to emulate pre-voleffects stuff.
		//  (Turn the limit up to <= 127.))
		pchn->vol = vol;
		if(pchn->achn != NULL)
			pchn->achn->vol = pchn->vol;
	} else if (vol <= 74) {
		// Ax
		if(vol == 65)
		{
			vfp = pchn->eff_slide_vol_veff;
		} else {
			pchn->eff_slide_vol_veff = vfp = ((int16_t)(vol-65));
		}
		slide_vol_now += vfp;
	} else if (vol <= 84) {
		// Bx
		if(vol == 75)
		{
			vfp = pchn->eff_slide_vol_veff;
		} else {
			pchn->eff_slide_vol_veff = vfp = ((int16_t)(vol-75));
		}
		slide_vol_now -= vfp;
	} else if (vol <= 94) {
		// Cx
		if(vol == 85)
		{
			vfp = pchn->eff_slide_vol_veff;
		} else {
			pchn->eff_slide_vol_veff = vfp = ((int16_t)(vol-85));
		}
		pchn->slide_vol += vfp;
	} else if (vol <= 104) {
		// Dx
		if(vol == 95)
		{
			vfp = pchn->eff_slide_vol_veff;
		} else {
			pchn->eff_slide_vol_veff = vfp = ((int16_t)(vol-95));
		}
		pchn->slide_vol -= vfp;
	} else if (vol <= 114) {
		// Ex
		if(vol == 105)
		{
			vfp = pchn->eff_slide_pitch;
		} else {
			pchn->eff_slide_pitch = vfp = ((int16_t)(vol-105))*4;
		}
		
		pchn->slide_pitch -= vfp;
	} else if (vol <= 124) {
		// Fx
		if(vol == 115)
		{
			vfp = pchn->eff_slide_pitch;
		} else {
			vfp = pchn->eff_slide_pitch = ((int16_t)(vol-115))*4;
		}
		
		pchn->slide_pitch += vfp;
	} else if (vol <= 127) {
		// DO NOTHING
	} else if (vol <= 192) {
		// panning
		pchn->pan = (pchn->pan & 0x80) | (vol-128);
		if(pchn->achn != NULL)
			pchn->achn->pan = pchn->pan;
	} else if (vol <= 202) {
		// Gx
		
		if(vol == 193)
		{
			vfp = (sackit->module->header.flags & IT_MOD_COMPGXX
				? pchn->eff_slide_porta
				: pchn->eff_slide_pitch);
		} else if(sackit->module->header.flags & IT_MOD_COMPGXX) {
			pchn->eff_slide_porta = vfp = slide_table[vol-194];
		} else {
			pchn->eff_slide_pitch = vfp = slide_table[vol-194];
		}
		
		pchn->slide_porta += vfp;
		flag_slide_porta = 1;
	} else if (vol <= 212) {
		// Hx
	}
	
	it_sample_t *psmp = pchn->sample;
	if(ins != 0)
	{
		if(sackit->module->header.flags & IT_MOD_INSTR)
		{
			uint8_t xnote = (note <= 119 ? note : pchn->note);
			
			it_instrument_t *cins = sackit->module->instruments[ins-1];
			if(cins == NULL)
				cins = pchn->instrument;
			else
				pchn->instrument = cins;
			
			// TODO: confirm behaviour
			if(cins != NULL)
			{
				if(cins->notesample[xnote][1] != 0)
				{
					it_sample_t *csmp = sackit->module->samples[cins->notesample[xnote][1]-1];
					if(csmp != NULL)
						pchn->sample = csmp;
				}
				
				if(note <= 119)
					vnote = cins->notesample[xnote][0];

				if((cins->ifc & 0x80) != 0 && can_set_cut)
				{
					pchn->filt_cut = (cins->ifc & 0x7F);
					if(pchn->achn != NULL)
						pchn->achn->filt_cut = pchn->filt_cut;
				}

				if((cins->ifr & 0x80) != 0 && can_set_res)
				{
					pchn->filt_res = (cins->ifr & 0x7F);
					if(pchn->achn != NULL)
						pchn->achn->filt_res = pchn->filt_res;
				}
				
				flag_done_instrument = 1;
			}
		} else {
			pchn->instrument = NULL;
			it_sample_t *csmp = sackit->module->samples[ins-1];
			if(csmp != NULL)
				pchn->sample = csmp;
		}

		if(/*ins != pchn->lins && */pchn->instrument != NULL && flag_nna_set == -1)
		{
			flag_nna_set = pchn->instrument->nna;
		}

		if(pchn->sample != NULL)
		{
			if(vol > 64)
			{
				pchn->vol = pchn->sample->vol;
				if(pchn->achn != NULL && (flag_nna_set == -1 || flag_nna_set == 0))
					pchn->achn->vol = pchn->vol;
			}
		}

		if(((
			pchn->achn == NULL || (!(pchn->achn->flags & SACKIT_ACHN_PLAYING))
			)|| pchn->lins != ins)
			&& note == 253
			&& pchn->note != 253)
		{
			note = pchn->note;
		}
		
		pchn->lins = ins;
	}

	if(note <= 119)
	{
		// actual note
		it_sample_t *csmp;

		if(sackit->module->header.flags & IT_MOD_INSTR)
		{
			uint8_t xnote = note;
			
			it_instrument_t *cins = pchn->instrument;
			if(cins != NULL)
			{
				// TODO: confirm behaviour
				if(cins->notesample[xnote][1] != 0)
				{
					csmp = sackit->module->samples[cins->notesample[xnote][1]-1];
					if(csmp != NULL)
						pchn->sample = csmp;
				}
				
				vnote = cins->notesample[xnote][0];
			}
		}
		
		uint32_t nfreq = 
			((uint32_t)(pitch_table[vnote*2]))
			| (((uint32_t)(pitch_table[vnote*2+1]))<<16);
		
		//printf("N %i %i %i %i\n", note, vnote, ins, nfreq);
		if(pchn->sample != NULL)
		{
			int flag_isnt_sliding = (pchn->achn == NULL || (!(pchn->achn->flags & SACKIT_ACHN_PLAYING)) || !flag_slide_porta);
			it_sample_t *nsmp = (psmp != NULL && (sackit->module->header.flags & IT_MOD_COMPGXX) && (!flag_isnt_sliding) ? pchn->achn->sample : pchn->sample);
			nfreq = sackit_mul_fixed_16_int_32(nfreq, nsmp->c5speed);
			pchn->tfreq = nfreq;
			pchn->note = note;
			
			if(flag_isnt_sliding)
			{
				pchn->freq = pchn->nfreq = nfreq;
				flag_retrig = 1;
			}

			// TODO: handle carry correctly in this case (it's weird)
			if(flag_slide_porta && pchn->achn != NULL && (sackit->module->header.flags & IT_MOD_COMPGXX) != 0)
			{
				if(pchn->instrument == NULL || (pchn->instrument->evol.flg & IT_ENV_CARRY) == 0)
				{
					pchn->achn->evol.x = 0;
					pchn->achn->evol.idx = 0;
				}
				if(pchn->instrument == NULL || (pchn->instrument->epan.flg & IT_ENV_CARRY) == 0)
				{
					pchn->achn->epan.idx = 0;
					pchn->achn->epan.x = 0;
				}
				if(pchn->instrument == NULL || (pchn->instrument->epitch.flg & IT_ENV_CARRY) == 0)
				{
					pchn->achn->epitch.x = 0;
					pchn->achn->epitch.idx = 0;
				}
			}
		}
	} else if(note == 255) {
		// note off
		sackit_nna_note_off(sackit, pchn->achn);
	} else if(note == 254) {
		// note cut
		sackit_nna_note_cut(sackit, pchn->achn);
	} else if(note != 253) {
		// note fade
		sackit_nna_note_fade(sackit, pchn->achn);
	}
	
	if(flag_retrig)
	{
		if(!flag_done_instrument)
		{
			
			// FIXME: this is messy! it shouldn't be duplicated twice!
			if(sackit->module->header.flags & IT_MOD_INSTR)
			{
				it_instrument_t *cins = sackit->module->instruments[pchn->lins-1];
				if(cins == NULL)
					cins = pchn->instrument;
				else
					pchn->instrument = cins;
				
				// TODO: confirm behaviour
				if(cins == NULL)
				{
					flag_retrig = 0;
				} else if(cins->notesample[pchn->note][1] != 0) {
					// FIXME: do i need to do something with the note HERE?
					it_sample_t *csmp = sackit->module->samples[cins->notesample[pchn->note][1]-1];
					if(csmp == NULL)
						csmp = pchn->sample;
					else {
						pchn->sample = csmp;
					}
					
					if(csmp == NULL)
						flag_retrig = 0;
				}
			} else {
				pchn->instrument = NULL;
				it_sample_t *csmp = sackit->module->samples[pchn->lins-1];
				if(csmp == NULL)
					csmp = pchn->sample;
				else
					pchn->sample = csmp;
				
				if(csmp == NULL)
					flag_retrig = 0;
			}

			if(!flag_retrig)
				sackit_nna_allocate(sackit, pchn);
		}
		
		if(flag_retrig)
		{
			pchn->rtg_counter = 0;
			if(flag_vibrato)
				pchn->vib_offs = 0;
			sackit_note_retrig(sackit, pchn, new_sample_offset);
		}
	}
	
	if(flag_vibrato && pchn->vib_lins != pchn->lins)
	{
		pchn->vib_lins = pchn->lins;
		pchn->vib_offs = 0;
	}
	
	if(flag_nna_set != -1)
		pchn->nna = flag_nna_set;
	
	if(pchn->achn != NULL)
	switch(flag_s7x)
	{
		case 0x7:
			pchn->achn->evol.flags &= ~IT_ENV_ON;
			break;
		case 0x8:
			pchn->achn->evol.flags |= IT_ENV_ON;
			break;
		case 0x9:
			pchn->achn->epan.flags &= ~IT_ENV_ON;
			break;
		case 0xA:
			pchn->achn->epan.flags |= IT_ENV_ON;
			break;
		case 0xB:
			pchn->achn->epitch.flags &= ~IT_ENV_ON;
			break;
		case 0xC:
			pchn->achn->epitch.flags |= IT_ENV_ON;
			break;
	}
	
	// update slides & stuff
	sackit_effect_volslide_cv(sackit, pchn, slide_vol_cv_now);
	sackit_effect_volslide_gv(sackit, pchn, slide_vol_gv_now);
	sackit_effect_volslide(sackit, pchn, slide_vol_now);
	sackit_effect_retrig(sackit, pchn, flag_retrig);
	sackit_effect_pitchslide(sackit, pchn, slide_pitch_now);
	sackit_effect_pitchslide_fine(sackit, pchn, slide_pitch_fine_now);
	if(pchn->achn != NULL)
		pchn->achn->ofreq = pchn->achn->freq;
	if(flag_vibrato)
	{
		if(sackit->module->header.flags & IT_MOD_OLDFX)
		{
			sackit_effect_vibrato_nooffs(sackit, pchn);
		} else {
			sackit_effect_vibrato(sackit, pchn);
		}
	}
	if(flag_tremolo)
	{
		sackit_effect_tremolo(sackit, pchn);
	}
	sackit_effect_tremor(sackit, pchn);
}
