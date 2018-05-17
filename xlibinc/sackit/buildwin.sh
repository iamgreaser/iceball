#!/bin/sh
make -f Makefile APPSUFFIX=.exe SDL_CFLAGS="-Iwinlibs/ -Iwinlibs/SDL/" SDL_LDFLAGS="-Lwinlibs/ -lmingw32 -lSDLmain -lSDL" CC=mingw32-gcc RANLIB=mingw32-ranlib LIBSACKIT_SO=sackit.dll LIBSACKIT_A=libsackit-w32.a

