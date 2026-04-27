import * as THREE from "./three.module.js";
import { createQuad, loadShaderSource } from "./setup.js";

const SHARP_MENGER_FOLD_K = 0.0001;
const DISABLED_VINE_LAYER = `
#define ENABLE_VINES 0
float vineField(vec3 pos) { return 1e8; }
vec2 vineColorInfo(vec3 pos) { return vec2(0.0); }
`;

function ensureTerrainPanelStyles() {
  if (document.getElementById("terrain-parameter-styles")) return;

  const style = document.createElement("style");
  style.id = "terrain-parameter-styles";
  style.textContent = `
    .terrain-parameters {
      position: fixed;
      top: 16px;
      right: 16px;
      z-index: 20;
      width: min(360px, calc(100vw - 32px));
      max-height: calc(100vh - 32px);
      overflow: auto;
      padding: 14px 16px 16px;
      border: 1px solid rgba(255, 244, 226, 0.14);
      border-radius: 14px;
      background: rgba(9, 14, 18, 0.74);
      box-shadow: 0 18px 50px rgba(0, 0, 0, 0.32);
      backdrop-filter: blur(18px);
    }

    .terrain-parameters h2 {
      margin: 0;
      font-size: 18px;
      line-height: 1.2;
      font-weight: 600;
    }

    .terrain-parameters p {
      margin: 8px 0 0;
      font-size: 12px;
      line-height: 1.45;
      color: rgba(242, 238, 229, 0.78);
    }

    .terrain-toggle-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      margin-top: 14px;
    }

    .terrain-toggle-copy {
      display: grid;
      gap: 4px;
    }

    .terrain-toggle-title {
      font-size: 12px;
      color: rgba(242, 238, 229, 0.88);
    }

    .terrain-toggle-caption {
      font-size: 11px;
      color: rgba(242, 238, 229, 0.60);
    }

    .terrain-toggle {
      position: relative;
      width: 52px;
      height: 30px;
      border: 0;
      padding: 0;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.12);
      cursor: pointer;
      transition: background-color 140ms ease;
    }

    .terrain-toggle.is-on {
      background: rgba(134, 180, 143, 0.72);
    }

    .terrain-toggle-knob {
      position: absolute;
      top: 3px;
      left: 3px;
      width: 24px;
      height: 24px;
      border-radius: 50%;
      background: #f2eee5;
      transition: transform 140ms ease;
    }

    .terrain-toggle.is-on .terrain-toggle-knob {
      transform: translateX(22px);
    }
  `;
  document.head.appendChild(style);
}

function mountTerrainPanel(initialState, onToggle) {
  ensureTerrainPanelStyles();

  const existing = document.querySelector(".terrain-parameters");
  if (existing) existing.remove();

  const panel = document.createElement("section");
  panel.className = "terrain-parameters";
  panel.innerHTML = `
    <h2>MengerFold Toggle</h2>
    <p>Switch between the crisp original Menger fold and the softened terrain version.</p>
    <div class="terrain-toggle-row">
      <div class="terrain-toggle-copy">
        <span class="terrain-toggle-title">Soft MengerFold</span>
        <span class="terrain-toggle-caption">Off keeps the sharper fold. On rounds the fold creases.</span>
      </div>
      <button type="button" class="terrain-toggle" aria-pressed="false" aria-label="Toggle soft MengerFold">
        <span class="terrain-toggle-knob"></span>
      </button>
    </div>
  `;

  const toggle = panel.querySelector(".terrain-toggle");
  function setState(enabled) {
    toggle.classList.toggle("is-on", enabled);
    toggle.setAttribute("aria-pressed", enabled ? "true" : "false");
  }

  setState(initialState);
  toggle.addEventListener("click", () => {
    const nextState = !toggle.classList.contains("is-on");
    setState(nextState);
    onToggle(nextState);
  });

  document.body.appendChild(panel);
}

function setDefineValue(source, defineName, value) {
  return source.replace(
    new RegExp(`#define\\s+${defineName}\\s+[^\\n]+`),
    `#define ${defineName} ${value}`,
  );
}

async function buildTerrainShaders(sceneConfig) {
  const [
    vertexShader,
    terrainShader,
    skybulbShader,
    sporePlantShader,
    vineShader,
    microbialMatShader,
    archShader,
  ] = await Promise.all([
    loadShaderSource("./glsl/fullscreen.vs.glsl"),
    loadShaderSource("./glsl/terrain.glsl"),
    loadShaderSource("./glsl/layer_mandelbulb_sky.glsl"),
    loadShaderSource("./glsl/layer_spore_plants.glsl"),
    sceneConfig.terrainLayers.vines
      ? loadShaderSource("./glsl/layer_vines.glsl")
      : Promise.resolve(DISABLED_VINE_LAYER),
    sceneConfig.terrainLayers.microbialMat
      ? loadShaderSource("./glsl/layer_microbial_mat.glsl")
      : Promise.resolve(""),
    // Apollo arch layer is always loaded so ENABLE_ARCH is always defined.
    loadShaderSource("./glsl/layer_apollo_arch.glsl"),
  ]);

  // terrain.glsl always samples skybulbField in its albedo path, so the
  // skybulb layer remains a required dependency even when disabled.
  const injectedSkybulb = setDefineValue(
    skybulbShader,
    "ENABLE_SKYBULBS",
    sceneConfig.terrainLayers.skybulbs ? 1 : 0,
  );
  const injectedBaseTerrain = setDefineValue(
    terrainShader,
    "ENABLE_BASE_TERRAIN",
    sceneConfig.terrainLayers.baseTerrain === false ? 0 : 1,
  );
  let injectedSporePlants = setDefineValue(
    sporePlantShader,
    "ENABLE_SPORE_PLANTS",
    sceneConfig.terrainLayers.sporePlants ? 1 : 0,
  );
  injectedSporePlants = setDefineValue(
    injectedSporePlants,
    "ENABLE_SPORE_PLANT_SHOWCASE",
    sceneConfig.terrainLayers.sporePlantShowcase ? 1 : 0,
  );
  const injectedArch = setDefineValue(
    archShader,
    "ENABLE_ARCH",
    sceneConfig.terrainLayers.apolloArch ? 1 : 0,
  );

  let fragmentShader = injectedBaseTerrain
    .replace("// __SKYBULB_LAYER__", injectedSkybulb)
    .replace("// __SPORE_PLANT_LAYER__", injectedSporePlants)
    .replace("// __VINE_LAYER__", vineShader)
    .replace("// __APOLLO_ARCH_LAYER__", injectedArch)
    .replace("// __TERRAIN_SURFACE_LAYERS__", microbialMatShader);

  if (sceneConfig.terrainLayers.microbialMat) {
    fragmentShader = setDefineValue(fragmentShader, "ENABLE_MICROBIAL_MAT", 1);
  }

  return { vertexShader, fragmentShader };
}

export async function runTerrainScene(sceneConfig) {
  const renderer = new THREE.WebGLRenderer({
    antialias: false,
    powerPreference: "high-performance",
  });
  document.body.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const quadCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  const clock = new THREE.Clock();
  const defaultParams = { ...sceneConfig.terrainParams };
  const params = { ...defaultParams };
  let softMengerFold = sceneConfig.terrainUi === "soft-toggle";

  const uniforms = {
    iResolution: { value: new THREE.Vector3(1, 1, 1) },
    iTime: { value: 0 },
    iMouse: { value: new THREE.Vector4(0, 0, 0, 0) },
    uZoom: { value: sceneConfig.initialView.zoom },
    uCameraOrigin: {
      value: new THREE.Vector3(
        ...(sceneConfig.cameraOrigin ?? [0.0, 11.5, 0.0]),
      ),
    },
    uTerrainFracScale: { value: params.fracScale },
    uTerrainAng1: { value: params.ang1 },
    uTerrainAng2: { value: params.ang2 },
    uTerrainShift: { value: new THREE.Vector3(params.shiftX, params.shiftY, params.shiftZ) },
    uTerrainFoldK: { value: params.foldK },
    uTerrainGridOffset: { value: new THREE.Vector2(params.gridOffsetX, params.gridOffsetZ) },
  };

  const defaultAngles = new THREE.Vector2(
    sceneConfig.initialView.angles[0],
    sceneConfig.initialView.angles[1],
  );
  const viewAngles = defaultAngles.clone();

  let hasMouseView = Boolean(sceneConfig.initialView.useMouseView);
  let isDragging = false;
  let lastPointerX = 0;
  let lastPointerY = 0;
  let zoom = sceneConfig.initialView.zoom;

  function syncUniforms() {
    uniforms.uTerrainFracScale.value = params.fracScale;
    uniforms.uTerrainAng1.value = params.ang1;
    uniforms.uTerrainAng2.value = params.ang2;
    uniforms.uTerrainShift.value.set(params.shiftX, params.shiftY, params.shiftZ);
    uniforms.uTerrainFoldK.value = softMengerFold ? params.foldK : SHARP_MENGER_FOLD_K;
    uniforms.uTerrainGridOffset.value.set(params.gridOffsetX, params.gridOffsetZ);
  }

  function applyMouseAngles(down) {
    const rx = Math.max(uniforms.iResolution.value.x, 1);
    const ry = Math.max(uniforms.iResolution.value.y, 1);

    uniforms.iMouse.value.x = (viewAngles.x / (2 * Math.PI) + 0.5) * rx;
    uniforms.iMouse.value.y = (viewAngles.y / Math.PI + 0.5) * ry;
    uniforms.iMouse.value.z = hasMouseView ? 1 : 0;
    uniforms.iMouse.value.w = down ? 1 : 0;
  }

  function updateResolution() {
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1) * 0.6);
    renderer.setSize(window.innerWidth, window.innerHeight);
    uniforms.iResolution.value.set(
      renderer.domElement.width,
      renderer.domElement.height,
      1,
    );
    applyMouseAngles(isDragging);
  }

  function dragView(event) {
    const dx = event.clientX - lastPointerX;
    const dy = event.clientY - lastPointerY;
    lastPointerX = event.clientX;
    lastPointerY = event.clientY;

    viewAngles.x -= dx * 0.006;
    viewAngles.y += dy * 0.004;
    viewAngles.y = THREE.MathUtils.clamp(viewAngles.y, -Math.PI * 0.46, Math.PI * 0.46);
    hasMouseView = true;
    applyMouseAngles(true);
  }

  renderer.domElement.style.touchAction = "none";
  renderer.domElement.addEventListener("pointerdown", (event) => {
    isDragging = true;
    lastPointerX = event.clientX;
    lastPointerY = event.clientY;
    hasMouseView = true;
    renderer.domElement.setPointerCapture(event.pointerId);
    applyMouseAngles(true);
  });
  renderer.domElement.addEventListener("pointermove", (event) => {
    if (isDragging) dragView(event);
  });
  renderer.domElement.addEventListener("pointerup", (event) => {
    isDragging = false;
    try {
      renderer.domElement.releasePointerCapture(event.pointerId);
    } catch {}
    applyMouseAngles(false);
  });
  renderer.domElement.addEventListener("pointercancel", () => {
    isDragging = false;
    applyMouseAngles(false);
  });
  renderer.domElement.addEventListener("wheel", (event) => {
    event.preventDefault();
    zoom = THREE.MathUtils.clamp(zoom - event.deltaY * 0.0012, 0, 1);
    uniforms.uZoom.value = zoom;
  }, { passive: false });

  window.addEventListener("resize", updateResolution);

  if (sceneConfig.terrainUi === "soft-toggle") {
    mountTerrainPanel(softMengerFold, (enabled) => {
      softMengerFold = enabled;
      syncUniforms();
    });
  }

  const { vertexShader, fragmentShader } = await buildTerrainShaders(sceneConfig);
  const material = new THREE.ShaderMaterial({
    uniforms,
    vertexShader,
    fragmentShader,
  });

  scene.add(createQuad(material));
  syncUniforms();
  updateResolution();

  renderer.setAnimationLoop(() => {
    uniforms.iTime.value = clock.getElapsedTime();
    renderer.render(scene, quadCamera);
  });
}
