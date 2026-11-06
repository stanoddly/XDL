# WebGPU GPU backend for the browser

Adds a WebGPU driver for the SDL GPU API on Emscripten, because stock SDL has no GPU backend there. It is the backend from [XDL_wgpu](https://github.com/stanoddly/XDL_wgpu), based on the original by [The Stickmahn](https://github.com/TheeStickmahn/SDL_wgpu). In XDL it builds into the SDL library, so an app links no separate library.

The driver name is `webgpu`, and `SDL_HINT_GPU_DRIVER` works as usual. Shaders are WGSL:

```c
#include <XDL/XDL.h>

SDL_GPUDevice *device = SDL_CreateGPUDevice(XDL_GPU_SHADERFORMAT_WGSL, debug, NULL);
SDL_GPUShaderCreateInfo info = { .code = wgsl_source, .code_size = wgsl_size, .format = XDL_GPU_SHADERFORMAT_WGSL, .entrypoint = "main", ... };
```

Bindings that cannot include the header define the bit themselves: `1u << 6`. The bit, the property names and their strings are in `XDL/XDL.h`.

The GPU render driver stays off on Emscripten, because the backend has no renderer shaders and, without asyncify, creating the render driver's device can hang instead of falling back.

## Blocking calls

WebGPU is asynchronous. The adapter and device requests, `SDL_WaitForGPUFences`, `SDL_WaitForGPUIdle` and `SDL_WaitAndAcquireGPUSwapchainTexture` spin on `SDL_DelayNS`, which yields to the browser only under `-sASYNCIFY` or `-sJSPI`. Without one of those, they never return.

An app that cannot use them, such as one on the .NET browser runtime, must not block:

1. Get the `WGPUInstance`, `WGPUAdapter` and `WGPUDevice` itself, asynchronously, and pass all three to `SDL_CreateGPUDeviceWithProperties()` with the `XDL_PROP_GPU_DEVICE_CREATE_WEBGPU_*` properties and `XDL_PROP_GPU_DEVICE_CREATE_SHADERS_WGSL_BOOLEAN`.
2. Per frame, use only `SDL_AcquireGPUSwapchainTexture()` and `SDL_QueryGPUFence()`.

## Linking

`SDL3::SDL3-static` carries `--use-port=emdawnwebgpu` in its link interface. An app that links the archive directly must pass that flag itself.

## Testing

`tests/webgpu` runs in headless Chromium. It needs the .NET 11 `wasm-tools` workload or your own Emscripten 6.0.3, plus Node.js and a Chromium:

```sh
tools/apply.sh
source tools/emsdk-env.sh
emcmake cmake -S tests/webgpu -B build/webgpu-test -DCMAKE_BUILD_TYPE=Release
cmake --build build/webgpu-test --parallel
tests/webgpu/run-test.sh
```

It prints `GPU driver 0: webgpu`, passes its readbacks, submits its frames, and ends with `XDL WebGPU test PASSED`.
