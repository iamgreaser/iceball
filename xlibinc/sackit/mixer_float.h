void MIXER_NAME(sackit_playback_t *sackit, int offs, int len)
{
	uint32_t tfreq = sackit->freq;
	
	int i,j;
	int offsend = offs+len;
#ifdef MIXER_STEREO
	int pan;
	float vl, vr;
	offs *= 2;
	offsend *= 2;
#endif
	
	int16_t *buf = &(sackit->buf[offs]);
	float *mixbuf = (float *)&(sackit->mixbuf[offs]);
	
	// just a guess :)
	int32_t ramplen = tfreq/400+1;
	
	float gvol = sackit->gv; // 7
	float mvol = sackit->mv; // 7

#ifdef MIXER_STEREO
	for(j = 0; j < len*2; j++)
#else
	for(j = 0; j < len; j++)
#endif
		mixbuf[j] = 0.0f;
	
#ifdef MIXER_STEREO
	if(sackit->anticlick_f[0] != 0 || sackit->anticlick_f[1] != 0)
	{
		float rampmul0 = sackit->anticlick_f[0];
		float rampmul1 = sackit->anticlick_f[1];
		sackit->anticlick_f[0] = 0.0f;
		sackit->anticlick_f[1] = 0.0f;
#else
	if(sackit->anticlick_f[0] != 0.0f)
	{
		float rampmul = sackit->anticlick_f[0];
		sackit->anticlick_f[0] = 0.0f;
#endif
		
		for(j = 0; j < ramplen; j++)
		{
#ifdef MIXER_STEREO
			mixbuf[j*2] += (((float)rampmul0)*(float)(ramplen-j-1))/ramplen;
			mixbuf[j*2+1] += (((float)rampmul1)*(float)(ramplen-j-1))/ramplen;
#else
			mixbuf[j] += (((float)rampmul)*(float)(ramplen-j-1))/ramplen;
#endif
		}
	}

	for(i = 0; i < sackit->achn_count; i++)
	{
		sackit_achannel_t *achn = &(sackit->achn[i]);
		
#ifdef MIXER_FILTERED
		sackit_filter_calc(sackit, achn);
		float fa = achn->filt_coeff[0];
		float fb = achn->filt_coeff[1];
		float fc = achn->filt_coeff[2];
#ifdef MIXER_STEREO
		float k0l = achn->filt_prev[0][0];
		float k0r = achn->filt_prev[1][0];
		float k1l = achn->filt_prev[0][1];
		float k1r = achn->filt_prev[1][1];
#else
		float k0 = achn->filt_prev[0][0];
		float k1 = achn->filt_prev[0][1];
#endif
#endif
		
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
			achn->lramp_f = 0;
			
			//printf("ramp %i %i %i\n", i, rampspd, (32768+rampspd-1)/rampspd);
			//printf("ramp %i %i %i\n", i, rampinc, ramprem);
		}

		achn->anticlick_f[0] = 0.0f;
		achn->anticlick_f[1] = 0.0f;
		
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

				// TODO: make this more accurate
				int sep = sackit->module->header.sep;
				vl = 0x100 * (128-sep) + vl * sep;
				vr = 0x100 * (128-sep) + vr * sep;
				vl /= 128.0f;
				vr /= 128.0f;
			}
			vl /= 256.0f;
			vr /= 256.0f;
#endif

			int32_t zoffs = achn->offs;
			float zsuboffs = achn->suboffs_f;
			float zlramp = achn->lramp_f;
			
#if 1
			// I suspect THIS one is more accurate with regards to IT itself.
			int32_t zfreqi = achn->ofreq;
			zfreqi = sackit_div_int_32_32_to_fixed_16(zfreqi,tfreq);
			float zfreq = zfreqi/65536.0f;
#else
			// This thing, of course, is more accurate with regards to maths.
			float zfreq = achn->ofreq;
			zfreq = ((double)zfreq)/((double)tfreq);
#endif
			
			//printf("freq %i %i %f\n", zfreq, zoffs, zsuboffs);
			
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
			
			double vol = mvol*achn->evol.y*achn->vol*achn->sv*achn->iv*achn->cv*gvol*achn->fadeout;
			vol /= 64.0f*64.0f*64.0f*64.0f*128.0f*64.0f*128.0f*1024.0f*512.0f;
			achn->lramp_f = vol;
			
			// TODO: get ramping working correctly
			for(j = 0; j < len; j++) {
				float v;
				// frozensun.it suggests this exception does NOT exist in IT.
				// Of course, interpolation sucks ass, so that's why most of the apps default to noninterpolated.
				if(0) // zfreq >= 1.0f)
				{
					v = zdata[zoffs];
				} else {
#ifdef MIXER_INTERP_LINEAR
					// get sample value
					float v0 = zdata[zoffs];
					float v1 = ((zoffs+1) == zlength
						? (zflg & IT_SMP_LOOP
							? zdata[zlpbeg]
							: 0)
						: zdata[(zoffs+1)]);
					v  = ((v0*(1.0-zsuboffs))
						+ (v1*(zsuboffs)))/32768.0f;
#else
#ifdef MIXER_INTERP_CUBIC
					// get sample value
					// TODO: do this more efficiently / correctly
					float v0 = (zoffs-1 < 0 ? 0.0f : zdata[zoffs-1]);
					float v1 = zdata[zoffs];
					float v2 = ((zoffs+1) == zlength
						? (zflg & IT_SMP_LOOP
							? zdata[zlpbeg]
							: 0)
						: zdata[(zoffs+1)]);
					float v3 = ((zoffs+2) == zlength
						? (zflg & IT_SMP_LOOP
							? zdata[zlpbeg+1]
							: 0)
						: zdata[(zoffs+2)]);

					// Reference: http://paulbourke.net/miscellaneous/interpolation/
					float t = zsuboffs;
					float t2 = t*t;
					float t3 = t2*t;

#if 1
					// using a Hermite spline
					const float bias = 0.0f;
					const float tension = 0.0f;

					float m0 = (v1 - v0)*(1.0 + bias)*(1.0 - tension)/2.0
					+          (v2 - v1)*(1.0 - bias)*(1.0 - tension)/2.0;
					float m1 = (v2 - v1)*(1.0 + bias)*(1.0 - tension)/2.0
					+          (v3 - v2)*(1.0 - bias)*(1.0 - tension)/2.0;
					float a0 = 2.0*t3 - 3.0*t2 + 1;
					float a1 = t3 - 2.0*t2 + t;
					float a2 = t3 - t2;
					float a3 = -2.0*t3 + 3.0*t2;

					v = a0*v1 + a1*m0 + a2*m1 + a3*v2;
#else
					// using a cubic spline
					float a0 =  v3 - v2 + v1 - v0;
					float a1 = -v1 + v0 - a0;
					float a2 =  v2 - v0;
					float a3 =  v1;

					v = a0*t3 + a1*t2 + a2*t + a3;

#endif
#else
					v = zdata[zoffs];
#endif
#endif
				}
				v /= 32768.0f;
				if(j < ramplen)
					v *= zlramp + (vol-zlramp)*(j/(float)ramplen);
				else
					v *= vol;

				// mix
#ifdef MIXER_FILTERED
#ifdef MIXER_STEREO
				float vxl = v*vl*fa + k0l*fb + k1l*fc;
				float vxr = v*vr*fa + k0r*fb + k1r*fc;
				if(vxl < -2.0f) vxl = -2.0f; else if(vxl > 2.0f) vxl = 2.0f;
				if(vxr < -2.0f) vxr = -2.0f; else if(vxr > 2.0f) vxr = 2.0f;
				if(k0l < -2.0f) k0l = -2.0f; else if(k0l > 2.0f) k0l = 2.0f;
				if(k0r < -2.0f) k0r = -2.0f; else if(k0r > 2.0f) k0r = 2.0f;
				if(k1l < -2.0f) k1l = -2.0f; else if(k1l > 2.0f) k1l = 2.0f;
				if(k1r < -2.0f) k1r = -2.0f; else if(k1r > 2.0f) k1r = 2.0f;
				k1l = k0l;
				k1r = k0r;
				k0l = vxl;
				k0r = vxr;

				mixbuf[j*2] += vxl;
				mixbuf[j*2+1] += vxr;
				achn->anticlick_f[0] = vxl;
				achn->anticlick_f[1] = vxr;
#else
				float vx = v*fa + k0*fb + k1*fc;
				if(vx < -2.0f) vx = -2.0f; else if(vx > 2.0f) vx = 2.0f;
				if(k0 < -2.0f) k0 = -2.0f; else if(k0 > 2.0f) k0 = 2.0f;
				if(k1 < -2.0f) k1 = -2.0f; else if(k1 > 2.0f) k1 = 2.0f;
				k1 = k0;
				k0 = vx;
				mixbuf[j] += vx;
				achn->anticlick_f[0] = vx;
#endif
#else
#ifdef MIXER_STEREO
				mixbuf[j*2] += v*vl;
				mixbuf[j*2+1] += v*vr;
				achn->anticlick_f[0] = v*vl;
				achn->anticlick_f[1] = v*vr;
#else
				mixbuf[j] += v;
				achn->anticlick_f[0] = v;
#endif
#endif
				
				// update
				zsuboffs += zfreq;
				int32_t zsuboffs_int = (int32_t)zsuboffs;
				zoffs += zsuboffs_int;
				zsuboffs -= zsuboffs_int;
				
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
								zsuboffs = 1.0-zsuboffs;
								achn->flags |= SACKIT_ACHN_REVERSE;
							} else {
								zoffs = zlpbeg*2-zoffs;
								zfreq = -zfreq;
								zsuboffs = 1.0-zsuboffs;
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
			achn->suboffs_f = zsuboffs;
#ifdef MIXER_FILTERED
#ifdef MIXER_STEREO
			achn->filt_prev[0][0] = k0l;
			achn->filt_prev[1][0] = k0r;
			achn->filt_prev[0][1] = k1l;
			achn->filt_prev[1][1] = k1r;
#else
			achn->filt_prev[0][0] = k0;
			achn->filt_prev[0][1] = k1;
#endif
#endif
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
		int32_t bv = -mixbuf[j]*32768.0f;
		if(bv < -32768) bv = -32768;
		else if(bv > 32767) bv = 32767;
		
		buf[j] = bv;
	}
}

