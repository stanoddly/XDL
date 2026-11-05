# Give transparent X11 windows an alpha visual

Stock SDL only picks a 32-bit visual for OpenGL windows, so a transparent window using anything else, such as Vulkan, has no alpha for the compositor to blend. This picks a 32-bit TrueColor visual for those windows when the X server has one.

## Testing

On an X11 desktop with a compositor, set `SDL_GPU_DRIVER=vulkan` and run `testgpu_simple_clear --transparent`. The desktop shows through the cleared color.
