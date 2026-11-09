# Free finished Vulkan work on every submit

With a window claimed, stock SDL's Vulkan backend frees finished work only on a submit whose command buffer requested a swapchain texture. Other submits leave finished command buffers, and the resources they used, marked in use. Metal and D3D12 free finished work on every submit.

For example, an app that uploads each update through a cycled transfer buffer, and does not acquire a swapchain texture that frame, gets a new transfer buffer for every upload, because the previous one stays in use. An app could avoid this by acquiring a swapchain texture every frame, which on other backends presents an undrawn texture for a hidden window, or by blocking in `SDL_WaitForGPUFences` or `SDL_WaitForGPUIdle`. An app that stops acquiring swapchain textures while its window is hidden piles up finished command buffers the same way.

The rule came from upstream's fix for defrag during recursive submits (`b53e7b447`, libsdl-org/SDL#12718), which gave two reasons:

- Defrag created textures, each texture creation submitted a command buffer, and that inner submit freed memory while defrag was iterating over it. The same fix stopped defrag from submitting, so nothing calls a submit from inside a submit anymore. `SDL_WaitForGPUFences` and `SDL_WaitForGPUIdle` already clean finished command buffers at any time.
- Presenting is a good time for this work, because the app often waits for earlier frames or v-sync then.

This patch checks fences, cleans finished command buffers and destroys released resources on every submit. Defrag and the freeing of empty allocations keep the second reason's timing: with a window claimed, they still wait for a submit that requested a swapchain texture. Freeing empty allocations stays there because an empty allocation can still be reused, and freeing it sooner could free and allocate memory on every submit.

Each submit now polls the fences of the command buffers that have not finished. Cleaning is the same work as before, done sooner. Measured once by hand on RADV, with a window claimed and 50 small upload submits plus one presenting submit per frame:

- With immediate presentation and an idle GPU, submitting took about 480 to 570 µs per frame with this patch and 640 to 730 µs without it.
- With v-sync and 16 GiB of buffer copies per frame, so that the GPU falls behind and the uploads wait behind the copies, a frame took 58 ms with and without this patch.

## Depends on

`0008-vulkan-defer-defrag`: this patch changes the same part of `VULKAN_Submit`, and keeps its defrag rule.

## Testing

`testgpucleanup` claims a window and uploads 20 times through a cycled transfer buffer, waiting for each upload with `SDL_QueryGPUFence`, without requesting a swapchain texture. It passes when the uploads use at most 2 transfer buffers. Stock SDL on Vulkan uses 20. Run it by hand on a desktop with `SDL_GPU_DRIVER=vulkan`, because the other backends already pass; it is not in `ctest`, because CI has no GPU display. On Vulkan with the validation layer, it reports no validation messages, and neither does `testgpu_spinning_cube`.

The test keeps every fence until the end. A fence released with `SDL_ReleaseGPUFence` returns to the pool while its finished command buffer still points to it. The next submit reuses and resets that fence, so the command buffer looks unfinished and is not cleaned. Releasing a fence before it signals also resets a fence that is still in use. That is a separate stock SDL bug, and this patch does not fix it.
