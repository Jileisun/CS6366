import * as THREE from "./three.module.js";
import { createQuad, loadShaderSource } from "./setup.js";
import { mountParameterPanel } from "./parameterPanel.js";

const UNIFORM_BINDINGS = {
  scale: "uApolloScale",
  iterations: "uApolloIterations",
  inset: "uApolloInset",
  inversion: "uApolloInversion",
  orbitRadius: "uApolloOrbitRadius",
  orbitSpeed: "uApolloOrbitSpeed",
  gain: "uApolloGain",
};

export async function runApolloScene(sceneConfig) {
  const renderer = new THREE.WebGLRenderer({
    antialias: false,
    powerPreference: "high-performance",
  });
  renderer.domElement.style.cssText = "display:block;width:100%;height:100%";
  document.body.style.cssText = "margin:0;overflow:hidden;background:#000";
  document.body.appendChild(renderer.domElement);

  const scene  = new THREE.Scene();
  const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  const clock  = new THREE.Clock();
  const params = { ...sceneConfig.apolloParams };
  const defaultParams = { ...params };

  const uniforms = {
    iResolution: { value: new THREE.Vector3(1, 1, 1) },
    iTime:       { value: 0 },
    iMouse:      { value: new THREE.Vector4(0, 0, 0, 0) },
    uApolloScale: { value: params.scale },
    uApolloIterations: { value: params.iterations },
    uApolloInset: { value: params.inset },
    uApolloInversion: { value: params.inversion },
    uApolloOrbitRadius: { value: params.orbitRadius },
    uApolloOrbitSpeed: { value: params.orbitSpeed },
    uApolloGain: { value: params.gain },
  };

  function applyParams() {
    for (const [key, uniformName] of Object.entries(UNIFORM_BINDINGS)) {
      uniforms[uniformName].value = params[key];
    }
  }

  function resize() {
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1));
    renderer.setSize(window.innerWidth, window.innerHeight);
    uniforms.iResolution.value.set(
      renderer.domElement.width,
      renderer.domElement.height,
      1,
    );
  }
  window.addEventListener("resize", resize);

  renderer.domElement.addEventListener("pointermove", (e) => {
    uniforms.iMouse.value.x = e.clientX;
    uniforms.iMouse.value.y = e.clientY;
  });

  const [vertexShader, fragmentShader] = await Promise.all([
    loadShaderSource("./glsl/fullscreen.vs.glsl"),
    loadShaderSource("./glsl/apollo_pure.fs.glsl"),
  ]);

  const material = new THREE.ShaderMaterial({ uniforms, vertexShader, fragmentShader });
  scene.add(createQuad(material));
  applyParams();
  resize();

  let panelHandle = null;
  if (sceneConfig.parameterPanel) {
    panelHandle = mountParameterPanel({
      ...sceneConfig.parameterPanel,
      initialValues: params,
      onUpdate(key, value) {
        params[key] = value;
        applyParams();
      },
      onReset() {
        Object.assign(params, defaultParams);
        applyParams();
        panelHandle?.setValues(params);
      },
    });
  }

  renderer.setAnimationLoop(() => {
    uniforms.iTime.value = clock.getElapsedTime();
    renderer.render(scene, camera);
  });
}
