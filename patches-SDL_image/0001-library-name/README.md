# Name the library XDL3_image

Names the built library `XDL3_image` instead of `SDL3_image`: `libXDL3_image.so.0`, `XDL3_image.dll` and `libXDL3_image.0.dylib`. A stock `libSDL3_image` then cannot load in its place. It needs `libSDL3`, whose symbols clash with XDL's.

The `IMG_` function names, `SDL3_image/` headers, `SDL3_image::` CMake targets and the `sdl3-image` pkg-config package name stay. Code written for SDL_image still builds.

## Testing

After `tools/build-project.sh SDL_image <prefix>`:

- `readelf -d <prefix>/lib/libXDL3_image.so.0` shows the soname `libXDL3_image.so.0` and needs `libXDL3.so.0`.
- `PKG_CONFIG_PATH=<prefix>/lib/pkgconfig pkg-config --libs sdl3-image` prints `-lXDL3_image`.
