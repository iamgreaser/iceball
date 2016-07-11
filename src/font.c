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

#define STB_RECT_PACK_IMPLEMENTATION
#include "stb_rect_pack.h"

#ifdef USE_FREETYPE
#include <freetype/freetype.h>
#else
#define STB_TRUETYPE_IMPLEMENTATION
#include "stb_truetype.h"
#endif

// size of glyph pages (too small means more texture switching, too big means
// slow sampling)
#define FONT_GLYPH_PAGE_WIDTH  512
#define FONT_GLYPH_PAGE_HEIGHT 512
// default glyph capacity for a font instance
#define FONT_GLYPH_COUNT_DEFAULT 256
// padding for individual glyphs, useful for bilinear filtering
#define FONT_GLYPH_PADDING 0
// packing options for stb_rect_pack, should be higher than
// FONT_GLYPH_COUNT_DEFAULT as it is constant during runtime
#define FONT_PACK_NODES_COUNT 512
// default size for the buffer where we rasterize glyphs to, not too important
#define FONT_BITMAP_BUF_LEN_DEFAULT 512
// the max number of glyph in *one* draw call
#define FONT_MAX_DRAW_GLYPHS 1024
// how many vertices
#define FONT_VERTEX_BUFFER_CAPACITY (FONT_MAX_DRAW_GLYPHS * 4)
// .. and indices
#define FONT_INDEX_BUFFER_CAPACITY (FONT_MAX_DRAW_GLYPHS * 6)
// max amt of buffered draw calls (useful?)
#define FONT_MAX_DRAW_CALLS 64

// can we not..
#ifndef DEDI
static font_page_t *new_font_page(unsigned int width, unsigned int height, unsigned int node_count);
#endif

#ifdef USE_FREETYPE
static FT_Library lib;
#endif

bool font_parse_ttf(font_t *fnt, const char *buf, int len)
{
	fnt->udtype = UD_FNT_TTF;
	fnt->data = buf;

#ifdef USE_FREETYPE
	// create a FT_Library if there is none

	if (!lib) {
		if (FT_Init_FreeType(&lib) != FT_Err_Ok) {
			return false;
		}
	}

	if (FT_New_Memory_Face(lib, buf, len, 0, &fnt->face) != FT_Err_Ok) {
		return false;
	}

#else
	if (!stbtt_InitFont(&fnt->info, fnt->data, 0)) {
		return false;
	}
#endif

#ifndef DEDI
	int ascent, descent, line_gap;

#ifdef USE_FREETYPE
    ascent = fnt->face->ascender;
	descent = fnt->face->descender;
	line_gap = fnt->face->height;
#else
	stbtt_GetFontVMetrics(&fnt->info, &ascent, &descent, &line_gap);
#endif
	int fh = ascent - descent;
	fnt->ascent = (float)ascent / (float)fh;
	fnt->descent = (float)descent / (float)fh;
	fnt->line_height = (float)(fh + line_gap) / (float)fh;

	fnt->page_chain = new_font_page(
		FONT_GLYPH_PAGE_WIDTH,
		FONT_GLYPH_PAGE_HEIGHT,
		FONT_PACK_NODES_COUNT);

	fnt->glyphs = calloc(FONT_GLYPH_COUNT_DEFAULT, sizeof(font_glyph_t));
	fnt->glyph_count = 0;
	fnt->glyph_capacity = FONT_GLYPH_COUNT_DEFAULT;
	fnt->glyph_data_buf_len = FONT_BITMAP_BUF_LEN_DEFAULT;
	fnt->glyph_data_buf = malloc(FONT_BITMAP_BUF_LEN_DEFAULT);
#endif

	return true;
}

bool font_load_ttf(font_t *fnt, const char *fname)
{
	int len;
	char *buf = net_fetch_file(fname, &len);
	if (!buf)
		return NULL;

	if (!font_parse_ttf(fnt, buf, len)) {
		free(buf);
		return false;
	}

	return true;
}

#ifndef DEDI
// a draw call is defined as a range of vertices + a texture name. when drawing
// a string and a glyph uses a different page than the previous, it creates a
// draw call using the amount of vertices since the last draw call was submitted
// and the previous glyph's texture name
typedef struct draw_call {
	GLuint page;
	GLuint len;
} draw_call_t;

// the vertex format for glyphs is 8 floats (32 bytes).
// there might be some room for improvement, but for now this aligns to a nice
// number and covers all needs
//
//     TODO: add sampler name, could reduce amount of draw calls
//     TODO: add z?
#pragma pack(push, 1)
typedef struct font_vertex {
	GLfloat x, y;
	GLfloat s, t;
	GLfloat r, g, b, a;
} font_vertex_t;
#pragma pack(pop)

// render implementation, not tied to any instance
// client-side memory for holding vertices to be uploaded
static font_vertex_t *glyph_vertex_buffer;
// amount of vertices in `glyph_vertex_buffer`
static GLuint data_len = 0;

// static indices for rendering quads
static GLuint quad_indices = 0;
// dynamic/stream vbo for rendering the glyphs
static GLuint quad_vbo = 0;

// amount of draw calls buffered
static GLuint draw_count = 0;
// buffer of draw calls to be executed
static draw_call_t draw_calls[FONT_MAX_DRAW_CALLS] = {{0}};

static void init_buffers()
{
	glyph_vertex_buffer = malloc(sizeof(font_vertex_t) * FONT_VERTEX_BUFFER_CAPACITY);

	glGenBuffers(1, &quad_vbo);
	glBindBuffer(GL_ARRAY_BUFFER, quad_vbo);
	glBufferData(
			GL_ARRAY_BUFFER,
			sizeof(*glyph_vertex_buffer) * FONT_VERTEX_BUFFER_CAPACITY,
			NULL,
			GL_STREAM_DRAW);

	uint16_t *indices = malloc(sizeof(uint16_t) * FONT_INDEX_BUFFER_CAPACITY);

	int i = 0, index = 0;
	while (i + 6 < FONT_INDEX_BUFFER_CAPACITY) {
		indices[i + 0] = index + 0;
		indices[i + 1] = index + 1;
		indices[i + 2] = index + 2;

		indices[i + 3] = index + 0;
		indices[i + 4] = index + 2;
		indices[i + 5] = index + 3;

		i += 6;
		index += 4;
	}

	glGenBuffers(1, &quad_indices);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, quad_indices);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(uint16_t) * FONT_INDEX_BUFFER_CAPACITY, indices, GL_STATIC_DRAW);

	free(indices);
}

// loaded glyphs are stored in a hash table using double hashing. glyphs are
// identified as a tuple of the codepoint + size. furthermore, the hash table's
// size must always be a multiple of 2, as we take advantage of the fact that
// the second hash function is odd to loop over all the slots in the table.
//
//     TODO: make hash funcs more compact
static inline uint32_t hash_key(uint32_t codepoint, uint16_t size)
{
	// we combine codepoint + size
	uint32_t hash = ((codepoint + size) * (codepoint + size + 1)) / 2 + size;
	return hash * 2654435761;
}

static inline uint32_t double_hash_key(uint32_t codepoint, uint16_t size)
{
	// stride needs to be odd so we go over all glyphs when we do modulo
	return (hash_key(codepoint, size) * 2) | 1;
}

static font_page_t *new_font_page(unsigned int width, unsigned int height, unsigned int node_count)
{
	font_page_t *page = malloc(sizeof(*page));
	page->pack_cxt = malloc(sizeof(stbrp_context));
	page->nodes = malloc(node_count * sizeof(stbrp_node));
	stbrp_init_target(page->pack_cxt, width, height, page->nodes, node_count);

	glBindTexture(GL_TEXTURE_2D, 0);
	glGenTextures(1, &page->texture);
	glBindTexture(GL_TEXTURE_2D, page->texture);

	// we use GL_ALPHA because we're stuck in legacy GL for now, but if/when we
	// do switch, we should use GL_RED and swizzle the channels in a shader
	// instead.
	//
	// TODO(fkaa): change formats when we go core

	glTexImage2D(GL_TEXTURE_2D, 0, GL_ALPHA, width, height, 0, GL_ALPHA, GL_UNSIGNED_BYTE, NULL);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

	page->next = NULL;

	return page;
}

static void font_page_free(font_page_t *page)
{
	glDeleteTextures(1, &page->texture);
	free(page->pack_cxt);
	free(page->nodes);
	free(page);
}

bool font_add_glyph(font_t *fnt, uint32_t codepoint, uint16_t size, int *off)
{
	// expand when necessary
	if (fnt->glyph_count + 1 >= fnt->glyph_capacity) {
		int old_capacity = fnt->glyph_capacity;

		fnt->glyph_capacity <<= 1;
		font_glyph_t *glyphs = calloc(fnt->glyph_capacity, sizeof(*glyphs));

		for (int i = 0; i < old_capacity; ++i) {
			// rehash according to the new size when we find an old one
			if (fnt->glyphs[i].page) {
				uint32_t ocp = fnt->glyphs[i].codepoint;
				uint16_t osz = fnt->glyphs[i].size;

				uint32_t offset = hash_key(ocp, osz) % fnt->glyph_capacity;
				uint32_t stride = double_hash_key(ocp, osz) % fnt->glyph_capacity;

				while (fnt->glyphs[offset].page != NULL) {
					offset = (offset + stride) % fnt->glyph_capacity;
				}

				glyphs[offset] = fnt->glyphs[i];
			}
		}

		free(fnt->glyphs);
		fnt->glyphs = glyphs;
	}

	uint32_t offset = hash_key(codepoint, size) % fnt->glyph_capacity;
	uint32_t stride = double_hash_key(codepoint, size) % fnt->glyph_capacity;

	while (fnt->glyphs[offset].page != NULL) {
		// if glyph + size exists, return
		if (fnt->glyphs[offset].codepoint == codepoint &&
			fnt->glyphs[offset].size == size) {
			return false;
		}

		// else we probe until we find a empty spot
		offset = (offset + stride) % fnt->glyph_capacity;
	}

	if (off)
		*off = offset;

	int x0, y0, x1, y1;
	int advance, left_side_bearing;
	int glyph_index;
	int glyph_width;
	int glyph_height;

#ifdef USE_FREETYPE
    FT_Set_Pixel_Sizes(fnt->face, 0, size);
	glyph_index = FT_Get_Char_Index(fnt->face, codepoint);

	if (!glyph_index) {
		return false;
	}

	FT_Load_Glyph(fnt->face, glyph_index, FT_LOAD_RENDER);
	FT_GlyphSlot g = fnt->face->glyph;
	advance = g->advance.x >> 6;
	left_side_bearing = g->lsb_delta >> 6;
	x0 = g->bitmap_left;
	y0 = g->bitmap_top;
	x1 = g->bitmap.width;
	y1 = g->bitmap.rows;
	glyph_width = g->bitmap.width;
	glyph_height = g->bitmap.rows;
#else
	float scale = stbtt_ScaleForMappingEmToPixels(&fnt->info, (float)size);
	glyph_index = stbtt_FindGlyphIndex(&fnt->info, codepoint);
	if (!glyph_index) {
		return false;
	}

	stbtt_GetGlyphHMetrics(&fnt->info, glyph_index, &advance, &left_side_bearing);
	stbtt_GetGlyphBitmapBox(&fnt->info, glyph_index, scale, scale, &x0, &y0, &x1, &y1);
	glyph_width = x1 - x0;
	glyph_height = y1 - y0;
	advance *= scale;
	left_side_bearing *= scale;
	y0 = -y0;
#endif

	struct stbrp_rect glyph_rect = {0};
	glyph_rect.w = glyph_width + FONT_GLYPH_PADDING * 2;
	glyph_rect.h = glyph_height + FONT_GLYPH_PADDING * 2;

	// we loop over all pages to try and pack glyph
	font_page_t *prev = fnt->page_chain;
	for (font_page_t *page = prev;
		 	page != NULL;
		 	page = page->next)
	{
		prev = page;

		stbrp_pack_rects(page->pack_cxt, &glyph_rect, 1);

		if (glyph_rect.was_packed)
			break;
	}

	// if we weren't able to pack glyph, create new page
	if (!glyph_rect.was_packed) {
		font_page_t *new_page = new_font_page(
				FONT_GLYPH_PAGE_WIDTH,
				FONT_GLYPH_PAGE_HEIGHT,
				FONT_GLYPH_PAGE_HEIGHT);

		stbrp_pack_rects(new_page->pack_cxt, &glyph_rect, 1);

		// .. and update page chain
		prev->next = new_page;
		prev = new_page;
	}

	font_glyph_t glyph;
	glyph.page = prev;
	glyph.glyph_idx = glyph_index;
	glyph.codepoint = codepoint;
	glyph.size = size;
	glyph.x = glyph_rect.x;
	glyph.y = glyph_rect.y;
	glyph.width = glyph_width;
	glyph.height = glyph_height;
	glyph.lsb = left_side_bearing;
	glyph.x_advance = advance;
	glyph.x_offset = x0;
	glyph.y_offset = y0;

	fnt->glyphs[offset] = glyph;
	fnt->glyph_count++;

#ifndef USE_FREETYPE
	// resize raster buffer if too small
	if (fnt->glyph_data_buf_len < glyph_width * glyph_height) {
		free(fnt->glyph_data_buf);
		fnt->glyph_data_buf = malloc(glyph_width * glyph_height);
	}

	// rasterize glyph
	stbtt_MakeGlyphBitmap(
			&fnt->info,
			fnt->glyph_data_buf, // scratch buffer
			glyph_width, glyph_height, // w, h
			glyph_width, // row_len
			scale, scale, // scale x, y
			glyph_index);
#endif

	// .. and upload to the texture page we packed it to earlier
	glBindTexture(GL_TEXTURE_2D, prev->texture);
	glPixelStorei(GL_UNPACK_ALIGNMENT,1);

#ifdef USE_FREETYPE
	glTexSubImage2D(
			GL_TEXTURE_2D,
			0,
			glyph.x + FONT_GLYPH_PADDING, glyph.y + FONT_GLYPH_PADDING,
			glyph_width, glyph_height,
			GL_ALPHA,
			GL_UNSIGNED_BYTE,
			g->bitmap.buffer);
#else
	glTexSubImage2D(
			GL_TEXTURE_2D,
			0,
			glyph.x + FONT_GLYPH_PADDING, glyph.y + FONT_GLYPH_PADDING,
			glyph_width, glyph_height,
			GL_ALPHA,
			GL_UNSIGNED_BYTE,
			fnt->glyph_data_buf);
#endif
	return true;
}

int font_get_glyph(font_t *fnt, uint32_t codepoint, uint16_t size, font_glyph_t *out)
{
	uint32_t offset = hash_key(codepoint, size) % fnt->glyph_capacity;
	uint32_t stride = double_hash_key(codepoint, size) % fnt->glyph_capacity;

	while (fnt->glyphs[offset].page != NULL) {
		if (fnt->glyphs[offset].codepoint == codepoint &&
				fnt->glyphs[offset].size == size) {
			*out = fnt->glyphs[offset];
			return offset;
		}

		offset = (offset + stride) % fnt->glyph_capacity;
	}

	// if glyph + size doesn't exist, try and create it
	if (font_add_glyph(fnt, codepoint, size, &offset)) {
		*out = fnt->glyphs[offset];
		return offset;
	}

	return -1;
}

// Copyright (c) 2008-2009 Bjoern Hoehrmann <bjoern@hoehrmann.de>
// See http://bjoern.hoehrmann.de/utf-8/decoder/dfa/ for details.

#define UTF8_ACCEPT 0
#define UTF8_REJECT 1

static const uint8_t utf8d[] = {
		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 00..1f
		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 20..3f
		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 40..5f
		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 60..7f
		1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9, // 80..9f
		7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7, // a0..bf
		8,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, // c0..df
		0xa,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x4,0x3,0x3, // e0..ef
		0xb,0x6,0x6,0x6,0x5,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8, // f0..ff
		0x0,0x1,0x2,0x3,0x5,0x8,0x7,0x1,0x1,0x1,0x4,0x6,0x1,0x1,0x1,0x1, // s0..s0
		1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,0,1,0,1,1,1,1,1,1, // s1..s2
		1,2,1,1,1,1,1,2,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1, // s3..s4
		1,2,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,3,1,3,1,1,1,1,1,1, // s5..s6
		1,3,1,1,1,1,1,3,1,3,1,1,1,1,1,1,1,3,1,1,1,1,1,1,1,1,1,1,1,1,1,1, // s7..s8
};

static uint32_t inline decode(uint32_t* state, uint32_t* codep, uint32_t byte) {
	uint32_t type = utf8d[byte];

	*codep = (*state != UTF8_ACCEPT) ?
			(byte & 0x3fu) | (*codep << 6) :
			(0xff >> type) & (byte);

	*state = utf8d[256 + *state*16 + type];
	return *state;
}

static void font_draw_flush()
{
	if (draw_count == 0)
		return;

	glBindBuffer(GL_ARRAY_BUFFER, quad_vbo);
	glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(*glyph_vertex_buffer) * data_len, glyph_vertex_buffer);

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, quad_indices);

	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glEnableClientState(GL_COLOR_ARRAY);

	glVertexPointer(2, GL_FLOAT, sizeof(font_vertex_t), 0);
	glTexCoordPointer(2, GL_FLOAT, sizeof(font_vertex_t), (const void *) (2 * sizeof(GLfloat)));
	glColorPointer(4, GL_FLOAT, sizeof(font_vertex_t), (const void *) (4 * sizeof(GLfloat)));

	// TODO: we need a better (unified) way to draw 2d geometry
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	glOrtho(0, screen_width, screen_height, 0, -1, 1);

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_TEXTURE_2D);
	glActiveTexture(GL_TEXTURE0);
	glEnable(GL_ALPHA_TEST);

	// TODO: do we have side-effects here?
	glAlphaFunc(GL_GREATER, 0);

	int offset = 0;
	for (int i = 0; i < draw_count; ++i) {
		draw_call_t draw_call = draw_calls[i];
		glBindTexture(GL_TEXTURE_2D, draw_call.page);
		glDrawElements(GL_TRIANGLES, draw_call.len, GL_UNSIGNED_SHORT, (const void *) offset);

		offset += draw_call.len;
	}

	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();

	glDisableClientState(GL_COLOR_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glDisableClientState(GL_VERTEX_ARRAY);
}

void font_draw_glyph(font_t *fnt, float x, float y, uint32_t color, font_glyph_t glyph)
{
	// lazy-initialize our buffers (no good place to call it)
	if (!quad_indices) {
		init_buffers();
	}

	GLuint page = draw_calls[draw_count].page;

	if (draw_calls[draw_count].page == 0) {
		draw_calls[draw_count].page = glyph.page->texture;
	}

	if (page != 0 && page != glyph.page->texture) {
		draw_calls[draw_count].page = page;
		draw_calls[draw_count].len = data_len;

		draw_count += 1;

		if (draw_count + 1 > FONT_MAX_DRAW_CALLS) {
			font_draw_flush();

			draw_count = 0;
			data_len = 0;
		}
	}

	float s = (float)(glyph.x + FONT_GLYPH_PADDING) / (float)FONT_GLYPH_PAGE_WIDTH;
	float t = (float)(glyph.y + FONT_GLYPH_PADDING) / (float)FONT_GLYPH_PAGE_HEIGHT;
	float u = (float)(glyph.x + FONT_GLYPH_PADDING + glyph.width) / (float)FONT_GLYPH_PAGE_WIDTH;
	float v = (float)(glyph.y + FONT_GLYPH_PADDING + glyph.height) / (float)FONT_GLYPH_PAGE_HEIGHT;

	float r = ((float)((color >> 24)  & 0x000000FF) / 255.f);
	float g = ((float)((color >> 16) & 0x000000FF) / 255.f);
	float b = ((float)((color >> 8) & 0x000000FF) / 255.f);
	float a = ((float)(color & 0x000000FF) / 255.f);

	// top left
	font_vertex_t tl = {
		.x = x,
		.y = y,
		.s = s,
		.t = t,
		.r = r,
		.g = g,
		.b = b,
		.a = a
	};

	// bottom left
	font_vertex_t bl = {
		.x = x,
		.y = y + glyph.height,
		.s = s,
		.t = v,
		.r = r,
		.g = g,
		.b = b,
		.a = a
	};

	// bottom right
	font_vertex_t br = {
		.x = x + glyph.width,
		.y = y + glyph.height,
		.s = u,
		.t = v,
		.r = r,
		.g = g,
		.b = b,
		.a = a
	};

	// top right
	font_vertex_t tr = {
		.x = x + glyph.width,
		.y = y,
		.s = u,
		.t = t,
		.r = r,
		.g = g,
		.b = b,
		.a = a
	};

	glyph_vertex_buffer[data_len++] = tl;
	glyph_vertex_buffer[data_len++] = bl;
	glyph_vertex_buffer[data_len++] = br;
	glyph_vertex_buffer[data_len++] = tr;

	draw_calls[draw_count].len += 6;

	// if we exceed capacity, flush
	if (data_len + 4 > FONT_VERTEX_BUFFER_CAPACITY) {
		font_draw_flush();

		draw_count = 0;
		data_len = 0;
	}
}

void font_flush(font_t *fnt)
{
	draw_count++;
	font_draw_flush();
	memset(draw_calls, 0, sizeof(draw_call_t) * 64);

	draw_count = 0;
	data_len = 0;
}

// "native" string drawing to test differences, should be removed
float font_draw(font_t *fnt, float x, float y, int size, uint32_t color, const char *str)
{
	uint32_t codepoint;
	uint32_t state = 0;
	const uint8_t *utf8 = str;
	int ns = 0;

	font_glyph_t glyph;
	float scale = 0;//stbtt_ScaleForPixelHeight(&fnt->info, (float)size);

	for (; *utf8; ++utf8) {
		if (decode(&state, &codepoint, *utf8))
			continue;

		if (!font_get_glyph(fnt, codepoint, size, &glyph)) {
			continue;
		}

		font_draw_glyph(fnt, x + (ns * scale) + glyph.x_offset, y + glyph.y_offset, color, glyph);

		ns += glyph.x_advance;
	}

	draw_count++;
	font_draw_flush();
	memset(draw_calls, 0, sizeof(draw_call_t) * 64);

	draw_count = 0;
	data_len = 0;

	return x;
}

#endif

void font_free(font_t *fnt)
{
#ifndef DEDI
	font_page_t *page = fnt->page_chain;
	while (page) {
		font_page_t *r = page;
		page = page->next;

		font_page_free(r);
	}

	if (fnt->glyph_data_buf)
		free(fnt->glyph_data_buf);

	if (fnt->data)
		free(fnt->data);

	if (fnt->glyphs)
		free(fnt->glyphs);
#endif
}
