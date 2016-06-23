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

camera_t tcam;
map_t *clmap = NULL;
map_t *svmap = NULL;

#ifndef DEDI
SDL_GLContext *gl_context = NULL;
SDL_Window *window = NULL;
SDL_Surface *screen = NULL;
char mk_app_title[128] = "iceball";
#endif
int screen_width = 800;
int screen_height = 600;
int screen_cubeshift = 0;
int screen_fullscreen = 0;
int screen_antialiasing_level = 0;
int screen_smooth_lighting = 0;
int mk_compat_mode = 1;
int gl_expand_textures = 0;
int gl_chunk_size = 16;
int gl_visible_chunks = 49;
int gl_chunks_tesselated_per_frame = 2;
int gl_use_fbo = 1;
int gl_quality = 1;
int gl_vsync = 1;
int gl_frustum_cull = 1;
int gl_occlusion_cull = 1;
int gl_flip_quads = 0;
int gl_expand_quads = 0;
int gl_shaders = 1;
int map_enable_autorender = 1;
int map_enable_ao = 1;
int map_enable_side_shading = 1;

int force_redraw = 1;

// bit 0 = client, bit 1 = server, bit 2 = main_client.lua has been loaded,
// bit 3 = currently loading main_client.lua and co, bit 4 == use ENet for client
int boot_mode = 0;

char *mod_basedir = NULL;
char *net_address;
char *net_path;
int net_port;

int main_argc;
char **main_argv;
char *main_argv0;
char *main_oldcwd;
int main_largstart = -1;

int64_t frame_prev = 0;
int64_t frame_now = 0;
int fps = 0;

double sec_curtime = 0.0;
double sec_lasttime = 0.0;
double sec_wait = 0.0;
double sec_serv_wait = 0.0;

float ompx = -M_PI, ompy = -M_PI, ompz = -M_PI;

int64_t usec_basetime;

#ifndef DEDI
int error_sdl(char *msg)
{
	fprintf(stderr, "%s: %s\n", msg, SDL_GetError());
	return 1;
}
#endif

int error_perror(char *msg)
{
	perror(msg);
	return 1;
}

#ifndef DEDI
int platform_init(void)
{
	if(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_NOPARACHUTE))
		return error_sdl("SDL_Init");

#ifndef WIN32
	signal(SIGPIPE, SIG_IGN);
	signal(SIGINT, SIG_DFL);
#endif

	return 0;
}

static const char* get_gl_debug_type_name(GLenum type)
{
	switch (type) {
	case GL_DEBUG_TYPE_ERROR:
		return "ERROR";
	case GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR:
		return "DEPRECATED_BEHAVIOR";
	case GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR:
		return "UNDEFINED_BEHAVIOR";
	case GL_DEBUG_TYPE_PORTABILITY:
		return "PORTABILITY";
	case GL_DEBUG_TYPE_PERFORMANCE:
		return "PERFORMANCE";
	case GL_DEBUG_TYPE_OTHER:
		return "OTHER";
	default:
		return "<UNKNOWN>";
	}
}

static const char* get_gl_debug_severity_name(GLenum severity)
{
	switch (severity) {
	case GL_DEBUG_SEVERITY_LOW:
		return "LOW";
	case GL_DEBUG_SEVERITY_MEDIUM:
		return "MEDIUM";
	case GL_DEBUG_SEVERITY_HIGH:
		return "HIGH";
	default:
		return "<UNKNOWN>";
	}
}

void APIENTRY opengl_cb_fun(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, const GLchar* message, void* userParam)
{
	printf("---------------------opengl-callback-start------------\n");
	printf("message: %s\n", message);
	printf("type: %s\n", get_gl_debug_type_name(type));
	printf("id: %d\n", id);
	printf("severity: %s\n", get_gl_debug_severity_name(severity));
	printf("---------------------opengl-callback-end--------------\n");
}

int video_init(void)
{
	SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 8);
	SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8);
	SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 8);
	SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
	SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8);

#ifndef NDEBUG
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_DEBUG_FLAG);
#endif

	if (screen_antialiasing_level > 0)
	{
		SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
		SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, screen_antialiasing_level);
	}

	window = SDL_CreateWindow("iceball",
		  SDL_WINDOWPOS_UNDEFINED,
		  SDL_WINDOWPOS_UNDEFINED,
		  screen_width,
		  screen_height, SDL_WINDOW_OPENGL | (screen_fullscreen ? SDL_WINDOW_FULLSCREEN : 0));
	if(window == NULL)
		return error_sdl("SDL_CreateWindow");

	SDL_StopTextInput();

	gl_context = SDL_GL_CreateContext(window);

	if(gl_context == NULL)
		return error_sdl("SDL_GL_CreateContext");

	SDL_GL_MakeCurrent(window, gl_context);

	if(gl_vsync)
		SDL_GL_SetSwapInterval(1);
	else
		SDL_GL_SetSwapInterval(0);

	int err_glad = gladLoadGLLoader(SDL_GL_GetProcAddress);
	if(!err_glad)
	{
		fprintf(stderr, "Glad failed to init\n");
		return 1;
	}

	printf("OpenGL: %s\n", glGetString(GL_VERSION));
	printf("GLSL: %s\n", glGetString(GL_SHADING_LANGUAGE_VERSION));
	printf("Renderer: %s\n", glGetString(GL_RENDERER));
	printf("Vendor: %s\n", glGetString(GL_VENDOR));

	if(!GLAD_GL_VERSION_2_0)
	{
		SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR,
			"Bad GPU",
			"OpenGL 2.0 is required for Iceball to run. Install the latest drivers for your GPU if you can.",
			NULL);
		return 1;
	}

#ifndef NDEBUG
	if (GLAD_GL_ARB_debug_output) {
		glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
		glDebugMessageCallbackARB(opengl_cb_fun, NULL);
		GLuint unusedIds = 0;
		glDebugMessageControlARB(GL_DONT_CARE,
			GL_DONT_CARE,
			GL_DONT_CARE,
			0,
			&unusedIds,
			1);

		fprintf(stdout, "Registered ARB_debug_output callback\n");
	}
	else {
		fprintf(stderr, "WARNING: Could not register ARB_debug_output callback\n");
	}
#endif

	return 0;
}

void video_deinit(void)
{
	if (gl_context)
		SDL_GL_DeleteContext(gl_context);
	if (window)
		SDL_DestroyWindow(window);
}

void platform_deinit(void)
{
	SDL_Quit();
}

int remap_scancodes(int scancode) {
	switch (scancode) {
		case SDL_SCANCODE_UNKNOWN: return SDLK_UNKNOWN;
		case SDL_SCANCODE_A: return SDLK_a;
		case SDL_SCANCODE_B: return SDLK_b;
		case SDL_SCANCODE_C: return SDLK_c;
		case SDL_SCANCODE_D: return SDLK_d;
		case SDL_SCANCODE_E: return SDLK_e;
		case SDL_SCANCODE_F: return SDLK_f;
		case SDL_SCANCODE_G: return SDLK_g;
		case SDL_SCANCODE_H: return SDLK_h;
		case SDL_SCANCODE_I: return SDLK_i;
		case SDL_SCANCODE_J: return SDLK_j;
		case SDL_SCANCODE_K: return SDLK_k;
		case SDL_SCANCODE_L: return SDLK_l;
		case SDL_SCANCODE_M: return SDLK_m;
		case SDL_SCANCODE_N: return SDLK_n;
		case SDL_SCANCODE_O: return SDLK_o;
		case SDL_SCANCODE_P: return SDLK_p;
		case SDL_SCANCODE_Q: return SDLK_q;
		case SDL_SCANCODE_R: return SDLK_r;
		case SDL_SCANCODE_S: return SDLK_s;
		case SDL_SCANCODE_T: return SDLK_t;
		case SDL_SCANCODE_U: return SDLK_u;
		case SDL_SCANCODE_V: return SDLK_v;
		case SDL_SCANCODE_W: return SDLK_w;
		case SDL_SCANCODE_X: return SDLK_x;
		case SDL_SCANCODE_Y: return SDLK_y;
		case SDL_SCANCODE_Z: return SDLK_z;
		case SDL_SCANCODE_1: return SDLK_1;
		case SDL_SCANCODE_2: return SDLK_2;
		case SDL_SCANCODE_3: return SDLK_3;
		case SDL_SCANCODE_4: return SDLK_4;
		case SDL_SCANCODE_5: return SDLK_5;
		case SDL_SCANCODE_6: return SDLK_6;
		case SDL_SCANCODE_7: return SDLK_7;
		case SDL_SCANCODE_8: return SDLK_8;
		case SDL_SCANCODE_9: return SDLK_9;
		case SDL_SCANCODE_0: return SDLK_0;
		case SDL_SCANCODE_RETURN: return SDLK_RETURN;
		case SDL_SCANCODE_ESCAPE: return SDLK_ESCAPE;
		case SDL_SCANCODE_BACKSPACE: return SDLK_BACKSPACE;
		case SDL_SCANCODE_TAB: return SDLK_TAB;
		case SDL_SCANCODE_SPACE: return SDLK_SPACE;
		case SDL_SCANCODE_MINUS: return SDLK_MINUS;
		case SDL_SCANCODE_EQUALS: return SDLK_EQUALS;
		case SDL_SCANCODE_LEFTBRACKET: return SDLK_LEFTBRACKET;
		case SDL_SCANCODE_RIGHTBRACKET: return SDLK_RIGHTBRACKET;
		case SDL_SCANCODE_BACKSLASH: return SDLK_BACKSLASH;
		case SDL_SCANCODE_SEMICOLON: return SDLK_SEMICOLON;
		case SDL_SCANCODE_COMMA: return SDLK_COMMA;
		case SDL_SCANCODE_PERIOD: return SDLK_PERIOD;
		case SDL_SCANCODE_SLASH: return SDLK_SLASH;
		case SDL_SCANCODE_CAPSLOCK: return 301 /* SDLK_CAPSLOCK */;
		case SDL_SCANCODE_F1: return 282 /* SDLK_F1 */;
		case SDL_SCANCODE_F2: return 283 /* SDLK_F2 */;
		case SDL_SCANCODE_F3: return 284 /* SDLK_F3 */;
		case SDL_SCANCODE_F4: return 285 /* SDLK_F4 */;
		case SDL_SCANCODE_F5: return 286 /* SDLK_F5 */;
		case SDL_SCANCODE_F6: return 287 /* SDLK_F6 */;
		case SDL_SCANCODE_F7: return 288 /* SDLK_F7 */;
		case SDL_SCANCODE_F8: return 289 /* SDLK_F8 */;
		case SDL_SCANCODE_F9: return 290 /* SDLK_F9 */;
		case SDL_SCANCODE_F10: return 291 /* SDLK_F10 */;
		case SDL_SCANCODE_F11: return 292 /* SDLK_F11 */;
		case SDL_SCANCODE_F12: return 293 /* SDLK_F12 */;
		case SDL_SCANCODE_F13: return 294 /* SDLK_F13 */;
		case SDL_SCANCODE_F14: return 295 /* SDLK_F14 */;
		case SDL_SCANCODE_F15: return 296 /* SDLK_F15 */;
		case SDL_SCANCODE_SCROLLLOCK: return 302 /* SDLK_SCROLLLOCK */;
		case SDL_SCANCODE_PAUSE: return 19 /* SDLK_PAUSE */;
		case SDL_SCANCODE_INSERT: return 277 /* SDLK_INSERT */;
		case SDL_SCANCODE_HOME: return 278 /* SDLK_HOME */;
		case SDL_SCANCODE_PAGEUP: return 280 /* SDLK_PAGEUP */;
		case SDL_SCANCODE_DELETE: return 127 /* SDLK_DELETE */;
		case SDL_SCANCODE_END: return 279 /* SDLK_END */;
		case SDL_SCANCODE_PAGEDOWN: return 281 /* SDLK_PAGEDOWN */;
		case SDL_SCANCODE_RIGHT: return 275 /* SDLK_RIGHT */;
		case SDL_SCANCODE_LEFT: return 276 /* SDLK_LEFT */;
		case SDL_SCANCODE_DOWN: return 274 /* SDLK_DOWN */;
		case SDL_SCANCODE_UP: return 273 /* SDLK_UP */;
		case SDL_SCANCODE_KP_DIVIDE: return 267 /* SDLK_KP_DIVIDE */;
		case SDL_SCANCODE_KP_MULTIPLY: return 268 /* SDLK_KP_MULTIPLY */;
		case SDL_SCANCODE_KP_MINUS: return 269 /* SDLK_KP_MINUS */;
		case SDL_SCANCODE_KP_PLUS: return 270 /* SDLK_KP_PLUS */;
		case SDL_SCANCODE_KP_ENTER: return 271 /* SDLK_KP_ENTER */;
		case SDL_SCANCODE_KP_1: return 257 /* SDLK_KP_1 */;
		case SDL_SCANCODE_KP_2: return 258 /* SDLK_KP_2 */;
		case SDL_SCANCODE_KP_3: return 259 /* SDLK_KP_3 */;
		case SDL_SCANCODE_KP_4: return 260 /* SDLK_KP_4 */;
		case SDL_SCANCODE_KP_5: return 261 /* SDLK_KP_5 */;
		case SDL_SCANCODE_KP_6: return 262 /* SDLK_KP_6 */;
		case SDL_SCANCODE_KP_7: return 263 /* SDLK_KP_7 */;
		case SDL_SCANCODE_KP_8: return 264 /* SDLK_KP_8 */;
		case SDL_SCANCODE_KP_9: return 265 /* SDLK_KP_9 */;
		case SDL_SCANCODE_KP_0: return 256 /* SDLK_KP_0 */;
		case SDL_SCANCODE_KP_PERIOD: return 266 /* SDLK_KP_PERIOD */;
		case SDL_SCANCODE_POWER: return 320 /* SDLK_POWER */;
		case SDL_SCANCODE_KP_EQUALS: return 272 /* SDLK_KP_EQUALS */;
		case SDL_SCANCODE_SYSREQ: return 317 /* SDLK_SYSREQ */;
		case SDL_SCANCODE_HELP: return 315 /* SDLK_HELP */;
		case SDL_SCANCODE_MENU: return 319 /* SDLK_MENU */;
		case SDL_SCANCODE_UNDO: return 322 /* SDLK_UNDO */;
		case SDL_SCANCODE_LCTRL: return 306 /* SDLK_LCTRL */;
		case SDL_SCANCODE_LSHIFT: return 304 /* SDLK_LSHIFT */;
		case SDL_SCANCODE_LALT: return 308 /* SDLK_LALT */;
		case SDL_SCANCODE_LGUI: return 310 /* SDLK_LGUI */;
		case SDL_SCANCODE_RCTRL: return 305 /* SDLK_RCTRL */;
		case SDL_SCANCODE_RSHIFT: return 303 /* SDLK_RSHIFT */;
		case SDL_SCANCODE_RALT: return 307 /* SDLK_RALT */;
		case SDL_SCANCODE_RGUI: return 309 /* SDLK_RGUI */;
		case SDL_SCANCODE_MODE: return 313 /* SDLK_MODE */;
		default: return -1;
	}
}
#endif

#if defined(DEDI) && defined(WIN32)
int64_t ms_now()
{
	static LARGE_INTEGER baseFreq;
	static BOOL qpc_Avail = QueryPerformanceFrequency( &baseFreq );
	if( qpc_Avail ) {
		LARGE_INTEGER now;
		QueryPerformanceCounter( &now );
		return (1000LL * now.QuadPart) / baseFreq.QuadPart;
	} else {
		return GetTickCount();
	}
}
#endif

int64_t platform_get_time_usec(void)
{
#ifdef WIN32
#ifndef DEDI
	int64_t msec = SDL_GetTicks();
	return msec*1000;
#else
	return ms_now()*1000;
#endif
#else
	struct timeval tv;
	gettimeofday(&tv, NULL);

	int64_t usec = tv.tv_usec;
	int64_t sec = tv.tv_sec;
	sec = (int64_t)(((int64_t)sec)*((int64_t)1000000));
	usec += sec;

	return usec;
#endif
}

#ifndef DEDI
static int ib_client_tick_hook(void) {
	lua_getglobal(lstate_client, "client");
	lua_getfield(lstate_client, -1, "hook_tick");
	lua_remove(lstate_client, -2);
	if(lua_isnil(lstate_client, -1))
	{
		lua_pop(lstate_client, 1);
		return 1;
	}

	double sec_delta = sec_curtime - sec_lasttime;
	if (sec_delta <= 0) {
		sec_delta = 0.00000001;
	}
	lua_pushnumber(lstate_client, sec_curtime);
	lua_pushnumber(lstate_client, sec_delta);
	if(lua_pcall(lstate_client, 2, 1, 0) != 0)
	{
		printf("Lua Client Error (tick): %s\n", lua_tostring(lstate_client, -1));
		lua_pop(lstate_client, 1);
		return 1;
	}
	//if(!(boot_mode & IB_SERVER))
	sec_wait += lua_tonumber(lstate_client, -1);
	lua_pop(lstate_client, 1);

	return 0;
}

static int ib_client_render_hook(void) {
	lua_getglobal(lstate_client, "client");
	lua_getfield(lstate_client, -1, "hook_render");
	lua_remove(lstate_client, -2);
	if(!lua_isnil(lstate_client, -1))
	{
		if(lua_pcall(lstate_client, 0, 0, 0) != 0)
		{
			printf("Lua Client Error (render): %s\n", lua_tostring(lstate_client, -1));
			lua_pop(lstate_client, 1);
			return 1;
		}
	}

	return 0;
}

static int ib_client_key_hook(SDL_Event ev) {
	lua_getglobal(lstate_client, "client");
	lua_getfield(lstate_client, -1, "hook_key");
	lua_remove(lstate_client, -2);
	if (lua_isnil(lstate_client, -1)) {
		// not hooked? ignore!
		lua_pop(lstate_client, 1);
		return 0;
	}

	int ch = remap_scancodes(ev.key.keysym.scancode);
	//if ((ev.key.keysym.unicode & 0xFF80) == 0)
	//	ch = ev.key.keysym.unicode & 0x1FF;

	lua_pushinteger(lstate_client, ch);
	lua_pushboolean(lstate_client, (ev.type == SDL_KEYDOWN));
	lua_pushinteger(lstate_client, (int) (ev.key.keysym.mod));
	lua_pushinteger(lstate_client, ch);

	if (lua_pcall(lstate_client, 4, 0, 0) != 0) {
		printf("Lua Client Error (key): %s\n", lua_tostring(lstate_client, -1));
		lua_pop(lstate_client, 1);
		return 1;
	}

	return 0;
}

static int ib_client_text_hook(SDL_Event ev) {
	lua_getglobal(lstate_client, "client");
	lua_getfield(lstate_client, -1, "hook_text");
	lua_remove(lstate_client, -2);
	if (lua_isnil(lstate_client, -1)) {
		// not hooked? ignore!
		lua_pop(lstate_client, 1);
		return 0;
	}

	char *str = ev.text.text;

	lua_pushstring(lstate_client, str);

	if (lua_pcall(lstate_client, 1, 0, 0) != 0) {
		printf("Lua Client Error (text): %s\n", lua_tostring(lstate_client, -1));
		lua_pop(lstate_client, 1);
		return 1;
	}

	return 0;
}

static int ib_client_mouse_press_hook(SDL_Event ev) {
	lua_getglobal(lstate_client, "client");
	lua_getfield(lstate_client, -1, "hook_mouse_button");
	lua_remove(lstate_client, -2);
	if (lua_isnil(lstate_client, -1)) {
		// not hooked? ignore!
		lua_pop(lstate_client, 1);
		return 0;
	}

	lua_pushinteger(lstate_client, ev.button.button);
	lua_pushboolean(lstate_client, (ev.type == SDL_MOUSEBUTTONDOWN));
	if (lua_pcall(lstate_client, 2, 0, 0) != 0) {
		printf("Lua Client Error (mouse_button): %s\n", lua_tostring(lstate_client, -1));
		lua_pop(lstate_client, 1);
		return 1;
	}

	return 0;
}

static int ib_client_mouse_motion_hook(SDL_Event ev)
{
#ifdef WIN32
	// THANKS FUCKDOWS
	// TODO: make fuckdows behave
	//printf("%i %i %i %i\n", ev.motion.xrel, ev.motion.yrel, ev.motion.x, ev.motion.y);
	if(ev.motion.xrel < -screen_width/4) return 0;
	if(ev.motion.xrel >  screen_width/4) return 0;
	if(ev.motion.yrel < -screen_height/4) return 0;
	if(ev.motion.yrel >  screen_height/4) return 0;
#endif
	lua_getglobal(lstate_client, "client");
	lua_getfield(lstate_client, -1, "hook_mouse_motion");
	lua_remove(lstate_client, -2);
	if (lua_isnil(lstate_client, -1)) {
		// not hooked? ignore!
		lua_pop(lstate_client, 1);
		return 0;
	}

	lua_pushinteger(lstate_client, ev.motion.x);
	lua_pushinteger(lstate_client, ev.motion.y);
	lua_pushinteger(lstate_client, ev.motion.xrel);
	lua_pushinteger(lstate_client, ev.motion.yrel);
	if (lua_pcall(lstate_client, 4, 0, 0) != 0) {
		printf("Lua Client Error (mouse_motion): %s\n", lua_tostring(lstate_client, -1));
		lua_pop(lstate_client, 1);
		return 1;
	}

	return 0;
}

static int ib_client_window_focus_hook(SDL_Event ev) {
	lua_getglobal(lstate_client, "client");
	lua_getfield(lstate_client, -1, "hook_window_activate");
	lua_remove(lstate_client, -2);
	if (lua_isnil(lstate_client, -1)) {
		// not hooked? ignore!
		lua_pop(lstate_client, 1);
		return 0;
	}

	lua_pushboolean(lstate_client, ev.window.event == SDL_WINDOWEVENT_FOCUS_GAINED);
	if (lua_pcall(lstate_client, 1, 0, 0) != 0) {
		printf("Lua Client Error (window_activate): %s\n", lua_tostring(lstate_client, -1));
		lua_pop(lstate_client, 1);
		return 1;
	}

	return 0;
}

int update_fps_counter(void)
{
	int quitflag = 0;

	// update FPS counter
	frame_now = platform_get_time_usec();
	fps++;

	if(frame_now - frame_prev > (int64_t)1000000)
	{
		char buf[128+32]; // topo how the hell did this not crash at 16 --GM
		sprintf(buf, "%s | FPS: %d", mk_app_title, fps);
		SDL_SetWindowTitle(window, buf);
		fps = 0;
		frame_prev = platform_get_time_usec();
	}

	return quitflag;
}

int render_client(void)
{
	int quitflag = 0;

	// skip while still loading
	if(mod_basedir == NULL || (boot_mode & IB_MAIN_LOADING))
		return 0;

	if(map_enable_autorender)
	{
		if (render_map_visible_chunks_count_dirty(clmap) > 0)
			force_redraw = 1;

		// redraw scene if necessary
		if(force_redraw
			|| fabsf(tcam.mpx-ompx) > 0.001f
			|| fabsf(tcam.mpy-ompy) > 0.01f
			|| fabsf(tcam.mpz-ompz) > 0.001f)
		{
#ifdef RENDER_FACE_COUNT
			render_face_remain = 6;
#else
			render_vxl_redraw(&tcam, clmap);
#endif
			ompx = tcam.mpx;
			ompy = tcam.mpy;
			ompz = tcam.mpz;
			force_redraw = 0;
		}

#ifdef RENDER_FACE_COUNT
		if(render_face_remain > 0)
			render_vxl_redraw(&tcam, clmap);
#endif
	}

	render_clear(&tcam);
	if(map_enable_autorender)
	{
		render_cubemap((uint32_t*)NULL,
			screen_width, screen_height, 0/4,
			&tcam, clmap,
			NULL, 0, '1', '0', 1.0f, 0);
	}

	// apply Lua HUD / model stuff
	quitflag = quitflag || ib_client_render_hook();

	// clean up stuff that may have happened in the scene
	glDepthMask(GL_TRUE);

	SDL_GL_SwapWindow(window);

#ifdef WIN32
	int msec_wait = 10*(int)(sec_wait*100.0f+0.5f);
	if(msec_wait > 0)
	{
		sec_wait -= msec_wait/1000.0f;
		SDL_Delay(msec_wait);
	}
#else
	int usec_wait = (int)(((double)sec_wait)*1000000.0+0.5f);
	if(usec_wait > 0)
	{
		sec_wait -= usec_wait/1000000.0;
		usleep(usec_wait);
	}
#endif

	return quitflag;
}

int poll_events(void)
{
	int quitflag = 0;

	SDL_Event ev;
	while(SDL_PollEvent(&ev)) {
		switch (ev.type) {
			case SDL_KEYUP:
			case SDL_KEYDOWN:
				quitflag = ib_client_key_hook(ev);
				break;
			case SDL_TEXTINPUT:
				quitflag = ib_client_text_hook(ev);
				break;
			case SDL_MOUSEBUTTONUP:
			case SDL_MOUSEBUTTONDOWN:
				quitflag = ib_client_mouse_press_hook(ev);
				break;
			case SDL_MOUSEMOTION:
				quitflag = ib_client_mouse_motion_hook(ev);
				break;
			case SDL_WINDOWEVENT:
				switch (ev.window.event) {
					case SDL_WINDOWEVENT_FOCUS_GAINED: {
						// workaround for SDL2 not properly resetting state when
						// alt-tabbing
						SDL_bool relative = SDL_GetRelativeMouseMode();
						if (relative) {
							SDL_SetWindowGrab(window, SDL_FALSE);
							SDL_SetRelativeMouseMode(SDL_FALSE);

							SDL_SetWindowGrab(window, SDL_TRUE);
							SDL_SetRelativeMouseMode(SDL_TRUE);
						}
					}
					case SDL_WINDOWEVENT_FOCUS_LOST:
						quitflag = ib_client_window_focus_hook(ev);
						break;
					default:
						break;
				}
				break;
			case SDL_QUIT:
				quitflag = 1;
				break;
			default:
				break;
		}
	}

	return quitflag;
}

int update_client(void)
{
	int quitflag = update_fps_counter();

	if(mod_basedir == NULL)
	{
		// do nothing
	} else if(boot_mode & IB_MAIN_LOADING) {
		printf("boot mode flag 8!\n");
		//abort();

		if(icelua_initfetch())
			return 1;

		boot_mode &= ~IB_MAIN_LOADING;
	} else {
		quitflag = quitflag || ib_client_tick_hook();
	}

	quitflag = quitflag || render_client();

	quitflag = quitflag || poll_events();

	return quitflag;
}
#endif

int update_server(void)
{
	// TODO: respect time returned
	int quitflag = 0;

	lua_getglobal(lstate_server, "server");
	lua_getfield(lstate_server, -1, "hook_tick");
	lua_remove(lstate_server, -2);
	if(lua_isnil(lstate_server, -1))
	{
		lua_pop(lstate_server, 1);
		return 1;
	}

	lua_pushnumber(lstate_server, sec_curtime);
	lua_pushnumber(lstate_server, sec_curtime - sec_lasttime);
	if(lua_pcall(lstate_server, 2, 1, 0) != 0)
	{
		printf("Lua Server Error (tick): %s\n", lua_tostring(lstate_server, -1));
		lua_pop(lstate_server, 1);
		return 1;
	}

#ifndef WIN32
	if(!(boot_mode & IB_CLIENT))
	{
		//printf("waity. %f\n", lua_tonumber(lstate_server, -1));
		sec_wait += lua_tonumber(lstate_server, -1);
		//printf("%f\n", sec_wait);
		int usec_wait = (int)(sec_wait*1000000.0+0.5);
		if(usec_wait > 0)
		{
			sec_wait -= ((double)usec_wait)/1000000.0;

			// TODO: broken? condition is not updated inside loop
			while(usec_wait > 1000000)
				sleep(1);
			usleep(usec_wait);
		}
	}
#endif
	lua_pop(lstate_server, 1);

	return 0;
}

#ifndef DEDI
int run_game_cont1(void)
{
	int quitflag = render_client();
	net_flush();
	if(boot_mode & IB_SERVER)
		quitflag = quitflag || update_server();
	net_flush();

	// update time
	sec_lasttime = sec_curtime;
	int64_t usec_curtime = platform_get_time_usec() - usec_basetime;
	sec_curtime = ((double)usec_curtime)/1000000.0;

	// update client/server
	quitflag = quitflag || update_fps_counter();

	return quitflag;
}

int run_game_cont2(void)
{
	int quitflag = 0;
	if(boot_mode & IB_SERVER)
		quitflag = quitflag || update_server();
	net_flush();

	// update time
	sec_lasttime = sec_curtime;
	int64_t usec_curtime = platform_get_time_usec() - usec_basetime;
	sec_curtime = ((double)usec_curtime)/1000000.0;

	return quitflag;
}
#endif

static void run_game(void)
{
	//clmap = map_load_aos(fnmap);

	tcam.mpx = 256.5f;
	tcam.mpz = 256.5f;
	tcam.mpy = 32.0f-3.0f;
	//clmap->pillars[((int)tcam.mpz)*clmap->xlen+((int)tcam.mpy)][4+1]-2.0f;

	tcam.mxx = 1.0f;
	tcam.mxy = 0.0f;
	tcam.mxz = 0.0f;
	tcam.myx = 0.0f;
	tcam.myy = 1.0f;
	tcam.myz = 0.0f;
	tcam.mzx = 0.0f;
	tcam.mzy = 0.0f;
	tcam.mzz = 1.0f;

	//render_vxl_redraw(&tcam, clmap);

	int quitflag = 0;

	usec_basetime = platform_get_time_usec();

	while(!quitflag)
	{
		// update time
		sec_lasttime = sec_curtime;
		int64_t usec_curtime = platform_get_time_usec() - usec_basetime;
		sec_curtime = ((double)usec_curtime)/1000000.0;

		// update client/server
#ifndef DEDI
		if(boot_mode & IB_CLIENT)
			quitflag = quitflag || update_client();
		net_flush();
#endif
		if(boot_mode & IB_SERVER)
			quitflag = quitflag || update_server();
		net_flush();
	}
	map_free(clmap);
	clmap = NULL;
}

static int print_usage(char *rname)
{
	fprintf(stderr, "usage:\n"
#ifndef DEDI
			"\tfor clients:\n"
			"\t\t%s -c iceball://address:port {clargs} <-,_ connect via ENet protocol (UDP)\n"
			"\t\t%s -c address port {clargs}           <-'\n"
			"\t\t%s -C iceball://address:port {clargs} <-,_ connect via TCP protocol\n"
			"\t\t%s -C address port {clargs}           <-'\n"
			"\tfor servers (quick-start, not recommended for anything serious!):\n"
			"\t\t%s -s port mod {args}\n"
#endif
			"\tfor dedicated servers:\n"
			"\t\t%s -d port mod {args}\n"
			"\n"
			"quick start:\n"
#ifdef DEDI
			"\t%s -d 0 pkg/base pkg/maps/mesa.vxl\n"
#else
			"\t%s -s 0 pkg/base pkg/maps/mesa.vxl\n"
#endif
			"\n"
			"options:\n"
#ifndef DEDI
			"\taddress:  hostname / IP address to connect to\n"
#endif
			"\tport:     TCP port number (recommended: 20737, can be 0 for localhost)\n"
			"\tmod:      mod to run\n"
#ifndef DEDI
			"\tclargs:   arguments to send to the client Lua script\n"
#endif
			"\targs:     arguments to send to the server Lua script\n"
#ifndef DEDI
			,rname,rname,rname,rname,rname
#endif
			,rname,rname);

#ifdef WIN32
	/*
	MessageBox(NULL, "Don't double-click on iceball.exe. Open a commandline instead.\r\n"
		"You should be able to see the usage information if you have.\r\n"
		"TIP: double-clicking on opencmd.bat will get you a commandline in the right place.", "Iceball", MB_OK|MB_ICONERROR|MB_APPLMODAL);
	*/
#endif

	return 99;
}

struct cli_args {
	int net_port;
	char *net_host;
	char *net_path;

	char *basedir;
	int boot_mode;
	int used_args;
};

static int parse_args(int argc, char *argv[], struct cli_args *args) {
	args->net_host = malloc(NET_HOST_SIZE);
	args->net_path = malloc(NET_PATH_SIZE);

	// we set the initial value to a leading slash in order to play nice with
	// sscanf later on
	args->net_path[0] = '/';
	args->net_path[1] = '\0';

#ifdef DEDI
	if (argc <= 1)
		return 1;
#else
	if (argc <= 1) {
		args->net_port = 0;
		args->basedir = "pkg/iceball/launch";
		// TODO: Just make IB_LAUNCHER == IB_LAUNCHER | IB_CLIENT | IB_SERVER? It piggybacks on the existing
		// (client | server) setup stuff anyway, so IB_LAUNCHER without (IB_CLIENT | IB_SERVER) doesn't make sense.
		args->boot_mode = IB_LAUNCHER | IB_CLIENT | IB_SERVER;
		args->used_args = 4;
	} else
#endif

#ifndef DEDI
	if (!strcmp(argv[1], "-h") || !strcmp(argv[1], "--help")) {
		return 1;
	} else if (!strcmp(argv[1], "-l")) {
		// TODO: Merge this with the argc <= 1 thing above
		args->net_port = 0;
		args->boot_mode = IB_LAUNCHER | IB_CLIENT | IB_SERVER;
		// TODO: Ensure used_args values are correct
		args->used_args = 2;
		if (argc >= 3) {
			args->basedir = argv[2];
			args->used_args = 3;
		}
	} else if (!strcmp(argv[1], "-c")) {
		if (argc <= 2 || (argc <= 3 && memcmp(argv[2], "iceball://", 10))) {
			return 1;
		}

		args->net_port = 20737;
		args->used_args = 3;

		if (sscanf(argv[2], "iceball://%[^:]:%i/%s", args->net_host, &args->net_port, &args->net_path[1]) < 1) {
			if (argc <= 3) {
				return 1;
			}

			args->net_host = strncpy(args->net_host, argv[2], NET_HOST_SIZE);
			args->net_port = atoi(argv[3]);
			args->used_args = 4;
		}

		args->basedir = NULL;
		args->boot_mode = IB_CLIENT | IB_ENET;

		printf("Connecting to \"%s\" port %i (ENet mode)\n", args->net_host, args->net_port);
	} else if (!strcmp(argv[1], "-C")) {
		if (argc <= 2 || (argc <= 3 && memcmp(argv[2], "iceball://", 10))) {
			return 1;
		}

		args->net_port = 20737;
		args->used_args = 3;

		if (sscanf(argv[2], "iceball://%[^:]:%i/%s", args->net_host, &args->net_port, &args->net_path[1]) < 1) {
			if (argc <= 3) {
				return 1;
			}

			args->net_host = strncpy(args->net_host, argv[2], NET_HOST_SIZE);
			args->net_port = atoi(argv[3]);
			args->used_args = 4;
		}

		args->basedir = NULL;
		args->boot_mode = IB_CLIENT;

		printf("Connecting to \"%s\" port %i (TCP mode)\n", args->net_host, args->net_port);
	} else if (!strcmp(argv[1], "-s")) {
		if (argc <= 3) {
			return 1;
		}

		args->net_port = atoi(argv[2]);
		args->basedir = argv[3];
		args->boot_mode = IB_CLIENT | IB_SERVER;
		args->used_args = 4;

		printf("Starting server on port %i, mod \"%s\" (local mode client)\n", args->net_port, args->basedir);
	} else
#endif
	if (!strcmp(argv[1], "-d")) {
		if (argc <= 3) {
			return 1;
		}

		args->net_port = atoi(argv[2]);
		args->basedir = argv[3];
		args->boot_mode = IB_SERVER;
		args->used_args = 4;

		printf("Starting headless/dedicated server on port %i, mod \"%s\"\n", args->net_port, args->basedir);
	} else {
		return 1;
	}

	if (boot_mode & IB_SERVER) {
		if (memcmp(args->basedir, "pkg/", 4)) {
			fprintf(stderr, "ERROR: package base dir must start with \"pkg/\"!\n");

			return 1;
		}

		if (strlen(args->basedir) < 5) {
			fprintf(stderr, "ERROR: package base dir can't actually be \"pkg/\"!\n");

			return 1;
		}
	}

	return 0;
}

static void free_args(struct cli_args *args)
{
	free(args->net_host);
	free(args->net_path);
}

int main(int argc, char *argv[])
{
	struct cli_args args = {0};
	int parse_status = parse_args(argc, argv, &args);

	if (parse_status) {
		print_usage(argv[0]);

		free_args(&args);
		return 1;
	}

	// TODO: minimize usage of globals
	main_argc = argc;
	main_argv = argv;
	main_argv0 = argv[0];
	main_oldcwd = NULL;

	net_address = args.net_host;
	net_port = args.net_port;
	net_path = args.net_path;

	boot_mode = args.boot_mode;
	mod_basedir = args.basedir;
	main_largstart = args.used_args;

#ifdef DEDI
	if (net_init()) goto cleanup;
	if (icelua_init()) goto cleanup;

	if (boot_mode & IB_SERVER)
		if (net_bind()) goto cleanup;

	run_game();

cleanup:
	if (boot_mode & IB_SERVER)
		net_unbind();

	icelua_deinit();
	net_deinit();

#else
	if (boot_mode & IB_CLIENT)
		if (platform_init()) goto cleanup;

	if (net_init()) goto cleanup;
	if (icelua_init()) goto cleanup;

	if (boot_mode & IB_SERVER)
		if (net_bind()) goto cleanup;

	if (boot_mode & IB_CLIENT) {
		if (net_connect()
				|| video_init()
				|| wav_init()
				|| render_init(screen_width, screen_height)) goto cleanup;
	}

	run_game();

cleanup:
	if (boot_mode & IB_CLIENT) {
		render_deinit();
		wav_deinit();
		video_deinit();
		net_disconnect();
	}

	if (boot_mode & IB_SERVER)
		net_unbind();

	icelua_deinit();
	net_deinit();

	if (boot_mode & IB_CLIENT)
		platform_deinit();
#endif

	fflush(stdout);
	fflush(stderr);

	free_args(&args);

	return 0;
}
