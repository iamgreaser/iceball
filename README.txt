GUYS GUYS GUYS
FIRST THING YOU NEED TO READ:

Read docs/READ_THIS_FIRST.txt, otherwise you will not be able to play this!
docs/ also has plenty of fun stuff, too,
though if you're getting into modding, read docs/modding_101.txt. Please.

 ------------------------------------------------------------------------------

This isn't a game yet. But it works to some extent now.

NOTE:
By Stack's request, this project is now known as "Iceball".

mesa.vxl is by Triplefox, and is currently being used to test load/render.

LICENSING NOTES:
Iceball is licensed under the regular GNU GPL version 3.
Ice Lua Components is licensed under the LGPL version 3.
All PMF/WAV/TGA assets are released under Creative Commons 3.0 BY-SA:
  http://creativecommons.org/licenses/by-sa/3.0/

These are unless otherwise marked Copyright (C) 2012, Iceball contributors.
See CREDITS.txt for the list, and my apologies if I've forgotten to update it.

Ice Lua Components contains some content from libSDL,
  which is licensed under the LGPL version 2.1.
It is marked accordingly.

All VXL maps are (C) their respective owners.
  
REQUIREMENTS:
- a C compiler that isn't crap (read: not MSVC++)
  - specifically, GCC
  - if you use something else we might consider compatibility with it
- an OS that isn't Windows
  - we'll be working on fixing that shortly
  - in the meantime, feel free to hack your way around the makefile
- SDL 1.2 (not 1.3)
- Lua 5.1 (not 5.2)
- zlib (for file compression/decompression during fetching)
- GNU make
  - if someone has BSD make, please tell us :)

CURRENT STATUS:
- The cubemap renders!
- The scene is rendered to the cubemap!
- You can move around!
- There are player objects!
- There are physics!
- There are models!
- There are IMAGES! Wow!
- The mouse works!
- PMF editor!
- You can buld!
- You can grif cahirs!
- YOU CAN SNIP!
- Map!
- Minimap!
- Killfeed!
- Basic pathname security!

STUFF TO DO:
- Sound assets! We need your sounds, guys!
  - I have made some of these already.
- Actually implement sound support.
- Network it up. (UnrealIncident has offered to work on this.)
- Make the physics less crap.
- Speed up the render a bit.
  - Fix the raycaster.
  - Reuse the cubemaps while moving (scale / depth-dependent translate)
    so we don't need to redraw the FULL cubemaps.
- Make the renderer look less crap.
- Make the models look less crap.
- Implement some form of lighting.
