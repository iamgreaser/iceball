# Versions
----------

*Current version:* 0.2.1-35

## Bugs
### Unfixed

| Msg                                                                    | Intro    |
| ---------------------------------------------------------------------- | -------- |
| B-format audio system incomplete                                       | 0.2.1-29 |
| FBO support incomplete                                                 | 0.2.1-16 |
| Garbage collection incomplete (only pmf/img/wav supported)             | 0.1.2-10 |
| Preliminary PNG support - more support to come when we can be bothered | 0.1.2-2  |
| [OpenGL] Frustum culling still screws up on occasion                   | 0.1-3    |
| Kick message isn't communicated properly                               | 0.0-49   |
| Occasional crash in sackit_module_free on common.mus_free              | 0.0      |
| Sound distance attenuation affected by zoom (workaround implemented)   | 0.0      |
| string mode bugged in net_pack, net_*_array                            | 0.0      |

### Fixed

| Msg                                                                                                         | Fix      | Intro    |
| ----------------------------------------------------------------------------------------------------------- | -------- | -------- |
| PRNG not supported                                                                                          | 0.2.1-35 | 0.0      |
| VXL height autodetection fails on ylen assertion                                                            | 0.2.1-33 | 0.2.1-32 |
| Possible crash when loading invalid maps                                                                    | 0.2.1-32 | 0.0      |
| Possible crash when loading VXL maps                                                                        | 0.2.1-31 | 0.2.1-4  |
| net_pack/unpack_array not supported                                                                         | 0.2.1-30 | 0.0      |
| string mode bugged in net_unpack                                                                            | 0.2.1-30 | 0.0      |
| B-format audio system not supported                                                                         | 0.2.1-29 | 0.0      |
| Potential infinite loop due to zero time delta                                                              | 0.2.1-28 | 0.0      |
| .it module music plays at wrong frequency when mixing freq not 44100Hz                                      | 0.2.1-27 | 0.0      |
| IMA ADPCM samples not supported                                                                             | 0.2.1-26 | 0.0      |
| img_dump not sandboxed - UPGRADE                                                                            | 0.2.1-23 | 0.2.1-22 |
| gl_flip_quads incomplete                                                                                    | 0.2.1-21 | 0.0      |
| map_render support incomplete                                                                               | 0.2.1-20 | 0.2.1-15 |
| FBOs not supported                                                                                          | 0.2.1-16 | 0.0      |
| map_render not supported                                                                                    | 0.2.1-15 | 0.0      |
| [OpenGL] Vertex attributes not supported in shaders                                                         | 0.2.1-14 | 0.0      |
| [OpenGL] VAs broken when VBOs disabled                                                                      | 0.2.1-12 | 0.0      |
| Segfault when blitting without a screen, even image-to-image                                                | 0.2.1-10 | 0.0      |
| [OpenGL] Map and PMF normals not emitted for shaders                                                        | 0.2.1-9  | 0.2.1-8  |
| [OpenGL] Normal information for VAs overrides colour information by mistake                                 | 0.2.1-9  | 0.2.1-7  |
| [OpenGL] GLSL shaders not supported                                                                         | 0.2.1-8  | 0.0      |
| [OpenGL] Multitexturing not supported                                                                       | 0.2.1-7  | 0.0      |
| [OpenGL] Stencil bits not set properly, resulting in red screen on some drivers                             | 0.2.1-6  | 0.2.1-2  |
| Crash on map_free after map_new                                                                             | 0.2.1-5  | 0.2.1-4  |
| Lack of depth / stencil buffer mode selection support                                                       | 0.2.1-2  | 0.0      |
| VA API lacks support for blending                                                                           | 0.2.1-1  | 0.1.2-1  |
| [Windows] Launcher crashes when joining server if path contains spaces and not run from command line        | 0.2a-7   | 0.1.2-11 |
| Compat breakage with va_render_global and textures                                                          | 0.2a-3   | 0.2a-2   |
| VA API rendering broken on non-VBO mode                                                                     | 0.2a-2   | 0.2a-1   |
| Memory leak when reusing a VA in va_make                                                                    | 0.2a-2   | 0.2a-1   |
| VA API lacks support for textures                                                                           | 0.2a-2   | 0.2a-1   |
| Lua vertex array (VA) rendering not supported                                                               | 0.2a-1   | 0.0      |
| JSON writer not sandboxed - UPGRADE                                                                         | 0.2a     | 0.1.2-6  |
| JSON writer crashes on 64-bit builds                                                                        | 0.2-2    | 0.1.2-6  |
| tcp_connect crashes on address failure                                                                      | 0.2-2    | 0.0      |
| argb_spit_to_merged broken on ARM                                                                           | 0.2-2    | 0.0      |
| Local code cannot write to clsave/pub                                                                       | 0.2-1    | 0.0      |
| Network serialisation broken on ARM                                                                         | 0.1.2-14 | 0.0      |
| Frame delay in client.hook_tick doesn't work properly - Frame limiter will not work                         | 0.1.2-12 | 0.0      |
| GARBAGE COLLECTION CRASHY AND UNSTABLE, DO NOT USE THIS VERSION                                             | 0.1.2-11 | 0.1.2-10 |
| Garbage collection not supported                                                                            | 0.1.2-10 | 0.0      |
| UDP sending can crash if DNS lookup fails                                                                   | 0.1.2-9  | 0.0      |
| General JSON support is broken                                                                              | 0.1.2-7  | 0.0      |
| JSON writing not supported                                                                                  | 0.1.2-6  | 0.0      |
| Server stability is a bit crap (this bug fixed in 0.1.2-5)                                                  | 0.1.2-5  | 0.0      |
| PNG reader lacks support for greyscale/indexed images                                                       | 0.1.2-4  | 0.1.2-2  |
| PNG reader lacks support for tRNS-block transparency                                                        | 0.1.2-4  | 0.1.2-2  |
| [OpenGL] Low-quality mode not supported                                                                     | 0.1.2-3  | 0.0      |
| PNG not supported                                                                                           | 0.1.2-2  | 0.0      |
| [OSX][softgm] Colours are incorrect (32-bit endian swap)                                                    | 0.1.2-1  | 0.0      |
| Sound broken wrt stereo (only the last sound played is in stereo; the rest uses the left for both channels) | 0.1.2    | 0.0      |
| [Windows] iceball:// handler doesn't set current directory correctly                                        | 0.1.1-9  | 0.1.1-8  |
| iceball:// URL scheme not supported                                                                         | 0.1.1-8  | 0.0      |
| [softgm] Image scaling not supported                                                                        | 0.1.1-7  | 0.1.1-5  |
| Incompatible semantics for image scaling                                                                    | 0.1.1-7  | 0.1.1-5  |
| Image scaling accidentally only supported integers for scale parameters                                     | 0.1.1-6  | 0.1.1-5  |
| Image scaling not supported                                                                                 | 0.1.1-5  | 0.0      |
| common.net_pack() reads an integer before it converts it to floating point                                  | 0.1.1-3  | 0.0      |
| [OpenGL] Preliminary stutter-reduced rendering (WIP)                                                        | 0.1.1-2  | 0.0-38   |
| [OpenGL] Breaking blocks around the edges does not update the chunks properly                               | 0.1.1-2  | 0.0      |
| Arbitrary UDP connections not supported                                                                     | 0.1.1-1  | 0.0      |
| Raw TCP appears to ignore the whitelist on the client side                                                  | 0.1-9    | 0.1-1    |
| Raw TCP still throws a lua error if it can't connect                                                        | 0.1-9    | 0.1-1    |
| Occasional crash when music is stopped                                                                      | 0.1-8    | 0.0      |
| [OpenGL] Frustum culling improved in later versions                                                         | 0.1-7    | 0.1-3    |
| [OpenGL] Ambient occlusion on sides rendered very unequally on very rare GPUs such as the Intel HD 3000     | 0.1-5    | 0.1-4    |
| [OpenGL] Ambient occlusion on sides not rendered equally                                                    | 0.1-4    | 0.0      |
| [OpenGL] Frustum culling not supported                                                                      | 0.1-3    | 0.0      |
| This build doesn't actually compile on not-windows because itoa isn't a real function.                      | 0.1-2    | 0.1-1    |
| Raw TCP connection throws an error on failure                                                               | 0.1-2    | 0.1-1    |
| Arbitrary TCP connections not supported                                                                     | 0.1-1    | 0.0      |
| Binary files don't have a type name                                                                         | 0.1      | 0.0      |
| JSON files cannot be remotely sent to clients                                                               | 0.1      | 0.0      |
| Local mode (-s) broken and causes a crash                                                                   | 0.0-53   | 0.0-51   |
| Timing accuracy somewhat bad (uses a float instead of a double, mostly an issue for sec_current)            | 0.0-53   | 0.0      |
| There are some weird network stability issues                                                               | 0.0-53   | 0.0      |
| Server tends to crash when a TCP connection loads and there's at least one other client still connected     | 0.0-52   | 0.0-51   |
| ENet protocol not supported                                                                                 | 0.0-51   | 0.0      |
| Network handle architecture changed. If it breaks, upgrade. If your mods break, FIX THEM.                   | 0.0-50   | 0.0      |
| Kick not handled gracefully                                                                                 | 0.0-49   | 0.0      |
| [OpenGL] Chunk count is static and does not adapt to different fog values                                   | 0.0-48   | 0.0      |
| No way to determine from the Lua end what renderer a client is using                                        | 0.0-48   | 0.0      |
| [OpenGL] Chunk generation pattern kinda sucks                                                               | 0.0-48   | 0.0      |
| Binary file loading/saving not supported                                                                    | 0.0-47   | 0.0      |
| [OpenGL] PMF models tend to z-fight                                                                         | 0.0-46   | 0.0-22   |
| Inbuilt tutorial not available in this version                                                              | 0.0-45   | 0.0      |
| libsackit is out of date and does not support IT 2.14p3 resonant filters                                    | 0.0-45   | 0.0      |
| [Windows] MessageBox added to 0.0-44 telling people not to double-click the .exe files                      | 0.0-44   | 0.0      |
| [Windows binary build] stdout/stderr is now moved to the commandline in 0.0-44 - upgrade!                   | 0.0-44   | 0.0      |
| File transfer cancellation not supported                                                                    | 0.0-43   | 0.0      |
| [OpenGL] lack of support for cards w/o non-power-of-2 texture support                                       | 0.0-42   | 0.0-22   |
| [OpenGL] option to disable VBOs not available                                                               | 0.0-41   | 0.0-22   |
| [OpenGL] Chunks rendering options not supported in game engine config file                                  | 0.0-40   | 0.0-22   |
| [softgm] Preliminary smooth lighting (WIP)                                                                  | 0.0-39   | 0.0-37   |
| [OpenGL] Rendering tends to stutter on some cards                                                           | 0.0-38   | 0.0-22   |
| [OpenGL] Smooth lighting not supported                                                                      | 0.0-35   | 0.0-22   |
| Server must be manually seeded                                                                              | 0.0-34   | 0.0      |
| A few compilation warnings that shouldn't be there                                                          | 0.0-34   | 0.0-33   |
| .it module music not supported                                                                              | 0.0-32   | 0.0      |
| broke dedicated server build... again                                                                       | 0.0-31   | 0.0-30   |
| clsave/config.json not supported                                                                            | 0.0-30   | 0.0      |
| [OpenGL] Crashes on map creation (as opposed to map loading)                                                | 0.0-29   | 0.0-19   |
| Sound loader only loads first half of 16-bit samples correctly                                              | 0.0-28   | 0.0      |
| Altered the international keyboard thing to be more backwards compatible                                    | 0.0-27   | 0.0      |
| THIS VERSION IS INCOMPATIBLE. PLEASE UPGRADE TO 0.0-27 AT LEAST.                                            | 0.0-27   | 0.0-25   |
| TODO: give changelog for -25/-26 (which I think are the same version more or less)                          | 0.0-26   | 0.0      |
| [OpenGL] VBOs not supported                                                                                 | 0.0-24   | 0.0-19   |
| [OpenGL] texture rendering is slow                                                                          | 0.0-23   | 0.0-19   |
| Preliminary OpenGL support (fog not supported yet)                                                          | 0.0-22   | 0.0-19   |
| PMF renderer does not update bones when redefined                                                           | 0.0-22   | 0.0-21   |
| OpenGL renderer ignores islocal flag when rendering PMFs                                                    | 0.0-21   | 0.0-19   |
| OpenGL not supported                                                                                        | 0.0-19   | 0.0      |
| OpenMP not supported                                                                                        | 0.0-17   | 0.0      |
| Per-face shading is only preliminary                                                                        | 0.0-16   | 0.0      |
| Color conversion functions are using hacky Lua code                                                         | 0.0-14   | 0.0      |
| No per-face shading                                                                                         | 0.0-13   | 0.0      |
| TGA loader prone to crashing on unsanitised data                                                            | 0.0-12   | 0.0      |
| Blocks appear inverted in common cases                                                                      | 0.0-11   | 0.0      |
| Immediate ceiling isn't drawn                                                                               | 0.0-10   | 0.0      |
| Mouse warping not implemented                                                                               | 0.0-9    | 0.0      |
| Renderer uses double-rect approximation of cube instead of using trapezia                                   | 0.0-8    | 0.0      |
| Camera roll / camera_point_sky not implemented - drunken cam will not roll properly                         | 0.0-7    | 0.0      |
| CRASHES ON CHANNEL WRAPAROUND - PLEASE UPDATE TO 0.0-6!                                                     | 0.0-6    | 0.0-5    |
| Dedicated server build was broken                                                                           | 0.0-5    | 0.0-4    |
| Sound is not supported                                                                                      | 0.0-4    | 0.0      |
| common.img_fill not implemented (this wrapper will be somewhat slow)                                        | 0.0-3    | 0.0      |
| PMF models have the wrong Z value when close to the screen edges, and can be seen through walls             | 0.0-1    | 0.0      |
| PMF models are sometimes saved with garbage following the name                                              | 0.0-1    | 0.0      |
| Client does pathname security checks for non-clsave files                                                   | 0.0-1    | 0.0      |
