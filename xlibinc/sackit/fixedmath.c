#include "sackit_internal.h"

uint32_t sackit_mul_fixed_16_int_32(uint32_t a, uint32_t b)
{
	/*uint32_t al = (uint16_t)(a&0xFFFF);
	uint32_t bl = (uint16_t)(b&0xFFFF);
	uint32_t ah = (uint16_t)(a>>16);
	uint32_t bh = (uint16_t)(b>>16);
	
	return ((al*bl)>>16)
		+ (bl*ah+bh*al)
		+ ((bh*ah)<<16);*/
	
	
	uint64_t aq = a;
	uint64_t bq = b;
	uint64_t rq = (((uint64_t)aq)*((uint64_t)bq))>>(uint64_t)16;
	
	return (uint32_t)rq;
}

uint32_t sackit_div_int_32_32_to_fixed_16(uint32_t a, uint32_t b)
{
	/*
	a  = q * b + r
	a  = ah * 2^16 + al
	ah = qh * b + rh
	al + K = ql * b + rl
	al = ql * b + rl - K
	
	a  = (qh * b + rh) * 2^16 + ql * b + rl - K
	a  = (qh * 2^16 * b) + rh * 2^16 + ql * b + rl - K
	a  = (qh * 2^16 + ql) * b + rh * 2^16 + rl - K
	
	the problem here is that rh * 2^16 is probably > b.
	setting K to 0, then defining L creatively:
	a  = (qh * 2^16 + ql + L) * b + (rh * 2^16 + rl - L*b)
	
	we need (rh * 2^16 + rl) / b for an integer.
	L = (rh * 2^16 + rl) / b.
	this means:
	(rh * 2^16 + rl) = L * b + Lr.
	
	so we're aiming for
	a  = (qh * 2^16 + ql + L) * b + (L*b + Lr - L*b)
	a  = (qh * 2^16 + ql + L) * b + Lr
	
	This doesn't really demonstrate much.
	
	*/
	/*uint32_t al = (uint32_t)(a<<16);
	uint32_t ah = (uint32_t)(a&0xFFFF0000);
	
	uint32_t rh = ah%b;
	uint32_t qh = ah/b;
	uint32_t ql = (al+(rh<<16))/b;
	*/
	
	// and here's the easy way out.
	uint64_t aq = a;
	uint64_t bq = b;
	uint64_t rq = (((uint64_t)aq)<<(uint64_t)16)/((uint64_t)bq);
	
	return (uint32_t)rq;
	
	//printf("%i %i / %i -> %i %i %i\n"
	//	,al,ah,b,rh,qh,ql
	//);
	//return ql+(qh<<16);
	//return (a<<16)/b;
}
