#include "sackit_internal.h"

void sackit_nna_note_cut(sackit_playback_t *sackit, sackit_achannel_t *achn)
{
	if(achn == NULL)
		return;
	
	achn->flags &= ~(
		SACKIT_ACHN_MIXING
		|SACKIT_ACHN_PLAYING
		|SACKIT_ACHN_SUSTAIN);
	
	sackit->anticlick[0] += achn->anticlick[0];
	sackit->anticlick[1] += achn->anticlick[1];
	sackit->anticlick_f[0] += achn->anticlick_f[0];
	sackit->anticlick_f[1] += achn->anticlick_f[1];
	achn->anticlick[0] = 0;
	achn->anticlick[1] = 0;
	achn->anticlick_f[0] = 0.0f;
	achn->anticlick_f[1] = 0.0f;
	achn->filt_prev[0][0] = 0.0f;
	achn->filt_prev[0][1] = 0.0f;
	achn->filt_prev[1][0] = 0.0f;
	achn->filt_prev[1][1] = 0.0f;
}

void sackit_nna_note_off(sackit_playback_t *sackit, sackit_achannel_t *achn)
{
	if(achn == NULL)
		return;
	
	achn->flags &= ~SACKIT_ACHN_SUSTAIN;
	
	if(achn->instrument != NULL)
	{
		it_instrument_t *cins = achn->instrument;
		if(cins->evol.flg & IT_ENV_ON)
		{
			if(cins->evol.flg & IT_ENV_LOOP)
				achn->flags |= SACKIT_ACHN_FADEOUT;
		} else {
			achn->flags |= SACKIT_ACHN_FADEOUT;
		}
	}
}

void sackit_nna_note_fade(sackit_playback_t *sackit, sackit_achannel_t *achn)
{
	if(achn == NULL)
		return;
	
	achn->flags |= SACKIT_ACHN_FADEOUT;
}

void sackit_nna_past_note(sackit_playback_t *sackit, sackit_achannel_t *achn, int nna)
{
	while(achn != NULL)
	{
		sackit_achannel_t *achn_next = achn->next;
		switch(nna)
		{
			case 0:
				sackit_nna_note_cut(sackit, achn);
				break;
			case 2:
				sackit_nna_note_off(sackit, achn);
				break;
			case 3:
				sackit_nna_note_fade(sackit, achn);
				break;
		}
		achn = achn_next;
	}
}

/*
from ITTECH.TXT:

The player in Impulse Tracker 'allocates' channels to notes whenever they
are *PLAYED*. In sample mode, the allocation is simple:
               Virtual Channel (number) = 'Host' channel (number)

In instrument mode, the following procedure is used:

    Check if channel is already playing ---Yes--> set 'background' flag on.
                |                                 'Trigger' NNA. If NNA=cut,
                No                                then use this virtual
                |                                 channel.
                |                                          |
                |<------------------ else -----------------/
                |
                v
    Search and find the first non-active virtual channel.
                |
    Non-active channel found? ----Yes----> Use this for playback.
                |
                No
                |
                v
   Search through and find the channel of lowest volume that is in the     #
   'background' (ie. no longer controlled directly)                        #
                |                                                          #
   Background channel found? ----Yes----> Use this for playback.           #
                |                                                          #
                No                                                         #
                |                                                          #
                v                                                          #
   Return error - the note is *NOT* allocated a channel, and hence is not  #
   played.                                                                 #

   This is actually quite a simple process... just that it's another of
   those 'hassles' to have to write...

   ### Note: This is by far the simplest implementation of congestion
             resolution. IT 2.03 and above have a greatly enhanced
             method which more selectively removes the most insignificant
             channel. Obviously, there is no best way to do this - I
             encourage you to experiment and find new algorithms for
             yourself.
*/

void sackit_nna_allocate(sackit_playback_t *sackit, sackit_pchannel_t *pchn)
{
	int i;
	
	// TODO: copy NNA info to the achn (or pchn?)
	
	sackit_achannel_t *old_achn = NULL;
	
	// Do a duplicate check
	// TODO: analyse this more deeply
	if(pchn->bg_achn != NULL)
	{
		sackit_achannel_t *achn = pchn->bg_achn;
		while(achn != NULL)
		{
			sackit_achannel_t *achn_next = achn->next;
			
			int dca_do = 0;
			
			if(achn->instrument != NULL && achn != pchn->achn)
			{
				switch(achn->instrument->dct)
				{
					case 0: // Off
						break;
					case 1: // Note
						dca_do = (achn->note == pchn->note);
						break;
					case 2: // Instrument
						dca_do = (achn->instrument == pchn->instrument);
						break;
					case 3: // Sample
						dca_do = (achn->sample == pchn->sample);
						break;
				}
			}
			
			if(dca_do)
			{
				//printf("DCA!\n");
				switch(achn->instrument->dca)
				{
					case 0:
						sackit_nna_note_cut(sackit, achn);
						break;
					case 1:
						sackit_nna_note_off(sackit, achn);
						break;
					case 2:
						sackit_nna_note_fade(sackit, achn);
						break;
				}
			}
			
			achn = achn_next;
		}
	}
	
	//printf("NNATRIG %016llX %016llX\n", pchn, pchn->achn);
	// Check if playing
	if(pchn->achn != NULL)
	{
		old_achn = pchn->achn;
		
		//printf("NNA %i %016llX\n", pchn->nna, old_achn);
		
		if(pchn->nna == 0)
		{
			sackit_nna_note_cut(sackit, old_achn);
			return;
		}
		if(!(old_achn->flags & SACKIT_ACHN_PLAYING))
			return;
		
		if(pchn->nna == 2)
			sackit_nna_note_off(sackit, old_achn);
		if(pchn->nna == 3)
			sackit_nna_note_fade(sackit, old_achn);
		
		old_achn->flags |= SACKIT_ACHN_BACKGND;
		pchn->achn = NULL;
	}
	
	// Search and find the first non-active virtual channel.
	for(i = 0; i < sackit->achn_count; i++)
	{
		sackit_achannel_t *achn = &(sackit->achn[i]);
		if(!(achn->flags & SACKIT_ACHN_PLAYING))
		{
			if(achn->parent != NULL)
			{
				if(achn->parent->achn == achn)
					achn->parent->achn = NULL;
				if(achn->parent->bg_achn == achn)
					achn->parent->bg_achn = achn->next;
			}
			
			if(achn->prev != NULL)
				achn->prev->next = achn->next;
			if(achn->next != NULL)
				achn->next->prev = achn->prev;
			
			sackit_playback_reset_achn(achn);
			
			pchn->bg_achn = old_achn;
			pchn->achn = achn;
			achn->parent = pchn;
			
			achn->prev = NULL;
			achn->next = old_achn;
			if(old_achn != NULL)
				old_achn->prev = achn;
			
			//printf("%i\n", i);
			return;
		}
	}
	
	// Search through and find the channel of lowest volume that is in the
	// 'background' (ie. no longer controlled directly)
	int tvol = 0xFFFFFF;
	int ti = 0;
	for(i = 0; i < sackit->achn_count; i++)
	{
		sackit_achannel_t *achn = &(sackit->achn[i]);
		if(achn->parent != NULL && achn->parent->achn == achn)
			continue; // foreground channel - SKIP THIS

		int cvol = (int32_t)achn->sv;
		cvol *= (int32_t)achn->iv;
		cvol *= (int32_t)achn->vol;
		cvol *= (int32_t)achn->cv;
		cvol >>= 16;
		cvol *= (int32_t)achn->evol.y;
		cvol *= (int32_t)achn->fadeout;
		
		if(cvol < tvol)
		{
			tvol = cvol;
			ti = i;
		}
	}

	// There's our channel.
	sackit_achannel_t *achn = &(sackit->achn[ti]);
	if(achn->parent != NULL)
	{
		if(achn->parent->achn == achn)
			achn->parent->achn = NULL;
		if(achn->parent->bg_achn == achn)
			achn->parent->bg_achn = achn->next;
	}
	
	if(achn->prev != NULL)
		achn->prev->next = achn->next;
	if(achn->next != NULL)
		achn->next->prev = achn->prev;
	
	if(old_achn == achn)
		old_achn = achn->next;
	pchn->bg_achn = old_achn;
	sackit_playback_reset_achn(achn);
	
	pchn->achn = achn;
	achn->parent = pchn;
	
	achn->prev = NULL;
	achn->next = old_achn;
	if(old_achn != NULL)
		old_achn->prev = achn;
}
