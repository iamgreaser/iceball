sackit is an .it format player that strives for sample accuracy.
Currently it's not quite there for any tests,
  but does come pretty close ignoring volume ramping.

IT 2.14p5 is what we're targetting right now.
- IT 2.11 is the first version with a .wav writer.
  - It hasn't really changed since the first .raw writer in IT206.
- IT v2.12 introduces anticlick into the .wav writer, which adds complexity.
  - As I have found out, it also adjusts the volume ramping timing.
    For 44kHz, 2.11 uses 89 samples, while 2.12 uses 111 samples.
    This appears to be 1/500 of a second for 2.11 and 1/400 for 2.12.
- IT v2.13 uses logarithmic vol ramping and quadratic interp.
  - I didn't really notice much difference with gm-pants.it.
- IT v2.14 COMPLETELY SCREWS EVERYTHING OVER,
    as it switches to a cubic-spline *FLOATING-POINT* mixer.
  - It also appears to double the volume in mono mode to match stereo mode volumes.
- IT v2.14 patch 3 does LOTS OF THINGS:
  - Hey guys, I'm a resonant filter!
    - Not much of an issue as I've seen the actual ASM source code Jeff released,
      although it's for the A,B,C coefficient stuff, not the actual mixing.
    - No really, this isn't much of an issue. The cubic interp needs work, though.
      - Although it also buggers up the anticlick a bit.
  - "Time accuracy improved"...
    - I think this means I can't just do (int)((mixfreq*4)/(tempo*10)).
    - ...it might actually refer to the volume ramping being SUBTLY different.
- IT v2.14 patch 4 introduces a 4 band EQ.
  - This means more bloody reverse engineering.
  - Yes, patch 4 actually existed. I don't have it though, but p5 should be the same.
  - Actually, after having done testing, there's VERY little difference.
    It might even be a source of variance:
      I noticed differences of what I think was exactly one sample, every now and then,
      with a very small difference.

So, the status of things, which is probably out of date:
- Tiny bit of +/- 1 per channel noise (for 2.11 / 2.12).
- Volume ramping isn't quite right (the length is correct for all versions, though. I think.).
- Anticlick is implemented. Not perfect though.
- Haven't quite got the right Amiga base clock, so slides tend to be off slightly.
  - This has been improved, but still gets it wrong every now and then.
- Vibrato works perfectly where it doesn't retrigger, at least wrt linear slides.
- IT214/215 decompression IS NOW IMPLEMENTED, YAY
- Sanity checks are lacking - it's pretty easy to crash it.
- Not many effects are implemented.
- Instruments are finally supported, though envelopes need work wrt sample-accuracy.
  - NNAs are in place. DCAs are, too, althought they need work.
  - Will abort() if you exhaust all 256 virtual channels at the moment.
- RESONANT FILTERS YAAAAAAAAY
- Envelope carry flag is somewhat implemented, with some Compat Gxx mode retrig happening.

If you'd like to test this,
- see if you can get ImpulseTracker 2.14p5 from somewhere (it214v5.zip)
- open DOSBox, core dynamic, cycles max, it /s20 /m44100
- open the IT module and play it with that wavewriter
- compare the module and the wav file with ./sackit_compare

If your test uses IT214-compressed samples (this pertains to testing pre-2.14 versions),
- open it up in IT >=2.14 (it214v5.zip should be fine)
- resave it as "IT2xx" (as opposed to "IT214")

AUTHORS:
  2012-2013 Ben "GreaseMonkey" Russell.

LICENCE:
  Public domain. I'm sick of people using libmikmod/libmodplug. THEY BOTH SUCK.

