# CG Project Scenes

Real-time GLSL scenes rendered with Three.js fullscreen quads.

The project now exposes four primary views:

- `Main`: Terrain Explorer terrain plus an Apollo Trees glow layer
- `Terrain`: standalone Terrain Explorer study with live controls
- `Apollo`: the earlier standalone Apollonian shader with live controls
- `Spore`: the standalone Mandelbulb spore render with live controls

## Run

Serve the folder with any local static server, for example:

```bash
python3 -m http.server 8000
```

Then open one of:

- `http://localhost:8000/`
- `http://localhost:8000/terrain.html`
- `http://localhost:8000/apollo.html`
- `http://localhost:8000/spore.html`

Legacy aliases still work:

- `vine.html` and `arch.html` open the `Apollo` scene
- `mandelbulb.html` and `spore-plants.html` open the `Spore` scene

## Controls

- `Main` and `Terrain`
  Mouse drag looks around and mouse wheel zooms.
- `Terrain`
  The right-side panel adjusts height, lacunarity, persistence, shape, flight speed, ground mode, quality, and sun mode.
- `Apollo`
  Mouse movement biases the orbit and the right-side panel adjusts the legacy Apollonian fractal.
- `Spore`
  Mouse drag orbits, mouse wheel zooms, and the right-side panel updates Mandelbulb parameters in real time.

## Layout

```text
CG_project/
├── index.html
├── terrain.html
├── apollo.html
├── spore.html
├── app.js
├── terrain.js
├── apollo.js
├── spore.js
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
    └── scene_mandelbulb_spore.fs.glsl
```

## Scene Setup

- `scene_terrain_explorer.fs.glsl` adapts the `ref/shadertoys/terrain_explorer` reference into a standalone parameterized terrain scene.
- `scene_main_combined.fs.glsl` reuses that terrain base and adds an Apollo Trees inspired glow layer derived from `ref/shadertoys/apollo trees`.
- `apollo.html` stays on the previous standalone Apollonian shader rather than using the Apollo Trees layer.
- `spore.html` keeps the current standalone Mandelbulb spore scene.
- The in-page navigation only lists the four primary scenes now.
