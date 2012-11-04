This isn't a game yet. But it works to some extent now.

mesa.vxl is by Triplefox, and is currently being used to test load/render.

REQUIREMENTS:
- a C compiler that isn't crap (read: not MSVC++)
  - specifically, GCC
  - if you use something else we might consider compatibility with it
- an OS that isn't Windows
  - we'll be working on fixing that shortly
  - in the meantime, feel free to hack your way around the makefile
- SDL 1.2 (not 1.3)
- Lua 5.1 (not 5.2)
- GNU make
  - if someone has BSD make, please tell us :)

CURRENT STATUS:
- The cubemap renders!
- The scene is rendered to the cubemap!
- You can move around!

STUFF TO DO:
- Get physics working.
- Models! Which means a z-buffer will most likely be needed.
  (We have those on the cubemaps at least! But they're not used yet.)
- Network it up. (UnrealIncident has offered to work on this.)
- Speed up the render a bit.
  - Reuse the cubemaps while moving (scale / depth-dependent translate)
    so we don't need to redraw the FULL cubemaps.
