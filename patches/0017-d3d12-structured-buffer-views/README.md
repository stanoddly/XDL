# Give Direct3D 12 structured views of storage buffers

Stock SDL's Direct3D 12 driver views every storage buffer as raw 4-byte words: `DXGI_FORMAT_R32_TYPELESS`, `D3D12_BUFFER_SRV_FLAG_RAW` and a stride of 0. Binding a storage buffer copies that view. A shader that declares the buffer as `StructuredBuffer<T>` or `RWStructuredBuffer<T>` then reads it through a view of the wrong kind, which Direct3D 12 leaves undefined. Most drivers read it correctly, but an AMD Radeon RX Vega 11 under Direct3D 12 reads element 0 for every index, while Vulkan on the same machine reads correctly. Vulkan, Metal and WebGPU keep the stride in the shader, so only Direct3D 12 needs it on the view, and `SDL_GPUBufferCreateInfo` has no stride to make such a view from.

This patch adds properties for the stride and for which slots are structured, in `include/XDL/XDL.h`:

| Property | Set on | Value |
| --- | --- | --- |
| `XDL_PROP_GPU_BUFFER_CREATE_STRIDE_NUMBER` | `SDL_GPUBufferCreateInfo.props` | the size of one element in bytes |
| `XDL_PROP_GPU_SHADER_CREATE_STRUCTURED_STORAGE_BUFFERS_NUMBER` | `SDL_GPUShaderCreateInfo.props` | bit `i` set: storage buffer slot `i` is a `StructuredBuffer<T>` |
| `XDL_PROP_GPU_COMPUTEPIPELINE_CREATE_STRUCTURED_READONLY_STORAGE_BUFFERS_NUMBER` | `SDL_GPUComputePipelineCreateInfo.props` | the same for read-only storage buffers |
| `XDL_PROP_GPU_COMPUTEPIPELINE_CREATE_STRUCTURED_READWRITE_STORAGE_BUFFERS_NUMBER` | `SDL_GPUComputePipelineCreateInfo.props` | the same for `RWStructuredBuffer<T>` |

For example, a buffer of 112-byte elements created with a stride of 112, bound to a fragment shader created with `0x4`, is read through a structured view in slot 2 and a raw view in slots 0 and 1.

`SDL_CreateGPUBuffer` passes the stride to the driver's `CreateBuffer`, which takes a new `stride` argument. The Vulkan, Metal and WebGPU drivers ignore it and the slot properties. The Direct3D 12 driver:

- Creates a structured SRV and, for `SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_WRITE`, a structured UAV beside the raw ones, under the same usage checks, when the stride is a multiple of 4, at most 2048 bytes (`D3D12_REQ_MULTI_ELEMENT_STRUCTURE_SIZE_IN_BYTES`) and no larger than the buffer. A cycled buffer gets the same views.
- Keeps the bound buffer of each graphics storage buffer slot instead of its raw descriptor, and picks the view of each slot when it writes the slot's descriptors to the GPU heap: before a draw or dispatch whose storage buffers a pipeline bind or a new binding changed, and for read-write compute buffers when the compute pipeline is bound. Binding stays a descriptor copy.
- Binds the raw view, as stock SDL does, to a structured slot whose buffer has no structured view, and logs a warning the first time it does so on the device. A negative slot property marks no slot.

Binding read-write compute buffers now writes as many descriptors as the pipeline declares. Stock SDL filled that many but wrote as many as the compute pass bound, so a pass that bound more copied handles it never set.

## Testing

CI compiles the Direct3D 12 driver but cannot run it, and the other drivers ignore the properties, so no automated test covers this patch.

Check it by hand on Windows under Direct3D 12, on a GPU whose driver reads a structured slot through a raw view wrongly, such as an AMD Radeon RX Vega 11, and on one other GPU:

- A fragment and a vertex shader reading `StructuredBuffer<T>` with a `T` larger than 16 bytes at several indices.
- A compute shader reading a `StructuredBuffer<T>` and writing a `RWStructuredBuffer<T>`.
- Switching between a pipeline with a structured slot and one with a raw slot without binding the buffer again, and a structured buffer that cycles.
