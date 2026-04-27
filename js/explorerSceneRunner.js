import * as THREE from "./three.module.js";
import { createQuad, loadShaderSource } from "./setup.js";
import { mountParameterPanel } from "./parameterPanel.js";

function clampViewPitch(value) {
  return THREE.MathUtils.clamp(value, -Math.PI * 0.45, Math.PI * 0.45);
}

function createSceneUniforms(sceneConfig) {
  const params = { ...sceneConfig.shaderParams };
  const uniforms = {
    iResolution: { value: new THREE.Vector3(1, 1, 1) },
    iTime: { value: 0 },
    iMouse: { value: new THREE.Vector4(0, 0, 0, 0) },
    uViewAz: { value: sceneConfig.initialView.angles[0] },
    uViewEl: { value: sceneConfig.initialView.angles[1] },
    uViewZoom: { value: sceneConfig.initialView.zoom },
  };

  for (const [paramKey, uniformName] of Object.entries(sceneConfig.uniformBindings ?? {})) {
    uniforms[uniformName] = { value: params[paramKey] };
  }

  return { params, uniforms };
}

export async function runExplorerScene(sceneConfig) {
  const renderer = new THREE.WebGLRenderer({
    antialias: false,
    powerPreference: "high-performance",
  });
  renderer.domElement.style.cssText = "display:block;width:100%;height:100%;touch-action:none";
  document.body.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const quadCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  const clock = new THREE.Clock();
  const { params, uniforms } = createSceneUniforms(sceneConfig);
  const defaultParams = { ...params };

  let azimuth = sceneConfig.initialView.angles[0];
  let elevation = sceneConfig.initialView.angles[1];
  let zoom = sceneConfig.initialView.zoom;
  let isDragging = false;
  let lastPointerX = 0;
  let lastPointerY = 0;

  function applyBoundParams() {
    for (const [paramKey, uniformName] of Object.entries(sceneConfig.uniformBindings ?? {})) {
      uniforms[uniformName].value = params[paramKey];
    }
  }

  function updateViewUniforms() {
    uniforms.uViewAz.value = azimuth;
    uniforms.uViewEl.value = elevation;
    uniforms.uViewZoom.value = zoom;
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

  function onPointerMove(event) {
    uniforms.iMouse.value.x = event.clientX;
    uniforms.iMouse.value.y = event.clientY;

    if (!isDragging) return;

    const dx = event.clientX - lastPointerX;
    const dy = event.clientY - lastPointerY;
    lastPointerX = event.clientX;
    lastPointerY = event.clientY;

    azimuth -= dx * 0.006;
    elevation = clampViewPitch(elevation + dy * 0.004);
    updateViewUniforms();
  }

  function onPointerDown(event) {
    if (event.button !== 0) return;
    isDragging = true;
    lastPointerX = event.clientX;
    lastPointerY = event.clientY;
    uniforms.iMouse.value.z = 1.0;
    renderer.domElement.setPointerCapture(event.pointerId);
  }

  function releasePointer(event) {
    isDragging = false;
    uniforms.iMouse.value.z = 0.0;
    if (event) renderer.domElement.releasePointerCapture(event.pointerId);
  }

  function onWheel(event) {
    event.preventDefault();
    zoom = THREE.MathUtils.clamp(
      zoom * Math.exp(-event.deltaY * 0.0012),
      sceneConfig.zoomRange?.[0] ?? 0.65,
      sceneConfig.zoomRange?.[1] ?? 2.2,
    );
    updateViewUniforms();
  }

  const [vertexShader, fragmentShader] = await Promise.all([
    loadShaderSource("./glsl/fullscreen.vs.glsl"),
    loadShaderSource(sceneConfig.fragmentShader),
  ]);

  const material = new THREE.ShaderMaterial({
    uniforms,
    vertexShader,
    fragmentShader,
  });

  scene.add(createQuad(material));
  applyBoundParams();
  updateViewUniforms();
  updateResolution();

  window.addEventListener("resize", updateResolution);
  renderer.domElement.addEventListener("pointermove", onPointerMove);
  renderer.domElement.addEventListener("pointerdown", onPointerDown);
  renderer.domElement.addEventListener("pointerup", releasePointer);
  renderer.domElement.addEventListener("pointercancel", releasePointer);
  renderer.domElement.addEventListener("wheel", onWheel, { passive: false });

  let panelHandle = null;
  if (sceneConfig.parameterPanel) {
    panelHandle = mountParameterPanel({
      ...sceneConfig.parameterPanel,
      initialValues: params,
      onUpdate(key, value) {
        params[key] = value;
        applyBoundParams();
      },
      onReset() {
        Object.assign(params, defaultParams);
        applyBoundParams();
        panelHandle?.setValues(params);
      },
    });
  }

  renderer.setAnimationLoop(() => {
    uniforms.iTime.value = clock.getElapsedTime();
    renderer.render(scene, quadCamera);
  });
}
