# Defer Vulkan memory defrag while a command buffer is open

SDL's Vulkan backend can defragment memory on any submit where cleanups run. With no window claimed, that is every submit. Defrag moves textures and leaves each old image in a copy layout. It only skips allocations that a transfer references, so a texture bound in another command buffer that is still open can be moved. When that command buffer is submitted, it samples the old image in the wrong layout, and validation reports `VUID-vkCmdDraw-None-09600`.

This patch counts open command buffers and defers defrag until a submit finds no other one open. The queued allocations wait for that submit. An app that always keeps a second command buffer open never defragments.

Defrag also reads each texture's container, which `SDL_ReleaseGPUTexture` on another thread frees at once. Defrag now holds the dispose lock, so the release waits until defrag has finished. Before this, a release during defrag was a use-after-free.

## Testing

On Vulkan, with validation on and no window claimed:

1. Create many small textures, release every second one, and submit, to leave holes in memory.
2. Acquire a command buffer, blit from the remaining textures, and keep it open.
3. Create a large texture, which finds no hole and marks the allocations for defrag. Creating a texture also submits.
4. Submit the open command buffer.

Stock SDL reports `VUID-vkCmdDraw-None-09600` at step 4. With this patch there are no validation errors, and a defrag still runs once no other command buffer is open.

For the dispose lock, add threads that repeatedly create and release textures of mixed sizes, and build with AddressSanitizer. Stock SDL reports a `heap-use-after-free` in `VULKAN_Submit`, on memory freed by `VULKAN_ReleaseTexture`, within a few runs.
