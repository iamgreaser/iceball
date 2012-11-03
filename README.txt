This isn't a game yet. But it works to some extent now.

mesa.vxl is by Triplefox, and is currently being used to test load/render.

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
