#include "sackit_internal.h"

uint32_t sackit_pitchslide_linear(uint32_t freq, int16_t amt)
{
	uint32_t slidemul;
	
	if(amt == 0)
		return freq;
	
	if(amt < 0)
	{
		slidemul = (uint32_t)linear_slide_down_table[-amt];
	} else  {
		slidemul = (uint32_t)linear_slide_up_table[amt*2+1];
		slidemul <<= 16;
		slidemul += (uint32_t)linear_slide_up_table[amt*2];
	}
	
	uint32_t r = sackit_mul_fixed_16_int_32(slidemul, freq);
	
	//printf("slide %i\n", r);
	
	return r;
}

uint32_t sackit_pitchslide_linear_fine(uint32_t freq, int16_t amt)
{
	uint32_t slidemul;
	
	if(amt == 0)
		return freq;
	
	if(amt < 0)
	{
		slidemul = (uint32_t)fine_linear_slide_down_table[-amt];
	} else  {
		slidemul = (uint32_t)fine_linear_slide_up_table[amt*2+1];
		slidemul <<= 16;
		slidemul += (uint32_t)fine_linear_slide_up_table[amt*2];
	}
	
	uint32_t r = sackit_mul_fixed_16_int_32(slidemul, freq);
	
	//printf("slFde %i\n", r);
	
	return r;
}

uint32_t sackit_pitchslide_amiga_fine(uint32_t freq, int16_t amt)
{
	if(amt == 0)
		return freq;
	
	uint32_t r = AMICLK/(AMICLK/((int64_t)freq) - ((int64_t)amt)*AMIMUL);
	
	//printf("ami %i\n", r);
	
	return r;
}

void sackit_effect_volslide(sackit_playback_t *sackit, sackit_pchannel_t *pchn, int8_t amt)
{
	if(amt < 0)
	{
		pchn->vol = (pchn->vol < -amt
			? 0
			: pchn->vol+amt);
	} else if(amt > 0) {
		pchn->vol = (pchn->vol+amt > 64
			? 64
			: pchn->vol+amt);
	}
	
	if(pchn->achn != NULL)
		pchn->achn->vol = pchn->vol;
}

void sackit_effect_volslide_cv(sackit_playback_t *sackit, sackit_pchannel_t *pchn, int8_t amt)
{
	if(amt < 0)
	{
		pchn->cv = (pchn->cv < -amt
			? 0
			: pchn->cv+amt);
	} else if(amt > 0) {
		pchn->cv = (pchn->cv+amt > 64
			? 64
			: pchn->cv+amt);
	}
	
	if(pchn->achn != NULL)
		pchn->achn->cv = pchn->cv;
}

void sackit_effect_volslide_gv(sackit_playback_t *sackit, sackit_pchannel_t *pchn, int8_t amt)
{
	if(amt < 0)
	{
		sackit->gv = (sackit->gv < -amt
			? 0
			: sackit->gv+amt);
	} else if(amt > 0) {
		sackit->gv = (sackit->gv+amt > 128
			? 128
			: sackit->gv+amt);
	}
}

void sackit_effect_pitchslide(sackit_playback_t *sackit, sackit_pchannel_t *pchn, int16_t amt)
{
	if(amt == 0 || pchn->freq == 0)
		return;
	
	// TODO confirm this behaviour
	
	if(sackit->module->header.flags & IT_MOD_LINEAR)
	{
		pchn->freq = sackit_pitchslide_linear(pchn->freq, amt);
	} else {
		pchn->freq = sackit_pitchslide_amiga_fine(pchn->freq, amt*4);
	}
	
	if(pchn->achn != NULL)
		pchn->achn->freq = pchn->freq;
	
	//printf("%i %i\n", pchn->achn->freq, pchn->achn->flags);
}

void sackit_effect_pitchslide_fine(sackit_playback_t *sackit, sackit_pchannel_t *pchn, int16_t amt)
{
	if(amt == 0 || pchn->freq == 0)
		return;
	
	// TODO confirm this behaviour
	
	if(sackit->module->header.flags & IT_MOD_LINEAR)
	{
		pchn->freq = sackit_pitchslide_linear_fine(pchn->freq, amt);
	} else {
		pchn->freq = sackit_pitchslide_amiga_fine(pchn->freq, amt);
	}
	
	if(pchn->achn != NULL)
		pchn->achn->freq = pchn->freq;
}

void sackit_effect_portaslide(sackit_playback_t *sackit, sackit_pchannel_t *pchn, int16_t amt)
{
	if(amt == 0 || (uint32_t)pchn->freq == pchn->tfreq || pchn->freq == 0)
		return;
	
	if((uint32_t)pchn->achn->freq < pchn->tfreq)
	{
		sackit_effect_pitchslide(sackit, pchn, amt);
		// TODO: confirm if > or >=
		if((uint32_t)pchn->achn->freq >= pchn->tfreq)
			pchn->nfreq = pchn->freq = pchn->tfreq;
	} else {
		sackit_effect_pitchslide(sackit, pchn, -amt);
		// TODO: confirm if < or <=
		if((uint32_t)pchn->achn->freq <= pchn->tfreq)
			pchn->nfreq = pchn->freq = pchn->tfreq;
	}
	
	if(pchn->achn != NULL)
		pchn->achn->freq = pchn->freq;
	
	//printf("%i\n", pchn->achn->freq);
}

void sackit_effect_vibrato_nooffs(sackit_playback_t *sackit, sackit_pchannel_t *pchn)
{
	int32_t v;
	
	if(pchn->achn == NULL || pchn->achn->ofreq == 0 || pchn->vib_speed == 0)
		return;
	
	//if(pchn->achn->vol == 0 || !(pchn->achn->flags & SACKIT_ACHN_PLAYING))
	if(!(pchn->achn->flags & SACKIT_ACHN_PLAYING))
		return;
	
	uint8_t offs = (uint8_t)pchn->vib_offs;
	
	switch(pchn->vib_type&3)
	{
		case 0: // sine
			v = fine_sine_data[offs];
			break;
		case 1: // ramp down
			v = fine_ramp_down_data[offs];
			break;
		case 2: // square
			v = fine_square_wave[offs];
			break;
		case 3: // random - NOT EASILY TESTABLE
			// TODO!
			v = 0;
			break;
	}
	
	/*
	chan_sj.it:
	12464 8
	12532 14
	12554 16
	12600 20
	12554 16
	12532 14
	12464 8
	12375 0
	12341 -7
	12219 -14
	12197 -16
	12153 -20
	12197 -16
	12219 -14
	12341 -7
	12375 0
	*/
	
	v = v*pchn->vib_depth;
	if(sackit->module->header.flags & IT_MOD_OLDFX)
		v = ~(v<<1);
	int negdepth = (v < 0);
	if(negdepth)
		v = ~v;
	v = (v+32)>>6;
	if(negdepth) v = -v;
	
	if(sackit->module->header.flags & IT_MOD_LINEAR)
	{
		if(v >= -15 && v <= 15)
		{
			pchn->achn->ofreq = sackit_pitchslide_linear_fine(pchn->achn->ofreq, v);
		} else {
			// compensating that i have no separate slide up/down function
			pchn->achn->ofreq = sackit_pitchslide_linear(pchn->achn->ofreq
				, (negdepth ? -((-v)>>2): v>>2));
		}
	} else {
		pchn->achn->ofreq = sackit_pitchslide_amiga_fine(pchn->achn->ofreq, v);
	}
	
	//printf("v %i %i\n", pchn->achn->ofreq, v);
}

void sackit_effect_vibrato(sackit_playback_t *sackit, sackit_pchannel_t *pchn)
{
	int32_t v;
	
	if(pchn->achn == NULL || pchn->achn->ofreq == 0 || pchn->vib_speed == 0)
		return;
	
	//if(pchn->achn->vol == 0 || !(pchn->achn->flags & SACKIT_ACHN_PLAYING))
	if(!(pchn->achn->flags & SACKIT_ACHN_PLAYING))
		return;
	
	// vibrato starts IMMEDIATELY.
	pchn->vib_offs += pchn->vib_speed;
	
	// apply.
	sackit_effect_vibrato_nooffs(sackit, pchn);
}

void sackit_effect_tremolo_nooffs(sackit_playback_t *sackit, sackit_pchannel_t *pchn)
{
	int32_t v;
	
	if(pchn->achn == NULL || pchn->achn->ofreq == 0 || pchn->tre_speed == 0)
		return;
	
	if(!(pchn->achn->flags & SACKIT_ACHN_PLAYING))
		return;
	
	uint8_t offs = (uint8_t)pchn->tre_offs;
	
	switch(pchn->vib_type&3)
	{
		case 0: // sine
			v = fine_sine_data[offs];
			break;
		case 1: // ramp down
			v = fine_ramp_down_data[offs];
			break;
		case 2: // square
			v = fine_square_wave[offs];
			break;
		case 3: // random - NOT EASILY TESTABLE
			// TODO!
			v = 0;
			break;
	}
	
	v = v*pchn->tre_depth;
	//if(sackit->module->header.flags & IT_MOD_OLDFX)
	//	v = ~(v<<1);
	int negdepth = (v < 0);
	if(negdepth)
		v = ~v;
	v = (v+64)>>7;
	if(negdepth) v = -v;
	
	v += pchn->achn->vol;
	if(v < 0) v = 0;
	if(v > 64) v = 64;
	pchn->achn->vol = v; 
}

void sackit_effect_tremolo(sackit_playback_t *sackit, sackit_pchannel_t *pchn)
{
	int32_t v;
	
	if(pchn->achn == NULL || pchn->achn->ofreq == 0 || pchn->tre_speed == 0)
		return;
	
	if(!(pchn->achn->flags & SACKIT_ACHN_PLAYING))
		return;
	
	pchn->tre_offs += pchn->tre_speed;
	
	// apply.
	sackit_effect_tremolo_nooffs(sackit, pchn);
}

void sackit_effect_tremor(sackit_playback_t *sackit, sackit_pchannel_t *pchn)
{
	if(!(pchn->trm_flags & 1))
		return;
	
	if(pchn->trm_flags & 2)
	{
		if(pchn->trm_cur_off == 0)
		{
			pchn->trm_cur_off = pchn->trm_val&15;
			if(pchn->trm_cur_off == 0 || (sackit->module->header.flags & IT_MOD_OLDFX))
				pchn->trm_cur_off++;
		}
		
		if(pchn->achn != NULL)
			pchn->achn->vol = 0;
		
		pchn->trm_cur_off--;
		if(pchn->trm_cur_off == 0)
			pchn->trm_flags &= ~2;
	} else {
		if(pchn->trm_cur_on == 0)
		{
			pchn->trm_cur_on = pchn->trm_val>>4;
			if(pchn->trm_cur_on == 0 || (sackit->module->header.flags & IT_MOD_OLDFX))
				pchn->trm_cur_on++;
		}
		pchn->trm_cur_on--;
		if(pchn->trm_cur_on == 0)
			pchn->trm_flags |= 2;
	}
}

void sackit_effect_retrig(sackit_playback_t *sackit, sackit_pchannel_t *pchn, int first_note)
{
	// TODO: confirm th
	if(!(pchn->rtg_flags&1))
		return;
	//printf("%02X %i\n", pchn->rtg_val, pchn->rtg_counter);
	
	if(pchn->rtg_counter == 0)
	{
		pchn->rtg_counter = pchn->rtg_val&15;
		if(pchn->rtg_counter == 0)
			pchn->rtg_counter++;
		
		if(!first_note)
		{
			sackit_note_retrig(sackit, pchn, 0);
			
			// TODO: work out rounding from * and / volslides
			switch(pchn->rtg_val>>4)
			{
				case 0x1:
					pchn->vol -= 1;
					break;
				case 0x2:
					pchn->vol -= 2;
					break;
				case 0x3:
					pchn->vol -= 4;
					break;
				case 0x4:
					pchn->vol -= 8;
					break;
				case 0x5:
					pchn->vol -= 16;
					break;
				
				case 0x6:
					pchn->vol = (pchn->vol*2+1)/3;
					break;
				case 0x7:
					pchn->vol = (pchn->vol+1)/2;
					break;
				
				case 0x9:
					pchn->vol += 1;
					break;
				case 0xA:
					pchn->vol += 2;
					break;
				case 0xB:
					pchn->vol += 4;
					break;
				case 0xC:
					pchn->vol += 8;
					break;
				case 0xD:
					pchn->vol += 16;
					break;
				
				case 0xE:
					pchn->vol = (pchn->vol*3+1)/2;
					break;
				case 0xF:
					pchn->vol *= 2;
					break;
			}
			
			if(((int8_t)pchn->vol) < 0)
				pchn->vol = 0;
			if(pchn->vol > 64)
				pchn->vol = 64;
			
			if(pchn->achn != NULL)
				pchn->achn->vol = pchn->vol;
		}
	}
	pchn->rtg_counter--;
}

void sackit_effect_samplevibrato(sackit_playback_t *sackit, sackit_achannel_t *achn)
{
	if(achn == NULL || achn->ofreq == 0)
		return;
	
	// from ITTECH.TXT:
	// Every processing cycle, the following occurs:
	// 1) Mov AX, [SomeVariableNameRelatingToVibrato]
	// 2) Add AL, Rate
	// 3) AdC AH, 0
	// 4) AH contains the depth of the vibrato as a fine-linear slide.
	// 5) Mov [SomeVariableNameRelatingToVibrato], AX  ; For the next cycle.
	if(achn->svib_power < 0xFF00)
		achn->svib_power += achn->svib_rate;
	if(achn->svib_power > (achn->svib_depth<<8))
		achn->svib_power = (achn->svib_depth<<8);
	
	achn->svib_offs += achn->svib_speed;
	
	// TODO: determine exact slide!
	int32_t v;
	
	//if(pchn->achn->vol == 0 || !(pchn->achn->flags & SACKIT_ACHN_PLAYING))
	if(!(achn->flags & SACKIT_ACHN_PLAYING))
		return;
	
	uint8_t offs = (uint8_t)achn->svib_offs;
	
	switch(achn->svib_type&3)
	{
		case 0: // sine
			v = fine_sine_data[offs];
			break;
		case 1: // ramp down
			v = fine_ramp_down_data[offs];
			break;
		case 2: // square
			v = fine_square_wave[offs];
			break;
		case 3: // random - NOT EASILY TESTABLE
			// TODO!
			v = 0;
			break;
	}
	
	//v = (v*((achn->svib_depth*achn->svib_power)>>11));
	
	// closest:
	//v = (v*((achn->svib_power>>8)*(((achn->svib_depth)>>3))));
	v = (v*(achn->svib_power>>8));
	v -= 32;
	
	// TODO: check if old effects affects sample vibrato
	int negdepth = (v < 0);
	if(negdepth)
		v = ~v;
	v = (v+(1<<5))>>6;
	if(negdepth) v = -v;
	
	if(v >= -15 && v <= 15)
	{
		achn->ofreq = sackit_pitchslide_linear_fine(achn->ofreq, v);
	} else {
		// compensating that i have no separate slide up/down function
		achn->ofreq = sackit_pitchslide_linear(achn->ofreq
			, (negdepth ? -((-v)>>2): v>>2));
	}
	//if(achn == (sackit->pchn[0].achn))
	//	printf("%i %04X %i\n",achn->ofreq, achn->svib_power, v);
}
