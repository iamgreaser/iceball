#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <errno.h>

#include <math.h>

#include "sackit.h"

typedef struct sackit_reader sackit_reader_t;
struct sackit_reader
{
	void *in;
	char (*getch)(sackit_reader_t *reader);
	size_t (*read)(sackit_reader_t *reader, void *out, size_t size);
	void (*seek)(sackit_reader_t *reader, long offset, int mode);
	long (*tell)(sackit_reader_t *reader);
};

typedef struct sackit_reader_data_mem sackit_reader_data_mem_t;
struct sackit_reader_data_mem
{
	const char* ptr;
	long pos, len;
};

// effects.c
uint32_t sackit_pitchslide_linear(uint32_t freq, int16_t amt);
uint32_t sackit_pitchslide_linear_fine(uint32_t freq, int16_t amt);
uint32_t sackit_pitchslide_amiga_fine(uint32_t freq, int16_t amt);
void sackit_effect_volslide(sackit_playback_t *sackit, sackit_pchannel_t *pchn, int8_t amt);
void sackit_effect_volslide_cv(sackit_playback_t *sackit, sackit_pchannel_t *pchn, int8_t amt);
void sackit_effect_volslide_gv(sackit_playback_t *sackit, sackit_pchannel_t *pchn, int8_t amt);
void sackit_effect_pitchslide(sackit_playback_t *sackit, sackit_pchannel_t *pchn, int16_t amt);
void sackit_effect_pitchslide_fine(sackit_playback_t *sackit, sackit_pchannel_t *pchn, int16_t amt);
void sackit_effect_portaslide(sackit_playback_t *sackit, sackit_pchannel_t *pchn, int16_t amt);
void sackit_effect_vibrato_nooffs(sackit_playback_t *sackit, sackit_pchannel_t *pchn);
void sackit_effect_vibrato(sackit_playback_t *sackit, sackit_pchannel_t *pchn);
void sackit_effect_tremolo_nooffs(sackit_playback_t *sackit, sackit_pchannel_t *pchn);
void sackit_effect_tremolo(sackit_playback_t *sackit, sackit_pchannel_t *pchn);
void sackit_effect_tremor(sackit_playback_t *sackit, sackit_pchannel_t *pchn);
void sackit_effect_retrig(sackit_playback_t *sackit, sackit_pchannel_t *pchn, int first_note);
void sackit_effect_samplevibrato(sackit_playback_t *sackit, sackit_achannel_t *achn);

// fixedmath.c
uint32_t sackit_mul_fixed_16_int_32(uint32_t a, uint32_t b);
uint32_t sackit_div_int_32_32_to_fixed_16(uint32_t a, uint32_t b);

// mixer_*.c
void sackit_playback_mixstuff_it211(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it211s(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it211l(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it211ls(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it212(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it212s(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it212l(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it212ls(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it214(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it214s(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it214l(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it214ls(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it214c(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it214cs(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it214f(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it214fs(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it214fl(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it214fls(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it214fc(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_it214fcs(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_intfast_a(sackit_playback_t *sackit, int offs, int len);
void sackit_playback_mixstuff_intfast_as(sackit_playback_t *sackit, int offs, int len);

// objects.c
it_module_t *sackit_module_load_offs_internal(sackit_reader_t *reader, int fboffs);
void sackit_playback_reset_achn(sackit_achannel_t *achn);
void sackit_playback_reset_pchn(sackit_pchannel_t *pchn);

// playroutine.c
void sackit_filter_calc(sackit_playback_t *sackit, sackit_achannel_t *achn);
void sackit_note_retrig(sackit_playback_t *sackit, sackit_pchannel_t *pchn, int offs);
void sackit_update_effects_chn(sackit_playback_t *sackit, sackit_pchannel_t *pchn,
	uint8_t note, uint8_t ins, uint8_t vol, uint8_t eft, uint8_t efp);
void sackit_update_effects(sackit_playback_t *sackit);
void sackit_update_pattern(sackit_playback_t *sackit);
void sackit_nna_allocate(sackit_playback_t *sackit, sackit_pchannel_t *pchn);
void sackit_nna_note_off(sackit_playback_t *sackit, sackit_achannel_t *achn);
void sackit_nna_note_cut(sackit_playback_t *sackit, sackit_achannel_t *achn);
void sackit_nna_note_fade(sackit_playback_t *sackit, sackit_achannel_t *achn);
void sackit_nna_past_note(sackit_playback_t *sackit, sackit_achannel_t *achn, int nna);
void sackit_tick(sackit_playback_t *sackit);

// tables.c
extern int8_t fine_sine_data[];
extern int8_t fine_ramp_down_data[];
extern int8_t fine_square_wave[];
extern uint16_t pitch_table[];
extern uint16_t fine_linear_slide_up_table[];
extern uint16_t linear_slide_up_table[];
extern uint16_t fine_linear_slide_down_table[];
extern uint16_t linear_slide_down_table[];
extern uint8_t slide_table[];
extern float quality_factor_table[];

