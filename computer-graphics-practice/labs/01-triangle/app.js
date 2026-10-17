// Lab 01: a deliberately small CPU triangle rasterizer.
// Change this file as you work through README.md in this folder.
(function () {
  const canvas = document.querySelector('#screen');
  const ctx = canvas.getContext('2d', { alpha: false });
  const image = ctx.createImageData(canvas.width, canvas.height);
  const controls = ['x0', 'y1', 'y2'].map((id) => document.getElementById(id));
  let showEdges = false;

  function edge(a, b, p) {
    return (p.x - a.x) * (b.y - a.y) - (p.y - a.y) * (b.x - a.x);
  }

  function colorAt(data, index, weights, colors) {
    for (let channel = 0; channel < 3; channel++) {
      data[index + channel] = Math.round(
        weights[0] * colors[0][channel] +
        weights[1] * colors[1][channel] +
        weights[2] * colors[2][channel]
      );
    }
    data[index + 3] = 255;
  }

  function draw() {
    const [x0, y1, y2] = controls.map((el) => Number(el.value));
    const vertices = [{ x: x0, y: 45 }, { x: 72, y: y1 }, { x: 405, y: y2 }];
    const colors = [[255, 103, 128], [86, 225, 192], [105, 155, 255]];
    const area = edge(vertices[0], vertices[1], vertices[2]);
    const minX = Math.max(0, Math.floor(Math.min(...vertices.map((v) => v.x))));
    const maxX = Math.min(canvas.width - 1, Math.ceil(Math.max(...vertices.map((v) => v.x))));
    const minY = Math.max(0, Math.floor(Math.min(...vertices.map((v) => v.y))));
    const maxY = Math.min(canvas.height - 1, Math.ceil(Math.max(...vertices.map((v) => v.y))));
    image.data.fill(0);
    for (let i = 3; i < image.data.length; i += 4) image.data[i] = 255;
    let covered = 0;

    if (Math.abs(area) > 1e-5) {
      for (let y = minY; y <= maxY; y++) {
        for (let x = minX; x <= maxX; x++) {
          // Sample at pixel centers. Change this to (x, y) and compare the silhouette.
          const p = { x: x + 0.5, y: y + 0.5 };
          const w0 = edge(vertices[1], vertices[2], p) / area;
          const w1 = edge(vertices[2], vertices[0], p) / area;
          const w2 = edge(vertices[0], vertices[1], p) / area;
          const epsilon = -1e-8;
          if (w0 >= epsilon && w1 >= epsilon && w2 >= epsilon) {
            const index = (y * canvas.width + x) * 4;
            colorAt(image.data, index, [w0, w1, w2], colors);
            covered++;
          }
        }
      }
    }
    ctx.putImageData(image, 0, 0);
    if (showEdges) {
      ctx.save();
      ctx.fillStyle = '#ffffff';
      for (let y = minY; y <= maxY; y += 8) {
        for (let x = minX; x <= maxX; x += 8) {
          const p = { x: x + 0.5, y: y + 0.5 };
          const inside = Math.abs(area) > 1e-5 && [
            edge(vertices[1], vertices[2], p) / area,
            edge(vertices[2], vertices[0], p) / area,
            edge(vertices[0], vertices[1], p) / area,
          ].every((w) => w >= -1e-8);
          if (inside) ctx.fillRect(x, y, 2, 2);
        }
      }
      ctx.restore();
    }
    controls.forEach((el) => { el.nextElementSibling.value = el.value; });
    document.querySelector('#stats').textContent = `${covered.toLocaleString()} px · area ${Math.round(area / 2)} px²`;
  }

  controls.forEach((el) => el.addEventListener('input', draw));
  document.querySelector('#reset').addEventListener('click', () => {
    ['240', '245', '245'].forEach((value, index) => { controls[index].value = value; });
    draw();
  });
  window.triangleLab = {
    init: draw,
    setEdges(value) { showEdges = value; draw(); },
  };
})();
