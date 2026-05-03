const RANGE_2 = (value) => value.toFixed(2);

const DEFAULT_TERRAIN_EXPLORER_PARAMS = {
  height: 0.6,
  lacunarity: 0.6,
  persistence: 0.7,
  shape: 0.5,
  flight: 0.18,
  groundMode: 1,
  qualityMode: 2,
  sunMode: 1,
};

const TERRAIN_UNIFORM_BINDINGS = {
  height: "uTerrHeight",
  lacunarity: "uTerrLacunarity",
  persistence: "uTerrPersistence",
  shape: "uTerrShape",
  flight: "uTerrFlightSpeed",
  groundMode: "uTerrGroundMode",
  qualityMode: "uTerrQualityMode",
  sunMode: "uTerrSunMode",
};

const TERRAIN_PANEL_SPECS = [
  { key: "height", label: "Height", min: 0.0, max: 1.0, step: 0.01, format: RANGE_2 },
  { key: "lacunarity", label: "Lacunarity", min: 0.0, max: 1.0, step: 0.01, format: RANGE_2 },
  { key: "persistence", label: "Persistence", min: 0.0, max: 1.0, step: 0.01, format: RANGE_2 },
  { key: "shape", label: "Shape", min: 0.0, max: 1.0, step: 0.01, format: RANGE_2 },
  {
    key: "groundMode",
    label: "Ground Mode",
    type: "select",
    options: [
      { value: 1, label: "1 Basic fBm" },
      { value: 2, label: "2 Elevated" },
      { value: 3, label: "3 Wave Cut" },
      { value: 4, label: "4 Sirenian" },
    ],
  },
];

const MAIN_PANEL_SPECS = [
  {
    key: "groundMode",
    label: "Ground Mode",
    type: "select",
    options: [
      { value: 1, label: "1 Basic fBm" },
      { value: 2, label: "2 Elevated" },
      { value: 3, label: "3 Wave Cut" },
      { value: 4, label: "4 Sirenian" },
    ],
  },
];

const DEFAULT_MAIN_PARAMS = {
  ...DEFAULT_TERRAIN_EXPLORER_PARAMS,
  height: 0.64,
  shape: 0.58,
  flight: 0.14,
  qualityMode: 3,
  sunMode: 2,
  apolloScale: 0.2,
  apolloLift: 5.5,
  apolloGap: 9.0,
  apolloGain: 1.15,
  apolloDrift: 0.8,
};

const MAIN_UNIFORM_BINDINGS = {
  ...TERRAIN_UNIFORM_BINDINGS,
  apolloScale: "uApolloTreeScale",
  apolloLift: "uApolloTreeLift",
  apolloGap: "uApolloTreeGap",
  apolloGain: "uApolloTreeGain",
  apolloDrift: "uApolloTreeDrift",
};

const DEFAULT_APOLLO_PARAMS = {
  scale: 1.0,
  iterations: 6,
  inset: 0.04,
  inversion: 0.48,
  orbitRadius: 2.8,
  orbitSpeed: 1.0,
  gain: 1.0,
};

const APOLLO_PANEL_SPECS = [
  { key: "scale", label: "Scale", min: 0.45, max: 1.8, step: 0.01, format: RANGE_2 },
  { key: "iterations", label: "Iterations", min: 4, max: 10, step: 1, format: (value) => String(Math.round(value)) },
  { key: "inset", label: "Inset", min: 0.0, max: 0.12, step: 0.001, format: RANGE_2 },
  { key: "inversion", label: "Inversion", min: 0.18, max: 1.08, step: 0.01, format: RANGE_2 },
  { key: "orbitSpeed", label: "Orbit Speed", min: 0.2, max: 1.8, step: 0.01, format: RANGE_2 },
];

const sceneEntries = [
  {
    key: "main",
    label: "Main",
    href: "./index.html",
    runtime: "explorer",
    title: "Main Scene",
    description: "Hybrid world scene: Terrain Explorer ground plus bounded Apollo tree-forms and floating Mandelbulb fractal actors.",
    controls: "Mouse drag to look. Mouse wheel to zoom. The right-side selector switches the terrain ground mode.",
    fragmentShader: "./glsl/scene_main_combined.fs.glsl",
    initialView: {
      angles: [0.0, -0.08],
      zoom: 1.0,
    },
    zoomRange: [0.7, 2.1],
    shaderParams: { ...DEFAULT_MAIN_PARAMS },
    uniformBindings: { ...MAIN_UNIFORM_BINDINGS },
    parameterPanel: {
      specs: MAIN_PANEL_SPECS,
      compact: true,
      showReset: false,
      showValue: false,
    },
  },
  {
    key: "terrain",
    label: "Terrain",
    href: "./terrain.html",
    runtime: "explorer",
    title: "Terrain Explorer",
    description: "Standalone terrain study based on the Terrain Explorer reference, with live controls for the landscape model.",
    controls: "Mouse drag to look. Mouse wheel to zoom. Right-side controls adjust the terrain form.",
    fragmentShader: "./glsl/scene_terrain_explorer.fs.glsl",
    initialView: {
      angles: [0.0, -0.1],
      zoom: 1.0,
    },
    zoomRange: [0.7, 2.1],
    shaderParams: { ...DEFAULT_TERRAIN_EXPLORER_PARAMS },
    uniformBindings: { ...TERRAIN_UNIFORM_BINDINGS },
    parameterPanel: {
      title: "Terrain Parameters",
      description: "This scene uses the Terrain Explorer reference. Adjust the terrain form in real time while flight speed, quality, and sun stay fixed.",
      specs: TERRAIN_PANEL_SPECS,
    },
  },
  {
    key: "apollo",
    label: "Apollo",
    href: "./apollo.html",
    runtime: "apollo",
    title: "Apollo Scene",
    description: "The previous standalone Apollonian scene stays here. It is separate from the Apollo Trees layer used in the main scene.",
    controls: "Mouse drag steers the orbit. Mouse wheel zooms. Right-side controls tune the standalone Apollonian fractal.",
    apolloParams: { ...DEFAULT_APOLLO_PARAMS },
    parameterPanel: {
      title: "Apollo Parameters",
      description: "This page keeps the earlier standalone Apollonian shader. The controls stay manual here, and the inversion range stays closer to the reference.",
      specs: APOLLO_PANEL_SPECS,
    },
  },
  {
    key: "mandelbulb",
    label: "Mandelbulb",
    href: "./mandelbulb.html",
    runtime: "mandelbulb",
    title: "Mandelbulb",
    description: "Standalone Mandelbulb render with live fractal controls.",
    controls: "Mouse drag to orbit. Mouse wheel to zoom. Power and phase stay manual here while bailout and spin stay fixed.",
    initialView: {
      zoom: 0.52,
      angles: [0.0, 0.86],
    },
    mandelbulbParams: {
      power: 8.0,
      iterations: 7,
      bailout: 2.0,
      scale: 1.0,
      spinSpeed: 0.0,
      phaseStrength: 0.22,
      phaseSpeed: 0.18,
    },
  },
];

const sceneMap = new Map(sceneEntries.map((entry) => [entry.key, entry]));

export const sceneLinks = sceneEntries.map(({ key, label, href }) => ({
  key,
  label,
  href,
}));

export function getSceneConfig(key) {
  const scene = sceneMap.get(key);
  if (!scene) {
    throw new Error(`Unknown scene: ${key}`);
  }
  return scene;
}
