# Name the library XDL3_ttf

Names the built library `XDL3_ttf` instead of `SDL3_ttf`: `libXDL3_ttf.so.0`, `XDL3_ttf.dll` and `libXDL3_ttf.0.dylib`. A stock `libSDL3_ttf` then cannot load in its place. It needs `libSDL3`, whose symbols clash with XDL's.

The `TTF_` function names, `SDL3_ttf/` headers, `SDL3_ttf::` CMake targets and the `sdl3-ttf` pkg-config package name stay. Code written for SDL_ttf still builds.

## Testing

After `tools/build-project.sh SDL_ttf <prefix>`:

- `readelf -d <prefix>/lib/libXDL3_ttf.so.0` shows the soname `libXDL3_ttf.so.0` and needs `libXDL3.so.0`.
- `PKG_CONFIG_PATH=<prefix>/lib/pkgconfig pkg-config --libs sdl3-ttf` prints `-lXDL3_ttf`.
