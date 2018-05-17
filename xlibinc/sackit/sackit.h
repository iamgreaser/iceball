#define AMICLK (938308796416LL)
#define AMIMUL (65536LL)

// note, these aren't the IT limits (smps is 99 afaik)
// but they should be fine for now --GM
#define MAX_ORDERS 256
#define MAX_INSTRUMENTS 256
#define MAX_SAMPLES 256
#define MAX_PATTERNS 256

#define SACKIT_MAX_ACHANNEL 256

enum {
	MIXER_IT211 = 0,
	MIXER_IT211S,
	MIXER_IT211L,
	MIXER_IT211LS,

	MIXER_IT212,
	MIXER_IT212S,
	MIXER_IT212L,
	MIXER_IT212LS,

	MIXER_IT214,
	MIXER_IT214S,
	MIXER_IT214L,
	MIXER_IT214LS,
	MIXER_IT214C,
	MIXER_IT214CS,

	MIXER_IT214F,
	MIXER_IT214FS,
	MIXER_IT214FL,
	MIXER_IT214FLS,
	MIXER_IT214FC,
	MIXER_IT214FCS,

	MIXER_INTFAST_A,
	MIXER_INTFAST_AS,
};

#pragma pack(push, 1)
typedef struct it_pattern
{
	uint16_t length;
	uint16_t rows;
	uint32_t reserved;
	uint8_t data[65536];
} it_pattern_t;
#pragma pack(pop)

#define IT_SMP_EXISTS   0x01
#define IT_SMP_16BIT    0x02
#define IT_SMP_STEREO   0x04
#define IT_SMP_COMPRESS 0x08
#define IT_SMP_LOOP     0x10
#define IT_SMP_SUSLOOP  0x20
#define IT_SMP_LOOPBIDI 0x40
#define IT_SMP_SUSBIDI  0x80

#pragma pack(push, 1)
typedef struct it_sample
{
	uint8_t magic[4]; // IMPS
	uint8_t dos_filename[13];
	uint8_t gvl, flg, vol;
	uint8_t sample_name[26];
	uint8_t cvt, dfp;
	uint32_t length;
	uint32_t loop_begin, loop_end;
	uint32_t c5speed;
	uint32_t susloop_begin, susloop_end;
	uint32_t samplepointer;
	uint8_t vis,vid,vir,vit;
	int16_t *data;
} it_sample_t;
#pragma pack(pop)

#define IT_ENV_ON       0x01
#define IT_ENV_LOOP     0x02
#define IT_ENV_SUSLOOP  0x04
#define IT_ENV_CARRY    0x08
#define IT_ENV_FILTER   0x80
// toDONE: confirm which bit ENV_CARRY *really* uses
// (it's not in ITTECH - dammit Jeff...)
// - yes, it IS that flag. Apparently it was added in IT 2.14p5 or MAYBE p4 (it's not in p3!).

#pragma pack(push, 1)
typedef struct it_envelope
{
	uint8_t flg,num;
	uint8_t lpb,lpe;
	uint8_t slb,sle;
#pragma pack(push, 1)
	struct {
		int8_t y;
		uint16_t x;
	} points[25];
#pragma pack(pop)
	uint8_t resv1;
} it_envelope_t;
#pragma pack(pop)

#define IT_MOD_STEREO  0x01
#define IT_MOD_VOL0MIX 0x02 /* Most. Useless. Flag. Ever. */
#define IT_MOD_INSTR   0x04
#define IT_MOD_LINEAR  0x08
#define IT_MOD_OLDFX   0x10
#define IT_MOD_COMPGXX 0x20
#define IT_MOD_USEPWD  0x40
#define IT_MOD_GETMIDI 0x80
#define IT_SPECIAL_MESSAGE  0x01
//define IT_SPECIAL_        0x02 // unknown
//define IT_SPECIAL_        0x04 // unknown
#define IT_SPECIAL_HASMIDI  0x08

#pragma pack(push, 1)
typedef struct it_instrument
{
	uint8_t magic[4]; // IMPI
	uint8_t dos_filename[13];
	uint8_t nna,dct,dca;
	uint16_t fadeout;
	uint8_t pps,ppc;
	uint8_t gbv,dfp;
	uint8_t rv,rp;
	uint16_t trkvers;
	uint8_t nos,resv1;
	uint8_t instrument_name[26];
	uint8_t ifc,ifr;
	uint8_t mch,mpr;
	uint16_t midibnk;
	uint8_t notesample[120][2];
	it_envelope_t evol;
	it_envelope_t epan;
	it_envelope_t epitch;
} it_instrument_t;
#pragma pack(pop)

typedef struct it_module_header it_module_header_t;

typedef struct it_module
{
#pragma pack(push, 1)
	struct it_module_header {
		uint8_t magic[4]; // IMPM
		uint8_t song_name[26];
		uint16_t philigt;
		uint16_t ordnum, insnum, smpnum, patnum;
		uint16_t cwtv, cmwt;
		uint16_t flags, special;
		uint8_t gv, mv, is, it, sep, pwd;
		uint16_t msglgth;
		uint32_t message_offset;
		uint32_t timestamp; // reserved my ass --GM
		uint8_t chnl_pan[64];
		uint8_t chnl_vol[64];
	} header;
#pragma pack(pop)

	uint8_t orders[MAX_ORDERS];
	it_instrument_t *instruments[MAX_INSTRUMENTS];
	it_sample_t *samples[MAX_SAMPLES];
	it_pattern_t *patterns[MAX_PATTERNS];
} it_module_t;

#define SACKIT_ENV_PLAYING 0x100
#define SACKIT_ENV_SUSTAIN 0x200
typedef struct sackit_envelope
{
	int8_t idx;
	int16_t x;
	int32_t y;
	int8_t def; // "default".
	int8_t lpbeg,lpend;
	int8_t susbeg,susend;
	uint8_t flags;
	
	// YES, the X is stored for the carry flag stuff!
	// (this can be noticed with compat Gxx)
	int16_t carry_x;
	int8_t carry_idx;
	uint8_t carry_flags;
} sackit_envelope_t;

// audio channel
#define SACKIT_ACHN_PLAYING  0x01
#define SACKIT_ACHN_MIXING   0x02
#define SACKIT_ACHN_RAMP     0x04
#define SACKIT_ACHN_REVERSE  0x08
#define SACKIT_ACHN_SUSTAIN  0x10
#define SACKIT_ACHN_FADEOUT  0x20
#define SACKIT_ACHN_BACKGND  0x40

typedef struct sackit_achannel sackit_achannel_t;
typedef struct sackit_pchannel sackit_pchannel_t;

struct sackit_achannel
{
	uint8_t note;
	
	int32_t ofreq;
	int32_t freq;
	int32_t offs;
	int32_t suboffs;
	float suboffs_f;
	uint16_t flags;
	uint8_t vol,sv,iv,cv; // TODO: more stuff
	uint8_t pan;
	uint16_t fv;
	int32_t lramp;
	float lramp_f;
	int16_t fadeout;

	int filt_cut;
	int filt_res;
	float filt_prev[2][2];
	float filt_coeff[3];

	int32_t anticlick[2];
	float anticlick_f[2];
	
	int32_t svib_speed;
	int32_t svib_type;
	int32_t svib_depth;
	int32_t svib_rate;
	int32_t svib_power;
	int32_t svib_offs;

	sackit_achannel_t *prev,*next;
	sackit_pchannel_t *parent;
	
	it_instrument_t *instrument;
	it_sample_t *sample;
	sackit_envelope_t evol,epan,epitch;
};

// pattern channel
struct sackit_pchannel
{
	sackit_achannel_t *achn;
	sackit_achannel_t *bg_achn;
	
	uint32_t tfreq;
	uint32_t nfreq;
	int32_t freq;
	uint8_t note;
	uint8_t lins;
	uint8_t cv;
	uint8_t pan;
	uint8_t vol;
	
	uint8_t nna;
	
	int16_t slide_vol;
	int16_t slide_pan;
	int16_t slide_pitch;
	int16_t slide_porta;
	int16_t slide_vol_cv;
	int16_t slide_vol_gv;
	uint16_t arpeggio;
	uint16_t note_cut;
	uint16_t note_delay;
	uint16_t note_delay_note;
	uint16_t note_delay_ins;
	uint16_t note_delay_vol;
	uint16_t vib_speed;
	int16_t vib_depth;
	uint16_t vib_offs;
	uint16_t vib_type;
	uint16_t vib_lins;
	uint16_t tre_speed;
	int16_t tre_depth;
	uint16_t tre_offs;
	uint16_t tre_type;
	uint8_t trm_val;
	uint8_t trm_flags;
	uint8_t trm_cur_on;
	uint8_t trm_cur_off;
	uint8_t rtg_val;
	uint8_t rtg_flags;
	uint8_t rtg_counter;
	
	int16_t loop_start;
	uint8_t loop_times;
	
	uint8_t eff_slide_vol;
	uint8_t eff_slide_vol_cv;
	uint8_t eff_slide_vol_gv;
	uint8_t eff_slide_vol_veff;
	uint8_t eff_slide_pitch;
	uint8_t eff_slide_porta;
	uint8_t eff_sample_offs;
	uint8_t eff_misc;
	uint8_t eff_arpeggio;
	uint8_t eff_vibrato;
	uint8_t eff_tremolo;
	uint8_t eff_tempo;
	uint8_t eff_tremor;
	uint8_t eff_retrig;

	int filt_cut;
	int filt_res;
	
	it_instrument_t *instrument;
	it_sample_t *sample;
	
	uint8_t lmask,ldata[5];
};

typedef struct sackit_playback sackit_playback_t;
struct sackit_playback
{
	it_module_t *module;
	
	uint16_t current_tick;
	uint16_t max_tick;
	uint16_t row_counter;
	
	uint16_t current_row;
	uint16_t process_row;
	uint16_t break_row;
	uint16_t number_of_rows; // TODO? refactor into pattern?
	
	uint16_t current_pattern;
	uint16_t process_order;
	
	uint16_t pat_ptr; // index of next row
	uint16_t pat_row;
	
	uint16_t tempo;
	int16_t tempo_inc;
	
	uint32_t buf_len;
	uint32_t buf_tick_rem;
	void (*f_mix)(sackit_playback_t *sackit, int offs, int len);
	int mixer_bytes;
	int freq;
	int16_t *buf;
	int32_t *mixbuf;
	
	uint8_t gv,mv;
	int32_t anticlick[2];
	float anticlick_f[2];
	
	uint16_t achn_count;
	sackit_pchannel_t pchn[64];
	sackit_achannel_t achn[SACKIT_MAX_ACHANNEL];
};

extern void (*(fnlist_itmixer[]))(sackit_playback_t *sackit, int offs, int len);

// objects.c
it_module_t *sackit_module_new(void);
void sackit_module_free(it_module_t *module);
it_module_t *sackit_module_load(const char *fname);
it_module_t *sackit_module_load_memory(const void *data, const long length);
it_module_t *sackit_module_load_offs(const char *fname, int fboffs);
void sackit_playback_free(sackit_playback_t *sackit);
void sackit_playback_reset2(sackit_playback_t *sackit, int buf_len, int achn_count,
	void (*f_mix)(sackit_playback_t *sackit, int offs, int len), int mixer_bytes, int freq);
void sackit_playback_reset(sackit_playback_t *sackit, int buf_len, int achn_count, int mixeridx);
sackit_playback_t *sackit_playback_new2(it_module_t *module, int buf_len, int achn_count,
	void (*f_mix)(sackit_playback_t *sackit, int offs, int len), int mixer_bytes, int freq);
sackit_playback_t *sackit_playback_new(it_module_t *module, int buf_len, int achn_count, int mixeridx);

// playroutine.c
extern int itmixer_bytes[];
void sackit_playback_update(sackit_playback_t *sackit);

