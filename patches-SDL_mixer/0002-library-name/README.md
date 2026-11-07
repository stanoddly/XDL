# Name the library XDL3_mixer

Names the built library `XDL3_mixer` instead of `SDL3_mixer`: `libXDL3_mixer.so.0`, `XDL3_mixer.dll` and `libXDL3_mixer.0.dylib`. A stock `libSDL3_mixer` then cannot load in its place. It needs `libSDL3`, whose symbols clash with XDL's.

The `MIX_` function names, `SDL3_mixer/` headers, `SDL3_mixer::` CMake targets and the `sdl3-mixer` pkg-config package name stay. Code written for SDL_mixer still builds.

## Testing

After `tools/build-project.sh SDL_mixer <prefix>`:

- `readelf -d <prefix>/lib/libXDL3_mixer.so.0` shows the soname `libXDL3_mixer.so.0` and needs `libXDL3.so.0`.
- `PKG_CONFIG_PATH=<prefix>/lib/pkgconfig pkg-config --libs sdl3-mixer` prints `-lXDL3_mixer`.
