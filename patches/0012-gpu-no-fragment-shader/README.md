# Let a graphics pipeline have no fragment shader

Stock `SDL_CreateGPUGraphicsPipeline` rejects a pipeline without a fragment shader, so a depth-only pass needs a fragment shader that does nothing. Vulkan, D3D12, Metal and WebGPU all allow a pipeline without a fragment stage.

This patch accepts NULL in `fragment_shader` when the pipeline has no color targets. For example, a shadow map pipeline sets only `vertex_shader`, a depth-stencil format and `has_depth_stencil_target`. It needs no new field. In debug mode, a pipeline with color targets but no fragment shader still asserts, because WebGPU keeps the color targets in the fragment state.

Each backend gives such a pipeline the resource layout of a fragment shader without resources, so binding and drawing work as before:

- Vulkan creates the pipeline with only the vertex stage.
- D3D12 creates it with no pixel shader bytecode.
- Metal leaves `fragmentFunction` unset.
- WebGPU leaves out the fragment state, and creates empty fragment bind group layouts, which the pipeline releases with itself.

Binding fragment resources to such a pipeline does what it does for a fragment shader without resources.

Upstream tracks this as `libsdl-org/SDL#12311`.

## Depends on

`0007-webgpu-backend`: this patch also changes its pipeline creation, and its browser test covers this patch.

## Testing

`tests/webgpu` draws with a depth-only pipeline at z 0.5, then draws in color at z 0.75 against that depth, and against a cleared depth buffer as a control. The first color draw fails the depth test and the control passes. It also checks that creating and releasing a depth-only pipeline leaves no layouts behind, and that a pipeline with a color target but no fragment shader asserts once and is not created.

The same draws were run once by hand on Vulkan, with the validation layer on, and passed with no validation messages. D3D12 and Metal are only compiled, by CI.
