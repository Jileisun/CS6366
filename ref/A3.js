import { setup, loadAndPlaceGLB } from "./js/setup.js";
import * as THREE from "./js/three.module.js";
import { SourceLoader } from "./js/SourceLoader.js";
import { THREEx } from "./js/KeyboardState.js";

// Setup and return the scene and related objects.
// You should look into js/setup.js to see what exactly is done here.
const { renderer, scene, camera, worldFrame } = setup();

// Used THREE.Clock for animation
var clock = new THREE.Clock();

/////////////////////////////////
//   YOUR WORK STARTS BELOW    //
/////////////////////////////////

// Initialize uniforms

// As in A1 we position the sphere in the world solely using this uniform
// So the initial y-offset being 1.0 here is intended.
const sphereOffset = { type: "v3", value: new THREE.Vector3(0.0, 1.0, 0.0) };

// Distance threshold beyond which the dog should shoot lasers at the sphere (needed for Q1c).
const LaserDistance = 10.0;

const waveDistance = 10.0;

// TODO: you may want to add more const's or var's to implement
// the dog waving its tail

// Materials: specifying uniforms and shaders
const sphereMaterial = new THREE.ShaderMaterial({
  uniforms: {
    sphereOffset: sphereOffset,
  },
});

const eyeMaterial = new THREE.ShaderMaterial();

// TODO: make necessary changes to implement the laser eyes

// Load shaders.
const shaderFiles = [
  "glsl/sphere.vs.glsl",
  "glsl/sphere.fs.glsl",
  "glsl/eye.vs.glsl",
  "glsl/eye.fs.glsl",
];

new SourceLoader().load(shaderFiles, function (shaders) {
  sphereMaterial.vertexShader = shaders["glsl/sphere.vs.glsl"];
  sphereMaterial.fragmentShader = shaders["glsl/sphere.fs.glsl"];

  eyeMaterial.vertexShader = shaders["glsl/eye.vs.glsl"];
  eyeMaterial.fragmentShader = shaders["glsl/eye.fs.glsl"];
});

// Load and place the dog geometry
// Look at the definition of loadOBJ to familiarize yourself with how each parameter
// affects the loaded object.

// TODO: Load and place the dog geometry in GLB format, a simple example is provided
loadAndPlaceGLB("glb/dog.glb", function (dog) {
  dog.traverse(function (child) {
    if (child instanceof THREE.SkinnedMesh) {
      var skeleton = new THREE.Skeleton(child.skeleton.bones);
      for (var i = 0; i < skeleton.bones.length; i++) {
        console.log(skeleton.bones[i].name);
        if (skeleton.bones[i].name == "Dog_Tail_01_02SHJnt_42") {
           console.log("Tail bone found");
        }
      }
    }
  });
  dog.scale.set(5, 5, 5);
  dog.position.set(0.0, 0.0, -8.0);
});


// Create the main covid sphere geometry
// https://threejs.org/docs/#api/en/geometries/SphereGeometry
const sphereGeometry = new THREE.SphereGeometry(1.0, 32.0, 32.0);
const sphere = new THREE.Mesh(sphereGeometry, sphereMaterial);
scene.add(sphere);

const sphereLight = new THREE.PointLight(0xffffff, 50.0, 100);
scene.add(sphereLight);

// Example for an eye ball
// TODO: Create two eye ball meshes from the same geometry
const eyeGeometry = new THREE.SphereGeometry(1.0, 32, 32);
const eyeScale = 0.5;

const leftEyeSocket = new THREE.Object3D();
const leftEyeSocketPos = new THREE.Vector3(-0.8, 9.2, 0.5);
leftEyeSocket.position.copy(leftEyeSocketPos);

const leftEye = new THREE.Mesh(eyeGeometry, eyeMaterial);
leftEye.scale.copy(new THREE.Vector3(eyeScale, eyeScale, eyeScale));
leftEyeSocket.add(leftEye);

scene.add(leftEyeSocket);

// Lasers
// https://threejs.org/docs/index.html#api/en/geometries/CylinderGeometry
// These could also be made with a two camera facing trinagles or quads instead of a full blown cylinder.
// The reason is that lasers have a simple geometry and don't have any fancy angle based shading (for now)


// Listen to keyboard events.
const keyboard = new THREEx.KeyboardState();
function checkKeyboard() {
  if (keyboard.pressed("W")) sphereOffset.value.z -= 0.1;
  else if (keyboard.pressed("S")) sphereOffset.value.z += 0.1;

  if (keyboard.pressed("A")) sphereOffset.value.x -= 0.1;
  else if (keyboard.pressed("D")) sphereOffset.value.x += 0.1;

  if (keyboard.pressed("E")) sphereOffset.value.y -= 0.1;
  else if (keyboard.pressed("Q")) sphereOffset.value.y += 0.1;

  // The following tells three.js that some uniforms might have changed.
  sphereMaterial.needsUpdate = true;
  eyeMaterial.needsUpdate = true;

  // Move the sphere light in the scene. This allows the floor to reflect the light as it moves.
  sphereLight.position.set(
    sphereOffset.value.x,
    sphereOffset.value.y,
    sphereOffset.value.z
  );
}

// Setup update callback
function update() {
  // TODO: make neccesary changes to implement gazing, the dog waving its tail, etc.
  checkKeyboard();
  
  // Requests the next update call, this creates a loop
  requestAnimationFrame(update);
  renderer.render(scene, camera);
}

// Start the animation loop.
update();
