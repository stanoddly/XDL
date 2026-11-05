# Name the library XDL3

Names the built library `XDL3` instead of `SDL3`: `libXDL3.so.0`, `XDL3.dll`, `libXDL3.0.dylib` and `libXDL3.a`. A stock `libSDL3` then cannot load in XDL's place, and a later XDL based on SDL 4 can sit beside it.

As in stock SDL, the static library is `XDL3-static` where it would clash with the DLL's import library, and for Apple frameworks.

The `SDL_` function names, `SDL3/` headers, `SDL3::` CMake targets and the `sdl3` pkg-config package name stay. Code written for SDL still builds, but a library already built against `libSDL3` must be rebuilt.

## Testing

After building and installing:

- `readelf -d <prefix>/lib/libXDL3.so.0` shows the soname `libXDL3.so.0`.
- `pkg-config --libs sdl3` prints `-lXDL3`.
- `tests/consumer` finds the package with `find_package(SDL3)` and links.
