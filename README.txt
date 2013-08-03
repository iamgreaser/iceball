Forums: http://iceballga.me
Our IRC channel is #iceball @ irc.quacknet.org (not quaKEnet, but quaCKnet).

If you have a Windows build, running iceball.exe should give you a tutorial
on how to actually run this thing.

If you've built this for not-Windows, running ./iceball should do the same.

The tutorial files are located in pkg/iceball/halp/.

If you can't run the tutorial, or you can't read the text on it,
read docs/troubleshooting.txt.

WE HAVE A SERVER LIST:
  http://play.iceballga.me:27790

 ------------------------------------------------------------------------------

LICENSING NOTES:
Iceball is licensed under the regular GNU GPL version 3.
Ice Lua Components is licensed under the LGPL version 3.
All assets are released under Creative Commons 3.0 BY-SA:
  http://creativecommons.org/licenses/by-sa/3.0/

These are, unless otherwise marked:
  Copyright (C) 2012-2013, Iceball contributors.
The credits list is almost always out of date,
so check the git log for a list of contributors.

Ice Lua Components contains some content from libSDL,
  which is licensed under the LGPL version 2.1.
It is marked accordingly.

The manual is in the public domain, except where otherwise specified.

MINIMUM SYSTEM REQUIREMENTS:
A computer.

BUILDING REQUIREMENTS:
- a C compiler that isn't crap (read: not MSVC++)
  - specifically, GCC
  - MinGW is a port of GCC for Windows: http://mingw.org/
  - OS X users: clang is highly recommended
  - if you use something else we might consider compatibility with it
  - learn_more has managed to get this to build with MSVC++ so uh, that could work too.
- SDL 1.2 (not 1.3) - http://libsdl.org/
- Lua 5.1 (not 5.2) - http://lua.org/
- zlib - http://zlib.net/
- sackit - https://github.com/iamgreaser/sackit/
  - you should copy libsackit.a and sackit.h to xlibinc.
- ENet 1.3 - http://enet.bespin.org/
- GNU make
  - if someone has BSD make, please tell us :)

On Windows, read Makefile.mingw for some instructions.
On other OSes, some files for sackit and ENet need to be in xlibinc.

OS X readme:
- install Homebrew and XCode Command-Line Tools
- brew install lua, enet, SDL, glew
- compile sackit from git and copy .a and .so files to /usr/local/lib and sackit.h to /usr/local/include
- make -f Makefile.glosx-clang (recommended, Makefile.glosx uses GCC, Makefile.osx uses the broken software renderer)
- to package into a .app, use ./package-osx.sh (brew install dylibbundler first)

MSVC readme (wip):
- create a folder 'winlibs' in the iceball dir
  dump all dll's + lib's in this folder (opengl,lua,zlib, sdl, glew)
  dump all includes in submaps (glew in glew submap, and so on)
  /iceball/
    /winlibs/
	  /glew/
	  /lua/
	  /SDL/
	  /zlib/
	  glew32.lib
	  glew32.dll
	  lua5.1.lib
	  lua5.1.dll
	  and so on..

- right mouse on project -> properties.
  Working directory (without quotes): '$(SolutionDir)/../'
  Command Arguments (without quotes):
	'-c iceballga.me 20737'  (connect to srv)
	'-s 0 pkg/base' (make local srv)
- edit clsave/pub/user.json
- now run it from vs.net debugger :)

for the git starters:
- git update-index --assume-unchanged clsave\pub\user.json

and to get updates from the main repo:
- git remote add upstream git://github.com/iamgreaser/iceball.git
- git pull --rebase upstream master
- git push origin master

