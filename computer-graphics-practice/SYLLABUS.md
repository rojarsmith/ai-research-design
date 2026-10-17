# Build plan

This is a practical sequence, not a list of topics to memorize. Each milestone adds one renderer capability and ends with something visible and a short explanation in your lab notebook. Lab 01 is the working starting point; later milestones are planned exercises.

## 00 — Set up a pixel workspace

**Build:** a CPU color buffer and a way to display it in a browser canvas.

**Learn as needed:** integer and floating-point coordinates, image rows/columns, RGB/RGBA, normalized versus pixel coordinates.

**Checkpoint:** explain how `(x, y)` maps to an array offset and why image row order matters. The supplied triangle lab starts with this foundation.

## 01 — Fill a triangle (implemented)

**Build:** triangle coverage with edge functions and interpolated vertex colors.

**Learn as needed:** 2D cross product, signed area, barycentric coordinates, pixel-center sampling, floating-point tolerance.

**Checkpoint:** explain winding, degenerate triangles, and why a shared edge needs a consistent fill rule. Complete exercises A–F in `labs/01-triangle/README.md`.

## 02 — Add 2D transforms and wireframe debugging

**Build:** a small scene of transformed triangles. Add translation, rotation, and scale controls; draw vertex markers and edges as a debug overlay.

**Learn as needed:** column versus row vectors, matrix multiplication order, homogeneous coordinates, coordinate handedness.

**Checkpoint:** predict the result of two transforms applied in opposite orders. Keep world coordinates separate from pixel coordinates.

## 03 — Make the first 3D image

**Build:** a rotating cube made from triangles, an orbit camera, and a perspective projection. First draw wireframe, then filled faces.

**Learn as needed:** model / world / view / clip spaces, camera basis, field of view, near/far planes, perspective divide, viewport mapping.

**Checkpoint:** trace one vertex through each space and explain why points farther away appear smaller. Draw the camera frustum and label the clip-volume convention used in your code.

## 04 — Decide what is visible

**Build:** a depth buffer, back-face culling, and clipping against the near plane. Add a toggle to compare each feature on and off.

**Learn as needed:** depth test, triangle winding, homogeneous clipping, z-fighting, depth precision.

**Checkpoint:** show two intersecting or overlapping meshes and explain why painter's sorting fails while per-sample depth succeeds. Explain a case that still causes z-fighting.

## 05 — Move geometry to the GPU

**Build:** port the same cube to WebGL 2 first. Upload positions and indices; write a vertex shader and fragment shader; animate a matrix. Then use the optional NVIDIA path below to run a native OpenGL 4.6 version on the GeForce GPU.

**Learn as needed:** graphics context, vertex buffers, vertex attributes, uniforms, shader compilation, interpolation between vertices.

**Checkpoint:** explain which calculations run once per vertex and which run for covered samples. Compare CPU and GPU outputs using the same vertex data and transforms.

## 06 — Add materials, light, and texture

**Build:** per-vertex or per-fragment Lambert diffuse lighting, then Blinn–Phong highlights, normals, and a sampled texture.

**Learn as needed:** normal transforms, dot product, light direction, UV coordinates, texture filtering, sRGB display versus linear-light calculation.

**Checkpoint:** rotate the object and light independently. Explain why normals need a different transform from positions under non-uniform scale, and why blending colors in the wrong color space looks dark.

## 07 — Shadows and image quality

**Build:** a two-pass shadow map and a small anti-aliasing comparison. Keep controls for shadow bias and resolution.

**Learn as needed:** render-to-texture, light-space transforms, aliasing, PCF filtering, bias artifacts, cost versus quality.

**Checkpoint:** capture one shadow acne artifact and one detached-shadow artifact; adjust the bias and describe the trade-off. Compare aliased and filtered edges at the same zoom.

## 08 — Final project: a tiny renderer demo

**Build:** a navigable scene with at least two meshes, a movable camera, depth, one textured lit material, and shadows or a documented substitute. Include a feature toggle or debug view.

**Deliver:** source code, a short screen recording or screenshots, and a 1–2 page design note. The note traces a vertex to a displayed fragment, states coordinate and depth conventions, describes one bug you diagnosed, and justifies one quality/performance trade-off.

**Self-review:** a classmate should be able to run the scene, change a control, and understand your pipeline diagram without reading every source file.

## NVIDIA GPU path — RTX 5070 Ti

The CPU triangle lab remains the reference implementation. When you reach the GPU stages, use WebGL 2 for the short setup path, then add a native C++ / OpenGL 4.6 app so NVIDIA's graphics tools can inspect your own frames. This GPU supports OpenGL 4.6 and Vulkan 1.4; NVIDIA's current Nsight Graphics requirements list RTX 50-series GPUs and support OpenGL and Vulkan. See [RTX 5070 family specs](https://www.nvidia.com/en-us/geforce/graphics-cards/50-series/rtx-5070-family/) and [Nsight Graphics requirements](https://developer.nvidia.com/nsight-graphics/get-started) before setup.

**Hands-on sequence:**

1. Confirm the app is running on the RTX 5070 Ti and record the driver/API information.
2. Capture one frame in Nsight Graphics. Inspect draw calls, vertex input, shader stages, textures, render targets, and depth state.
3. Change a shader or a resource and capture again. Explain how the change appears in the frame and whether it affects image quality or frame time.
4. Use a GPU trace or shader profiler to compare one deliberately simple workload with one heavier workload. Treat the capture as evidence, not as a complete model of the chip.
5. **Optional compute bridge:** write a CUDA image filter and compare it with a fragment-shader version. Use this to study thread execution and memory movement; CUDA is general-purpose GPU compute, not a replacement for the graphics pipeline.
6. **Optional advanced extension:** add Vulkan ray queries or ray-traced shadows after the conventional depth, material, and shadow stages are understood.

Exact Nsight features vary by release, API, driver, and GPU. Keep the first renderer API-neutral at the concept level; use NVIDIA-specific captures only for diagnosing the actual GeForce implementation.

## Hardware thread — understand what runs where

Study these ideas alongside the milestones above. The goal is to explain the visible performance effects of the GPU's execution and memory model, not to memorize one vendor's chip diagram or learn circuit design.

- **Pipeline mapping (milestones 03–05):** distinguish programmable shader work from pipeline stages such as primitive assembly, rasterization, depth/stencil, blending, and texture sampling. Connect each visible feature to the stage that produces it.
- **Parallel execution (milestones 05–06):** understand why many vertex or fragment invocations can run in parallel; learn SIMD/SIMT, execution groups, latency hiding, and branch divergence. Treat exact group widths and scheduling as hardware-specific details.
- **Memory and data movement (milestones 05–07):** distinguish registers, caches, texture sampling, device memory capacity/bandwidth, and CPU↔GPU uploads/readbacks. Predict when a scene is limited by arithmetic, memory traffic, transfers, or synchronization.
- **Pixel and display path (milestones 01, 04, 07):** connect framebuffer formats, depth precision, blending and color space to storage and output. Learn at a high level how a rendered frame reaches a display; refresh rate and scanout details are optional at first.
- **Measure before optimizing (milestones 07–08):** compare frame time while changing resolution, overdraw, shader work, mesh count, and texture size one at a time. Form a bottleneck hypothesis and use an available browser/GPU profiler or controlled comparison to test it. Hardware counters and vendor tools are optional extensions.

**Hardware checkpoints:** draw a pipeline diagram and label which work is programmable; explain why GPUs favor lots of parallel work over fast single-thread response; identify one bandwidth-heavy and one compute-heavy scene; show evidence for one bottleneck and one change that improved frame time. Do not infer the bottleneck from utilization percentage alone.

## Suggested study sessions

Split each milestone into short cycles:

1. **Predict:** draw a diagram or write expected values before changing code.
2. **Implement:** add one capability and keep a known-good state to compare against.
3. **Inspect:** use a control, debug color, or deliberately broken case to reveal behavior.
4. **Explain:** write what happened and why; note assumptions and a counterexample.

Computer science math is useful, but do not pause the project for a full math review. Derive the small pieces when the renderer needs them: cross and dot products for geometry and lighting; matrices for coordinate changes; interpolation for attributes; and sampling for pixels and textures.
