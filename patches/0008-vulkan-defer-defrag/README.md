# Defer Vulkan memory defrag while a command buffer is open

SDL's Vulkan backend can defragment memory on any submit when no window is claimed, and otherwise on a submit that requested a swapchain texture. Defrag moves textures and leaves each old image in a copy layout. It only skips allocations that a transfer references, so a texture bound in another command buffer that is still open can be moved. When that command buffer is submitted, it samples the old image in the wrong layout, and validation reports `VUID-vkCmdDraw-None-09600`.

This patch counts open command buffers and lets a submit defragment only when no other one is open. For example, with an upload command buffer and a frame command buffer open, submitting the uploads defers defrag, and submitting the frame then runs it.

Some apps now defragment rarely or never:

- With a window claimed, only a submit that requested a swapchain texture can defragment. An app whose uploads are still open when it submits its frame never defragments.
- An app that always keeps another command buffer open never defragments, and one that often does defragments rarely. `SDL_CreateGPUTexture` also opens and submits a command buffer of its own, which counts.

While defrag waits, free space in the queued allocations cannot be reused and no more allocations are queued, so the app can use more memory.

Defrag also reads each texture's container, which `SDL_ReleaseGPUTexture` on another thread frees at once. Defrag now holds the dispose lock, so the release waits until defrag has finished. Before this, a release during defrag was a use-after-free.

Defrag can still act on a texture or buffer that another thread is creating. Before it has a container, defrag can crash. For a texture, after that but before its first barrier, defrag copies it from the wrong layout, and validation reports `VUID-vkCmdDraw-None-09600` with layout `UNDEFINED`. This affects apps that create resources on one thread while another submits. Stock SDL has this too.

## Testing

On Vulkan, with validation on and no window claimed:

1. Create many small textures, release every second one, and submit, to leave holes in memory.
2. Acquire a command buffer, blit from the remaining textures, and keep it open.
3. Create a texture larger than 2 MiB, such as 1024 x 1024 RGBA, which finds no hole and marks the allocations for defrag. Creating a texture also submits.
4. Submit the open command buffer.

Stock SDL reports `VUID-vkCmdDraw-None-09600` at step 4. With this patch there are no validation errors, and a defrag still runs once no other command buffer is open.

For the dispose lock, add threads that repeatedly create and release textures of mixed sizes, and build with AddressSanitizer. Stock SDL reports a `heap-use-after-free` in `VULKAN_Submit`, on memory freed by `VULKAN_ReleaseTexture`, within a few runs. With this patch, AddressSanitizer reports no use-after-free. With validation on, these threads can still report the `UNDEFINED` case above.
