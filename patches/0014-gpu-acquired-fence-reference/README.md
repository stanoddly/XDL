# Give the caller of SDL_SubmitGPUCommandBufferAndAcquireFence its own fence reference

In stock SDL, Vulkan and D3D12 hand the fence of `SDL_SubmitGPUCommandBufferAndAcquireFence` to the caller with the command buffer's only reference. The command buffer then does not release the fence when it is cleaned. When the app calls `SDL_ReleaseGPUFence`, the fence returns to the pool while the submitted command buffer still points to it, and the next submit reuses and resets it.

For example, an app polls `SDL_QueryGPUFence` until it returns true, then releases the fence. The next submit resets that fence, so the finished command buffer looks unfinished, and the resources it used stay in use. It is cleaned only when a later check finds that fence signaled again. In a loop that does this on every submit, that may not happen before `SDL_WaitForGPUIdle`. If the app releases a fence before it signals, which the API does not forbid, it is worse:

- Vulkan resets a fence that a pending submission will still signal, which Vulkan forbids (`VUID-vkResetFences-pFences-01123`).
- D3D12 hands the fence to the next command buffer, and the earlier submission's signal can make that command buffer look finished before the GPU has run it.

This patch gives the caller a reference of its own, taken while `submitLock` is held, so that another thread cannot clean the command buffer first. A cleaned command buffer always releases its own reference. When D3D12 presents or cleans and fails after the submit, `SDL_SubmitGPUCommandBufferAndAcquireFence` returns NULL and releases the caller's reference. Upstream fixed Metal the same way in `51ef86a11`, and XDL's WebGPU backend already did this.

The `autoReleaseFence` field is gone. Besides `SubmitAndAcquireFence`, only `Cancel` cleared it, because a canceled command buffer has no fence. Cleaning now checks for a fence instead.

## Depends on

`0013-vulkan-cleanup-every-submit`: this patch changes its test, `testgpucleanup`.

## Testing

`testgpucleanup` now releases each fence as soon as `SDL_QueryGPUFence` returns true. Without this patch, it uses 20 transfer buffers on Vulkan and fails. With it, it uses 2 and passes. Run it by hand on a desktop with `SDL_GPU_DRIVER=vulkan`, as `0013-vulkan-cleanup-every-submit` describes. With the validation layer on, it and `testgpu_spinning_cube` report no validation messages.

D3D12 is only compiled, by CI.
