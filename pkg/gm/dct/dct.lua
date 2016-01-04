--[[
DCT + IDCT mod for Iceball

WARNING: This mod is covered by software patents.

Not that I actually know which ones, but due to the nature of this being
useful for any possible video application whatsoever, it's guaranteed to be covered
by some stupid bullshit patent that doesn't have any right to exist,
but exists anyway because the US govt are a bunch of fucking morons.

After all, it's a GPU implementation of a DCT in GLSL,
which is really fucking useful for video,
and oddly enough is what I intend to use it for eventually.

This means that it's probably covered by these hypothetical patents:

* Method for calculating a DCT on a GPU
* Method for calculating a DCT using GLSL
* Method for calculating a fast DCT
* Method for calculating a fast DCT on a GPU
* Method for calculating anything related to fourier transforms on a GPU
* Method for storing signed colour data in an 8bpc space
* Method for compressing (in the audio sense, not in the data sense) values into an 8bpc space 
* Method for compressing values into an 8bpc space, number two
* Method for compressing values into an 8bpc space, number three
* Method for converting between colourspaces on a GPU
* Method for running programs on a GPU, filed because the clerk at the patent office wasn't looking
* Method for calculating a DCT in a video game, on a GPU
* Method for calculating a DCT in a networked video game, on a GPU
* Method for sending a DCT algorithm over a network
* Method for sending a GLSL shader over a network
* And any apparatus for applying any of those methods.

So please, if you use this software, either:

* Ensure that you are in a country that doesn't give software patents any more respect than they deserve (read: none),

or:

* Don't tell IBM.

Thank you.

P.S. If you own any patents that covers this piece of software,
please let me know so I can work out how to make a modified version
that doesn't violate any of your patents.

P.P.S. No, I am not going to settle for a patent licensing deal.

]]

if not (USE_FBO and USE_GLSL_21) then return end

-- FBO spam
fbo_dct_apply1 = client.fbo_create(screen_width, screen_height, true)
fbo_dct_apply2 = client.fbo_create(screen_width, screen_height, false)
fbo_dct_unapply1 = client.fbo_create(screen_width, screen_height, false)
fbo_dct_unapply2 = client.fbo_create(screen_width, screen_height, false)

dofile("pkg/gm/dct/shaders.lua")
--dofile("pkg/gm/dct/shaders-130.lua") -- int-based, notably slower

function dct_apply_scene()
	if fbo_dct_apply1 then
		shader_dct_apply.set_uniform_i("tex0", 0)
		shader_dct_apply.set_uniform_f("smul", screen_width, screen_height)
		shader_dct_apply.set_uniform_f("smul_inv", 1.0/screen_width, 1.0/screen_height)

		client.fbo_use(fbo_dct_apply2)
		shader_dct_apply.set_uniform_f("is_init", 1.0)
		shader_dct_apply.set_uniform_f("is_fini", 0.0)
		shader_dct_apply.set_uniform_f("is_inverse", 0.0)
		shader_dct_apply.push()
		client.img_blit(fbo_dct_apply1, 0, 0)
		shader_dct_apply.pop()

		client.fbo_use(fbo_dct_unapply1)
		shader_dct_apply.set_uniform_f("is_init", 0.0)
		shader_dct_apply.set_uniform_f("is_fini", 0.0)
		shader_dct_apply.set_uniform_f("is_inverse", 0.0)
		shader_dct_apply.push()
		client.img_blit(fbo_dct_apply2, 0, 0)
		shader_dct_apply.pop()

		client.fbo_use(fbo_dct_unapply2)
		shader_dct_apply.set_uniform_f("is_init", 0.0)
		shader_dct_apply.set_uniform_f("is_fini", 0.0)
		shader_dct_apply.set_uniform_f("is_inverse", 1.0)
		shader_dct_apply.push()
		client.img_blit(fbo_dct_unapply1, 0, 0)
		shader_dct_apply.pop()

		client.fbo_use(nil)
		shader_dct_apply.set_uniform_f("is_init", 0.0)
		shader_dct_apply.set_uniform_f("is_fini", 1.0)
		shader_dct_apply.set_uniform_f("is_inverse", 1.0)
		shader_dct_apply.push()
		client.img_blit(fbo_dct_unapply2, 0, 0)
		shader_dct_apply.pop()

	end
end

do
	local s_hook_render = client.hook_render
	function client.hook_render(...)
		local s_fbo_use = client.fbo_use
		local is_using_nil = true
		local s_img_dump = client.img_dump
		function client.fbo_use(fbo, ...)
			if fbo == nil then
				is_using_nil = true
				return s_fbo_use(fbo_dct_apply1, ...)
			else
				is_using_nil = false
				return s_fbo_use(fbo, ...)
			end
		end

		function client.img_dump(...)
			if is_using_nil then s_fbo_use(nil) end
			local ret = {s_img_dump(...)}
			if is_using_nil then s_fbo_use(fbo_dct_apply1) end
			return unpack(ret)
		end

		s_fbo_use(fbo_dct_apply1)

		s_hook_render()

		client.fbo_use = s_fbo_use
		client.img_dump = s_img_dump

		dct_apply_scene()
		s_fbo_use(fbo_dct_apply1)
	end
end
