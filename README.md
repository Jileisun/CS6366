# CG Project Scenes

Real-time GLSL scenes rendered with Three.js fullscreen quads.

The project now exposes four primary views:

- `Main`: Terrain Explorer ground plus bounded Apollo and Mandelbulb fractal actors
- `Terrain`: standalone Terrain Explorer study with live controls
- `Apollo`: the earlier standalone Apollonian shader with live controls
- `Mandelbulb`: the standalone Mandelbulb render with live controls

## Run

Serve the folder with any local static server, for example:

```bash
python3 -m http.server 8000
```

Then open one of:

- `http://localhost:8000/`
- `http://localhost:8000/terrain.html`
- `http://localhost:8000/apollo.html`
- `http://localhost:8000/mandelbulb.html`

## Controls

- `Main` and `Terrain`
  Mouse drag looks around and mouse wheel zooms.
- `Main`
  The right-side panel switches the terrain ground mode used under the hybrid world scene.
- `Terrain`
  The right-side panel adjusts height, lacunarity, persistence, shape, and ground mode.
- `Apollo`
  Mouse drag steers the orbit, mouse wheel zooms, and the right-side panel adjusts the legacy Apollonian fractal.
- `Mandelbulb`
  Mouse drag orbits, mouse wheel zooms, and the right-side panel updates Mandelbulb parameters in real time.

## Layout

```text
CG_project/
├── index.html
├── terrain.html
├── apollo.html
├── mandelbulb.html
├── app.js
├── terrain.js
├── apollo.js
├── mandelbulb.js
├── js/
│   ├── sceneRegistry.js
│   ├── sceneChrome.js
│   ├── startScene.js
│   ├── explorerSceneRunner.js
│   ├── apolloSceneRunner.js
│   ├── mandelbulbSceneRunner.js
│   ├── parameterPanel.js
│   └── setup.js
└── glsl/
    ├── scene_main_combined.fs.glsl
    ├── scene_terrain_explorer.fs.glsl
    ├── apollo_pure.fs.glsl
    └── scene_mandelbulb.fs.glsl
```

`ref/` is kept only for local references and archived experiments. It is ignored by git and is not part of the published repository.

## Scene Setup

- `scene_terrain_explorer.fs.glsl` adapts the `ref/shadertoys/terrain_explorer` reference into a standalone parameterized terrain scene.
- `scene_main_combined.fs.glsl` reuses that terrain base and adds bounded Apollo and Mandelbulb fractal actors over the heightfield.
- `apollo.html` stays on the previous standalone Apollonian shader rather than using the Apollo Trees layer.
- `mandelbulb.html` keeps the current standalone Mandelbulb scene.
- The in-page navigation only lists the four primary scenes now.
