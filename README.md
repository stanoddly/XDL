# XDL

XDL is an altered version of [SDL](https://github.com/libsdl-org/SDL). It is not an official SDL release.

The repo holds patches, not SDL source. `external/SDL` pins a released SDL tag, and `tools/apply.sh` applies `patches/` to it in `build/SDL`, which git ignores.

## Why XDL exists

SDL does not accept contributions made with generative AI, and XDL respects that rule. A developer who uses an agent to fix an SDL bug therefore cannot share the fix through SDL.

XDL is for those developers. A fix becomes a patch here, so others can benefit from it, and nothing LLM-written goes to SDL. [AGENTS.md](AGENTS.md) tells an agent how to work in this repo.

## Build

```sh
git clone --recurse-submodules https://github.com/stanoddly/XDL.git
cd XDL
tools/apply.sh
cmake -S build/SDL -B build/cmake -DCMAKE_BUILD_TYPE=Release
cmake --build build/cmake --config Release
```

The library is `XDL3`: `libXDL3.so.0`, `XDL3.dll` or `libXDL3.0.dylib`. The `SDL_` function names, `SDL3/` headers, `SDL3::` CMake targets and the `sdl3` pkg-config package stay the same, so code written for SDL builds against it. What XDL adds to the API is in `XDL/XDL.h`. On Emscripten, the SDL GPU API runs on WebGPU: see [the patch's README](patches/0007-webgpu-backend/README.md). Do not load XDL and a stock SDL in one process, because their symbols clash.

## SDL_image, SDL_ttf and SDL_mixer

XDL also builds these libraries against XDL3, as `XDL3_image`, `XDL3_ttf` and `XDL3_mixer`. A stock `SDL3_image` needs `libSDL3`, so it cannot run with XDL. `external/<library>` pins a released tag, and `patches-<library>/` holds its patches. After the build above:

```sh
cmake --install build/cmake --prefix build/install --config Release
tools/apply.sh SDL_image
tools/build-project.sh SDL_image build/install
```

`build-project.sh` fetches the libraries that the satellite vendors and links them in, so each library needs only XDL3 and system libraries. XDL3_image and XDL3_mixer build only the formats their own source decodes. XDL3_image has no animated PNG, TIFF, WebP or AVIF. XDL3_mixer has no Opus, WavPack, tracker music, MIDI or GME. XDL3_ttf vendors FreeType and HarfBuzz, without plutosvg, so it draws no SVG color glyphs. The function names, headers, CMake targets and pkg-config packages stay those of SDL_image, SDL_ttf and SDL_mixer.

Each [release](https://github.com/stanoddly/XDL/releases) has one zip per platform with `runtimes/<rid>/native/` and the licenses in `THIRD-PARTY-NOTICES.txt`, plus the [browser](#browser) zip. CI also uploads them from every build, as the `xdl3-<target>` and `third-party-notices` artifacts. The file names drop the version, such as `libXDL3_image.so`, while a satellite asks for `libXDL3.so.0`. When you load the libraries by path, load XDL3 first, so the loader finds it already loaded.

## Browser

The `browser-wasm-net11` target builds XDL3 and the satellites as static archives for the .NET 11 browser runtime, with the same codecs. Its zip `xdl3-browser-wasm-net11.zip` holds `runtimes/browser-wasm/native/` with `XDL3.a`, `XDL3_image.a`, `XDL3_mixer.a` and `XDL3_ttf.a`. Emscripten has no stable ABI, so the archives link only into a .NET runtime built with the same Emscripten, the one of .NET 11's `wasm-tools` workload. A later .NET gets a target of its own.

Reference the archives with `NativeFileReference` and keep their file names. The .NET browser build takes each file name as the module that `DllImport("XDL3")` and the others bind to.

```xml
<ItemGroup>
  <NativeFileReference Include="native/XDL3.a;native/XDL3_image.a;native/XDL3_mixer.a;native/XDL3_ttf.a" />
</ItemGroup>
<PropertyGroup>
  <EmccExtraLDFlags>--use-port=emdawnwebgpu</EmccExtraLDFlags>
</PropertyGroup>
```

The .NET runtime does not use asyncify, so an app must create the GPU device without blocking. [The WebGPU patch's README](patches/0007-webgpu-backend/README.md) describes how.

To build the archives, install the .NET 11 SDK and its `wasm-tools` workload, and run `tools/apply.sh` for SDL and each satellite. Then:

```sh
source tools/emsdk-env.sh
tools/build-browser.sh build/install-browser
tools/collect-runtime.sh browser-wasm build/install-browser build/browser-wasm/native
```

## Patches

Each directory in `patches/` and `patches-<library>/` is one change, with a `README.md` that explains it. [MAINTAINING.md](MAINTAINING.md) covers changing a patch and moving to a new SDL release.

## Bugs

Report XDL bugs in this repo, not to SDL. Report a problem to SDL only if a human has reproduced it on stock SDL.

## License

XDL uses the zlib license. See [LICENSE](LICENSE). The built libraries also contain third-party code, whose licenses CI collects with `tools/third-party-notices.sh`.
