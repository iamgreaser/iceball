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
			achn->lramp = 0;
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
			// TODO: sort the order / rounding out
			// 4) FV = Vol * SV * IV * CV * GV * VEV * NFC / 2^41
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
				vol = (bvol)>>(1+14+6+6+6+6+7+10+7-14);
			}
			//printf("%04X\n", vol);
			//vol += 0x0080;
			//vol &= 0x7F00;

			achn->lramp = vol;

#ifdef MIXER_STEREO
			int vlpre = (vol*vl)>>8;
			int vrpre = (vol*vr)>>8;
#endif

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
			}

			if(ramprem > len) ramprem = len;

#ifndef INTFAST_MIX1
#define INTFAST_MIX1(vol) \
	/* get sample value */ \
	int32_t v = zdata[zoffs]; \
	v = (v*(vol))>>16; \
	/* mix */ \
	int vout = v; \
	mixbuf[j] += vout; \
	/* update */ \
	zsuboffs += zfreq; \
	zoffs += (((int32_t)zsuboffs)>>16); \
	zsuboffs &= 0xFFFF;
#endif

#ifndef INTFAST_MIX2
#define INTFAST_MIX2(vl, vr) \
	/* get sample value */ \
	int32_t v = zdata[zoffs]; \
	/* mix */ \
	int voutl = (v*(vl))>>16; \
	int voutr = (v*(vr))>>16; \
	mixbuf[j*2+0] += voutl; \
	mixbuf[j*2+1] += voutr; \
	/* update */ \
	zsuboffs += zfreq; \
	zoffs += (((int32_t)zsuboffs)>>16); \
	zsuboffs &= 0xFFFF;
#endif

#ifndef INTFAST_AC1
#define INTFAST_AC1 \
	achn->anticlick[0] = vout;
#endif

#ifndef INTFAST_AC2
#define INTFAST_AC2 \
	achn->anticlick[0] = voutl; \
	achn->anticlick[1] = voutr;
#endif

#ifndef INTFAST_TERM_NOLOOP
#define INTFAST_TERM_NOLOOP \
	if(zoffs >= (int32_t)zlength) \
	{ \
		achn->flags &= ~( \
			 SACKIT_ACHN_MIXING \
			|SACKIT_ACHN_PLAYING \
			|SACKIT_ACHN_SUSTAIN); \
		j = len; \
		break; \
	}
#endif

#ifndef INTFAST_TERM_LOOP
#define INTFAST_TERM_LOOP \
	if(zoffs >= (int32_t)zlength) \
	{ \
		while(zoffs >= (int32_t)zlpend) \
			zoffs += (zlpbeg-zlpend); \
	}
#endif

#ifndef INTFAST_TERM_BIDI
#define INTFAST_TERM_BIDI \
	if((zfreq < 0 \
		? zoffs < zlpbeg \
		: zoffs >= (int32_t)zlength)) \
	{ \
		if(zfreq > 0) \
		{ \
			zoffs = zlpend*2-1-zoffs; \
			zfreq = -zfreq; \
			zsuboffs = 0x10000-zsuboffs; \
			achn->flags |= SACKIT_ACHN_REVERSE; \
		} else { \
			zoffs = zlpbeg*2-zoffs; \
			zfreq = -zfreq; \
			zsuboffs = 0x10000-zsuboffs; \
			achn->flags &= ~SACKIT_ACHN_REVERSE; \
		} \
	}
#endif

// TODO: estimate termination lengths (effectively (32 - 32.16)/32: that is, ((i32<<16) - i32_16)/(i32<<16))
#ifndef INTFAST_TLEN_NOBIDI
#define INTFAST_TLEN_NOBIDI \
	(zlength - zoffs)
#endif

#ifndef INTFAST_MIX_HANDLER
#define INTFAST_MIX_HANDLER(Mix1, Mix2, Ac, Term) \
	for(j = 0; j < ramprem; j++) { \
		Mix1; \
		Ac; \
		rampmul += rampspd; \
		Term; \
	} \
	for(; j < len; j++) { \
		Mix2; \
		Ac; \
		Term; \
	}
#endif

			if((zflg & IT_SMP_LOOP) && (zflg & IT_SMP_LOOPBIDI))
			{
#ifdef MIXER_STEREO
#	ifdef MIXER_ANTICLICK
				INTFAST_MIX_HANDLER(
					INTFAST_MIX2((rampmul*vl) >> 8, (rampmul*vr) >> 8),
					INTFAST_MIX2(vlpre, vrpre),
					INTFAST_AC2,
					INTFAST_TERM_BIDI);
#	else
				INTFAST_MIX_HANDLER(
					INTFAST_MIX2((rampmul*vl) >> 8, (rampmul*vr) >> 8),
					INTFAST_MIX2(vlpre, vrpre),
					,
					INTFAST_TERM_BIDI);
#	endif
#else
#	ifdef MIXER_ANTICLICK
				INTFAST_MIX_HANDLER(
					INTFAST_MIX1(rampmul),
					INTFAST_MIX1(vol),
					INTFAST_AC1,
					INTFAST_TERM_BIDI);
#	else
				INTFAST_MIX_HANDLER(
					INTFAST_MIX1(rampmul),
					INTFAST_MIX1(vol),
					,
					INTFAST_TERM_BIDI);
#	endif
#endif
			} else if((zflg & IT_SMP_LOOP) && !(zflg & IT_SMP_LOOPBIDI)) {
#ifdef MIXER_STEREO
#	ifdef MIXER_ANTICLICK
				INTFAST_MIX_HANDLER(
					INTFAST_MIX2((rampmul*vl) >> 8, (rampmul*vr) >> 8),
					INTFAST_MIX2(vlpre, vrpre),
					INTFAST_AC2,
					INTFAST_TERM_LOOP);
#	else
				INTFAST_MIX_HANDLER(
					INTFAST_MIX2((rampmul*vl) >> 8, (rampmul*vr) >> 8),
					INTFAST_MIX2(vlpre, vrpre),
					,
					INTFAST_TERM_LOOP);
#	endif
#else
#	ifdef MIXER_ANTICLICK
				INTFAST_MIX_HANDLER(
					INTFAST_MIX1(rampmul),
					INTFAST_MIX1(vol),
					INTFAST_AC1,
					INTFAST_TERM_LOOP);
#	else
				INTFAST_MIX_HANDLER(
					INTFAST_MIX1(rampmul),
					INTFAST_MIX1(vol),
					,
					INTFAST_TERM_LOOP);
#	endif
#endif
			} else {
#ifdef MIXER_STEREO
#	ifdef MIXER_ANTICLICK
				INTFAST_MIX_HANDLER(
					INTFAST_MIX2((rampmul*vl) >> 8, (rampmul*vr) >> 8),
					INTFAST_MIX2(vlpre, vrpre),
					INTFAST_AC2,
					INTFAST_TERM_NOLOOP);
#	else
				INTFAST_MIX_HANDLER(
					INTFAST_MIX2((rampmul*vl) >> 8, (rampmul*vr) >> 8),
					INTFAST_MIX2(vlpre, vrpre),
					,
					INTFAST_TERM_NOLOOP);
#	endif
#else
#	ifdef MIXER_ANTICLICK
				INTFAST_MIX_HANDLER(
					INTFAST_MIX1(rampmul),
					INTFAST_MIX1(vol),
					INTFAST_AC1,
					INTFAST_TERM_NOLOOP);
#	else
				INTFAST_MIX_HANDLER(
					INTFAST_MIX1(rampmul),
					INTFAST_MIX1(vol),
					,
					INTFAST_TERM_NOLOOP);
#	endif
#endif
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

