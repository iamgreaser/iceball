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

// Features from the MK fork. Do not bump this unless you are syncing with it.
#define MK_REVISION 11

// This is what you modify: BUMP Z EVERY TIME YOU CHANGE THE C SIDE
#define VERSION_W 0
#define VERSION_X 2
#define VERSION_Y 1
#define VERSION_A 0
#define VERSION_Z 26
// Remember to bump "Z" basically every time you change the engine!
// Remember to bump the version in Lua too!
// Remember to document API changes in a new version!
// Z can only be 0 for official releases!

#define MODEL_BONE_MAX  256
#define MODEL_POINT_MAX 4096
#define PACKET_LEN_MAX 2560
#define PATH_LEN_MAX 128

// i wouldn't go near this limit if i were you...
#define CLIENT_MAX 512

#define WAV_MFREQ 44100
#define WAV_BUFSIZE 2048
// MUST BE A POWER OF TWO
#define WAV_CHN_COUNT 128

//define RENDER_FACE_COUNT 2

#ifndef _MSC_VER
#define PACK_START
#define PACK_END
#ifdef __MMX__
#include <mmintrin.h>
#endif
#ifdef __SSE__
#include <xmmintrin.h>
#endif
#ifdef __SSE2__
#include <emmintrin.h>
#endif
#include <stdint.h>
#else
#define __attribute__(x)
#define PACK_START __pragma( pack(push, 1) )
#define PACK_END __pragma( pack(pop) )
typedef signed __int8		int8_t;
typedef unsigned __int8		uint8_t;
typedef signed __int16		int16_t;
typedef unsigned __int16	uint16_t;
typedef signed __int32		int32_t;
typedef unsigned __int32	uint32_t;
typedef signed __int64		int64_t;
typedef unsigned __int64	uint64_t;
#define snprintf	sprintf_s
#define _USE_MATH_DEFINES	//M_PI and whatnot from math.h
#pragma warning( disable: 4200 4244 4996)
#endif

#ifdef _OPENMP
#include <omp.h>
#endif

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <time.h>
#include <ctype.h>

#ifndef WIN32
#include <sys/time.h>
#include <signal.h>
#endif

#include <math.h>
#include <assert.h>

#include <enet/enet.h>

#ifdef __cplusplus
extern "C" {
#endif
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#ifdef __cplusplus
};
#endif

#ifdef WIN32
#ifdef stderr
#undef stderr
#endif
#define stderr stdout
#endif


#ifndef DEDI
#include <SDL.h>
#include <GL/glew.h>
#endif

#ifndef DEDI
#include <sackit.h>
#endif
#include <zlib.h>

#ifdef WIN32

// just so we can get getaddrinfo
// you will need Windows 2000 at least!
#ifdef _WIN32_WINNT
#undef _WIN32_WINNT
#endif
#define _WIN32_WINNT 0x0501
#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>

#else

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>

#include <fcntl.h>

#endif

enum
{
	UD_INVALID = 0,

	UD_JSON,
	UD_LOG,
	UD_LUA,
	UD_MAP_ICEMAP,
	UD_MAP_VXL,
	UD_MAP,
	UD_PMF,
	UD_IMG_TGA,
	UD_WAV,
	UD_MUS_IT,
	UD_BIN,
	UD_IMG_PNG,

	UD_MAX_SUPPORTED,

	UD_IMG,
	UD_VA,
	UD_SHADER,
	UD_FBO,

	UD_MAX
};

// if this flag is set, free when finished sending
#define UDF_TEMPSEND 0x8000

// hack for softgm so the colours look right
#ifdef APPLE
#define SCREEN_BSWAP_32_ENDIAN
#endif

#ifdef __SSE__
__attribute__((aligned(16)))
#endif
PACK_START
typedef union vec4f
{
	struct { float x,y,z,w; } __attribute__((__packed__)) p;
	float a[4];
#ifdef __SSE__
	float __attribute__ ((vector_size (16))) m;
#endif
} __attribute__((__packed__)) vec4f_t;

#ifdef __SSE__
__attribute__((aligned(16)))
#endif
typedef struct matrix
{
	//column-major!
	vec4f_t c[4];
} __attribute__((__packed__)) matrix_t;
PACK_END

typedef struct camera
{
	// camera bollocks
	float mxx,mxy,mxz,mxpad;
	float myx,myy,myz,mypad;
	float mzx,mzy,mzz,mzpad;
	float mpx,mpy,mpz,mppad;
} camera_t;

PACK_START
typedef struct model_point
{
	uint16_t radius;
	int16_t x,y,z;
	uint8_t b,g,r,resv1;
} __attribute__((__packed__)) model_point_t;
PACK_END

typedef struct model model_t;
typedef struct model_bone
{
	int udtype;
	char name[16];
	model_t *parent;
	int parent_idx;
	int ptlen, ptmax;
#ifndef DEDI
	GLuint vbo;
	int vbo_dirty;
	float *vbo_arr;
	int vbo_arr_len, vbo_arr_max;
#endif
	model_point_t pts[];
} model_bone_t;

struct model
{
	int udtype;
	int bonelen, bonemax;
	model_bone_t *bones[];
};

#define VA_MAX_IMG 8
#define VA_MAX_TC 1
#define VA_MAX_ATTR 32
typedef struct va
{
	int udtype;
	int vertex_offs;
	int vertex_size;
	int color_offs;
	int color_size;
	int normal_offs;
	int texcoord_offs[VA_MAX_TC];
	int texcoord_size[VA_MAX_TC];
	int texcoord_count;
	int attr_offs[VA_MAX_ATTR];
	int attr_size[VA_MAX_ATTR];
	int attr_count;
	int stride;
	int data_len; // measured in points
	float *data;
#ifndef DEDI
	GLuint vbo;
	int vbo_dirty;
#endif
} va_t;

typedef struct shader
{
	int udtype;
#ifndef DEDI
	GLuint prog;
#endif
} shader_t;

typedef struct fbo
{
	int udtype;
#ifndef DEDI
	GLuint ctex, dstex;
	GLuint handle;
#endif
	int width, height;
} fbo_t;


PACK_START
// source: http://paulbourke.net/dataformats/tga/
typedef struct img_tgahead
{
	uint8_t idlen;
	uint8_t cmtype;
	uint8_t imgtype;
	uint16_t cmoffs;
	uint16_t cmlen;
	uint8_t cmbpp;
	uint16_t xstart;
	uint16_t ystart;
	uint16_t width;
	uint16_t height;
	uint8_t bpp;
	uint8_t flags;
} __attribute__((__packed__)) img_tgahead_t;
PACK_END

typedef struct img
{
	int udtype;
#ifndef DEDI
	GLuint tex;
	int tex_dirty;
#endif
	img_tgahead_t head;
	uint32_t pixels[];
} img_t;

typedef struct wav
{
	int udtype;
	uint32_t refcount; // 1 for all of lua, 1 per channel
	uint32_t freq;
	uint32_t len;
	int16_t data[]; // y'know, just in case we get 16-bit sound.
} wav_t;

typedef struct wavchn
{
	wav_t *src;
	int idx;
	int flags;
	float freq_mod;
	float vol, vol_spread;
	float x,y,z;
	uint32_t offs, suboffs;
} wavchn_t;
#define WCF_ACTIVE   0x00000001
#define WCF_GLOBAL   0x00000002

/*

Pillar data:

Note, indices are like so:
0 1 2 3

Column header:
L - - -:
  (L+1)*4 = length in bytes
  - = reserved

Chunk header:
N S E A:
  N = number of 4bytes including header this chunk has (N=0 => last chunk)
  S = starting block for top part
  E = ending block for top part
  A = air start after bottom part (N=0 => E-S+1 blocks are stored)

Block data:
B G R T:
  B = blue
  G = green
  R = red! suprised?
  T = type of block.

In other words, VOXLAP vxl with a length header and different 4th data byte,
  and you can actually store crap in the invisible sections.
(Trust me. This format packs incredibly well.)

If you're keen to store interesting stuff that's not visible,
feel free to store it in the "invisible" parts.

*Yes*, you can get away with this! We're not using a static 16MB heap.

*/

#ifndef DEDI
typedef struct map_chunk map_chunk_t;
struct map_chunk
{
	GLuint vbo;
	int vbo_dirty;
	int vbo_arr_len, vbo_arr_max;
	int cx, cz;

	int ytmin, ytmax, ybmax;
	GLuint oq;
	int oc_wait;
	int oc_posted;

	int flood_ctr;
	map_chunk_t *flood_next;

	float *vbo_arr;
};
#endif

typedef struct map
{
	int udtype;
	int xlen, ylen, zlen;
#ifndef DEDI
	int enable_side_shading;
	int enable_ao;
	float fog_distance;
	int vertex_offs, vertex_size;
	int color_offs, color_size;
	int normal_offs, normal_size;
	int tc0_offs, tc0_size;
	int stride;
	/* circular array of visible map chunks */
	map_chunk_t *visible_chunks_arr;
	/* current virtual center position in the circular array */
	int visible_chunks_vcenter_x;
	int visible_chunks_vcenter_z;
	/* current virtual center chunk coordinates in the circular array */
	int visible_chunks_vcenter_cx;
	int visible_chunks_vcenter_cz;
	int visible_chunks_len;
#endif
	uint8_t **pillars;
	char *entities;
	size_t entities_size;  // Includes null-terminator
	// TODO ? heap allocator ?
} map_t;

enum
{
	BT_INVALID = 0, // don't use this type!
	BT_SOLID_BREAKABLE,

	BT_MAX
};

typedef struct packet packet_t;
struct packet
{
	packet_t *p, *n;
	int neth;
	int len;
	char data[];
};

typedef struct client
{
	// legacy proto only
	packet_t *head, *tail;
	packet_t *send_head, *send_tail;
	int sockfd;
	int isfull;

	// enet proto only
	ENetPeer *peer;

	// client only
	char *cfetch_ubuf;
	char *cfetch_cbuf;
	int cfetch_ulen, cfetch_clen;
	int cfetch_cpos;
	int cfetch_udtype;

	// server only
	char *sfetch_ubuf;
	char *sfetch_cbuf;
	int sfetch_ulen, sfetch_clen;
	int sfetch_cpos;
	int sfetch_udtype;

	// serialisation - legacy proto only
	char rpkt_buf[PACKET_LEN_MAX*2];
	int rpkt_len;
	char spkt_buf[PACKET_LEN_MAX*2];
	int spkt_ppos,spkt_len;
} client_t;

#define SOCKFD_NONE -1
#define SOCKFD_LOCAL -2
#define SOCKFD_ENET -3

enum
{
	PATH_INVALID_ENUM = 0, // don't use this!

	PATH_CLSAVE_BASEDIR,
	PATH_CLSAVE_BASEDIR_VOLATILE,
	PATH_CLSAVE_PUBLIC,
	PATH_CLSAVE_VOLATILE,
	PATH_SVSAVE_BASEDIR,
	PATH_SVSAVE_BASEDIR_VOLATILE,
	PATH_SVSAVE_PUBLIC,
	PATH_SVSAVE_VOLATILE,
	PATH_PKG_BASEDIR,
	PATH_PKG,

	PATH_ERROR_BADCHARS,
	PATH_ERROR_ACCDENIED,

	PATH_ENUM_MAX
};

// dsp.c
float interp_linear(float y0, float y1, float x);
float interp_cubic(float y0, float y1, float y2, float y3, float x);
float interp_hermite6p(float y0, float y1, float y2, float y3, 
		float y4, float y5, float x);
float frequency2wavelength(int rate, float frequency);
float wavelength2frequency(int rate, float wavelength);
float frequency2midinote(float frequency);
float midinote2frequency(float midinote);
float below_min_power(float amplitude);
float attentuationDB2pctpower(float data);
float equal_power_left(float pan);
float equal_power_right(float pan);

// img.c
void img_free(img_t *img);
void img_gc_set(lua_State *L);
img_t *img_parse_tga(int len, const char *data, lua_State *L);
img_t *img_load_tga(const char *fname, lua_State *L);
void img_write_tga(const char *fname, img_t *img);

// json.c
int json_parse(lua_State *L, const char *p);
int json_load(lua_State *L, const char *fname);
int json_write(lua_State *L, const char *fname);

// lua.c
extern lua_State *lstate_client;
extern lua_State *lstate_server;
int icelua_initfetch(void);
int icelua_init(void);
void icelua_deinit(void);

// main.c
extern camera_t tcam;
extern map_t *clmap, *svmap;
#ifndef DEDI
extern SDL_Surface *screen;
extern int screen_width, screen_height;
extern int screen_cubeshift;
extern int screen_fullscreen;
extern int screen_antialiasing_level;
extern int screen_smooth_lighting;
extern int map_enable_autorender;
extern int map_enable_ao;
extern int map_enable_side_shading;
extern int gl_expand_textures;
extern int gl_use_vbo;
extern int gl_use_fbo;
extern int gl_quality;
extern int gl_vsync;
extern int gl_frustum_cull;
extern int gl_flip_quads;
extern int gl_expand_quads;
extern int gl_chunk_size;
extern int gl_visible_chunks;
extern int gl_chunks_tesselated_per_frame;
extern int gl_occlusion_cull;
extern int gl_max_texunits;
extern int gl_shaders;
#endif
extern int mk_compat_mode;
extern int force_redraw;

extern int net_port;
extern char *net_addr;
extern char net_addr_xbuf[];
extern int boot_mode;
extern char *mod_basedir;

extern int main_argc;
extern char **main_argv;
extern char *main_argv0;
extern char *main_oldcwd;
extern int main_largstart;

int run_game_cont1(void);
int run_game_cont2(void);

int error_sdl(char *msg);
int error_perror(char *msg);

// map.c
map_t *map_parse_aos(int len, const char *data);
map_t *map_parse_icemap(int len, const char *data);
map_t *map_load_aos(const char *fname);
map_t *map_load_icemap(const char *fname);
char *map_serialise_icemap(map_t *map, int *len);
int map_save_icemap(map_t *map, const char *fname);
int map_set_mapents(map_t *map, const char *src, size_t size);
void map_free(map_t *map);

// model.c
model_bone_t *model_bone_new(model_t *pmf, int ptmax);
model_bone_t *model_bone_extend(model_bone_t *bone, int ptmax);
void model_bone_free(model_bone_t *bone);
model_t *model_new(int bonemax);
model_t *model_extend(model_t *pmf, int bonemax);
void model_free(model_t *pmf);
void model_gc_set(lua_State *L);
model_t *model_parse_pmf(int len, const char *data);
model_t *model_load_pmf(const char *fname);
int model_save_pmf(model_t *pmf, const char *fname);

// network.c
extern client_t to_server;
extern client_t to_clients[];
extern client_t to_client_local;
client_t *net_neth_get_client(int neth);
char *net_fetch_file(const char *fname, int *flen);
int net_packet_push(int len, const char *data, int neth, packet_t **head, packet_t **tail);
int net_packet_push_lua(int len, const char *data, int neth, int unreliable, packet_t **head, packet_t **tail);
packet_t *net_packet_pop(packet_t **head, packet_t **tail);
void net_packet_free(packet_t *pkt, packet_t **head, packet_t **tail);
void net_kick_sockfd_immediate(int sockfd, ENetPeer *peer, const char *msg);
void net_kick_client_immediate(client_t *cli, const char *msg);
client_t *net_find_sockfd(int sockfd, ENetPeer *peer);
void net_flush(void);
int net_connect(void);
void net_disconnect(void);
int net_bind(void);
void net_unbind(void);
int net_init(void);
void net_deinit(void);

// path.c
char *path_filter(const char *path);
int path_get_type(const char *path);
int path_type_client_local(int type);
int path_type_client_readable(int type);
int path_type_client_writable(int type);
int path_type_server_readable(int type);
int path_type_server_writable(int type);

// render.c
img_t *render_dump_img(int width, int height, int sx, int sy);
void render_blit_img(uint32_t *pixels, int width, int height, int pitch,
	img_t *src, int dx, int dy, int bw, int bh, int sx, int sy, uint32_t color, float scalex, float scaley);
#ifndef DEDI
#ifdef RENDER_FACE_COUNT
extern int render_face_remain;
#endif
#define FOG_MAX_DISTANCE 511.5f /* that's not going to work well, by the way! */
#define FOG_INIT_DISTANCE 60.0f
extern float fog_distance;
extern uint32_t fog_color;
extern uint32_t cam_shading[6];
void render_vxl_redraw(camera_t *camera, map_t *map);
void render_clear(camera_t *camera);
void render_cubemap(uint32_t *pixels, int width, int height, int pitch, camera_t *camera, map_t *map,
	img_t **img, int do_blend, char sfactor, char dfactor, float alpha, int img_count);
void render_pmf_bone(uint32_t *pixels, int width, int height, int pitch, camera_t *cam_base,
	model_bone_t *bone, int islocal,
	float px, float py, float pz, float ry, float rx, float ry2, float scale);
void render_vertex_array(uint32_t *pixels, int width, int height, int pitch, camera_t *cam_base,
	va_t *bone, int islocal,
	float px, float py, float pz, float ry, float rx, float ry2, float scale,
	img_t **img, int do_blend, char sfactor, char dfactor, float alpha, int img_count);
void render_resize(int width, int height);
int render_init(int width, int height);
void render_deinit(void);
void render_init_visible_chunks(map_t *map, int starting_chunk_coordinate_x, int starting_chunk_coordinate_z);
void render_init_va_format(map_t *map);
void render_map_mark_chunks_as_dirty(map_t *map, int pillar_x, int pillar_z);
void render_free_visible_chunks(map_t *map);
int render_map_visible_chunks_count_dirty(map_t *map);
#endif

// png.c
img_t *img_parse_png(int len, const char *data, lua_State *L);
img_t *img_load_png(const char *fname, lua_State *L);
void img_write_png(const char *fname, img_t *img);

// vecmath.c
vec4f_t mtx_apply_vec(matrix_t *mtx, vec4f_t *vec);
void mtx_identity(matrix_t *mtx);
void cam_point_dir(camera_t *model, float dx, float dy, float dz, float zoom, float roll);
void cam_point_dir_sky(camera_t *model, float dx, float dy, float dz, float sx, float sy, float sz, float zoom);

// wav.c
#ifndef DEDI
extern sackit_playback_t *icesackit_pb;
extern int icesackit_bufoffs;
extern float icesackit_vol;
extern float icesackit_mvol;
#endif
wav_t *wav_parse(char *buf, int len);
wav_t *wav_load(const char *fname);
void wav_kill(wav_t *wav);
void wav_gc_set(lua_State *L);
#ifndef DEDI
extern int wav_mfreq;
extern int wav_bufsize;
extern float wav_gvol;
extern float wav_cube_size;
extern wavchn_t wchn[WAV_CHN_COUNT];
wavchn_t *wav_chn_alloc(int flags, wav_t *wav, float x, float y, float z, float vol, float freq_mod, float vol_spread);
void wav_chn_kill(wavchn_t *chn);
int wav_init(void);
void wav_deinit(void);
#endif

