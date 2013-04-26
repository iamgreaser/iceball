Iceball
======

  
> GUYS GUYS GUYS. 
> FIRST THING YOU NEED TO READ:
>  
> docs/READ_THIS_FIRST.txt might work.
> If not, there's a tutorial on the forums:
>   
> http://iceballga.me

------------------------------------------------------------------------------

This is FINALLY a game, BUT is not ready to be released yet.

NOTE
----
By Stack's request, this project is now known as "Iceball".

mesa.vxl is by Triplefox, and is currently being used to test load/render.

LICENSING NOTES
---------------
Iceball is licensed under the regular GNU GPL version 3.
Ice Lua Components is licensed under the LGPL version 3.
All assets are released under Creative Commons 3.0 BY-SA:
> http://creativecommons.org/licenses/by-sa/3.0/

These are, unless otherwise marked:
> Copyright (C) 2012-2013, Iceball contributors.

The credits list is almost always out of date, so check the git log for a list of contributors.

Ice Lua Components contains some content from libSDL,  which is licensed under the LGPL version 2.1.
It is marked accordingly.

The manual is in the public domain, except where otherwise specified.

REQUIREMENTS
------------

1. a C compiler that isn't crap (read: not MSVC++)
  * specifically, GCC
  * MinGW is a port of GCC for Windows: http://mingw.org/
  * if you use something else we might consider compatibility with it
  * learn_more has managed to get this to build with MSVC++ so uh, that could work too.
2. SDL 1.2 (not 1.3) - http://libsdl.org/
3. Lua 5.1 (not 5.2) - http://lua.org/
4. zlib - http://zlib.net/
5. sackit - https://github.com/iamgreaser/sackit/
  * you should copy libsackit.a and sackit.h to xlibinc.
6. GNU make
  * if someone has BSD make, please tell us :)

COMPILING ON UNIX
----------------
After installing/compiling all dependencies, just execute `make`. 
No `./configure` needed.

If some trouble with lua, try uncomment line in Makefile

    HEADERS_Lua = #-I /usr/include/lua5.1
    
Also, if you get error "library not found for -llua" try change line in Makefile

    LIBS_Lua = -llua

to

    LIBS_Lua = -llua5.1

If you encounter another problem, keep your eye on Makefile

MSVC readme (wip)
-----------------
1. create a folder `winlibs` in the buldenthesnip dir
  dump all dll's + lib's in this folder (opengl, lua, zlib, sdl, glew)
  dump all includes in submaps (glew in glew submap, and so on)
  * /buldenthesnip/
     * /winlibs/
         * /glew/
         * /lua/
         * /SDL/
         * /zlib/
         * glew32.lib
         * glew32.dll
         * lua5.1.lib
         * lua5.1.dll
         * and so on..

2. right mouse on project -> properties.
 *  Working directory: `$(SolutionDir)/../`
 *  Command Arguments:
     * `-c iceballga.me 20737`  (connect to srv)
     * `-s 0 pkg/base` (make local srv)
3. edit clsave/pub/user.json
4. now run it from vs.net debugger :)


------------------------------------------------------------------------------
### STUFF TO DO BEFORE 0.1 CAN BE RELEASED
* DOCS!!! (ones which aren't crap)
* make net_pack more solid
* JSON writer
* make kicking not suck

### for the git starters
    git update-index --assume-unchanged clsave\pub\user.json

### and to get updates from the main repo
    git remote add upstream git://github.com/iamgreaser/buldthensnip.git
    git pull --rebase upstream master
    git push origin master

