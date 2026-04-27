// setup.js
// Shared fullscreen shader helpers.

import * as THREE from "./three.module.js";

export function setup() {
  const renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(window.innerWidth, window.innerHeight);
  document.body.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const quadCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);

  return { renderer, scene, quadCamera };
}

export function createQuad(material) {
  const geometry = new THREE.PlaneGeometry(2, 2);
  const quad = new THREE.Mesh(geometry, material);
  quad.frustumCulled = false;
  return quad;
}

export async function loadShaderSource(path) {
  const response = await fetch(path);
  if (!response.ok) throw new Error(`Failed to load shader: ${path}`);
  return response.text();
}
