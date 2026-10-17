# Computer Graphics Practice

**English** | [繁體中文](README.zh-TW.md) | [Open the interactive course](index.html)

A build-first computer graphics course for a computer science student who already programs. Start with the math you need, make pixels on the CPU, then move the same ideas into shaders and a small real-time renderer.

## Start here

1. Open [`index.html`](index.html) in a modern browser. It works offline and has an English / Traditional Chinese switch.
2. Start with **01 — Draw a triangle**. The demo implements a CPU framebuffer, edge tests, and barycentric color interpolation.
3. Change the vertex controls, read the experiment prompts, then implement the listed variations in `labs/01-triangle/app.js`.
4. Keep a `NOTES.md` of observations, screenshots, and your answers to each checkpoint.

No graphics card setup, engine, package manager, or prior graphics course is required for the first labs. The course introduces WebGL 2 after the software renderer so that the CPU work gives GPU concepts context. The browser page is a learning aid, not a substitute for implementing each exercise.

## Course route

| Stage | Build | Core ideas |
| --- | --- | --- |
| 0. Pixels | Plot pixels and draw a triangle on a CPU framebuffer | Coordinates, sampling, rasterization, barycentric coordinates |
| 1. 2D transforms | Move, rotate, and scale shapes | Vectors, matrices, composition, homogeneous coordinates |
| 2. 3D transforms | Render a rotating mesh with a camera | Model / view / projection, clip space, perspective divide |
| 3. Visibility | Add a depth buffer and back-face culling | Depth testing, winding, clipping, precision |
| 4. GPU pipeline | Port the mesh to WebGL 2 and write shaders | Vertex processing, interpolation, fragments, buffers, uniforms |
| 5. Materials and light | Add normals, Lambert / Blinn-Phong, textures | Coordinate spaces, sampling, color spaces, BRDF intuition |
| 6. Shadows and quality | Add a shadow map and anti-aliasing experiments | Multiple passes, bias, aliasing, trade-offs |
| 7. Final project | Build a compact interactive scene and explain its pipeline | Profiling, debugging, design choices, reproducible demos |

The detailed milestone-by-milestone build plan is in [`SYLLABUS.md`](SYLLABUS.md). Lab 01 is implemented in this directory; later milestones are the planned course sequence to build as you progress.

Suggested pace: 2–4 hours per stage. Spend most of each session changing code and inspecting output; use the concept notes to explain what you observe.

## Working loop

For every lab: **predict → implement → inspect → explain**. Change one thing at a time. Record a concrete observation (for example, which side of a triangle is included at a shared edge) and connect it to the rule in your implementation. Do not move on until you can explain the pixels, not just run the demo.

## Files

- [`index.html`](index.html) — bilingual course overview and interactive first lab.
- [`labs/01-triangle/app.js`](labs/01-triangle/app.js) — deliberately readable CPU triangle rasterizer to extend.
- [`labs/01-triangle/README.md`](labs/01-triangle/README.md) — experiment brief and implementation checkpoints.

## Completion target

Finish with a renderer you wrote yourself, an interactive final scene, and a short technical note that traces one vertex from object space through rasterization to a displayed pixel. You should be able to justify your coordinate conventions, depth behavior, lighting model, and at least one quality/performance trade-off.
