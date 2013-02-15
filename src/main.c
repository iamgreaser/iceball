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
SDL_Surface *screen = NULL;
#endif
int screen_width = 800;
int screen_height = 600;

int force_redraw = 1;

// bit 0 = client, bit 1 = server, bit 2 == main_client.lua has been loaded
int boot_mode = 0;

char *mod_basedir = NULL;
char *net_addr;
int net_port;

int main_argc;
char **main_argv;
int main_largstart = -1;

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
	if(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_NOPARACHUTE))
		return error_sdl("SDL_Init");
	
#ifndef WIN32
	signal(SIGPIPE, SIG_IGN);
	signal(SIGINT, SIG_DFL);
#endif
	
	return 0;
}

int video_init(void)
{
	SDL_WM_SetCaption("iceball",NULL);
	
#ifdef USE_OPENGL
	SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 8);
	SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8);
	SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 8);
	SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
	screen = SDL_SetVideoMode(screen_width, screen_height, 32, SDL_OPENGL);
	GLenum err_glew = glewInit();
	if(err_glew != GLEW_OK)
	{
		fprintf(stderr, "GLEW failed to init: %s\n", glewGetErrorString(err_glew));
		return 1;
	}
	if(!GL_ARB_texture_non_power_of_two)
	{
		fprintf(stderr, "ERROR: GL_ARB_texture_non_power_of_two not supported by your GPU. Either get a better GPU, or use the software renderer.\n");
		return 1;
	}
#else
	screen = SDL_SetVideoMode(screen_width, screen_height, 32, 0);
#endif
	
	if(screen == NULL)
		return error_sdl("SDL_SetVideoMode");
	
	return 0;
}

void video_deinit(void)
{
	// don't do anything
}

void platform_deinit(void)
{
	SDL_Quit();
}
#endif

int64_t platform_get_time_usec(void)
{
#ifdef WIN32
	int64_t msec = SDL_GetTicks();
	return msec*1000;
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

int64_t frame_prev = 0;
int64_t frame_now = 0;
int fps = 0;

float sec_curtime = 0.0f;
float sec_lasttime = 0.0f;
float sec_wait = 0.0f;
float sec_serv_wait = 0.0f;

float ompx = -M_PI, ompy = -M_PI, ompz = -M_PI;

int64_t usec_basetime;

#ifndef DEDI
int update_client_contpre1(void)
{
	int quitflag = 0;
	
	// update FPS counter
	frame_now = platform_get_time_usec();
	fps++;
	
	if(frame_now - frame_prev > (int64_t)1000000)
	{
		char buf[64]; // topo how the hell did this not crash at 16 --GM
		sprintf(buf, "iceball | FPS: %d", fps);
		SDL_WM_SetCaption(buf, NULL);
		fps = 0;
		frame_prev = platform_get_time_usec();
	}
	
	return quitflag;
}

int update_client_cont1(void)
{
	int quitflag = 0;
	
	// skip while still loading
	if(mod_basedir == NULL || (boot_mode & 8))
		return 0;
	
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
	
	//printf("%.2f",);
	// draw scene to cubemap
	SDL_LockSurface(screen);

	//memset(screen->pixels, 0x51, screen->h*screen->pitch);
	render_cubemap((uint32_t*)screen->pixels,
		screen->w, screen->h, screen->pitch/4,
		&tcam, clmap);
	
	// apply Lua HUD / model stuff
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
	
	SDL_UnlockSurface(screen);
#ifdef USE_OPENGL
	SDL_GL_SwapBuffers();
#else
	SDL_Flip(screen);
#endif
	
	int msec_wait = 10*(int)(sec_wait*100.0f+0.5f);
	if(msec_wait > 0)
	{
		sec_wait -= msec_wait;
		SDL_Delay(msec_wait);
	}
	
	SDL_Event ev;
	while(SDL_PollEvent(&ev))
	switch(ev.type)
	{
		case SDL_KEYUP:
		case SDL_KEYDOWN:
			// inform Lua client
			lua_getglobal(lstate_client, "client");
			lua_getfield(lstate_client, -1, "hook_key");
			lua_remove(lstate_client, -2);
			if(lua_isnil(lstate_client, -1))
			{
				// not hooked? ignore!
				lua_pop(lstate_client, 1);
				break;
			}
			
			lua_pushinteger(lstate_client, ev.key.keysym.sym);
			lua_pushboolean(lstate_client, (ev.type == SDL_KEYDOWN));
			lua_pushinteger(lstate_client, (int)(ev.key.keysym.mod));
			
			if(lua_pcall(lstate_client, 3, 0, 0) != 0)
			{
				printf("Lua Client Error (key): %s\n", lua_tostring(lstate_client, -1));
				lua_pop(lstate_client, 1);
				quitflag = 1;
				break;
			}
			break;
		case SDL_MOUSEBUTTONUP:
		case SDL_MOUSEBUTTONDOWN:
			// inform Lua client
			lua_getglobal(lstate_client, "client");
			lua_getfield(lstate_client, -1, "hook_mouse_button");
			lua_remove(lstate_client, -2);
			if(lua_isnil(lstate_client, -1))
			{
				// not hooked? ignore!
				lua_pop(lstate_client, 1);
				break;
			}
			lua_pushinteger(lstate_client, ev.button.button);
			lua_pushboolean(lstate_client, (ev.type == SDL_MOUSEBUTTONDOWN));
			if(lua_pcall(lstate_client, 2, 0, 0) != 0)
			{
				printf("Lua Client Error (mouse_button): %s\n", lua_tostring(lstate_client, -1));
				lua_pop(lstate_client, 1);
				quitflag = 1;
				break;
			}
			break;
		case SDL_MOUSEMOTION:
			// inform Lua client
			lua_getglobal(lstate_client, "client");
			lua_getfield(lstate_client, -1, "hook_mouse_motion");
			lua_remove(lstate_client, -2);
			if(lua_isnil(lstate_client, -1))
			{
				// not hooked? ignore!
				lua_pop(lstate_client, 1);
				break;
			}
			lua_pushinteger(lstate_client, ev.motion.x);
			lua_pushinteger(lstate_client, ev.motion.y);
			lua_pushinteger(lstate_client, ev.motion.xrel);
			lua_pushinteger(lstate_client, ev.motion.yrel);
			if(lua_pcall(lstate_client, 4, 0, 0) != 0)
			{
				printf("Lua Client Error (mouse_motion): %s\n", lua_tostring(lstate_client, -1));
				lua_pop(lstate_client, 1);
				quitflag = 1;
				break;
			}
			break;
		case SDL_ACTIVEEVENT:
			if( ev.active.state & SDL_APPACTIVE ||
				ev.active.state & SDL_APPINPUTFOCUS )
			{
				lua_getglobal(lstate_client, "client");
				lua_getfield(lstate_client, -1, "hook_window_activate");
				lua_remove(lstate_client, -2);
				if(lua_isnil(lstate_client, -1))
				{
					// not hooked? ignore!
					lua_pop(lstate_client, 1);
					break;
				}
				lua_pushboolean(lstate_client, ev.active.gain == 1);
				if(lua_pcall(lstate_client, 1, 0, 0) != 0)
				{
					printf("Lua Client Error (window_activate): %s\n", lua_tostring(lstate_client, -1));
					lua_pop(lstate_client, 1);
					quitflag = 1;
					break;
				}
			}
			break;
		case SDL_QUIT:
			quitflag = 1;
			break;
		default:
			break;
	}
	
	return quitflag;
}

int update_client(void)
{
	int quitflag = update_client_contpre1();
	
	if(mod_basedir == NULL)
	{
		// do nothing
	} else if(boot_mode & 8) {
		printf("boot mode flag 8!\n");
		//abort();
		
		if(icelua_initfetch())
			return 1;
		
		boot_mode &= ~8;
	} else {
		lua_getglobal(lstate_client, "client");
		lua_getfield(lstate_client, -1, "hook_tick");
		lua_remove(lstate_client, -2);
		if(lua_isnil(lstate_client, -1))
		{
			lua_pop(lstate_client, 1);
			return 1;
		}
		
		lua_pushnumber(lstate_client, sec_curtime);
		lua_pushnumber(lstate_client, sec_curtime - sec_lasttime);
		if(lua_pcall(lstate_client, 2, 1, 0) != 0)
		{
			printf("Lua Client Error (tick): %s\n", lua_tostring(lstate_client, -1));
			lua_pop(lstate_client, 1);
			return 1;
		}
		if(!(boot_mode & 2))
			sec_wait += lua_tonumber(lstate_client, -1);
		lua_pop(lstate_client, 1);
	}
	
	quitflag = quitflag || update_client_cont1();
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
	if(!(boot_mode & 1))
	{
		//printf("waity. %f\n", lua_tonumber(lstate_server, -1));
		sec_wait += lua_tonumber(lstate_server, -1);
		//printf("%f\n", sec_wait);
		int usec_wait = (int)(sec_wait*1000000.0+0.5);
		if(usec_wait > 0)
		{
			sec_wait -= ((double)usec_wait)/1000000.0;
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
	int quitflag = update_client_cont1();
	net_flush();
	if(boot_mode & 2)
		quitflag = quitflag || update_server();
	net_flush();
	
	// update time
	sec_lasttime = sec_curtime;
	int64_t usec_curtime = platform_get_time_usec() - usec_basetime;
	sec_curtime = ((float)usec_curtime)/1000000.0f;
	
	// update client/server
	quitflag = quitflag || update_client_contpre1();
	
	return quitflag;
}

int run_game_cont2(void)
{
	int quitflag = 0;
	if(boot_mode & 2)
		quitflag = quitflag || update_server();
	net_flush();
	
	// update time
	sec_lasttime = sec_curtime;
	int64_t usec_curtime = platform_get_time_usec() - usec_basetime;
	sec_curtime = ((float)usec_curtime)/1000000.0f;
	
	return quitflag;
}
#endif

void run_game(void)
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
		sec_curtime = ((float)usec_curtime)/1000000.0f;
		
		// update client/server
#ifndef DEDI
		if(boot_mode & 1)
			quitflag = quitflag || update_client();
		net_flush();
#endif
		if(boot_mode & 2)
			quitflag = quitflag || update_server();
		net_flush();
	}
	map_free(clmap);
	clmap = NULL;
}

int print_usage(char *rname)
{
	fprintf(stderr, "usage:\n"
#ifndef DEDI
			"\tfor clients:\n"
			"\t\t%s -c address port {clargs}\n"
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
			,rname,rname
#endif
			,rname,rname);
	
	return 99;
}

int main_dbghelper(int argc, char *argv[])
{
	if(argc <= 1)
		return print_usage(argv[0]);
	
	main_argc = argc;
	main_argv = argv;
#ifndef DEDI
	if(!strcmp(argv[1], "-c"))
	{
		if(argc <= 3)
			return print_usage(argv[0]);
		
		net_addr = argv[2];
		net_port = atoi(argv[3]);
		printf("Connecting to \"%s\" port %i\n", net_addr, net_port);
		mod_basedir = NULL;
		main_largstart = 4;
		
		boot_mode = 1;
		//return 101;
	} else if(!strcmp(argv[1], "-s")) {
		if(argc <= 3)
			return print_usage(argv[0]);
		
		net_port = atoi(argv[2]);
		mod_basedir = argv[3];
		printf("Starting server on port %i, mod \"%s\"\n", net_port, mod_basedir);
		main_largstart = 4;
		
		boot_mode = 3;
	} else
#endif
	if(!strcmp(argv[1], "-d")) {
		if(argc <= 3)
			return print_usage(argv[0]);
		
		net_port = atoi(argv[2]);
		mod_basedir = argv[3];
		printf("Starting headless/dedicated server on port %i, mod \"%s\"\n", net_port, mod_basedir);
		main_largstart = 4;
		
		boot_mode = 2;
		//return 101;
	} else {
		return print_usage(argv[0]);
	}
	
	if(boot_mode & 2)
	{
		if(memcmp(mod_basedir,"pkg/",4))
		{
			fprintf(stderr, "ERROR: package base dir must start with \"pkg/\"!\n");
			return 109;
		}
		
		if(strlen(mod_basedir) < 5)
		{
			fprintf(stderr, "ERROR: package base dir can't actually be \"pkg/\"!\n");
			return 109;
		}
	}
	
#ifndef DEDI
	if((!(boot_mode & 1)) || !platform_init()) {
#endif
	if(!net_init()) {
	if(!icelua_init()) {
	if((!(boot_mode & 2)) || !net_bind()) {
#ifndef DEDI
	if((!(boot_mode & 1)) || !net_connect()) {
	if((!(boot_mode & 1)) || !video_init()) {
	if((!(boot_mode & 1)) || !wav_init()) {
	if((!(boot_mode & 1)) || !render_init(screen->w, screen->h)) {
#endif
		run_game();
#ifndef DEDI
		if(boot_mode & 1) render_deinit();
	} if(boot_mode & 1) wav_deinit();
	} if(boot_mode & 1) video_deinit();
	} if(boot_mode & 1) net_disconnect();
#endif
	} if(boot_mode & 2) net_unbind();
	} icelua_deinit();
	} net_deinit();
#ifndef DEDI
	} if(boot_mode & 1) platform_deinit();
	}
#endif
	
	return 0;
}


#ifdef __cplusplus
extern "C"
#endif
int main(int argc, char *argv[])
{
	int iRet = main_dbghelper( argc, argv );
#if _DEBUG && _WIN32
	if( iRet != 0 && IsDebuggerPresent() ) {	//we didnt exit successfully, and there is a debugger attached.
		DebugBreak();		//break!
	}
#endif
	return iRet;
}