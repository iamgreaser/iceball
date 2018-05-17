#include "sackit_internal.h"

// IT211 mixer
#define MIXER_NAME sackit_playback_mixstuff_it211
#define MIXER_VER 211
#include "mixer_int.h"
#undef MIXER_NAME

#define MIXER_NAME sackit_playback_mixstuff_it211s
#define MIXER_STEREO
#include "mixer_int.h"
#undef MIXER_STEREO
#undef MIXER_NAME
#undef MIXER_VER

// IT211 mixer, interpolated
#define MIXER_INTERP_LINEAR
#define MIXER_NAME sackit_playback_mixstuff_it211l
#define MIXER_VER 211
#include "mixer_int.h"
#undef MIXER_NAME

#define MIXER_NAME sackit_playback_mixstuff_it211ls
#define MIXER_STEREO
#include "mixer_int.h"
#undef MIXER_STEREO
#undef MIXER_NAME
#undef MIXER_VER
#undef MIXER_INTERP_LINEAR

// IT212 mixer: IT211 with an anticlick filter for note cuts
#define MIXER_NAME sackit_playback_mixstuff_it212
#define MIXER_VER 212
#define MIXER_ANTICLICK
#include "mixer_int.h"
#undef MIXER_NAME

#define MIXER_NAME sackit_playback_mixstuff_it212s
#define MIXER_STEREO
#include "mixer_int.h"
#undef MIXER_STEREO
#undef MIXER_NAME
#undef MIXER_ANTICLICK
#undef MIXER_VER

// IT212 mixer, interpolated
#define MIXER_NAME sackit_playback_mixstuff_it212l
#define MIXER_VER 212
#define MIXER_ANTICLICK
#define MIXER_INTERP_LINEAR
#include "mixer_float.h"
#undef MIXER_NAME

#define MIXER_NAME sackit_playback_mixstuff_it212ls
#define MIXER_STEREO
#include "mixer_float.h"
#undef MIXER_STEREO
#undef MIXER_NAME
#undef MIXER_ANTICLICK
#undef MIXER_VER
#undef MIXER_INTERP_LINEAR

// IT214 mixer: floating point mixer
#define MIXER_NAME sackit_playback_mixstuff_it214
#define MIXER_VER 214
#define MIXER_ANTICLICK
#include "mixer_float.h"
#undef MIXER_NAME

#define MIXER_NAME sackit_playback_mixstuff_it214s
#define MIXER_STEREO
#include "mixer_float.h"
#undef MIXER_STEREO
#undef MIXER_NAME
#undef MIXER_ANTICLICK
#undef MIXER_VER

// IT214 mixer, interpolated linearly
#define MIXER_FILTERED
#define MIXER_NAME sackit_playback_mixstuff_it214l
#define MIXER_VER 214
#define MIXER_ANTICLICK
#define MIXER_INTERP_LINEAR
#include "mixer_float.h"
#undef MIXER_NAME

#define MIXER_NAME sackit_playback_mixstuff_it214ls
#define MIXER_STEREO
#include "mixer_float.h"
#undef MIXER_STEREO
#undef MIXER_NAME
#undef MIXER_ANTICLICK
#undef MIXER_VER
#undef MIXER_INTERP_LINEAR

// IT214 mixer, interpolated cubically
#define MIXER_NAME sackit_playback_mixstuff_it214c
#define MIXER_VER 214
#define MIXER_ANTICLICK
#define MIXER_INTERP_CUBIC
#include "mixer_float.h"
#undef MIXER_NAME

#define MIXER_NAME sackit_playback_mixstuff_it214cs
#define MIXER_STEREO
#include "mixer_float.h"
#undef MIXER_STEREO
#undef MIXER_NAME
#undef MIXER_ANTICLICK
#undef MIXER_VER
#undef MIXER_INTERP_CUBIC

// IT214p3 mixer: resonant filter mixer
#define MIXER_NAME sackit_playback_mixstuff_it214f
#define MIXER_VER 214
#define MIXER_ANTICLICK
#include "mixer_float.h"
#undef MIXER_NAME

#define MIXER_NAME sackit_playback_mixstuff_it214fs
#define MIXER_STEREO
#include "mixer_float.h"
#undef MIXER_STEREO
#undef MIXER_NAME
#undef MIXER_ANTICLICK
#undef MIXER_VER

// IT214p3 mixer, interpolated linearly
#define MIXER_NAME sackit_playback_mixstuff_it214fl
#define MIXER_VER 214
#define MIXER_ANTICLICK
#define MIXER_INTERP_LINEAR
#include "mixer_float.h"
#undef MIXER_NAME

#define MIXER_NAME sackit_playback_mixstuff_it214fls
#define MIXER_STEREO
#include "mixer_float.h"
#undef MIXER_STEREO
#undef MIXER_NAME
#undef MIXER_ANTICLICK
#undef MIXER_VER
#undef MIXER_INTERP_LINEAR

// IT214p3 mixer, interpolated cubically
#define MIXER_NAME sackit_playback_mixstuff_it214fc
#define MIXER_VER 214
#define MIXER_ANTICLICK
#define MIXER_INTERP_CUBIC
#include "mixer_float.h"
#undef MIXER_NAME

#define MIXER_NAME sackit_playback_mixstuff_it214fcs
#define MIXER_STEREO
#include "mixer_float.h"
#undef MIXER_STEREO
#undef MIXER_NAME
#undef MIXER_ANTICLICK
#undef MIXER_VER
#undef MIXER_INTERP_CUBIC
#undef MIXER_FILTERED

// Fast integer mixer, anticlick
#define MIXER_NAME sackit_playback_mixstuff_intfast_a
#define MIXER_VER 212
#define MIXER_ANTICLICK
#include "mixer_int_fast.h"
#undef MIXER_NAME

#define MIXER_NAME sackit_playback_mixstuff_intfast_as
#define MIXER_STEREO
#include "mixer_int_fast.h"
#undef MIXER_STEREO
#undef MIXER_NAME
#undef MIXER_ANTICLICK
#undef MIXER_VER

