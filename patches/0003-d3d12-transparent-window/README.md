# Transparent Direct3D 12 windows

Lets `SDL_WINDOW_TRANSPARENT` work with the SDL GPU API and the Direct3D 12 renderer. Stock SDL's `SDL_ClaimWindowForGPUDevice` refuses every transparent window, so this removes that check for all GPU backends.

On Windows, the D3D12 GPU backend and renderer present through DirectComposition for windows that SDL creates. Opaque windows fall back to an HWND swap chain when DirectComposition is unavailable. Transparent windows need DirectComposition, and tearing is not available for them. `docs/README-windows.md` has the details, including premultiplied alpha.

On Xbox, the D3D12 backend returns an error for a transparent window.

## Testing

On a Windows desktop, set `SDL_GPU_DRIVER=direct3d12` and run:

- `testgpu_simple_clear --transparent`: the desktop shows through the cleared color.
- `testgpu_simple_clear`: the window is opaque, and resizing it works.
