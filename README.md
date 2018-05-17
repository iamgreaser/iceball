![Iceball logo](https://raw.githubusercontent.com/iamgreaser/iceball/master/pkg/iceball/gfx/splash_logo.png)
[![Build Status](https://travis-ci.org/iamgreaser/iceball.svg?branch=master)](https://travis-ci.org/iamgreaser/iceball)

Iceball is both a highly-extensible engine on top of which people can do anything they want, and a game that builds upon the classic version of [Ace of Spades](http://en.wikipedia.org/wiki/Ace_of_Spades_(video_game)) experience.

# Getting started

Just want to play Iceball? You can grab the latest build from [here](https://github.com/iamgreaser/iceball/releases). If you want to modify the source or just simply build Iceball yourself, see the [How to Build](#how-to-build) section below, or alternatively check out the (now possibly outdated) [instructions](https://github.com/iamgreaser/iceball/wiki/Building) on the wiki.

If you're planning on contributing to the Iceball project, please check out [contribution guidelines](https://github.com/iamgreaser/iceball/wiki/Helping-out) on the wiki as well. All help is appreciated!

# Community

-   **Official**:
    -   Reddit: [/r/iceball](http://reddit.com/r/iceball)
    -   IRC: `irc.fractiongamers.com/#iceball` ([webchat](http://webchat.fractiongamers.com/?channels=iceball))
-   **Unofficial**:
    -   BnS subreddit: [/r/buildandshoot](http://reddit.com/r/buildandshoot)
    -   BnS subforum: [buildandshoot.com](http://www.buildandshoot.com/viewforum.php?f=84)

# How to Build

## Linux

Grab the dependencies:

```
# Ubuntu et. al.
$ sudo apt update
$ sudo apt install cmake libsdl2-dev libenet-dev libluajit-5.1-dev
```

Run CMake and compile:

```
cmake . && cmake --build .
```

## Windows

### Msys2

The Msys2 MinGW toolchain is recommended since it provides hassle-free dependency management.

Grab the dependencies (assuming running MSYS2 MinGW 64-bit shell; otherwise change x86_64 to i686)

```
$ pacman -S mingw-w64-x86_64-cmake mingw-w64-x86_64-SDL2 mingw-w64-x86_64-luajit-git mingw-w64-x86_64-enet
```

Run CMake and compile:

```
$ cmake -G "MSYS Makefiles" . && make iceball
```

If you want to build the dedicated server executable, run

```
$ make iceball-dedi
```

### MinGW

Dependency management is done using Hunter;

```
$ cmake -G "MinGW Makefiles" -DHUNTER_ENABLED=ON -DCMAKE_SH="CMAKE_SH-NOTFOUND" . && mingw32-make iceball
```

If you want to build the dedicated server executable, run

```
$ mingw32-make iceball-dedi
```

### MSVC

Dependency management is done using Hunter as well. Open up the VS command prompt and enter

```
$ cmake -G "Visual Studio 15 2017 Win64" -DHUNTER_ENABLED=ON . && cmake --build . --target iceball
```

If you want to build the dedicated server executable, run

```
$ cmake --build . --target iceball-dedi
```

## OS X

Grab the dependencies:

```
$ brew install lua, enet, SDL2
```

Run CMake and compile:

```
$ cmake . && cmake --build .
```

# Feedback
If you have some thoughts on how to improve this project, please use the subreddit to start a discussion about it. If the feature you want added is both clearly defined and plausible, you can open a issue in the [issue tracker](https://github.com/iamgreaser/iceball/issues) instead.

You should also use the [issue tracker](https://github.com/iamgreaser/iceball/issues) for reporting any bugs you find. Make sure they aren't already reported though!

# More info

Check out the `docs/` directory for some in-depth information regarding formats, engine intrinsics etc. Be aware that not all documentation may be up to date however. A lot of information is also available at the original [wiki](https://github.com/iamgreaser/iceball/wiki).

# License

```
    Iceball is licensed under the regular GNU GPL version 3.
    Ice Lua Components is licensed under the LGPL version 3.
    Any of the "Team Sparkle" stuff is available under MIT, including the launcher.
    Sackit is under public domain.
    All assets are released under Creative Commons 3.0 BY-SA:
      http://creativecommons.org/licenses/by-sa/3.0/

    These are, unless otherwise marked:
      Copyright (C) 2012-2015, Iceball contributors.

    The credits list is almost always out of date,
    so check the git log for a list of contributors.

    Ice Lua Components contains some content from libSDL,
      which is licensed under the LGPL version 2.1.
    It is marked accordingly.

    Code in src/external is licensed under their respective licenses,
      which are listed in LICENCE-others.txt.

    The manual is in the public domain, except where otherwise specified.

    Copyright (C) 2012-2015, Iceball contributors
```
