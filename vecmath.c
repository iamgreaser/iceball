#include "common.h"

void cam_point_dir(model_t *model, float dx, float dy, float dz)
{
	// Another case where I'd copy-paste code from my aimbot.
	// Except the last time I did it, I redid it from scratch,
	// and then dumped it. (VUW COMP308 Project 2012T2, anyone?)
	//
	// But yeah, basically this code's useful for making aimbots >:D
	//
	// Am I worried?
	// Well, the average skid is too lazy to compile this.
	// So, uh, no, not really.
	
	// Get two distance values.
	float d2 = dx*dx+dz*dz;
	float d3 = dy*dy+d2;
	
	// Square root them so they're actually distance values.
	d2 = sqrtf(d2);
	d3 = sqrtf(d3);
	
	
	// Now build that matrix!
	
	// Front vector (Z): Well, duh.
	model->mzx = dx/d3;
	model->mzy = dy/d3;
	model->mzz = dz/d3;
	
	// Left (TODO: confirm) vector (X): Simple 2D 90deg rotation.
	// Can be derived from a bit of trial and error.
	model->mxx = dz/d3;
	model->mxy = dy/d3;
	model->mxz = -dx/d3;
	
	// Down vector (Y): STUPID GIMBAL LOCK GRR >:(
	// But really, this one's the hardest of them all.
	//
	// I decided to cheat and look at my aimbot anyway.
	// Still doesn't quite solve my problem :(
	model->myx = dx*dy/(d2*d3);
	model->myy = sqrtf(1.0f - dy*dy/d3*d3);
	model->myz = dz*dy/(d2*d3);
}
