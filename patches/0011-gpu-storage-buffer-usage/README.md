# Check a storage buffer's usage when it is bound

In debug mode, stock SDL checks a storage texture's usage when a compute pass begins, but never a storage buffer's. A buffer created without the usage that SDL documents for a binding binds anyway, and the backend's behavior is undefined. D3D12, for example, picks a buffer's default resource state from its usage.

This patch adds `BufferCommonHeader` to `SDL_sysgpu.h`, which holds a buffer's usage, and starts every backend's buffer container with it, as `TextureCommonHeader` does for textures. D3D12 and WebGPU already kept the usage, so the header replaces their own field.

In debug mode, these calls now assert with `SDL_assert_release` and bind nothing when a buffer lacks the usage:

| Call | Required usage |
| --- | --- |
| `SDL_BindGPUVertexStorageBuffers` | `SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ` |
| `SDL_BindGPUFragmentStorageBuffers` | `SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ` |
| `SDL_BindGPUComputeStorageBuffers` | `SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_READ` |
| `SDL_BeginGPUComputePass`, read-write buffers | `SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_WRITE` |

For example, binding a buffer created with only `SDL_GPU_BUFFERUSAGE_VERTEX` through `SDL_BindGPUFragmentStorageBuffers` asserts, and `SDL_BeginGPUComputePass` with it as a read-write buffer returns NULL. Without debug mode, nothing changes.

## Depends on

`0007-webgpu-backend`: the header also starts its buffer container, and its browser test covers this patch.

## Testing

`tests/webgpu` counts assertions while it binds buffers with the required usage in each of the four ways, and then a buffer created with only `SDL_GPU_BUFFERUSAGE_VERTEX` in each of them. It expects no assertions for the first and 4 for the second. The same check was run once by hand on Vulkan and passed. D3D12 and Metal are only compiled, by CI.
