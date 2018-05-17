void MIXER_NAME(sackit_playback_t *sackit, int offs, int len)
{
	uint32_t tfreq = sackit->freq;
	
	int i,j;
	int offsend = offs+len;
#ifdef MIXER_STEREO
	int pan, vl, vr;
	offs *= 2;
	offsend *= 2;
#endif
	
	int16_t *buf = &(sackit->buf[offs]);
	int32_t *mixbuf = (int32_t *)&(sackit->mixbuf[offs]);
	
	// just a guess :)
#if MIXER_VER <= 211
	int32_t ramplen = tfreq/500+1;
#else
	int32_t ramplen = tfreq/400+1;
#endif
	
	int32_t gvol = sackit->gv; // 7
	int32_t mvol = sackit->mv; // 7

#ifdef MIXER_STEREO
	for(j = 0; j < len*2; j++)
#else
	for(j = 0; j < len; j++)
#endif
		mixbuf[j] = 0;
	
#ifdef MIXER_ANTICLICK
#ifdef MIXER_STEREO
	if(sackit->anticlick[0] != 0 || sackit->anticlick[1] != 0)
	{
		int32_t rampmul0 = sackit->anticlick[0];
		int32_t rampmul1 = sackit->anticlick[1];
		sackit->anticlick[0] = 0;
		sackit->anticlick[1] = 0;
#else
	if(sackit->anticlick[0] != 0)
	{
		int32_t rampmul = sackit->anticlick[0];
		sackit->anticlick[0] = 0;
#endif
		
		for(j = 0; j < ramplen; j++)
		{
#ifdef MIXER_STEREO
			mixbuf[j*2] += (((int32_t)rampmul0)*(int32_t)(ramplen-j-1))/ramplen;
			mixbuf[j*2+1] += (((int32_t)rampmul1)*(int32_t)(ramplen-j-1))/ramplen;
#else
			mixbuf[j] += (((int32_t)rampmul)*(int32_t)(ramplen-j-1))/ramplen;
#endif
		}
	}
#endif

	for(i = 0; i < sackit->achn_count; i++)
	{
		sackit_achannel_t *achn = &(sackit->achn[i]);
		
		if(achn->sample == NULL || achn->sample->data == NULL
			|| achn->offs >= (int32_t)achn->sample->length
			|| achn->offs < 0)
		{
			achn->flags &= ~(
				SACKIT_ACHN_RAMP
				|SACKIT_ACHN_MIXING
				|SACKIT_ACHN_PLAYING
				|SACKIT_ACHN_SUSTAIN);
		}
		
		if(achn->flags & SACKIT_ACHN_RAMP)
		{
			achn->flags &= ~SACKIT_ACHN_RAMP;
			//ramprem = rampspd;
			achn->lramp = 0;
			
			//printf("ramp %i %i %i\n", i, rampspd, (32768+rampspd-1)/rampspd);
			//printf("ramp %i %i %i\n", i, rampinc, ramprem);
		}

#ifdef MIXER_ANTICLICK
		achn->anticlick[0] = 0;
		achn->anticlick[1] = 0;
#endif
		
		// TODO: ramp stereowise properly
		if(achn->flags & SACKIT_ACHN_MIXING)
		{
#ifdef MIXER_STEREO
			pan = achn->pan;
			if(pan == 100)
			{
				vl = 0x100;
				vr = -0x100;
			} else {
				if(pan <= 32)
				{
					vl = 0x100;
					vr = pan<<3;
				} else {
					vl = (64-pan)<<3;
					vr = 0x100;
				}

				int sep = sackit->module->header.sep;
				vl = 0x100 * (128-sep) + vl * sep;
				vr = 0x100 * (128-sep) + vr * sep;
				vl >>= 7;
				vr >>= 7;
			}
#endif

			int32_t zoffs = achn->offs;
			int32_t zsuboffs = achn->suboffs;
			int32_t zfreq = achn->ofreq;
			int32_t zlramp = achn->lramp;
			
			zfreq = sackit_div_int_32_32_to_fixed_16(zfreq,tfreq);
			
			//printf("freq %i %i %i\n", zfreq, zoffs, zsuboffs);
			
			int32_t zlpbeg = achn->sample->loop_begin;
			int32_t zlpend = achn->sample->loop_end;
			int32_t zlength = achn->sample->length;
			uint8_t zflg = achn->sample->flg;
			int16_t *zdata = achn->sample->data;
			
			if((achn->flags & SACKIT_ACHN_SUSTAIN)
				&& (zflg & IT_SMP_SUSLOOP))
			{
				zlpbeg = achn->sample->susloop_begin;
				zlpend = achn->sample->susloop_end;
				zflg |= IT_SMP_LOOP;
				if(zflg & IT_SMP_SUSBIDI)
				{
					zflg |= IT_SMP_LOOPBIDI;
				} else {
					zflg &= ~IT_SMP_LOOPBIDI;
				}
			}
			
			if(!(zflg & IT_SMP_LOOPBIDI))
				achn->flags &= ~SACKIT_ACHN_REVERSE;
			
			// TODO: sanity check somewhere!
			if(zflg & IT_SMP_LOOP)
				zlength = zlpend;
			if(achn->flags & SACKIT_ACHN_REVERSE)
				zfreq = -zfreq;
			
			int32_t vol = 0x8000;
			/*vol = ((int32_t)achn->vol) // 6
				*((int32_t)achn->sv) // 6
				*((int32_t)achn->cv) // 6
				*gvol // 7
			;
			//vol += (1<<9);
			vol >>= 10;
			vol = (vol*mvol)>>7; // 7*/
			// TODO: sort the order / rounding out
			// 4) FV = Vol * SV * IV * CV * GV * VEV * NFC / 2^41
			/*vol = (vol*((int32_t)achn->vol))>>6;
			vol = (vol*((int32_t)achn->sv))>>6;
			vol = (vol*((int32_t)achn->iv))>>7;
			vol = (vol*((int32_t)achn->cv))>>6;
			vol = (vol*gvol)>>7;
			vol = (vol*((int32_t)achn->evol.y))>>6;
			vol = (vol*((int32_t)achn->fadeout))>>10;
			vol = (vol*mvol)>>7;*/
			{
				/*int64_t bvol = 0x8000;
				bvol = (bvol*(int64_t)achn->evol.y)>>14;
				bvol = (bvol*(int64_t)achn->vol)>>6;
				bvol = (bvol*(int64_t)achn->sv)>>6;
				bvol = (bvol*(int64_t)achn->iv)>>6;
				bvol = (bvol*(int64_t)achn->cv)>>6;
				bvol = (bvol*(int64_t)gvol)>>7;
				bvol = (bvol*(int64_t)achn->fadeout)>>10;
				bvol = (bvol*(int64_t)mvol)>>7;
				vol = (bvol)>>1;*/
				int64_t bvol = 1;
				bvol = (bvol*(int64_t)achn->evol.y);
				bvol = (bvol*(int64_t)achn->vol);
				bvol = (bvol*(int64_t)achn->sv);
				bvol = (bvol*(int64_t)achn->iv);
				bvol = (bvol*(int64_t)achn->cv);
				bvol = (bvol*(int64_t)gvol);
				bvol = (bvol*(int64_t)achn->fadeout);
				bvol = (bvol*(int64_t)mvol);
				vol = (bvol)>>(1+14+6+6+6+6+7+10+7-15);
			}
			//printf("%04X\n", vol);
			//vol += 0x0080;
			//vol &= 0x7F00;
			
			achn->lramp = vol;
			
			int32_t rampmul = zlramp;
			int32_t ramprem = ramplen;
			int32_t rampdelta = (vol-zlramp);
			int negdepth = (rampdelta < 0);
			int32_t rampdelta_i = rampdelta;
			if(negdepth)
				rampdelta = -rampdelta;
			int32_t rampspd = (rampdelta+0x0080)&~0x00FF;
			
			rampspd = rampspd / (ramplen+1);
			
			rampspd &= ~3;
			
			if(negdepth)
			{
				rampspd = -rampspd;
				//rampspd -= 4;
			}
			
			/*
			if(rampdelta != 0)
				printf("%5i %04X / %5i %04X mod90 is %5i => %5i \n", vol, vol
					, rampdelta
					, rampdelta_i&0xFFFF
					, (rampdelta_i+(ramplen+1)*0x10000) % (ramplen+1)
					, rampspd);
			*/
			
			/*
			Ramp speeds:
			06BF NOT 16
			0B40 = 32
			0CC0 = 36
			0F00 = 40
			1200 = 48
			1800 = 68
			1E00 = 84
			1ED8 NOT 84 (it's 88!)
			27C0 = 112
			3000 = 136
			
			D000 = -136
			E800 NOT -68
			EE00 = -48
			F400 = -32
			F4C0 (?) -28
			FA00 (?) -16
			*/
			
			//printf("%i\n", rampspd);
			for(j = 0; j < len; j++) {
#ifdef MIXER_INTERP_LINEAR
				// get sample value
				int32_t v0 = zdata[zoffs];
				int32_t v1 = ((zoffs+1) == zlength
					? (zflg & IT_SMP_LOOP
						? zdata[zlpbeg]
						: 0)
					: zdata[(zoffs+1)]);
				int32_t v  = ((v0*((65535-zsuboffs)))>>16)
					+ ((v1*(zsuboffs))>>16);
#else
				int32_t v = zdata[zoffs];
#endif
				
				if(ramprem > 0)
				{
					v = (v*rampmul+0x8000)>>16;
					rampmul += rampspd;
					ramprem--;
				} else {
					v = ((v*vol+0x8000)>>16);
				}
				
				// mix
#ifdef MIXER_STEREO
				mixbuf[j*2] += v*vl>>8;
				mixbuf[j*2+1] += v*vr>>8;
#else
				mixbuf[j] += v;
#endif
#ifdef MIXER_ANTICLICK
#ifdef MIXER_STEREO
				achn->anticlick[0] = v*vl>>8;
				achn->anticlick[1] = v*vr>>8;
#else
				achn->anticlick[0] = v;
#endif
#endif
				
				// update
				zsuboffs += zfreq;
				zoffs += (((int32_t)zsuboffs)>>16);
				zsuboffs &= 0xFFFF;
				
				if((zfreq < 0
					? zoffs < zlpbeg
					: zoffs >= (int32_t)zlength))
				{
					// TODO: ping-pong/bidirectional loops
					// TODO? speed up for tiny loops?
					if(zflg & IT_SMP_LOOP)
					{
						if(zflg & IT_SMP_LOOPBIDI)
						{
							if(zfreq > 0)
							{
								zoffs = zlpend*2-1-zoffs;
								zfreq = -zfreq;
								zsuboffs = 0x10000-zsuboffs;
								achn->flags |= SACKIT_ACHN_REVERSE;
							} else {
								zoffs = zlpbeg*2-zoffs;
								zfreq = -zfreq;
								zsuboffs = 0x10000-zsuboffs;
								achn->flags &= ~SACKIT_ACHN_REVERSE;
							}
						} else {
							while(zoffs >= (int32_t)zlpend)
								zoffs += (zlpbeg-zlpend);
						}
					} else {
						achn->flags &= ~(
							 SACKIT_ACHN_MIXING
							|SACKIT_ACHN_PLAYING
							|SACKIT_ACHN_SUSTAIN);
						break;
					}
				}
			}
			
			achn->offs = zoffs;
			achn->suboffs = zsuboffs;
		} else if(achn->flags & SACKIT_ACHN_PLAYING) {
			// TODO: update offs/suboffs
		}
	}
	
	// stick into the buffer
#ifdef MIXER_STEREO
	for(j = 0; j < len*2; j++)
#else
	for(j = 0; j < len; j++)
#endif
	{
		int32_t bv = -mixbuf[j];
		if(bv < -32768) bv = -32768;
		else if(bv > 32767) bv = 32767;
		
		buf[j] = bv;
	}
}

