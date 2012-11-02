This doesn't work yet.

mesa.vxl is by Triplefox, and is currently being used to test load/render.

CURRENT STATUS:
- The cubemap renders!
- Some parts of the scene are partially rendered to the cubemap!

STUFF TO DO:
- Render the rest of the scene to the cubemap.
- Speed up the render a bit.
- Take input from user. Yep, I hate this part.
- From there, get a flying camera working.
- From there, get physics working.
- Reuse the cubemaps while moving (scale / depth-dependent translate)
  so we don't need to redraw the FULL cubemaps.
- Models! Which means a z-buffer will most likely be needed.
  (We have those on the cubemaps at least! But they're not used yet.)
- Network it up. (UnrealIncident has offered to work on this.)
