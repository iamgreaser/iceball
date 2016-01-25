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

// Basic implementation of the PCG psuedorandom number generator.
// Specifically, PCG-XSH-RR, as that's what the paper recommends for general use.
// This may diverge from the official implementations, but I wanted to give credit.
// TODO: We could drop the stream part and use a set value. It's useful for seeding
// a new PRNG from an existing one's output, but if people just want random seeds,
// we can seed from time.
// On the other hand, using a set value does allow us to ensure that a relatively
// good value is chosen (co-primes, etc.).

#define PRNG_MULTIPLIER 6364136223846793005ULL

void prng_seed(prng_t *rng, uint64_t seed, uint64_t stream) {
	rng->state = 0;
	// This must be odd (although it will still work sub-optimally if even)
	rng->stream = (stream << 1) | 1;
	// Initialise the state
	prng_random(rng);
	rng->state += seed;
	// Properly initialise the state (diverge the streams)
	prng_random(rng);
}

uint32_t prng_random(prng_t *rng) {
	uint64_t state = rng->state;

	// Update stored state
	rng->state = state * PRNG_MULTIPLIER + rng->stream;

	// Generate number
	// Top 5 bits specify rotation (for 32 bit result):
	//   * 64 - 5 = 59
	//   * 32 - 5 = 27
	//   * (5 + 32) / 2 = 18
	uint32_t xor_shifted = (uint32_t)(((state >> 18) ^ state) >> 27);
	uint32_t rotation = (uint32_t)(state >> 59);
	return (xor_shifted >> rotation) | (xor_shifted << (-rotation & 31));
}

double prng_random_double(prng_t *rng) {
	uint32_t random = prng_random(rng);
	return (double)random / UINT32_MAX;
}

double prng_random_double_range(prng_t *rng, double minimum, double maximum) {
	uint32_t random = prng_random(rng);
	double d = (double)random / UINT32_MAX;
	return minimum + d * (maximum - minimum);
}

// Magical maths thanks to Forrest B. Brown, "Random number Generation with Arbitrary Strides"
void prng_jump(prng_t *rng, uint64_t step) {
	uint64_t m_result = 1;
	uint64_t c_result = 0;
	uint64_t stream = rng->stream;
	uint64_t multiplier = PRNG_MULTIPLIER;
	while (step > 0) {
		if (step & 1) {
			m_result *= multiplier;
			c_result = c_result * multiplier + stream;
		}
		stream = (multiplier + 1) * stream;
		multiplier *= multiplier;
		step >>= 1;
	}
	rng->state = m_result * rng->state + c_result;
}
