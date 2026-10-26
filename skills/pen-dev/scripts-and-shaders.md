# Using scripts and shaders on the pen.dev canvas

## Scripting

Use `script` node types to generate content with JavaScript. Scripts are `.js` files on disk, referenced via relative uri path in `scriptUri`.

- Every script must start with `/** @schema 2.11 */` (current version). Missing this tag is an error.
- Scripts receive a `pencil` object: `pencil.width`, `pencil.height`, `pencil.input.<name>`.
- Scripts must return an array of node objects following the `.pen` schema.
- Declare inputs as `@input name: type [= default]`. Available types: `number`, `string`, `boolean`, `color`, `ref`, `enum`.
- Math.random() is deterministic in scripts and can be safely used for procedural generation.

```js
/**
 * @schema 2.11
 * @input rows: number = 3
 * @input gap: number = 4
 * @input color: color = #3B82F6
 * @input label: string = "Hello"
 * @input filled: boolean = true
 * @input layout: enum("grid", "stack", "scatter") = "grid"
 * @input target: ref
 */
const rows = Math.max(1, Math.floor(pencil.input.rows));
const cellH = (pencil.height - pencil.input.gap * (rows - 1)) / rows;

const nodes = [];
for (let r = 0; r < rows; r++) {
  nodes.push({
    type: "rectangle",
    name: "Bar " + (r + 1),
    x: 0,
    y: r * (cellH + pencil.input.gap),
    width: pencil.width,
    height: cellH * Math.random(),
    fill: pencil.input.color,
  });
}

return nodes;
```

## Shaders

The `shader` fill type can be used to create complex graphics effects using WebGL shaders. The `shader` effect type runs the same kind of shader over the rendered node instead (see Shader effects below).

- Shaders are WebGL 1.0 fragment shaders (#version 100), with one addition: textureSize(sampler, lod) is available for aspect-correct texturing.
- Supported uniform types:
  - float, int: as numbers
  - vec2/3/4, ivec2/3/4: as arrays of numbers or "#RRGGBB" strings for colors
  - sampler2D: as image URL strings (loaded as with UNPACK_FLIP_Y_WEBGL, so `texture2D(tex, gl_FragCoord.xy / resolution)` shows the image upright), or one of these special URLs:
    - "pencil:object": the node's own rendering below the shader, over transparent: in a fill the fills under it (plus the node's effects drawn before fills, like shadows), in a stroke additionally all fills, in an effect every fill, stroke and earlier effect. Texels are premultiplied by alpha, like gl_FragColor; outside the node it is transparent.
    - "pencil:background": the content rendered behind the node, with nothing of the node itself. Outside the node it mirrors. Offset/distort the sampling coordinate for refraction-like effects. Ideal for glass/frosted/refraction/magnifier effects. Prefer "pencil:background" over faking the background.
- Uniforms can be annotated with special comments:
  - @color: marks vec3 or vec4 uniforms to use color picker controls.
  - @default: sets the default value for the uniform.
  - @resolution: set to the resolution of the output. e.g. can be used to normalize gl_FragCoord.
  - @mouse: set to the mouse position in the same space as gl_FragCoord. For interactive effects.
  - @time: set to the elapsed time in seconds. For animations.
  - @sdf: a sampler2D set to an SDF texture of the node's shape (in a shader effect: of the rendered content). The r channel holds the signed distance in @resolution units (positive = inside). The gb channels hold the gradient of the distance field (direction of increasing distance), in texel space. Use gb instead of numerically differentiating the r channel!
  - @mipmap: the texture will be mipmapped. Off by default. Turn it on when the sample coordinate varies smoothly (glass, refraction, blur); keep it off when it jumps between neighboring pixels (pixelation, mosaics, high-frequency turbulence).
  - @min/@max: set the range of a uniform for better UI controls. Only applies to number uniforms.
  - @range <min>, <max>: shorthand for @min and @max on the same line. Shows a slider in the UI.
  - @label <text>: sets the uniform's display name in the UI. Always set the label.

```glsl
/** @resolution */
uniform vec2 u_resolution;

/**
 * @label Size
 * @default 32
 */
uniform float u_size;

/**
 * @label Primary Color
 * @color
 * @default #ffffff
 */
uniform vec3 u_color1;

/**
 * @label Secondary Color
 * @color
 * @default #000000
 */
uniform vec3 u_color2;

void main() {
  vec2 cell = floor(gl_FragCoord.xy / u_size);
  float check = mod(cell.x + cell.y, 2.0);
  vec3 color = mix(u_color1, u_color2, check);
  gl_FragColor = vec4(color, 1.0);
}
```

### Shader effects

A `shader` effect (`effect: { type: "shader", url, uniforms }`) post-processes the node: the node, its children and its other effects are rendered into the `pencil:object` texture, and the shader's output is drawn in place of the node. Use it for distortion, pixelation, color grading, glitch and similar effects on existing content. Use a shader fill when the shader generates the image itself. `pencil:object` and `pencil:background` mean the same in fills and effects, so a shader written for one works as the other; a `pencil:background` shader (glass, ripple, ...) refracts what is behind the node either way.

- `@resolution` and `gl_FragCoord` are the same as for a fill: the node's size and the node's own coordinates. The shader is run over the node's visual bounds (strokes, shadows, blur, unclipped children included), so there `gl_FragCoord` goes outside `0..@resolution`, and `pencil:object`, `@sdf` and `pencil:background` cover those bounds too: uv outside `0..1` samples them.
- Multiple shader effects are chained in list order: each one's `pencil:object` is the output of the previous one.
- `@sdf` is the SDF of the content's alpha channel (edge at 50% alpha), so shadows, blurs and earlier shader effects on the node move the edge.
- `pencil:object` is rendered over transparent, so blend modes inside the node only blend with the node's own content below them. A blend mode that reaches the bottom of the node (nothing opaque under it) blends with the scene when drawn normally, but not inside `pencil:object`.
- Combine `pencil:object` and `pencil:background`: distort the shape with `pencil:object` and refract `pencil:background` through the result for a glass effect on a distorted node.

```glsl
/** @resolution */
uniform vec2 u_resolution;

/** @label Content */
uniform sampler2D u_content;

/**
 * @label Pixel Size
 * @default 8
 * @range 1, 64
 */
uniform float u_pixelSize;

void main() {
  vec2 cell = (floor(gl_FragCoord.xy / u_pixelSize) + 0.5) * u_pixelSize;
  gl_FragColor = texture2D(u_content, cell / u_resolution);
}
```

```json
{ "type": "shader", "url": "pixelate.glsl", "uniforms": { "u_content": "pencil:object" } }
```
