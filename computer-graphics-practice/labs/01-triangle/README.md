# Lab 01 — Draw a triangle

## Goal

Implement the basic questions a rasterizer answers: what pixel samples a triangle covers, and what color each covered sample receives. The demo is intentionally CPU-only and small enough to read in one sitting.

## Run

Open `../../index.html` in a modern browser. Move the sliders and toggle edge samples. The page works without a server or network connection.

## Read the implementation

1. `edge(a, b, p)` returns a signed 2D cross product. Its sign says which side of an oriented edge contains point `p`.
2. Three edge values are divided by the triangle's signed area to produce barycentric weights. They add to one for points on the triangle plane.
3. A sample is covered when all three weights have the same orientation (within a tiny tolerance).
4. The same weights blend the three vertex colors.
5. The sample is at the pixel center `(x + 0.5, y + 0.5)`, not the integer corner.

The demo omits clipping and the GPU. Its small fixed canvas keeps the direct per-pixel loops understandable. It also uses a small symmetric tolerance instead of a production API's precise top-left fill convention, so two adjacent triangles may both include a shared-edge sample. Treat this as an experiment to investigate.

## Exercises

- **A — Sample location:** change the sample from `(x + 0.5, y + 0.5)` to `(x, y)`. Compare edge pixels and explain why a subpixel shift changes coverage.
- **B — Winding:** reverse two vertices. Explain why the signed area and edge signs both change, while the rendered triangle stays visible.
- **C — Interpolation:** replace the RGB colors with a single flat color. Then restore per-vertex colors and print `w0 + w1 + w2` for a few samples. Explain small floating-point error.
- **D — Shared edge:** render two triangles that form a rectangle. Find a sample on their shared diagonal. Can both own it? Can neither own it? Try the top-left rule: accept zero-valued edges only for a consistent subset of directed edges.
- **E — Degeneracy:** set all three points nearly collinear. What does `area` approach? Why should a renderer avoid dividing by a near-zero area?
- **F — Efficiency:** this implementation tests the triangle's axis-aligned bounding box. Count examined samples versus covered samples as you move the controls. What would tiled traversal change?

## Checkpoints

Answer these in your lab notebook:

1. Why do barycentric weights sum to one?
2. Why do the same weights work for both coverage and color interpolation?
3. What does this implementation do when the triangle has zero area?
4. What rule would you add so two triangles that share an edge cover each edge sample exactly once?

## Next

Apply a 2D homogeneous transformation to the three vertices before rasterization. Keep rasterization unchanged. This clean separation will help when model, view, and projection matrices arrive later.
