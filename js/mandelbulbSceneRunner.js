import * as THREE from "./three.module.js";
import { createQuad, loadShaderSource } from "./setup.js";

const PARAMETER_SPECS = [
  { key: "power", label: "Power", min: 2.0, max: 12.0, step: 0.1, format: (value) => value.toFixed(1) },
  { key: "iterations", label: "Iterations", min: 3, max: 12, step: 1, format: (value) => String(Math.round(value)) },
  { key: "bailout", label: "Bailout", min: 1.5, max: 8.0, step: 0.1, format: (value) => value.toFixed(1) },
  { key: "scale", label: "Scale", min: 0.55, max: 1.8, step: 0.01, format: (value) => value.toFixed(2) },
  { key: "spinSpeed", label: "Spin", min: 0.0, max: 1.0, step: 0.01, format: (value) => value.toFixed(2) },
  { key: "phaseStrength", label: "Phase", min: 0.0, max: 1.2, step: 0.01, format: (value) => value.toFixed(2) },
  { key: "phaseSpeed", label: "Phase Speed", min: 0.0, max: 1.0, step: 0.01, format: (value) => value.toFixed(2) },
];

function ensureParameterPanelStyles() {
  if (document.getElementById("mandelbulb-parameter-styles")) return;

  const style = document.createElement("style");
  style.id = "mandelbulb-parameter-styles";
  style.textContent = `
    .mandelbulb-parameters {
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

    .mandelbulb-parameters h2 {
      margin: 0;
      font-size: 18px;
      line-height: 1.2;
      font-weight: 600;
    }

    .mandelbulb-parameters p {
      margin: 8px 0 0;
      font-size: 12px;
      line-height: 1.45;
      color: rgba(242, 238, 229, 0.78);
    }

    .mandelbulb-parameter-list {
      display: grid;
      gap: 12px;
      margin-top: 14px;
    }

    .mandelbulb-parameter-row {
      display: grid;
      gap: 6px;
    }

    .mandelbulb-parameter-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      font-size: 12px;
      color: rgba(242, 238, 229, 0.88);
    }

    .mandelbulb-parameter-value {
      color: rgba(174, 220, 191, 0.96);
      font-variant-numeric: tabular-nums;
    }

    .mandelbulb-parameter-slider {
      width: 100%;
      margin: 0;
      accent-color: #86b48f;
    }

    .mandelbulb-parameter-actions {
      display: flex;
      justify-content: flex-end;
      margin-top: 14px;
    }

    .mandelbulb-parameter-reset {
      padding: 8px 12px;
      border: 1px solid rgba(242, 238, 229, 0.16);
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.03);
      color: rgba(242, 238, 229, 0.88);
      font: inherit;
      cursor: pointer;
    }

    .mandelbulb-parameter-reset:hover {
      background: rgba(255, 255, 255, 0.08);
      border-color: rgba(242, 238, 229, 0.24);
    }
  `;
  document.head.appendChild(style);
}

function mountParameterPanel(initialParams, onUpdate, onReset) {
  ensureParameterPanelStyles();

  const existing = document.querySelector(".mandelbulb-parameters");
  if (existing) existing.remove();

  const panel = document.createElement("section");
  panel.className = "mandelbulb-parameters";
  panel.innerHTML = `
    <h2>Fractal Parameters</h2>
    <p>These sliders update the standalone Mandelbulb in real time. The main scene does not load this shader.</p>
    <div class="mandelbulb-parameter-list"></div>
    <div class="mandelbulb-parameter-actions">
      <button type="button" class="mandelbulb-parameter-reset">Reset</button>
    </div>
  `;

  const list = panel.querySelector(".mandelbulb-parameter-list");
  const controlRefs = new Map();

  for (const spec of PARAMETER_SPECS) {
    const row = document.createElement("label");
    row.className = "mandelbulb-parameter-row";

    const head = document.createElement("div");
    head.className = "mandelbulb-parameter-head";

    const title = document.createElement("span");
    title.textContent = spec.label;

    const value = document.createElement("span");
    value.className = "mandelbulb-parameter-value";
    value.textContent = spec.format(initialParams[spec.key]);

    head.append(title, value);

    const slider = document.createElement("input");
    slider.className = "mandelbulb-parameter-slider";
    slider.type = "range";
    slider.min = String(spec.min);
    slider.max = String(spec.max);
    slider.step = String(spec.step);
    slider.value = String(initialParams[spec.key]);

    slider.addEventListener("input", () => {
      const nextValue = Number(slider.value);
      value.textContent = spec.format(nextValue);
      onUpdate(spec.key, nextValue);
    });

    controlRefs.set(spec.key, { slider, value });
    row.append(head, slider);
    list.appendChild(row);
  }

  panel.querySelector(".mandelbulb-parameter-reset").addEventListener("click", onReset);
  document.body.appendChild(panel);

  return {
    panel,
    setValues(nextParams) {
      for (const spec of PARAMETER_SPECS) {
        const controls = controlRefs.get(spec.key);
        if (!controls) continue;
        controls.slider.value = String(nextParams[spec.key]);
        controls.value.textContent = spec.format(nextParams[spec.key]);
      }
    },
  };
}

async function buildMandelbulbShaders() {
  const [vertexShader, fragmentShader] = await Promise.all([
    loadShaderSource("./glsl/fullscreen.vs.glsl"),
    loadShaderSource("./glsl/scene_mandelbulb_spore.fs.glsl"),
  ]);

  return {
    vertexShader,
    fragmentShader,
  };
}

export async function runMandelbulbScene(sceneConfig) {
  const renderer = new THREE.WebGLRenderer({
    antialias: false,
    powerPreference: "high-performance",
  });
  document.body.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const quadCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  const clock = new THREE.Clock();
  const defaultParams = { ...sceneConfig.mandelbulbParams };
  const params = { ...defaultParams };

  const uniforms = {
    iResolution: { value: new THREE.Vector3(1, 1, 1) },
    iTime: { value: 0 },
    uZoom: { value: sceneConfig.initialView.zoom },
    uMbPower: { value: params.power },
    uMbIterations: { value: params.iterations },
    uMbBailout: { value: params.bailout },
    uMbScale: { value: params.scale },
    uMbSpinSpeed: { value: params.spinSpeed },
    uMbPhaseStrength: { value: params.phaseStrength },
    uMbPhaseSpeed: { value: params.phaseSpeed },
    uMbYaw: { value: sceneConfig.initialView.angles[0] },
    uMbPitch: { value: sceneConfig.initialView.angles[1] },
  };

  let zoom = sceneConfig.initialView.zoom;
  let isDragging = false;
  let lastPointerX = 0;
  let lastPointerY = 0;
  let yaw = sceneConfig.initialView.angles[0];
  let pitch = sceneConfig.initialView.angles[1];

  function syncUniforms() {
    uniforms.uMbPower.value = params.power;
    uniforms.uMbIterations.value = params.iterations;
    uniforms.uMbBailout.value = params.bailout;
    uniforms.uMbScale.value = params.scale;
    uniforms.uMbSpinSpeed.value = params.spinSpeed;
    uniforms.uMbPhaseStrength.value = params.phaseStrength;
    uniforms.uMbPhaseSpeed.value = params.phaseSpeed;
  }

  function updateResolution() {
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.25));
    renderer.setSize(window.innerWidth, window.innerHeight);
    uniforms.iResolution.value.set(
      renderer.domElement.width,
      renderer.domElement.height,
      1,
    );
  }

  function updateViewAngles() {
    uniforms.uMbYaw.value = yaw;
    uniforms.uMbPitch.value = pitch;
  }

  function dragView(event) {
    const dx = event.clientX - lastPointerX;
    const dy = event.clientY - lastPointerY;
    lastPointerX = event.clientX;
    lastPointerY = event.clientY;

    yaw -= dx * 0.006;
    pitch += dy * 0.004;
    pitch = THREE.MathUtils.clamp(pitch, -Math.PI * 0.46, Math.PI * 0.46);
    updateViewAngles();
  }

  renderer.domElement.style.touchAction = "none";
  renderer.domElement.addEventListener("pointerdown", (event) => {
    isDragging = true;
    lastPointerX = event.clientX;
    lastPointerY = event.clientY;
    renderer.domElement.setPointerCapture(event.pointerId);
  });
  renderer.domElement.addEventListener("pointermove", (event) => {
    if (isDragging) dragView(event);
  });
  renderer.domElement.addEventListener("pointerup", (event) => {
    isDragging = false;
    try {
      renderer.domElement.releasePointerCapture(event.pointerId);
    } catch {}
  });
  renderer.domElement.addEventListener("pointercancel", () => {
    isDragging = false;
  });

  renderer.domElement.addEventListener("wheel", (event) => {
    event.preventDefault();
    zoom = THREE.MathUtils.clamp(zoom - event.deltaY * 0.0012, 0, 1);
    uniforms.uZoom.value = zoom;
  }, { passive: false });

  window.addEventListener("resize", updateResolution);

  const parameterPanel = mountParameterPanel(
    params,
    (key, value) => {
      params[key] = value;
      syncUniforms();
    },
    () => {
      Object.assign(params, defaultParams);
      syncUniforms();
      parameterPanel.setValues(params);
    },
  );

  const { vertexShader, fragmentShader } = await buildMandelbulbShaders();
  const material = new THREE.ShaderMaterial({
    uniforms,
    vertexShader,
    fragmentShader,
  });

  scene.add(createQuad(material));
  updateViewAngles();
  updateResolution();

  renderer.setAnimationLoop(() => {
    uniforms.iTime.value = clock.getElapsedTime();
    renderer.render(scene, quadCamera);
  });
}
