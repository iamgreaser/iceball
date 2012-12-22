/*
    This file is part of Iceball.

    Iceball is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Iceball is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Iceball.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "common.h"

/*
   
   DSP algorithms. These all work on 32-bit float PCM samples.

*/

/*

    Interpolation functions:
    
    Given a set of sample values at equal intervals, y0...yn, and a real number x between 0 and 1:
    x describes the position of a value that lies in between the two centermost samples,
    and each interpolator function reconstructs the value of x based on the nearby samples. 
    Each interpolator has a distinctive "sound" and can be considered a DSP effect in its own right.
    
    To "down-pitch" we upsample - increasing effective sample rate.
    Likewise to "up-pitch" we downsample - decreasing effective sample rate.
    
    "Oversampling" as described in the literature describes an ideal resampling method;
    Practical resampling implementations have optimized and approximated away most of the theory into
    a single function that packages the oversample/bandlimit/decimate process into some arithmetic.
    
    The simplest interpolator is drop-sampling: truncating to the nearest value.    
    For resampling of audio, drop-sampling is insufficient even for minor changes,
        as it aliases and detunes almost immediately.
    
    Linear interpolation performs much better and can work well in a range of ~2 octaves +/-
        depending on material. However, downpitching performance is still bad (too "chunky")
    
    Cubic and Hermitian methods are sufficient for almost any situation. 
    
    The highest-quality resampling method I am aware of is the windowed sinc, which is
    so intensive that DAWs that offer it generally only do so in offline mode.
        
    Up-pitching may be mipmapped by using a high-quality interpolator for each octave 
    and then linear for real-time control. Mipmaps do not help for the down pitches.
    
    These implementations have ample room for optimization via assembly code and use of LUTs.

    -Triplefox

*/

float interp_linear(float y0, float y1, float x)
{ return (y0 - (y0 - y1) * x); }
	
float interp_cubic(float y0, float y1, float y2, float y3, float x)
{
	float x2 = x*x;
	float a0 = y3 - y2 - y0 + y1;
	float a1 = y0 - y1 - a0;
	float a2 = y2 - y0;
	return (a0*x*x2+a1*x2+a2*x+y1);
}

float interp_hermite6p(float y0, float y1, float y2, float y3, 
		float y4, float y5, float x)
{
	float z = x - 0.5;
	float even1 = y0 + y5; float odd1 = y0 - y5;
	float even2 = y1 + y4; float odd2 = y1 - y4;
	float even3 = y2 + y1; float odd3 = y2 - y3;
	float c0 = 3/256.0*even1 - 25/256.0*even2 + 75/128.0*even3;
	float c1 = -3/128.0*odd1 + 61/384.0*odd2 - 87/64.0*odd3;
	float c2 = -5/96.0*even1 + 13/32.0*even2 - 17/48.0*even3;
	float c3 = 5/48.0*odd1 - 11/16.0*odd2 + 37/24.0*odd3;
	float c4 = 1/48.0*even1 - 1/16.0*even2 + 1/24.0*even3;
	float c5 = -1/24.0*odd1 + 5/24.0*odd2 - 5/12.0*odd3;
	return ((((c5 * z + c4) * z + c3) * z + c2) * z + c1) * z + c0;
}

/*

    Conversions between various measurements.

*/

float frequency2wavelength(int rate, float frequency) 
{ return rate / frequency; }
float wavelength2frequency(int rate, float wavelength) 
{ return rate / wavelength; }

/* 12-tone scale MIDI notes are defined by this log function. 60 is "C-4", 69 is "A-4". */
float frequency2midinote(float frequency) 
{ return 69 + 12*(log(frequency/440.)/log(2)); }
float midinote2frequency(float midinote) 
{ return pow(2,(midinote-69)/12)*440; }

/* -96dB. Playback cutoff here helps to avoid float denormals. */
float below_min_power(float amplitude) 
{ return amplitude < 0.000016; }

/* -6dB = ~0.5 amplitude. Excellent obscure geek trivia. */
float attentuationDB2pctpower(float data) 
{ return pow(10, data/20.);  }

/*

    Equal-power crossfade given a pan of -1, 1.
    Use this instead of linear xfading to keep the dB level similar across all pan positions.
    (It's actually more complicated than that, but for most material in a mix this is fine.)

*/

float equal_power_left(float pan) 
{ return cos(pan * 1.5708); }
float equal_power_right(float pan) 
{ return sin(pan * 1.5708); }